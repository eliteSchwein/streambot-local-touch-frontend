import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool available: false
    property bool powered: false
    property bool busy: false
    property bool scanning: false
    property string busyAddress: ""
    property string lastError: ""

    property var pairedDevices: []
    property var discoveredDevices: []

    function refresh() {
        if (refreshProcess.running)
            return

        refreshProcess.exec([
            "sh",
            "-c",
            "printf '__SHOW__\\n'; "
            + "bluetoothctl show 2>/dev/null || true; "
            + "printf '__PAIRED__\\n'; "
            + "(bluetoothctl devices Paired 2>/dev/null "
            + "|| bluetoothctl paired-devices 2>/dev/null "
            + "|| true); "
            + "printf '__ALL__\\n'; "
            + "bluetoothctl devices 2>/dev/null || true; "
            + "printf '__CONNECTED__\\n'; "
            + "(bluetoothctl devices Connected 2>/dev/null || true)"
        ])
    }

    function setPowered(enabled) {
        if (busy)
            return

        busy = true
        busyAddress = ""
        lastError = ""

        actionProcess.exec([
            "bluetoothctl",
            "power",
            enabled ? "on" : "off"
        ])
    }

    function setScanning(enabled) {
        if (busy || !powered || !available)
            return

        scanning = enabled
        lastError = ""

        scanProcess.exec([
            "bluetoothctl",
            "scan",
            enabled ? "on" : "off"
        ])

        if (enabled)
            scanRefreshTimer.restart()
    }

    function pairDevice(device) {
        if (
            busy
            || !powered
            || device === null
            || device === undefined
            || !device.address
        ) {
            return
        }

        busy = true
        busyAddress = device.address
        lastError = ""

        // NoInputNoOutput handles the common "Just Works" pairing flow
        // entirely inside the touch UI. After pairing succeeds, trust and
        // connect are performed automatically.
        actionProcess.exec([
            "sh",
            "-c",
            "bluetoothctl --agent NoInputNoOutput pair "
            + shellQuote(device.address)
            + " && bluetoothctl trust "
            + shellQuote(device.address)
            + " && bluetoothctl connect "
            + shellQuote(device.address)
        ])
    }

    function connectDevice(device) {
        if (
            busy
            || !powered
            || device === null
            || device === undefined
            || !device.address
        ) {
            return
        }

        busy = true
        busyAddress = device.address
        lastError = ""

        actionProcess.exec([
            "bluetoothctl",
            "connect",
            device.address
        ])
    }

    function disconnectDevice(device) {
        if (
            busy
            || device === null
            || device === undefined
            || !device.address
        ) {
            return
        }

        busy = true
        busyAddress = device.address
        lastError = ""

        actionProcess.exec([
            "bluetoothctl",
            "disconnect",
            device.address
        ])
    }

    function forgetDevice(device) {
        if (
            busy
            || device === null
            || device === undefined
            || !device.address
        ) {
            return
        }

        busy = true
        busyAddress = device.address
        lastError = ""

        actionProcess.exec([
            "bluetoothctl",
            "remove",
            device.address
        ])
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function parseDeviceLines(text, connectedSet, pairedSet) {
        const result = []

        for (const rawLine of String(text ?? "").split(/\r?\n/)) {
            const line = rawLine.trim()
            const match = line.match(
                /^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/
            )

            if (!match)
                continue

            const address = match[1].toUpperCase()
            const name = match[2].trim()

            result.push({
                address: address,
                name: name,
                connected: connectedSet[address] === true,
                paired: pairedSet[address] === true
            })
        }

        result.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1

            return a.name.localeCompare(b.name)
        })

        return result
    }

    function parseAddressSet(text) {
        const result = ({})

        for (const rawLine of String(text ?? "").split(/\r?\n/)) {
            const match = rawLine.trim().match(
                /^Device\s+([0-9A-Fa-f:]{17})\s+/
            )

            if (match)
                result[match[1].toUpperCase()] = true
        }

        return result
    }

    function parseState(text) {
        const value = String(text ?? "")

        const pairedMarker = value.indexOf("__PAIRED__")
        const allMarker = value.indexOf("__ALL__")
        const connectedMarker = value.indexOf("__CONNECTED__")

        const showText =
            pairedMarker >= 0
            ? value.slice(0, pairedMarker)
            : value

        const pairedText =
            pairedMarker >= 0
            ? value.slice(
                pairedMarker + "__PAIRED__".length,
                allMarker >= 0 ? allMarker : value.length
            )
            : ""

        const allText =
            allMarker >= 0
            ? value.slice(
                allMarker + "__ALL__".length,
                connectedMarker >= 0
                    ? connectedMarker
                    : value.length
            )
            : ""

        const connectedText =
            connectedMarker >= 0
            ? value.slice(
                connectedMarker + "__CONNECTED__".length
            )
            : ""

        root.available =
            /Controller\s+[0-9A-Fa-f:]{17}/.test(showText)

        root.powered =
            /\bPowered:\s+yes\b/i.test(showText)

        const pairedSet = parseAddressSet(pairedText)
        const connectedSet = parseAddressSet(connectedText)

        root.pairedDevices =
            parseDeviceLines(
                pairedText,
                connectedSet,
                pairedSet
            )

        const allDevices =
            parseDeviceLines(
                allText,
                connectedSet,
                pairedSet
            )

        root.discoveredDevices =
            allDevices.filter(
                device => device.paired !== true
            )
    }

    property Process refreshProcess: Process {
        stdout: StdioCollector {
            onStreamFinished:
                root.parseState(text)
        }
    }

    property Process scanProcess: Process {
        onExited: {
            Qt.callLater(root.refresh)
        }
    }

    property Process actionProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const output = String(text ?? "").trim()

                if (
                    output !== ""
                    && /Failed|not available|AuthenticationFailed|ConnectionAttemptFailed/i.test(output)
                ) {
                    root.lastError = output
                }
            }
        }

        onExited: code => {
            if (code !== 0 && root.lastError === "")
                root.lastError = "Bluetooth action failed"

            root.busy = false
            root.busyAddress = ""

            Qt.callLater(root.refresh)
        }
    }

    property Timer refreshTimer: Timer {
        interval: 3000
        repeat: true
        running: false

        onTriggered:
            root.refresh()
    }

    property Timer scanRefreshTimer: Timer {
        interval: 1500
        repeat: true
        running: root.scanning

        onTriggered:
            root.refresh()
    }

    function setAutoRefresh(enabled) {
        refreshTimer.running = enabled

        if (!enabled && scanning)
            setScanning(false)

        if (enabled)
            refresh()
    }

    Component.onCompleted:
        refresh()
}
