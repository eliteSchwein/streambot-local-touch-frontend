import QtQuick
import QtQuick.Layouts

import "../components/md3"

Md3Dialog {
    id: root

    required property var i18n
    required property var websocket
    required property var backendStatus

    readonly property bool shouldShow:
        !backendStatus.ready
        || !websocket.connected

    readonly property bool showStartupStatus:
        !backendStatus.ready
        && backendStatus.startupStage !== ""

    function humanizeStage(stage) {
        const value =
            String(stage ?? "")
                .trim()

        if (value === "")
            return i18n.text("connect_stage_unknown")

        return value
            .replace(/[_-]+/g, " ")
            .replace(/\b\w/g, function(character) {
                return character.toUpperCase()
            })
    }

    readonly property string localizedStage:
        humanizeStage(
            backendStatus.startupStage
        )

    title:
        showStartupStatus
        ? i18n.text("connect_starting_title")
        : (
            websocket.connecting
            ? i18n.text("connect_reconnecting")
            : i18n.text("connect_connection_lost")
        )

    supportingText:
        showStartupStatus
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
                        root.showStartupStatus
                        ? root.localizedStage
                        : (
                            root.websocket.connecting
                            ? root.i18n.text("connect_reconnecting")
                            : root.i18n.text("connect_connection_lost")
                        )

                    color: Md3Theme.surfaceContent

                    font.pixelSize: 14
                    font.weight: Font.DemiBold

                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true

                    text:
                        root.backendStatus.hasStatus
                        ? (
                            root.backendStatus.ready
                            ? root.websocket.url
                            : root.backendStatus.restUrl + "/api/status"
                        )
                        : root.backendStatus.restUrl + "/api/status"

                    color: Md3Theme.surfaceVariantContent
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                }
            }

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                Rectangle {
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

                        color:
                            Md3Theme.surfaceContainerHigh
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

    // Persistent, same as old Vue dialog.
    actions: []
}
