import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "components"
import "components/md3"
import "dialogs"
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

    BackendStatus {
        id: backendStatus

        restUrl: config.restUrl
        websocket: websocket
    }

    WsClient {
        id: websocket

        url: config.websocketUrl

        // Same basic order as the old Vue reconnect loop:
        // do not establish WS until /api/status reports ready=true.
        enabled: backendStatus.ready
    }

    NetworkManager {
        id: network
    }

    DashboardStore {
        id: dashboardStore
    }

    IpcHandler {
        target: "streambot-touch"

        function openPowerMenu(): void {
            powerMenu.open()
        }
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
            id: appRoot

            property int currentPage: 0

            anchors.fill: parent
            color: Md3Theme.background

            DashboardPage {
                id: dashboardPage

                visible: appRoot.currentPage === 0

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

            AudioPage {
                id: audioPage

                visible: appRoot.currentPage === 1

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

            MacrosPage {
                id: macrosPage

                visible:
                    appRoot.currentPage === 2

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: navigation.top
                }

                i18n: i18n
                store: dashboardStore
                websocket: websocket
            }

            ChannelPointsPage {
                id: channelPointsPage

                visible:
                    appRoot.currentPage === 3

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

            SystemPage {
                id: systemPage
                visible: appRoot.currentPage === 4
                anchors { top: parent.top; left: parent.left; right: parent.right; bottom: navigation.top }
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

                // Keep actual page navigation centered regardless of
                // the power button on the far right.
                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Md3NavButton {
                        icon: "home"
                        selected: appRoot.currentPage === 0

                        onClicked:
                            appRoot.currentPage = 0
                    }

                    Md3NavButton {
                        icon: "volume-high"
                        selected: appRoot.currentPage === 1

                        onClicked:
                            appRoot.currentPage = 1
                    }

                    Md3NavButton {
                        icon: "dialpad"
                        selected: appRoot.currentPage === 2

                        onClicked:
                            appRoot.currentPage = 2
                    }

                    Md3NavButton {
                        icon: "motion-play-outline"
                        selected: appRoot.currentPage === 3

                        onClicked:
                            appRoot.currentPage = 3
                    }

                    Md3NavButton {
                        icon: "server"
                        selected: appRoot.currentPage === 4
                        badge: dashboardStore.updatesAvailable

                        onClicked:
                            appRoot.currentPage = 4
                    }
                }

                // Global power action, deliberately not part of the centered
                // page-navigation Row.
                Rectangle {
                    id: navPowerButton

                    anchors {
                        right: parent.right
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }

                    width: 40
                    height: 40
                    radius: 20

                    color:
                        navPowerTap.pressed
                            ? Md3Theme.surfaceContainerHigh
                            : "transparent"

                    MdiIcon {
                        anchors.centerIn: parent

                        name: "power"
                        size: 21
                    }

                    TapHandler {
                        id: navPowerTap

                        onTapped:
                            powerMenu.open()
                    }
                }
            }

            NetworkDrawer {
                id: settingsDrawer

                // Keep the drawer and its bottom drag/close handle above the
                // navigation bar instead of overlapping its pointer area.
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: navigation.top
                }

                i18n: i18n
                config: config
                network: network
            }

            ConnectDialog {
                id: connectDialog

                anchors.fill: parent
                z: 8000000

                i18n: i18n
                websocket: websocket
                backendStatus: backendStatus
            }

            // Global top-most dialog. Keep this outside NetworkDrawer so its z
            // is compared directly with ConnectDialog and Md3Keyboard.
            PowerMenuDialog {
                id: powerMenu

                anchors.fill: parent
                z: 20000000

                i18n: i18n
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
