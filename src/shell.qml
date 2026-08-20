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

            SwipeView {
                id: pages

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    bottom: pagination.top
                }

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
                }
            }

            Rectangle {
                id: pagination

                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }

                height: 48
                color: Md3Theme.surfaceContainer

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Repeater {
                        model: pages.count

                        Rectangle {
                            required property int index

                            width: pages.currentIndex === index
                                ? 22
                                : 8

                            height: 8
                            radius: 4

                            color: pages.currentIndex === index
                                ? Md3Theme.primary
                                : Md3Theme.surfaceVariantContent

                            Behavior on width {
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.OutCubic
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

                z: 100000
                language: config.language
            }

            // Qt Virtual Keyboard. It lives inside the kiosk window, so it
            // overlays the UI instead of changing the Wayland exclusive zone.
}
    }
}
