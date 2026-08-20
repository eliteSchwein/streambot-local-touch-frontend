import QtQuick
import QtWebSockets

QtObject {
    id: root

    property string url: "ws://127.0.0.1:8100"

    property bool autoReconnect: true
    property int reconnectInterval: 2000

    readonly property bool connected:
        socket.status === WebSocket.Open

    readonly property int status:
        socket.status

    readonly property string errorString:
        socket.errorString

    signal connectedChangedState(bool connected)
    signal messageReceived(string message)
    signal jsonReceived(var data)
    signal socketError(string error)

    function sendText(message) {
        if (!connected) {
            console.warn("[websocket] cannot send while disconnected")
            return false
        }

        socket.sendTextMessage(message)
        return true
    }

    function sendJson(data) {
        return sendText(JSON.stringify(data))
    }

    function reconnect() {
        reconnectTimer.stop()

        socket.active = false
        reconnectTimer.restart()
    }

    function disconnect() {
        reconnectTimer.stop()
        socket.active = false
    }

    function connect() {
        reconnectTimer.stop()

        if (!socket.active)
            socket.active = true
    }

    WebSocket {
        id: socket

        url: root.url
        active: true

        onStatusChanged: {
            switch (status) {
                case WebSocket.Open:
                    console.log("[websocket] connected:", root.url)

                    reconnectTimer.stop()
                    root.connectedChangedState(true)
                    break

                case WebSocket.Closed:
                    console.log("[websocket] disconnected:", root.url)

                    root.connectedChangedState(false)

                    if (root.autoReconnect)
                        reconnectTimer.restart()

                    break

                case WebSocket.Error:
                    console.warn(
                        "[websocket] error:",
                        errorString
                    )

                    root.socketError(errorString)
                    root.connectedChangedState(false)

                    if (root.autoReconnect)
                        reconnectTimer.restart()

                    break
            }
        }

        onTextMessageReceived: message => {
            root.messageReceived(message)

            try {
                const data = JSON.parse(message)
                root.jsonReceived(data)
            } catch (error) {
                // Not every websocket message needs to be JSON.
            }
        }
    }

    Timer {
        id: reconnectTimer

        interval: root.reconnectInterval
        repeat: false

        onTriggered: {
            if (root.connected)
                return

            console.log("[websocket] reconnecting:", root.url)

            socket.active = false
            socket.active = true
        }
    }
}