import QtQuick
import QtQuick.Layouts
import "../components/md3"

Item {
    required property var i18n
    required property var config

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Text {
            text: i18n.text("page_system")
            color: Md3Theme.surfaceContent

            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        Md3Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            title: i18n.text("system")

            Text {
                text:
                    i18n.text("host")
                    + ": "
                    + config.host

                color: Md3Theme.surfaceContent
                font.pixelSize: 13
            }

            Text {
                text:
                    i18n.text("websocket")
                    + ": "
                    + config.websocketUrl

                color: Md3Theme.surfaceVariantContent
                font.pixelSize: 12
            }

            Text {
                text:
                    i18n.text("rest_api")
                    + ": "
                    + config.restUrl

                color: Md3Theme.surfaceVariantContent
                font.pixelSize: 12
            }

            Text {
                text:
                    i18n.text("language")
                    + ": "
                    + config.language

                color: Md3Theme.surfaceVariantContent
                font.pixelSize: 12
            }
        }
    }
}
