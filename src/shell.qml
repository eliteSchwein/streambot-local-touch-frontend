import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import "components"
import "pages"
import "services"

ShellRoot {
    id: root

    Config {
        id: config
    }

    I18n {
        id: i18n

        language: config.language
    }

    WsClient {
        id: websocket

        url: config.websocketUrl

        onConnectionChanged: connected => {
            console.log(
                "[websocket]",
                connected
                    ? "connected"
                    : "disconnected"
            )
        }

        onJsonReceived: data => {
            console.log(
                "[websocket] json:",
                JSON.stringify(data)
            )
        }
    }

    PanelWindow {
        id: window

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        focusable: true

        color: "#121212"

        Rectangle {
            anchors.fill: parent

            color: "#121212"

            SwipeView {
                id: pages

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: pagination.top
                }

                currentIndex: 0

                interactive: true

                HomePage {
                    i18n: i18n
                    websocket: websocket
                }

                ControlsPage {
                    i18n: i18n
                    websocket: websocket
                }

                SystemPage {
                    i18n: i18n
                    config: config
                    websocket: websocket
                }
            }

            Rectangle {
                id: pagination

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                height: 74

                color: "#181818"

                Row {
                    anchors.centerIn: parent

                    spacing: 16

                    Repeater {
                        model: pages.count

                        Rectangle {
                            required property int index

                            width: pages.currentIndex === index
                                ? 28
                                : 12

                            height: 12

                            radius: 6

                            color: pages.currentIndex === index
                                ? "white"
                                : "#555555"

                            Behavior on width {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            TapHandler {
                                onTapped: {
                                    pages.currentIndex = index
                                }
                            }
                        }
                    }
                }
            }

            NotificationDrawer {
                i18n: i18n

                anchors.top: parent.top
            }
        }
    }
}