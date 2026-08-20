import QtQuick
import QtWebSockets

QtObject {
    id: root

    property string url: "ws://127.0.0.1:8100"
    property bool autoReconnect: true
    property int reconnectInterval: 2000
    property bool enabled: true

    property var endpoints: [
        "notify_alert",
        "notify_alert_query",
        "notify_music_update",
        "notify_playlist_update",
        "notify_music_cava",
        "notify_audio_update",
        "notify_audio_outputs_update",
        "notify_auto_macros_update",
        "notify_macro_update",
        "notify_channel_point_update",
        "notify_update_manager",
        "notify_storage_update"
    ]

    property int nextRequestId: 1

    readonly property bool connected:
        socket.status === WebSocket.Open

    readonly property bool connecting:
        socket.status === WebSocket.Connecting

    property bool everConnected: false

    signal connectionChanged(bool connected)
    signal messageReceived(string message)
    signal jsonReceived(var data)
    signal rpcResponse(int id, var data)
    signal socketError(string error)

    function send(message) {
        return typeof message === "string"
            ? sendText(message)
            : sendJson(message)
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

    property WebSocket socket: WebSocket {
        url: root.url
        active: root.enabled

        onStatusChanged: function(status) {
            switch (status) {
            case WebSocket.Open:
                console.log(
                    "[websocket] connected:",
                    root.url
                )

                root.everConnected = true
                root.reconnectTimer.stop()
                root.connectionChanged(true)
                Qt.callLater(root.registerEndpoints)
                break

            case WebSocket.Closed:
                root.connectionChanged(false)

                if (
                    root.autoReconnect
                    && root.enabled
                ) {
                    root.reconnectTimer.restart()
                }

                break

            case WebSocket.Error:
                root.socketError(errorString)
                root.connectionChanged(false)

                if (
                    root.autoReconnect
                    && root.enabled
                ) {
                    root.reconnectTimer.restart()
                }

                break
            }
        }

        onTextMessageReceived: message => {
            root.messageReceived(message)

            try {
                const data = JSON.parse(message)

                // JSON-RPC response: do not treat it like a notification.
                if (
                    data
                    && data.id !== undefined
                    && (
                        data.result !== undefined
                        || data.error !== undefined
                        || data.params !== undefined
                    )
                ) {
                    root.rpcResponse(
                        Number(data.id),
                        data
                    )
                }

                root.jsonReceived(data)
            } catch (error) {
            }
        }
    }

    property Timer reconnectTimer: Timer {
        interval: root.reconnectInterval
        repeat: false

        onTriggered: {
            if (
                !root.enabled
                || root.socket.status === WebSocket.Open
            ) {
                return
            }

            root.socket.active = false
            root.socket.active = true
        }
    }
}
