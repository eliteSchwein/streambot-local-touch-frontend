import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../md3"

Rectangle {
    id: root

    required property string name
    required property var macro
    required property string restUrl
    required property var i18n

    property string runState: "idle"

    implicitHeight: 58

    radius: Md3Theme.radiusMedium
    color: Md3Theme.surfaceContainer

    border.width: 1
    border.color: Md3Theme.outlineVariant

    readonly property int taskCount:
        Array.isArray(macro.tasks)
        ? macro.tasks.length
        : 0

    function taskCountText() {
        if (taskCount === 1)
            return i18n.text("macro_task")

        return i18n
            .text("macro_tasks")
            .replace("%1", taskCount)
    }

    function triggerMacro() {
        if (
            runState === "loading"
            || !restUrl
        ) {
            return
        }

        runState = "loading"

        triggerProcess.command = [
            "curl",
            "-sS",
            "-o",
            "/dev/null",
            "-w",
            "HTTP:%{http_code}",
            "-X",
            "POST",
            "-H",
            "Content-Type: application/json",
            "--data-raw",
            JSON.stringify({
                macro: root.name
            }),
            root.restUrl + "/api/macro"
        ]

        triggerProcess.running = true
    }

    Process {
        id: triggerProcess

        running: false

        stdout: SplitParser {
            onRead: line => {
                const match =
                    String(line)
                        .match(/HTTP:(\d+)/)

                if (!match)
                    return

                const code =
                    Number(match[1])

                root.runState =
                    code >= 200 && code < 300
                    ? "success"
                    : "error"

                resetTimer.restart()
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (!String(line).trim())
                    return

                console.warn(
                    "[macro]",
                    root.name,
                    line
                )

                root.runState = "error"
                resetTimer.restart()
            }
        }
    }

    Timer {
        id: resetTimer

        interval: 2500
        repeat: false

        onTriggered:
            root.runState = "idle"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8

        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: 2

            Text {
                Layout.fillWidth: true

                text: root.name
                color: Md3Theme.surfaceContent

                font.pixelSize: 12
                font.weight: Font.DemiBold

                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                implicitWidth:
                    taskText.implicitWidth + 14

                implicitHeight: 21

                radius: 11
                color:
                    Md3Theme.surfaceContainerHighest

                Text {
                    id: taskText

                    anchors.centerIn: parent

                    text:
                        root.taskCountText()

                    color:
                        Md3Theme.surfaceVariantContent

                    font.pixelSize: 8
                    font.weight: Font.Medium
                }
            }
        }

        Rectangle {
            id: runButton

            Layout.alignment: Qt.AlignVCenter

            implicitWidth: 44
            implicitHeight: 44

            radius: 22

            color: {
                if (root.runState === "success")
                    return Md3Theme.success

                if (root.runState === "error")
                    return Md3Theme.error

                if (root.runState === "loading")
                    return Md3Theme.surfaceContainerHigh

                return Md3Theme.primary
            }

            MdiIcon {
                anchors.centerIn: parent

                name: {
                    if (root.runState === "success")
                        return "check"

                    if (root.runState === "error")
                        return "alert-circle"

                    return "play"
                }

                size: 21

                // Primary/success/error backgrounds all need
                // the dark selected icon variant.
                selected:
                    root.runState !== "loading"
            }

            TapHandler {
                enabled:
                    root.runState !== "loading"

                onTapped:
                    root.triggerMacro()
            }
        }
    }
}
