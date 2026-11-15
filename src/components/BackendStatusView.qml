import QtQuick
import QtQuick.Layouts

import "md3"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var backendStatus

    readonly property bool active:
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

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 560)
        spacing: 18

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 58
            Layout.preferredHeight: 58

            Rectangle {
                anchors.centerIn: parent

                width: 48
                height: 48
                radius: 24

                color: "transparent"

                border.width: 5
                border.color: Md3Theme.primary

                Rectangle {
                    anchors {
                        top: parent.top
                        right: parent.right
                    }

                    width: 22
                    height: 22
                    color: Md3Theme.background
                }

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.active
                }
            }
        }

        Text {
            Layout.fillWidth: true

            text:
                root.showStartupStatus
                ? root.i18n.text("connect_starting_title")
                : root.i18n.text("connect_connection_lost")

            color: Md3Theme.surfaceContent
            font.pixelSize: 24
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true

            text:
                root.showStartupStatus
                ? root.i18n.text("connect_starting_text")
                : root.i18n.text("connect_connection_lost_text")

            color: Md3Theme.surfaceVariantContent
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.preferredWidth: Math.min(parent.width, 420)
            implicitHeight: 52

            radius: Md3Theme.radiusLarge
            color: Qt.rgba(
                Md3Theme.surfaceContainer.r,
                Md3Theme.surfaceContainer.g,
                Md3Theme.surfaceContainer.b,
                0.94
            )

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    Layout.alignment: Qt.AlignVCenter
                    radius: 4
                    color: Md3Theme.primary
                }

                Text {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    text: root.currentStatusText
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
