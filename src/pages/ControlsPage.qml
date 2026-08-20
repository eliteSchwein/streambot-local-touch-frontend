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
            text: i18n.text("page_controls")
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

                title: i18n.text("audio")

                Text {
                    text: i18n.text("music")
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 13
                }

                Md3Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: 0.25
                }

                Text {
                    text: i18n.text("tts")
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 13
                }

                Md3Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: 0.12
                }
            }

            Md3Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                title: i18n.text("actions")

                Md3Button {
                    Layout.fillWidth: true

                    text: i18n.text("reconnect")

                    onClicked: {
                        websocket.reconnect()
                    }
                }
            }
        }
    }
}
