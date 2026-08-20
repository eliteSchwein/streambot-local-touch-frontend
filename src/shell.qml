import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

import "components"
import "services"

ShellRoot {
    id: root

    Config {
        id: config
    }

    WsClient {
        id: websocket

        url: config.websocketUrl

        onConnectionChanged: connected => {
            console.log(
                "[websocket]",
                connected ? "connected" : "disconnected"
            )
        }

        onJsonReceived: data => {
            console.log(
                "[websocket] json:",
                JSON.stringify(data)
            )
        }

        onMessageReceived: message => {
            console.log(
                "[websocket] raw:",
                message
            )
        }

        onSocketError: error => {
            console.warn(
                "[websocket] error:",
                error
            )
        }
    }

    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "#121212"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: websocket.connected
                    ? "WebSocket connected"
                    : "WebSocket disconnected"

                color: "white"
            }

            Text {
                text: config.websocketUrl
                color: "#aaaaaa"
            }

            Button {
                text: "Send test"
                enabled: websocket.connected

                onClicked: {
                    websocket.sendJson({
                        type: "test",
                        source: "streambot-touch"
                    })
                }
            }

            Button {
                text: "Reconnect"

                onClicked: {
                    websocket.reconnect()
                }
            }
        }
    }
}