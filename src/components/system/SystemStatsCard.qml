import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../md3"

Rectangle {
    id: root

    required property var i18n
    required property var info
    required property var storage

    implicitHeight: 190

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

    // CPU metrics are read directly from the local Debian/Linux system.
    // CPU usage comes from /proc/stat and temperature from /sys/class/thermal.
    property real nativeCpuUsage: -1
    property real nativeCpuTemperature: -1
    property real previousCpuTotal: -1
    property real previousCpuIdle: -1

    readonly property real cpuUsage:
        clampPercent(nativeCpuUsage)

    readonly property real cpuTemperature:
        nativeCpuTemperature

    readonly property real ramUsage:
        clampPercent(info?.ram_usage)

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

    function refreshNativeCpu() {
        if (nativeCpuProcess.running)
            return

        nativeCpuProcess.exec([
            "/bin/sh",
            "-c",
            "head -n 1 /proc/stat; "
            + "temp=''; "
            + "if [ -r /sys/class/thermal/thermal_zone0/temp ]; then "
            + "temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null); "
            + "fi; "
            + "if [ -z \"$temp\" ]; then "
            + "for f in /sys/class/thermal/thermal_zone*/temp /sys/class/hwmon/hwmon*/temp*_input; do "
            + "[ -r \"$f\" ] || continue; "
            + "temp=$(cat \"$f\" 2>/dev/null); "
            + "[ -n \"$temp\" ] && break; "
            + "done; "
            + "fi; "
            + "printf 'TEMP %s\\n' \"$temp\""
        ])
    }

    Process {
        id: nativeCpuProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = String(text)
                    .trim()
                    .split(/\\r?\\n/)

                for (const line of lines) {
                    const value = String(line).trim()

                    if (value.startsWith("cpu ")) {
                        const fields = value
                            .split(/\\s+/)
                            .slice(1)
                            .map(Number)

                        if (fields.length < 4)
                            continue

                        let valid = true
                        for (const field of fields) {
                            if (!Number.isFinite(field)) {
                                valid = false
                                break
                            }
                        }

                        if (!valid)
                            continue

                        const user = fields[0] ?? 0
                        const nice = fields[1] ?? 0
                        const system = fields[2] ?? 0
                        const idle = fields[3] ?? 0
                        const iowait = fields[4] ?? 0
                        const irq = fields[5] ?? 0
                        const softirq = fields[6] ?? 0
                        const steal = fields[7] ?? 0

                        const idleAll = idle + iowait
                        const total =
                            user
                            + nice
                            + system
                            + idle
                            + iowait
                            + irq
                            + softirq
                            + steal

                        if (
                            root.previousCpuTotal >= 0
                            && root.previousCpuIdle >= 0
                        ) {
                            const totalDelta =
                                total - root.previousCpuTotal
                            const idleDelta =
                                idleAll - root.previousCpuIdle

                            if (totalDelta > 0) {
                                root.nativeCpuUsage =
                                    Math.max(
                                        0,
                                        Math.min(
                                            100,
                                            (totalDelta - idleDelta)
                                            / totalDelta
                                            * 100
                                        )
                                    )
                            }
                        }

                        root.previousCpuTotal = total
                        root.previousCpuIdle = idleAll
                        continue
                    }

                    if (value.startsWith("TEMP ")) {
                        const raw = Number(
                            value.substring(5).trim()
                        )

                        if (Number.isFinite(raw)) {
                            root.nativeCpuTemperature =
                                Math.abs(raw) >= 1000
                                ? raw / 1000
                                : raw
                        }
                    }
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                const message = String(line).trim()
                if (message !== "")
                    console.warn(
                        "[system-native-cpu]",
                        message
                    )
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered:
            root.refreshNativeCpu()
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
                Layout.preferredWidth: 142
                Layout.preferredHeight: 142
                Layout.alignment: Qt.AlignVCenter

                Canvas {
                    id: rings
                    anchors.fill: parent

                    property real cpuValue: root.cpuUsage
                    property real ramValue: root.ramUsage
                    property real storageValue: root.internalStorageUsage

                    onCpuValueChanged: requestPaint()
                    onRamValueChanged: requestPaint()
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

                        // Same three-ring hierarchy as Commander 2.0:
                        // CPU outer, RAM middle, internal storage inner.
                        drawRing(ctx, cx, cy, 58, 9, cpuValue, "#EF5350")
                        drawRing(ctx, cx, cy, 44, 9, ramValue, "#FFB300")
                        drawRing(ctx, cx, cy, 30, 9, storageValue, "#26C6DA")
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 9
                        Layout.preferredHeight: 9
                        radius: 5
                        color: "#EF5350"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.i18n.text("system_cpu_usage")
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 11
                    }

                    Text {
                        text: root.percentText(root.cpuUsage)
                        color: Md3Theme.surfaceContent
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 9
                        Layout.preferredHeight: 9
                        radius: 5
                        color: "#FFB300"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.i18n.text("system_ram_usage")
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 11
                    }

                    Text {
                        text: root.percentText(root.ramUsage)
                        color: Md3Theme.surfaceContent
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 9
                        Layout.preferredHeight: 9
                        radius: 5
                        color: "#26C6DA"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.i18n.text("system_internal_storage_usage")
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 11
                    }

                    Text {
                        text: root.percentText(root.internalStorageUsage)
                        color: Md3Theme.surfaceContent
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
