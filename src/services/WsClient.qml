import QtQuick
import QtWebSockets
QtObject {
    id: root
    property string url: "ws://127.0.0.1:8100"
    property bool autoReconnect: true
    property int reconnectInterval: 2000
    property var endpoints: ["notify_alert","notify_alert_query"]
    property int nextRequestId: 1
    readonly property bool connected: socket.status === WebSocket.Open
    signal connectionChanged(bool connected)
    signal messageReceived(string message)
    signal jsonReceived(var data)
    signal socketError(string error)
    function send(message) { return typeof message === "string" ? sendText(message) : sendJson(message) }
    function sendText(message) {
        if (socket.status !== WebSocket.Open) { console.warn("[websocket] cannot send while disconnected"); return false }
        socket.sendTextMessage(message); return true
    }
    function sendJson(data) { try { return sendText(JSON.stringify(data)) } catch(e) { return false } }
    function sendRpc(method, params) {
        const id=nextRequestId++, req={jsonrpc:"2.0",id:id,method:method}
        if (params !== undefined) req.params=params
        return sendJson(req) ? id : -1
    }
    function registerEndpoints() {
        if (socket.status === WebSocket.Open) sendRpc("register_endpoints", endpoints)
    }
    function reconnect() { reconnectTimer.stop(); socket.active=false; reconnectTimer.restart() }
    property WebSocket socket: WebSocket {
        url: root.url; active: true
        onStatusChanged: {
            if (status === WebSocket.Open) {
                console.log("[websocket] connected:",root.url); root.reconnectTimer.stop(); root.connectionChanged(true); Qt.callLater(root.registerEndpoints)
            } else if (status === WebSocket.Closed) {
                root.connectionChanged(false); if (root.autoReconnect) root.reconnectTimer.restart()
            } else if (status === WebSocket.Error) {
                root.socketError(errorString); if (root.autoReconnect) root.reconnectTimer.restart()
            }
        }
        onTextMessageReceived: message => {
            root.messageReceived(message)
            try { root.jsonReceived(JSON.parse(message)) } catch(e) {}
        }
    }
    property Timer reconnectTimer: Timer {
        interval: root.reconnectInterval
        onTriggered: { if (!root.connected) { root.socket.active=false; root.socket.active=true } }
    }
}
