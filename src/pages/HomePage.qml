import QtQuick
import QtQuick.Layouts
import "../components/md3"

Item {
    required property var i18n
    required property var websocket

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            text: i18n.text("page_home")
            color: Md3Theme.surfaceContent

            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Md3Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                title: i18n.text("websocket")

                Text {
                    text: websocket.connected
                        ? i18n.text("connected")
                        : i18n.text("disconnected")

                    color: websocket.connected
                        ? Md3Theme.success
                        : Md3Theme.error

                    font.pixelSize: 15
                }
            }

            Md3Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                title: i18n.text("alerts")

                Text {
                    text: i18n.text("no_alerts")
                    color: Md3Theme.surfaceVariantContent
                    font.pixelSize: 13
                }
            }
        }
    }
}
