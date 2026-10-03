import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool available: false
    property bool powered: false
    property bool busy: false
    property var devices: []

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
            + "printf '__CONNECTED__\\n'; "
            + "(bluetoothctl devices Connected 2>/dev/null || true)"
        ])
    }

    function setPowered(enabled) {
        if (busy)
            return

        busy = true
        actionProcess.exec([
            "bluetoothctl",
            "power",
            enabled ? "on" : "off"
        ])
    }

    function toggleDevice(device) {
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
        actionProcess.exec([
            "bluetoothctl",
            device.connected ? "disconnect" : "connect",
            device.address
        ])
    }

    function parseDeviceLines(text, connectedSet) {
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
                connected: connectedSet[address] === true
            })
        }

        result.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1

            return a.name.localeCompare(b.name)
        })

        return result
    }

    function parseState(text) {
        const value = String(text ?? "")
        const pairedMarker = value.indexOf("__PAIRED__")
        const connectedMarker = value.indexOf("__CONNECTED__")

        const showText =
            pairedMarker >= 0
            ? value.slice(0, pairedMarker)
            : value

        const pairedText =
            pairedMarker >= 0
            ? value.slice(
                pairedMarker + "__PAIRED__".length,
                connectedMarker >= 0
                    ? connectedMarker
                    : value.length
            )
            : ""

        const connectedText =
            connectedMarker >= 0
            ? value.slice(
                connectedMarker
                + "__CONNECTED__".length
            )
            : ""

        root.available =
            /Controller\s+[0-9A-Fa-f:]{17}/.test(showText)

        root.powered =
            /\bPowered:\s+yes\b/i.test(showText)

        const connectedSet = ({})

        for (const rawLine of connectedText.split(/\r?\n/)) {
            const match = rawLine.trim().match(
                /^Device\s+([0-9A-Fa-f:]{17})\s+/
            )

            if (match)
                connectedSet[match[1].toUpperCase()] = true
        }

        root.devices =
            root.parseDeviceLines(
                pairedText,
                connectedSet
            )
    }

    property Process refreshProcess: Process {
        stdout: StdioCollector {
            onStreamFinished:
                root.parseState(text)
        }
    }

    property Process actionProcess: Process {
        onExited: {
            root.busy = false
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

        if (enabled)
            refresh()
    }

    Component.onCompleted:
        refresh()
}
