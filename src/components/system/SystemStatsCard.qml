import QtQuick
import QtQuick.Layouts
import "../md3"

Rectangle {
    id: root

    required property var i18n
    required property var info
    required property var storage

    implicitHeight: 176

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
        return Number.isFinite(n) ? n : null
    }

    function fallbackStoragePercent() {
        const total = numberOrNull(storage?.total)
        const used = numberOrNull(storage?.used)

        if (
            total === null
            || used === null
            || total <= 0
        ) {
            return null
        }

        return Math.max(
            0,
            Math.min(
                100,
                used / total * 100
            )
        )
    }

    readonly property real cpuUsage:
        numberOrNull(info?.cpu_usage) ?? -1

    readonly property real cpuTemperature:
        numberOrNull(info?.cpu_temperature) ?? -1

    readonly property real ramUsage:
        numberOrNull(info?.ram_usage) ?? -1

    readonly property real internalStorageUsage: {
        const backendValue =
            numberOrNull(info?.internal_storage_usage)

        if (backendValue !== null)
            return backendValue

        const fallback = fallbackStoragePercent()
        return fallback === null ? -1 : fallback
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

    function barValue(value) {
        if (value < 0)
            return 0

        return Math.max(
            0,
            Math.min(
                1,
                value / 100
            )
        )
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 9

        Text {
            Layout.fillWidth: true

            text: root.i18n.text("system_stats")
            color: Md3Theme.surfaceContent

            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: [
                    {
                        label: root.i18n.text("system_cpu_usage"),
                        value: root.cpuUsage,
                        text: root.percentText(root.cpuUsage)
                    },
                    {
                        label: root.i18n.text("system_cpu_temp"),
                        value: -1,
                        text: root.tempText(root.cpuTemperature)
                    },
                    {
                        label: root.i18n.text("system_ram_usage"),
                        value: root.ramUsage,
                        text: root.percentText(root.ramUsage)
                    },
                    {
                        label: root.i18n.text("system_internal_storage_usage"),
                        value: root.internalStorageUsage,
                        text: root.percentText(root.internalStorageUsage)
                    }
                ]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 54

                    radius: Md3Theme.radiusMedium
                    color: Md3Theme.surfaceContainerHighest

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.fillWidth: true

                                text: modelData.label
                                color: Md3Theme.surfaceVariantContent

                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.text
                                color: Md3Theme.surfaceContent

                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 5

                            visible:
                                Number(modelData.value) >= 0

                            radius: 3
                            color: Md3Theme.surfaceContainer

                            Rectangle {
                                width:
                                    parent.width
                                    * root.barValue(
                                        Number(modelData.value)
                                    )

                                height: parent.height
                                radius: parent.radius
                                color: Md3Theme.primary

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 250
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
