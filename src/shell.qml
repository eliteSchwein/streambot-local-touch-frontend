import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import "components"
import "components/md3"
import "pages"
import "services"

ShellRoot {
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
    }

    NetworkManager {
        id: network
    }

    DashboardStore {
        id: dashboardStore
    }

    Connections {
        target: websocket

        function onJsonReceived(data) {
            dashboardStore.handleMessage(data)
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
        exclusionMode: ExclusionMode.Ignore
        color: Md3Theme.background

        Rectangle {
            anchors.fill: parent
            color: Md3Theme.background

            DashboardPage {
                id: dashboardPage

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: navigation.top
                }

                i18n: i18n
                websocket: websocket
                store: dashboardStore
            }

            Rectangle {
                id: navigation

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                height: 52
                color: Md3Theme.surfaceContainer

                Row {
                    anchors.centerIn: parent

                    Md3NavButton {
                        icon: "⌂"selected: true
                    }
                }
            }

            NetworkDrawer {
                anchors.fill: parent

                i18n: i18n
                config: config
                network: network
            }

            Md3Keyboard {
                id: keyboard

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                z: 10000000
                language: config.language
            }

}
    }
}
