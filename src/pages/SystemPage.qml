import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../components"

Item {
    id: root

    property var i18n
    property var config
    property var websocket

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24

        spacing: 18

        Text {
            text: root.i18n.text("page_system")

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

                title: root.i18n.text("system")

                ColumnLayout {
                    Layout.fillWidth: true

                    Text {
                        text:
                            root.i18n.text("host")
                            + ": "
                            + root.config.host

                        color: "white"
                        font.pixelSize: 18
                    }

                    Text {
                        text:
                            root.i18n.text("websocket")
                            + ": "
                            + root.config.websocketUrl

                        color: "#cccccc"
                        font.pixelSize: 18
                    }

                    Text {
                        text:
                            root.i18n.text("rest_api")
                            + ": "
                            + root.config.restUrl

                        color: "#cccccc"
                        font.pixelSize: 18
                    }
                }
            }

            DashboardCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                title: root.i18n.text("language")

                Text {
                    text: root.config.language === "de"
                        ? "Deutsch"
                        : "English"

                    color: "white"

                    font.pixelSize: 26
                    font.bold: true
                }
            }
        }
    }
}