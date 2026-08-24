import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var websocket

    property bool running: false
    property bool starting: false
    property string stage: "idle"
    property real pingMs: -1
    property real downloadMbps: -1
    property real uploadMbps: -1
    property string errorText: ""

    function tr(key, fallback) {
        const value = root.i18n.text(key)
        return value === key ? fallback : value
    }

    function resetStartGuard() {
        starting = false
        startGuard.stop()
    }

    function applySpeedtestState(state) {
        if (!state)
            return

        running = state.running === true
        stage = state.stage || "idle"
        pingMs = state.ping_ms === null || state.ping_ms === undefined
            ? -1
            : Number(state.ping_ms)
        downloadMbps = state.download_mbps === null || state.download_mbps === undefined
            ? -1
            : Number(state.download_mbps)
        uploadMbps = state.upload_mbps === null || state.upload_mbps === undefined
            ? -1
            : Number(state.upload_mbps)
        errorText = state.error || ""

        if (running || stage === "finished" || stage === "error")
            resetStartGuard()
    }

    function startSpeedtest() {
        if (
            running
            || starting
            || !websocket.connected
        ) {
            return
        }

        starting = true
        startGuard.restart()

        const requestId = websocket.sendRpc("speedtest", {
            action: "start"
        })

        if (requestId < 0)
            resetStartGuard()
    }

    function requestStatus() {
        if (!websocket.connected)
            return

        websocket.sendRpc("speedtest", {
            action: "status"
        })
    }

    function formatPing(value) {
        if (!Number.isFinite(value) || value < 0)
            return "—"

        return Math.round(value) + " ms"
    }

    function formatMbps(value) {
        if (!Number.isFinite(value) || value < 0)
            return "—"

        return value.toFixed(1) + " Mbit/s"
    }

    function stageText() {
        return tr(
            "speedtest_stage_" + stage,
            stage
        )
    }

    Component.onCompleted:
        Qt.callLater(requestStatus)

    Connections {
        target: websocket

        function onConnectionChanged(connected) {
            if (connected)
                Qt.callLater(root.requestStatus)
            else
                root.resetStartGuard()
        }

        function onJsonReceived(message) {
            if (!message)
                return

            if (
                message.method === "notify_speedtest_update"
                && message.params
            ) {
                root.applySpeedtestState(message.params)
                return
            }

            // Handle the direct RPC response from start/status as well.
            if (
                message.id !== undefined
                && message.result
                && message.result.speedtest
            ) {
                root.applySpeedtestState(
                    message.result.speedtest
                )
            }
        }
    }

    Timer {
        id: startGuard
        interval: 3000
        repeat: false

        onTriggered:
            root.starting = false
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 12
        }

        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            MetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                iconName: "timer-outline"
                title: root.tr("speedtest_ping", "Ping")
                value: root.formatPing(root.pingMs)
                active: root.stage === "ping"
            }

            MetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                iconName: "download"
                title: root.tr(
                    "speedtest_download",
                    "Download"
                )
                value: root.formatMbps(root.downloadMbps)
                active: root.stage === "download"
            }

            MetricCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                iconName: "upload"
                title: root.tr(
                    "speedtest_upload",
                    "Upload"
                )
                value: root.formatMbps(root.uploadMbps)
                active: root.stage === "upload"
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            text:
                root.errorText.length > 0
                    ? root.errorText
                    : root.stageText()

            color:
                root.errorText.length > 0
                    ? Md3Theme.error
                    : Md3Theme.surfaceVariantContent

            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: 16

            readonly property bool canStart:
                !root.running
                && !root.starting
                && root.websocket.connected

            // Same colors as the Update button.
            color:
                canStart
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

            opacity:
                canStart
                    ? 1
                    : 0.55

            Text {
                anchors.centerIn: parent

                text:
                    root.running
                        ? root.i18n.text("speedtest_running")
                        : (
                            root.starting
                                ? root.i18n.text("speedtest_starting")
                                : root.i18n.text("speedtest_run")
                        )

                color:
                    parent.canStart
                        ? Md3Theme.primaryContent
                        : Md3Theme.surfaceVariantContent

                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            TapHandler {
                enabled: parent.canStart
                onTapped: root.startSpeedtest()
            }
        }
    }

    component MetricCard: Rectangle {
        id: metric

        required property string iconName
        required property string title
        required property string value
        property bool active: false

        radius: Md3Theme.radiusLarge

        color:
            metric.active
                ? Md3Theme.surfaceContainerHigh
                : Md3Theme.surfaceContainer

        border.width: 1
        border.color:
            metric.active
                ? Md3Theme.primary
                : Md3Theme.outlineVariant

        Column {
            anchors.centerIn: parent
            spacing: 8

            MdiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: metric.iconName
                size: 26
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: metric.title
                color: Md3Theme.surfaceVariantContent
                font.pixelSize: 12
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: metric.value
                color: Md3Theme.surfaceContent
                font.pixelSize: 24
                font.weight: Font.Bold
            }
        }
    }
}
