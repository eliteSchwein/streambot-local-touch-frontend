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
            text: root.i18n.text("page_home")

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

                title: root.i18n.text("websocket")

                Text {
                    text: root.websocket.connected
                        ? root.i18n.text("connected")
                        : root.i18n.text("disconnected")

                    color: root.websocket.connected
                        ? "#9be28f"
                        : "#ff8a80"

                    font.pixelSize: 25
                    font.bold: true
                }
            }

            DashboardCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                title: root.i18n.text("alerts")

                Text {
                    text: root.i18n.text("no_alerts")

                    color: "#cccccc"

                    font.pixelSize: 20
                }
            }
        }
    }
}