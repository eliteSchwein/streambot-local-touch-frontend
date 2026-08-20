pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    function show() {
        setVisible(true)
    }

    function hide() {
        setVisible(false)
    }

    function setVisible(visible) {
        keyboardProcess.exec([
            "busctl",
            "call",
            "--user",
            "sm.puri.OSK0",
            "/sm/puri/OSK0",
            "sm.puri.OSK0",
            "SetVisible",
            "b",
            visible ? "true" : "false"
        ])
    }

    property Process keyboardProcess: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[keyboard]", text.trim())
            }
        }
    }
}
