import QtQuick
import QtQuick.Layouts

import "../md3"

Rectangle {
    id: root

    required property string interfaceName
    required property var device
    required property var i18n
    required property var websocket

    signal linkRequested(string interfaceName, var device)

    property real draftVolume:
        Number(
            device.current_volume
            ?? device.default_volume
            ?? 0
        )

    readonly property bool pipewireSink:
        device.pipewire_sink === true
        || device.pipewire_sink === "true"

    readonly property real minVolume:
        Number(device.min_range ?? 0)

    readonly property real maxVolume:
        Number(device.max_range ?? 1)

    readonly property real stepVolumeValue: {
        const value = Number(device.steps_range ?? 0.01)

        return Number.isFinite(value) && value > 0
            ? value
            : 0.01
    }

    readonly property bool muted:
        device.muted === true

    radius: Md3Theme.radiusLarge
    color: Md3Theme.surfaceContainer

    border.width: 1
    border.color: Md3Theme.outlineVariant

    implicitHeight: 92

    function clampVolume(value) {
        return Math.max(
            minVolume,
            Math.min(maxVolume, value)
        )
    }

    function setVolume(value) {
        const safeValue =
            clampVolume(Number(value))

        draftVolume = safeValue

        websocket.sendRpc(
            "set_volume",
            {
                interface: interfaceName,
                volume: safeValue
            }
        )
    }

    function stepVolume(direction) {
        setVolume(
            draftVolume
            + stepVolumeValue * direction
        )
    }

    onDeviceChanged: {
        if (!volumeSlider.pressed) {
            draftVolume = Number(
                device.current_volume
                ?? device.default_volume
                ?? 0
            )
        }
    }

    Timer {
        id: volumeSendTimer

        interval: 160
        repeat: false

        onTriggered:
            root.setVolume(root.draftVolume)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ColumnLayout {
            Layout.preferredWidth: 125
            Layout.alignment: Qt.AlignVCenter

            spacing: 2

            Text {
                Layout.fillWidth: true

                text: root.interfaceName
                color: Md3Theme.surfaceContent

                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true

                visible: root.pipewireSink

                text:
                    root.device.sink_name
                    || ("streambot_" + root.interfaceName)

                color: Md3Theme.surfaceVariantContent
                font.pixelSize: 8
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: 3

            Md3Slider {
                id: volumeSlider

                Layout.fillWidth: true

                from: root.minVolume
                to: root.maxVolume
                stepSize: root.stepVolumeValue

                enabled: !root.muted
                value: root.draftVolume

                onMoved: {
                    root.draftVolume = value
                    volumeSendTimer.restart()
                }

                onPressedChanged: {
                    if (!pressed) {
                        volumeSendTimer.stop()
                        root.setVolume(value)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Md3IconButton {
                    icon: "−"
                    enabled: !root.muted

                    onClicked:
                        root.stepVolume(-1)
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter

                    text:
                        Math.round(
                            root.draftVolume * 100
                        )
                        + "%"

                    color: Md3Theme.surfaceVariantContent
                    font.pixelSize: 10
                }

                Item {
                    Layout.fillWidth: true
                }

                Md3IconButton {
                    icon: "+"
                    enabled: !root.muted

                    onClicked:
                        root.stepVolume(1)
                }
            }
        }

        AudioLinkButton {
            Layout.alignment: Qt.AlignVCenter

            visible: root.pipewireSink

            onClicked:
                root.linkRequested(
                    root.interfaceName,
                    root.device
                )
        }
    }
}
