import QtQuick
import QtQuick.Layouts
import "../md3"

Rectangle {
    id: root

    required property var i18n
    required property var info
    required property var storage

    implicitHeight: 165

    radius: Md3Theme.radiusLarge
    color: "transparent"
    border.width: 0

    Md3GlassSurface {
        anchors.fill: parent
        tintColor: Md3Theme.surfaceContainer
        tintOpacity: 0.94
        radius: root.radius
    }

    function numberOrNull(value) {
        if (
            value === undefined
            || value === null
            || value === ""
        ) {
            return null
        }

        const n = Number(value)
        if (Number.isFinite(n))
            return n

        if (typeof value === "string") {
            const parsed = parseFloat(value)
            if (Number.isFinite(parsed))
                return parsed
        }

        return null
    }

    function clampPercent(value) {
        const n = numberOrNull(value)
        if (n === null)
            return -1
        return Math.max(0, Math.min(100, n))
    }

    function fallbackStoragePercent() {
        const total = numberOrNull(storage?.total)
        const used = numberOrNull(storage?.used)

        if (total === null || used === null || total <= 0)
            return -1

        return clampPercent(used / total * 100)
    }

    readonly property real cpuUsage:
        clampPercent(info?.cpu_usage)

    readonly property real cpuTemperature: {
        const value = numberOrNull(info?.cpu_temperature)
        return value === null ? -1 : value
    }

    readonly property real ramUsage:
        clampPercent(info?.ram_usage)

    readonly property bool hasSwap:
        (numberOrNull(info?.swap_total) ?? 0) > 0

    readonly property real swapUsage:
        hasSwap ? clampPercent(info?.swap_usage) : -1

    readonly property color cpuColor: "#EF5350"
    readonly property color ramColor: "#FFB300"
    readonly property color swapColor: "#AB47BC"
    readonly property color storageColor: "#26C6DA"

    // Same thresholds as the admin panel: orange from 80 %, red from 90 %.
    readonly property real usageWarningPercent: 80
    readonly property real usageCriticalPercent: 90

    function usageColor(value) {
        if (value >= usageCriticalPercent)
            return Md3Theme.error
        if (value >= usageWarningPercent)
            return "#FF9800"
        return Md3Theme.surfaceContent
    }

    readonly property real internalStorageUsage: {
        const backendValue = clampPercent(info?.internal_storage_usage)
        return backendValue >= 0
            ? backendValue
            : fallbackStoragePercent()
    }

    function percentText(value) {
        return value >= 0
            ? Math.round(value) + "%"
            : "—"
    }

    function tempText(value) {
        return value >= 0
            ? Math.round(value) + " °C"
            : "—"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.i18n.text("system_stats")
                color: Md3Theme.surfaceContent
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            Text {
                text:
                    root.i18n.text("system_cpu_temp")
                    + "  "
                    + root.tempText(root.cpuTemperature)
                color: Md3Theme.surfaceContent
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Item {
                Layout.preferredWidth: 126
                Layout.preferredHeight: 126
                Layout.alignment: Qt.AlignVCenter

                Canvas {
                    id: rings
                    anchors.fill: parent

                    property real cpuValue: root.cpuUsage
                    property real ramValue: root.ramUsage
                    property real swapValue: root.swapUsage
                    property real storageValue: root.internalStorageUsage

                    onCpuValueChanged: requestPaint()
                    onRamValueChanged: requestPaint()
                    onSwapValueChanged: requestPaint()
                    onStorageValueChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    function drawRing(ctx, cx, cy, radius, width, value, color) {
                        const start = -Math.PI / 2
                        const full = Math.PI * 2

                        ctx.beginPath()
                        ctx.strokeStyle = Md3Theme.surfaceContainerHighest
                        ctx.lineWidth = width
                        ctx.lineCap = "round"
                        ctx.arc(cx, cy, radius, start, start + full, false)
                        ctx.stroke()

                        if (value < 0)
                            return

                        const progress = Math.max(0, Math.min(100, value)) / 100
                        if (progress <= 0)
                            return

                        ctx.beginPath()
                        ctx.strokeStyle = color
                        ctx.lineWidth = width
                        ctx.lineCap = "round"
                        ctx.arc(
                            cx,
                            cy,
                            radius,
                            start,
                            start + full * progress,
                            false
                        )
                        ctx.stroke()
                    }

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()

                        const cx = width / 2
                        const cy = height / 2

                        // Same ring hierarchy as the admin panel:
                        // CPU outer, RAM, swap, internal storage inner.
                        drawRing(ctx, cx, cy, 54, 6, cpuValue, root.cpuColor)
                        drawRing(ctx, cx, cy, 43, 6, ramValue, root.ramColor)
                        drawRing(ctx, cx, cy, 32, 6, swapValue, root.swapColor)
                        drawRing(ctx, cx, cy, 21, 6, storageValue, root.storageColor)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                Repeater {
                    model: [
                        {
                            label: "system_cpu_usage",
                            color: root.cpuColor,
                            value: root.cpuUsage,
                            available: true
                        },
                        {
                            label: "system_ram_usage",
                            color: root.ramColor,
                            value: root.ramUsage,
                            available: true
                        },
                        {
                            label: "system_swap_usage",
                            color: root.swapColor,
                            value: root.swapUsage,
                            available: root.hasSwap
                        },
                        {
                            label: "system_internal_storage_usage",
                            color: root.storageColor,
                            value: root.internalStorageUsage,
                            available: true
                        }
                    ]

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 9
                            Layout.preferredHeight: 9
                            radius: 5
                            color: modelData.color
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.i18n.text(modelData.label)
                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.available
                                ? root.percentText(modelData.value)
                                : root.i18n.text("system_no_swap")
                            color: modelData.available
                                ? root.usageColor(modelData.value)
                                : Md3Theme.surfaceVariantContent
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
