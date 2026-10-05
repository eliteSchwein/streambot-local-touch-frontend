import QtQuick
import QtWebSockets

QtObject {
    id: root

    property string baseUrl: "ws://127.0.0.1:8100"
    property string target: "music_preview"
    property bool autoReconnect: true
    property int reconnectInterval: 2000
    property bool enabled: true

    readonly property string url:
        baseUrl.replace(/\/$/, "")
        + "/cava/"
        + encodeURIComponent(target)

    readonly property bool connected:
        socket.status === WebSocket.Open

    readonly property bool connecting:
        socket.status === WebSocket.Connecting

    signal jsonReceived(var data)
    signal socketError(string error)

    function connectNow() {
        reconnectTimer.stop()

        if (!enabled) {
            socket.active = false
            return
        }

        if (
            socket.status === WebSocket.Open
            || socket.status === WebSocket.Connecting
        ) {
            return
        }

        socket.active = false

        Qt.callLater(function() {
            if (root.enabled)
                root.socket.active = true
        })
    }

    function reconnect() {
        reconnectTimer.stop()
        socket.active = false

        if (enabled)
            reconnectTimer.restart()
    }

    onEnabledChanged: {
        if (!enabled) {
            reconnectTimer.stop()
            socket.active = false
            return
        }

        Qt.callLater(connectNow)
    }

    onUrlChanged: {
        if (enabled)
            reconnect()
    }

    Component.onCompleted: {
        if (enabled)
            Qt.callLater(connectNow)
    }

    property WebSocket socket: WebSocket {
        url: root.url
        active: false

        onStatusChanged: function(status) {
            switch (status) {
                case WebSocket.Open:
                    console.log(
                        "[cava] connected:",
                        root.url
                    )
                    root.reconnectTimer.stop()
                    break

                case WebSocket.Closed:
                    if (
                        root.autoReconnect
                        && root.enabled
                    ) {
                        root.reconnectTimer.restart()
                    }
                    break

                case WebSocket.Error:
                    root.socketError(errorString)

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
            try {
                root.jsonReceived(JSON.parse(message))
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

            root.connectNow()
        }
    }
}
