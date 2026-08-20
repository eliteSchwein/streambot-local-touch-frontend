import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Settings
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

    function updateKeyboardLocale() {
        const wantedLocale =
            config.language === "de"
            ? "de_DE"
            : "en_US"

        // Keep the keyboard limited to the two languages supported by the UI.
        VirtualKeyboardSettings.activeLocales = [
            "en_US",
            "de_DE"
        ]

        VirtualKeyboardSettings.locale = wantedLocale
        VirtualKeyboardSettings.closeOnReturn = true
        VirtualKeyboardSettings.handwritingModeDisabled = true
    }

    Component.onCompleted: updateKeyboardLocale()

    Connections {
        target: config

        function onLanguageChanged() {
            updateKeyboardLocale()
        }
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

            // Qt Virtual Keyboard. It lives inside the kiosk window, so it
            // overlays the UI instead of changing the Wayland exclusive zone.
            InputPanel {
                id: inputPanel

                z: 100000

                onActiveChanged: {
                    console.log("[keyboard] active:", active)
                }
                width: parent.width

                y: active
                    ? parent.height - height
                    : parent.height

                Behavior on y {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
