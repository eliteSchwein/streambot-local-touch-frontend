import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../components"

Item {
    id: root

    property var i18n
    property var websocket

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        spacing: 18

        Text {
            text: root.i18n.text("page_controls")

            color: "white"

            font.pixelSize: 34
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            spacing: 18

            DashboardCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                title: root.i18n.text("audio")

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 14

                    Text {
                        text: root.i18n.text("music")
                        color: "white"
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: 0.25
                    }

                    Text {
                        text: root.i18n.text("tts")
                        color: "white"
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: 0.12
                    }
                }
            }

            DashboardCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                title: root.i18n.text("actions")

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 16

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60

                        text: root.i18n.text("test_alert")

                        onClicked: {
                            root.websocket.sendRpc(
                                "test_alert",
                                {}
                            )
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60

                        text: root.i18n.text("reconnect")

                        onClicked: {
                            root.websocket.reconnect()
                        }
                    }
                }
            }
        }
    }
}