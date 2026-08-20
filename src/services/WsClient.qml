import QtQuick
import QtWebSockets

QtObject {
    id: root

    property string url: "ws://127.0.0.1:8100"

    property bool autoReconnect: true
    property int reconnectInterval: 2000

    property var endpoints: [
        "notify_alert",
        "notify_alert_query"
    ]

    property int nextRequestId: 1

    readonly property bool connected:
        socket.status === WebSocket.Open

    readonly property int status:
        socket.status

    readonly property string errorString:
        socket.errorString

    signal connectionChanged(bool connected)
    signal messageReceived(string message)
    signal jsonReceived(var data)
    signal socketError(string error)

    function send(message) {
        if (typeof message === "string")
            return sendText(message)

        return sendJson(message)
    }

    function sendText(message) {
        if (socket.status !== WebSocket.Open) {
            console.warn(
                "[websocket] cannot send while disconnected"
            )

            return false
        }

        socket.sendTextMessage(message)
        return true
    }

    function sendJson(data) {
        try {
            return sendText(JSON.stringify(data))
        } catch (error) {
            console.warn(
                "[websocket] failed to serialize JSON:",
                error
            )

            return false
        }
    }

    function sendRpc(method, params) {
        const id = nextRequestId++

        const request = {
            jsonrpc: "2.0",
            id: id,
            method: method
        }

        if (params !== undefined)
            request.params = params

        if (!sendJson(request))
            return -1

        return id
    }

    function registerEndpoints() {
        if (socket.status !== WebSocket.Open)
            return

        console.log(
            "[websocket] registering endpoints:",
            JSON.stringify(endpoints)
        )

        sendRpc(
            "register_endpoints",
            endpoints
        )
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

    property WebSocket socket: WebSocket {
        url: root.url
        active: true

        onStatusChanged: {
            switch (status) {
                case WebSocket.Open:
                    console.log(
                        "[websocket] connected:",
                        root.url
                    )

                    root.reconnectTimer.stop()
                    root.connectionChanged(true)

                    Qt.callLater(root.registerEndpoints)

                    break

                case WebSocket.Closed:
                    console.log(
                        "[websocket] disconnected:",
                        root.url
                    )

                    root.connectionChanged(false)

                    if (root.autoReconnect)
                        root.reconnectTimer.restart()

                    break

                case WebSocket.Error:
                    console.warn(
                        "[websocket] error:",
                        errorString
                    )

                    root.socketError(errorString)
                    root.connectionChanged(false)

                    if (root.autoReconnect)
                        root.reconnectTimer.restart()

                    break
            }
        }

        onTextMessageReceived: message => {
            root.messageReceived(message)

            try {
                const data = JSON.parse(message)
                root.jsonReceived(data)
            } catch (error) {
                // Raw non-JSON messages are valid too.
            }
        }
    }

    property Timer reconnectTimer: Timer {
        interval: root.reconnectInterval
        repeat: false

        onTriggered: {
            if (root.socket.status === WebSocket.Open)
                return

            console.log(
                "[websocket] reconnecting:",
                root.url
            )

            root.socket.active = false
            root.socket.active = true
        }
    }
}