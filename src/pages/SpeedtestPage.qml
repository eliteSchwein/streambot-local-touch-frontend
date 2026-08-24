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
        const value = root.i18n.tr(key)
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

    Rectangle {
        anchors {
            fill: parent
            margins: 10
        }

        radius: Md3Theme.radiusLarge
        color: Md3Theme.surfaceContainer
        border.width: 1
        border.color: Md3Theme.outlineVariant

        ColumnLayout {
            anchors {
                fill: parent
                margins: 12
            }

            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true

                    text: root.tr(
                        "speedtest_title",
                        "Speedtest"
                    )

                    color: Md3Theme.surfaceContent
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: Math.max(
                        74,
                        stageLabel.implicitWidth + 34
                    )

                    radius: 12

                    color:
                        root.running
                            ? Md3Theme.primaryContainer
                            : Md3Theme.surfaceContainerHigh

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        MdiIcon {
                            anchors.verticalCenter: parent.verticalCenter

                            name:
                                root.running
                                    ? "progress-clock"
                                    : "check-circle-outline"

                            size: 15
                        }

                        Text {
                            id: stageLabel
                            anchors.verticalCenter: parent.verticalCenter

                            text: root.stageText()

                            color:
                                root.running
                                    ? Md3Theme.onPrimaryContainer
                                    : Md3Theme.onSurfaceVariant

                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true

                text: root.tr(
                    "speedtest_description",
                    "Test the backend network connection."
                )

                color: Md3Theme.onSurfaceVariant
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Md3Theme.outlineVariant
            }

            MetricRow {
                iconName: "timer-outline"
                title: root.tr("speedtest_ping", "Ping")
                value: root.formatPing(root.pingMs)
                active: root.stage === "ping"
            }

            MetricRow {
                iconName: "download"
                title: root.tr(
                    "speedtest_download",
                    "Download"
                )
                value: root.formatMbps(root.downloadMbps)
                active: root.stage === "download"
            }

            MetricRow {
                iconName: "upload"
                title: root.tr(
                    "speedtest_upload",
                    "Upload"
                )
                value: root.formatMbps(root.uploadMbps)
                active: root.stage === "upload"
            }

            Item {
                Layout.fillHeight: true
            }

            Rectangle {
                visible: root.errorText.length > 0

                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 38 : 0

                radius: Md3Theme.radiusMedium
                color: Md3Theme.errorContainer

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }

                    spacing: 6

                    MdiIcon {
                        name: "alert-circle-outline"
                        size: 17
                    }

                    Text {
                        Layout.fillWidth: true

                        text: root.errorText
                        color: Md3Theme.onErrorContainer
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                id: runButton

                Layout.fillWidth: true
                Layout.preferredHeight: 40

                radius: Md3Theme.radiusMedium

                color:
                    runTap.pressed
                        ? Md3Theme.primaryContainer
                        : (
                                root.running
                                || root.starting
                                || !root.websocket.connected
                                ? Md3Theme.surfaceContainerHighest
                                : Md3Theme.primary
                        )

                opacity:
                        root.running
                    || root.starting
                    || !root.websocket.connected
                    ? 0.72
                    : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    MdiIcon {
                        anchors.verticalCenter: parent.verticalCenter

                        // "play-circle-outline" gives the action a clear
                        // start-button appearance instead of a bare play glyph.
                        name:
                                root.running || root.starting
                            ? "progress-clock"
                            : "play-circle-outline"

                        size: 18
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        text:
                            root.running
                                ? root.tr(
                                    "speedtest_running",
                                    "Speedtest running"
                                )
                                : (
                                    root.starting
                                        ? root.tr(
                                            "speedtest_starting",
                                            "Starting…"
                                        )
                                        : root.tr(
                                            "speedtest_run",
                                            "Run speedtest"
                                        )
                                )

                        color:
                                root.running
                            || root.starting
                            || !root.websocket.connected
                            ? Md3Theme.onSurfaceVariant
                            : Md3Theme.onPrimary

                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                TapHandler {
                    id: runTap

                    enabled:
                        !root.running
                        && !root.starting
                        && root.websocket.connected

                    onTapped:
                        root.startSpeedtest()
                }
            }
        }
    }

    component MetricRow: Rectangle {
        id: metric

        required property string iconName
        required property string title
        required property string value
        property bool active: false

        Layout.fillWidth: true
        Layout.preferredHeight: 52

        radius: Md3Theme.radiusMedium

        color:
            active
                ? Md3Theme.primaryContainer
                : Md3Theme.surfaceContainerHigh

        border.width: 1
        border.color:
            active
                ? Md3Theme.primary
                : Md3Theme.outlineVariant

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }

            spacing: 8

            MdiIcon {
                name: metric.iconName
                size: 18
            }

            Text {
                Layout.fillWidth: true

                text: metric.title

                color:
                    metric.active
                        ? Md3Theme.onPrimaryContainer
                        : Md3Theme.onSurfaceVariant

                font.pixelSize: 12
            }

            Text {
                text: metric.value

                color:
                    metric.active
                        ? Md3Theme.onPrimaryContainer
                        : Md3Theme.onSurface

                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }
}
