import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property string restUrl
    required property var websocket

    property bool ready: false
    property string startupStage: ""
    property bool hasStatus: false

    readonly property bool shouldPoll:
        !websocket.connected

    function fetchStatus() {
        if (
            !shouldPoll
            || statusProcess.running
            || restUrl === ""
        ) {
            return
        }

        statusProcess.exec([
            "curl",
            "-fsS",
            "--connect-timeout",
            "0.4",
            "--max-time",
            "1",
            restUrl + "/api/status"
        ])
    }

    function applyStatus(raw) {
        let status

        try {
            status = JSON.parse(raw)
        } catch (error) {
            // Match the old Vue behavior:
            // invalid/transient responses must not erase the last
            // successful startup stage.
            return
        }

        if (
            status === null
            || typeof status !== "object"
            || Array.isArray(status)
        ) {
            return
        }

        hasStatus = true
        ready = status.ready === true

        if (
            typeof status.bootup_stage === "string"
            && status.bootup_stage.length > 0
        ) {
            startupStage = status.bootup_stage
        }

        console.log(
            "[backend-status] ready:",
            ready,
            "stage:",
            startupStage
        )
    }

    Component.onCompleted:
        Qt.callLater(fetchStatus)

    Connections {
        target: root.websocket

        function onConnectionChanged(connected) {
            if (!connected)
                Qt.callLater(root.fetchStatus)
        }
    }

    property Process statusProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyStatus(text)
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 500
        repeat: true
        running: true

        onTriggered:
            root.fetchStatus()
    }
}
