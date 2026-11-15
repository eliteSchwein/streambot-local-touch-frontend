import QtQuick
import QtWebSockets

QtObject {
    id: root

    property string url: "ws://127.0.0.1:8100"
    property bool autoReconnect: true
    property int reconnectInterval: 2000
    property bool enabled: true

    // Backend 2.0/3.0: subscriptions are explicit per connection.
    // Never use ["all"]; on every reconnect the complete required set is
    // registered again. The backend sends the current state once for every
    // registered state endpoint, then only sends that endpoint again when its
    // state changes.
    property var endpoints: [
        "notify_interaction",
        "notify_interaction_queue",
        "notify_music_update",
        "notify_playlist_update",
        "notify_audio_update",
        "notify_audio_outputs_update",
        "notify_auto_macros_update",
        "notify_macro_update",
        "notify_channel_point_update",
        "notify_update_manager",
        "notify_storage_update",
        "notify_system_info",
        "notify_settings_update",
        "notify_speedtest_update"
    ]

    property int nextRequestId: 1

    // id -> { method, expectedMethod }
    property var pendingRequests: ({})

    readonly property bool connected:
        socket.status === WebSocket.Open

    readonly property bool connecting:
        socket.status === WebSocket.Connecting

    property bool everConnected: false

    signal connectionChanged(bool connected)
    signal messageReceived(string message)

    // notify_* packets only.
    signal jsonReceived(var data)
    signal notificationReceived(string method, var params, var data)

    // result_* / JSON-RPC response packets only.
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

    function resultMethodFor(method) {
        return "result_" + String(method ?? "")
    }

    function sendRpc(method, params, expectedResultMethod) {
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

        const pending = Object.assign({}, pendingRequests)
        pending[String(id)] = {
            method: String(method),
            expectedMethod:
                expectedResultMethod !== undefined
                ? String(expectedResultMethod)
                : resultMethodFor(method)
        }
        pendingRequests = pending

        return id
    }

    function forgetRequest(id) {
        const key = String(id)
        if (pendingRequests[key] === undefined)
            return

        const pending = Object.assign({}, pendingRequests)
        delete pending[key]
        pendingRequests = pending
    }

    function cancelAllPendingRequests() {
        pendingRequests = ({})
    }

    function normalizedEndpoints(values) {
        const out = []

        for (const raw of (values ?? [])) {
            const endpoint = String(raw ?? "").trim()

            if (
                endpoint === ""
                || endpoint === "all"
                || !endpoint.startsWith("notify_")
                || out.includes(endpoint)
            ) {
                continue
            }

            out.push(endpoint)
        }

        return out
    }

    function registerEndpoints(values) {
        if (socket.status !== WebSocket.Open)
            return -1

        const list = normalizedEndpoints(
            values !== undefined
            ? values
            : endpoints
        )

        if (list.length === 0)
            return -1

        console.log(
            "[websocket] registering endpoints:",
            JSON.stringify(list)
        )

        return sendRpc(
            "register_endpoints",
            list,
            "result_register_endpoints"
        )
    }

    // Optional incremental subscription helper for future Touch cards.
    // Registration is idempotent on the backend.
    function subscribeEndpoint(endpoint) {
        const name = String(endpoint ?? "").trim()

        if (
            name === ""
            || name === "all"
            || !name.startsWith("notify_")
        ) {
            return false
        }

        const next = normalizedEndpoints(
            (endpoints ?? []).concat([name])
        )
        endpoints = next

        if (socket.status === WebSocket.Open)
            registerEndpoints([name])

        return true
    }

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
        cancelAllPendingRequests()

        if (!enabled) {
            socket.active = false
            return
        }

        socket.active = false
        reconnectTimer.restart()
    }

    function handleIncomingPacket(data) {
        if (!data || typeof data !== "object")
            return

        const method =
            typeof data.method === "string"
            ? data.method
            : ""

        // Notifications are state/event traffic and never satisfy RPC calls.
        if (method.startsWith("notify_")) {
            root.notificationReceived(
                method,
                data.params,
                data
            )
            root.jsonReceived(data)
            return
        }

        const hasId =
            data.id !== undefined
            && data.id !== null

        if (!hasId)
            return

        const id = Number(data.id)
        const pending =
            root.pendingRequests[String(id)]

        if (pending === undefined) {
            // Late response from a request that was cancelled by reconnect.
            return
        }

        // Backend 3.0 uses result_* response methods. Keep support for the
        // classic JSON-RPC {result}/{error} envelope during migration.
        const classicResponse =
            data.result !== undefined
            || data.error !== undefined

        const resultResponse =
            method.startsWith("result_")

        if (!classicResponse && !resultResponse)
            return

        if (
            resultResponse
            && pending.expectedMethod !== ""
            && method !== pending.expectedMethod
        ) {
            console.warn(
                "[websocket] response method mismatch:",
                "id=" + id,
                "expected=" + pending.expectedMethod,
                "received=" + method
            )
            return
        }

        root.forgetRequest(id)
        root.rpcResponse(id, data)
    }

    onEnabledChanged: {
        if (!enabled) {
            reconnectTimer.stop()
            cancelAllPendingRequests()
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
                        "[websocket] connected:",
                        root.url
                    )

                    root.everConnected = true
                    root.reconnectTimer.stop()
                    root.connectionChanged(true)

                    // Register only after Qt reports the socket as truly open.
                    // The backend immediately sends the initial state for all
                    // registered state endpoints.
                    Qt.callLater(function() {
                        root.registerEndpoints()
                    })
                    break

                case WebSocket.Closed:
                    root.cancelAllPendingRequests()
                    root.connectionChanged(false)

                    if (
                        root.autoReconnect
                        && root.enabled
                    ) {
                        root.reconnectTimer.restart()
                    }
                    break

                case WebSocket.Error:
                    root.cancelAllPendingRequests()
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
                root.handleIncomingPacket(data)
            } catch (error) {
                console.warn(
                    "[websocket] invalid JSON:",
                    error
                )
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
