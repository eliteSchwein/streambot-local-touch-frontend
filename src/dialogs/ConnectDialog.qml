import QtQuick
import QtQuick.Layouts

import "../components/md3"

Md3Dialog {
    id: root

    required property var i18n
    required property var websocket

    readonly property bool startupMode:
        !websocket.everConnected

    readonly property bool shouldShow:
        !websocket.connected

    title:
        startupMode
        ? i18n.text("connect_starting_title")
        : (
            websocket.connecting
            ? i18n.text("connect_reconnecting")
            : i18n.text("connect_connection_lost")
        )

    supportingText:
        startupMode
        ? i18n.text("connect_starting_text")
        : i18n.text("connect_connection_lost_text")

    onShouldShowChanged: {
        if (shouldShow) {
            open()
        } else {
            close()
        }
    }

    Component.onCompleted: {
        if (shouldShow)
            open()
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44

                radius: 22
                color: Md3Theme.surfaceContainerHighest

                MdiIcon {
                    anchors.centerIn: parent

                    name: "wifi-sync"
                    size: 22
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true

                    text:
                        root.startupMode
                        ? root.i18n.text("connect_starting_stage")
                        : root.i18n.text("connect_reconnecting")

                    color: Md3Theme.surfaceContent
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true

                    text: root.websocket.url

                    color: Md3Theme.surfaceVariantContent
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                }
            }

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                Rectangle {
                    id: spinner

                    anchors.centerIn: parent

                    width: 22
                    height: 22
                    radius: 11

                    color: "transparent"
                    border.width: 3
                    border.color: Md3Theme.primary

                    Rectangle {
                        anchors {
                            top: parent.top
                            right: parent.right
                        }

                        width: 10
                        height: 10
                        color: Md3Theme.surfaceContainerHigh
                    }

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: root.shouldShow
                    }
                }
            }
        }
    }

    // Intentionally no actions: this is a persistent status dialog.
    actions: []
}
