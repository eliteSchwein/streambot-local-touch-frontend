pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int focusedInputs: 0
    property bool visible: focusedInputs > 0

    function inputFocused() {
        focusedInputs++

        if (focusedInputs === 1)
            setVisible(true)
    }

    function inputBlurred() {
        focusedInputs = Math.max(0, focusedInputs - 1)

        if (focusedInputs === 0)
            setVisible(false)
    }

    function setVisible(show) {
        keyboardProcess.exec([
            "busctl",
            "call",
            "--user",
            "sm.puri.OSK0",
            "/sm/puri/OSK0",
            "sm.puri.OSK0",
            "SetVisible",
            "b",
            show ? "true" : "false"
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
