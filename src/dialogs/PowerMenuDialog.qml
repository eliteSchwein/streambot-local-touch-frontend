import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../components/md3"

Md3Dialog {
    id: root

    required property var i18n

    title: i18n.text("power_menu")

    property string pendingAction: ""

    function run(command, actionName) {
        if (actionProcess.running)
            return

        pendingAction = actionName
        actionProcess.command = command
        actionProcess.running = true
    }

    Process {
        id: actionProcess

        running: false

        stderr: SplitParser {
            onRead: line => {
                if (String(line).trim() !== "") {
                    console.warn(
                        "[power]",
                        root.pendingAction,
                        line
                    )
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                // Closing is useful for backend restart and harmless for
                // poweroff/reboot, where the compositor will disappear anyway.
                root.close()
                root.pendingAction = ""
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        PowerActionButton {
            Layout.fillWidth: true

            icon: "power-standby"
            title: root.i18n.text("shutdown_device")
            supportingText:
                root.i18n.text("shutdown_device_text")

            destructive: true

            onClicked:
                root.run(
                    [
                        "systemctl",
                        "poweroff"
                    ],
                    "poweroff"
                )
        }

        PowerActionButton {
            Layout.fillWidth: true

            icon: "restart"
            title: root.i18n.text("restart_device")
            supportingText:
                root.i18n.text("restart_device_text")

            onClicked:
                root.run(
                    [
                        "systemctl",
                        "reboot"
                    ],
                    "reboot"
                )
        }

        PowerActionButton {
            Layout.fillWidth: true

            icon: "server"
            title: root.i18n.text("restart_backend")
            supportingText:
                root.i18n.text("restart_backend_text")

            onClicked:
                root.run(
                    [
                        "systemctl",
                        "--user",
                        "restart",
                        "stream-overlord.service"
                    ],
                    "restart-backend"
                )
        }
    }

    actions: [
        Md3Button {
            text: root.i18n.text("cancel")
            outlined: true

            onClicked:
                root.close()
        }
    ]
}
