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

    function stageText(stage) {
        const value =
            String(stage ?? "")
                .trim()

        if (value === "")
            return i18n.text("connect_stage_unknown")

        const key =
            "connect_stage_" + value

        const translated =
            i18n.text(key)

        // I18n returns the key itself when a translation does not exist.
        if (
            translated !== ""
            && translated !== key
        ) {
            return translated
        }

        return value
            .replace(/[_-]+/g, " ")
            .replace(/\b\w/g, function(character) {
                return character.toUpperCase()
            })
    }

    readonly property string currentStatusText: {
        if (showStartupStatus) {
            return stageText(
                backendStatus.startupStage
            )
        }

        if (websocket.connecting)
            return i18n.text("connect_reconnecting")

        return i18n.text("connect_connection_lost")
    }

    title:
        showStartupStatus
        ? i18n.text("connect_starting_title")
        : i18n.text("connect_connection_lost")

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
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Spinner directly beside the actual status text.
            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter

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

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    Layout.fillWidth: true

                    text:
                        root.currentStatusText

                    color: Md3Theme.surfaceContent

                    font.pixelSize: 14
                    font.weight: Font.DemiBold

                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // Persistent status dialog, matching the old admin/touch behavior.
    actions: []
}
