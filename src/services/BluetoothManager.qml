import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool available: false
    property bool powered: false
    property bool busy: false
    property bool scanning: false
    property string scanTransport: "bredr"
    property string busyAddress: ""
    property string lastErrorCode: ""
    property string lastErrorDetail: ""

    property var pairedDevices: []
    property var discoveredDevices: []

    function clearError() {
        lastErrorCode = ""
        lastErrorDetail = ""
    }

    function cleanBluetoothOutput(value) {
        // bluetoothctl may emit ANSI/terminal control sequences even when
        // launched without an interactive terminal.
        return String(value ?? "")
            .replace(/\x1b\[[0-9;?]*[ -/]*[@-~]/g, "")
            .replace(/\r/g, "")
            .trim()
    }

    function classifyError(value) {
        const text = cleanBluetoothOutput(value)

        if (text === "")
            return ""

        if (/AuthenticationFailed|Authentication Failed/i.test(text))
            return "authentication_failed"

        if (/AuthenticationRejected|Rejected/i.test(text))
            return "authentication_rejected"

        if (/AuthenticationCanceled|AuthenticationCancelled|Canceled/i.test(text))
            return "authentication_canceled"

        if (/ConnectionAttemptFailed|Failed to connect/i.test(text))
            return "connection_failed"

        if (/not available|NotAvailable/i.test(text))
            return "not_available"

        if (/timeout|Timed out/i.test(text))
            return "timeout"

        if (/Failed|Error/i.test(text))
            return "generic"

        return ""
    }

    function refresh() {
        if (refreshProcess.running)
            return

        refreshProcess.exec([
            "sh",
            "-c",
            "paired=\"$(bluetoothctl devices Paired 2>/dev/null || bluetoothctl paired-devices 2>/dev/null || true)\"; "
            + "all=\"$(bluetoothctl devices 2>/dev/null || true)\"; "
            + "connected=\"$(bluetoothctl devices Connected 2>/dev/null || true)\"; "
            + "printf '__SHOW__\\n'; "
            + "bluetoothctl show 2>/dev/null || true; "
            + "printf '__PAIRED__\\n%s\\n' \"$paired\"; "
            + "printf '__ALL__\\n%s\\n' \"$all\"; "
            + "printf '__CONNECTED__\\n%s\\n' \"$connected\"; "
            + "printf '__INFO__\\n'; "
            + "printf '%s\\n%s\\n' \"$paired\" \"$all\" | awk '/^Device / {print $2}' | sort -u | while read -r addr; do "
            + "  [ -n \"$addr\" ] || continue; "
            + "  printf '__DEVICE__ %s\\n' \"$addr\"; "
            + "  bluetoothctl info \"$addr\" 2>/dev/null || true; "
            + "done"
        ])
    }

    function setPowered(enabled) {
        if (busy)
            return

        busy = true
        busyAddress = ""
        clearError()

        actionProcess.exec([
            "bluetoothctl",
            "power",
            enabled ? "on" : "off"
        ])
    }

    function setScanning(enabled) {
        if (!powered || !available)
            return

        scanning = enabled
        clearError()

        if (enabled) {
            scanTransport = "bredr"
            startScanCycle()
        } else {
            Qt.callLater(refresh)
        }
    }

    function startScanCycle() {
        if (
            !scanning
            || !powered
            || !available
            || scanProcess.running
        ) {
            return
        }

        // Keep bluetoothctl alive long enough for BlueZ discovery to actually
        // find nearby devices. Once the timed scan exits, refresh() reads
        // BlueZ's device cache and another cycle starts while scanning stays on.
        scanProcess.exec([
            "bluetoothctl",
            "--timeout",
            scanTransport === "bredr" ? "15" : "5",
            "scan",
            scanTransport
        ])
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
        clearError()

        // Pairing while discovery is active is unreliable with a number of
        // Classic Bluetooth devices. Stop our scan loop immediately and tell
        // BlueZ to stop discovery before starting the pairing agent.
        scanning = false
        scanCycleDelay.stop()

        // NoInputNoOutput handles the common "Just Works" pairing flow.
        // After a successful pair, trust and connect automatically.
        actionProcess.exec([
            "sh",
            "-c",
            "(bluetoothctl scan off >/dev/null 2>&1 || true); "
            + "sleep 0.6; "
            + "bluetoothctl --agent NoInputNoOutput pair "
            + shellQuote(device.address)
            + " && bluetoothctl trust "
            + shellQuote(device.address)
            + " && bluetoothctl connect "
            + shellQuote(device.address)
            + " 2>&1"
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
        clearError()

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
        clearError()

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
        clearError()

        actionProcess.exec([
            "bluetoothctl",
            "remove",
            device.address
        ])
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function parseInfoMap(text) {
        const result = ({})
        const value = String(text ?? "")
        const lines = value.split(/\r?\n/)
        let currentAddress = ""
        let currentLines = []

        function commitCurrent() {
            if (currentAddress === "")
                return

            const block = currentLines.join("\n")
            const iconMatch = block.match(/^\s*Icon:\s+(.+)$/m)
            const icon = iconMatch ? iconMatch[1].trim() : ""

            let kind = "generic"
            if (/(audio|headset|headphones|speaker)/i.test(icon) || /0000110b|0000110d|00001108|0000111e|00001131/i.test(block))
                kind = "audio"
            else if (/(phone|modem)/i.test(icon))
                kind = "phone"
            else if (/(input-keyboard|input-mouse)/i.test(icon) || /00001124/i.test(block))
                kind = "input"
            else if (/(computer|laptop)/i.test(icon))
                kind = "computer"

            result[currentAddress] = {
                icon: icon,
                kind: kind
            }
        }

        for (const rawLine of lines) {
            const deviceMatch = rawLine.match(/^__DEVICE__\s+([0-9A-Fa-f:]{17})$/)
            if (deviceMatch) {
                commitCurrent()
                currentAddress = deviceMatch[1].toUpperCase()
                currentLines = []
                continue
            }
            currentLines.push(rawLine)
        }

        commitCurrent()
        return result
    }

    function deviceTypeLabel(kind) {
        switch (kind) {
            case "audio":
                return "SPK"
            case "phone":
                return "PH"
            case "computer":
                return "PC"
            case "input":
                return "KB"
            default:
                return "BT"
        }
    }

    function parseDeviceLines(text, connectedSet, pairedSet, infoMap) {
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

            const info = infoMap?.[address] ?? ({})

            result.push({
                address: address,
                name: name,
                connected: connectedSet[address] === true,
                paired: pairedSet[address] === true,
                kind: info.kind ?? "generic",
                kindLabel: root.deviceTypeLabel(info.kind ?? "generic")
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
        const infoMarker = value.indexOf("__INFO__")

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
                connectedMarker + "__CONNECTED__".length,
                infoMarker >= 0
                    ? infoMarker
                    : value.length
            )
            : ""

        const infoText =
            infoMarker >= 0
            ? value.slice(infoMarker + "__INFO__".length)
            : ""

        root.available =
            /Controller\s+[0-9A-Fa-f:]{17}/.test(showText)

        root.powered =
            /\bPowered:\s+yes\b/i.test(showText)

        const pairedSet = parseAddressSet(pairedText)
        const connectedSet = parseAddressSet(connectedText)
        const infoMap = parseInfoMap(infoText)

        root.pairedDevices =
            parseDeviceLines(
                pairedText,
                connectedSet,
                pairedSet,
                infoMap
            )

        const allDevices =
            parseDeviceLines(
                allText,
                connectedSet,
                pairedSet,
                infoMap
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

            if (root.scanning) {
                // Classic Bluetooth first catches speakers/headsets that may
                // not advertise over BLE. Then alternate with LE so both
                // transports stay covered while the Scan button is active.
                root.scanTransport =
                    root.scanTransport === "bredr"
                    ? "le"
                    : "bredr"

                scanCycleDelay.restart()
            }
        }
    }

    property Timer scanCycleDelay: Timer {
        interval: 250
        repeat: false

        onTriggered:
            root.startScanCycle()
    }

    property Process actionProcess: Process {
        property string output: ""

        stdout: StdioCollector {
            onStreamFinished: {
                actionProcess.output =
                    root.cleanBluetoothOutput(text)
            }
        }

        onExited: code => {
            const errorCode =
                root.classifyError(actionProcess.output)

            if (errorCode !== "") {
                root.lastErrorCode = errorCode

                // Keep only a short, sanitized final line for diagnostics.
                const lines =
                    actionProcess.output
                        .split(/\n/)
                        .map(line => line.trim())
                        .filter(line => line !== "")

                root.lastErrorDetail =
                    lines.length > 0
                    ? lines[lines.length - 1]
                    : ""
            } else if (code !== 0) {
                root.lastErrorCode = "generic"
                root.lastErrorDetail = ""
            }

            actionProcess.output = ""
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
