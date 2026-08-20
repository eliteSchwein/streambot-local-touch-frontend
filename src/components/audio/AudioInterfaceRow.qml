import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../md3"

Rectangle {
    id: root

    required property string interfaceName
    required property var device
    required property var i18n
    required property var websocket

    property bool physical: false
    property bool showLinkButton: !physical

    signal linkRequested(string interfaceName, var device)

    property real draftVolume:
        Number(
            device.current_volume
            ?? device.default_volume
            ?? device.volume
            ?? 0
        )

    property real previousVolume:
        Math.max(
            0.01,
            Number(
                device.current_volume
                ?? device.default_volume
                ?? device.volume
                ?? 0.2
            )
        )

    readonly property bool pipewireSink:
        !physical
        && (
            device.pipewire_sink === true
            || device.pipewire_sink === "true"
        )

    readonly property real minVolume:
        Number(device.min_range ?? 0)

    readonly property real maxVolume:
        Number(device.max_range ?? 1)

    readonly property real stepVolumeValue: {
        if (physical)
            return 0.05

        const value =
            Number(device.steps_range ?? 0.01)

        return Number.isFinite(value) && value > 0
            ? value
            : 0.01
    }

    readonly property bool muted:
        physical
        ? device.muted === true
        : (
            device.muted === true
            || draftVolume <= minVolume
        )

    readonly property string subtitle: {
        if (physical) {
            return String(
                device.name
                ?? device.id
                ?? ""
            )
        }

        return String(
            device.sink_name
            ?? ("streambot_" + interfaceName)
        )
    }

    radius: Md3Theme.radiusLarge
    color: Md3Theme.surfaceContainer

    border.width: 1
    border.color: Md3Theme.outlineVariant

    implicitHeight: 76

    function physicalOutputName() {
        return String(
            device.name
            ?? device.id
            ?? ""
        )
    }

    function clampVolume(value) {
        return Math.max(
            minVolume,
            Math.min(maxVolume, value)
        )
    }

    function setVolume(value) {
        const safeValue =
            clampVolume(Number(value))

        if (safeValue > 0)
            previousVolume = safeValue

        draftVolume = safeValue

        if (physical) {
            const outputName =
                physicalOutputName()

            if (!outputName)
                return

            pactlProcess.command = [
                "pactl",
                "set-sink-volume",
                outputName,
                Math.round(safeValue * 100) + "%"
            ]

            pactlProcess.running = true
            return
        }

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

    function toggleMute() {
        if (physical) {
            const outputName =
                physicalOutputName()

            if (!outputName)
                return

            pactlProcess.command = [
                "pactl",
                "set-sink-mute",
                outputName,
                "toggle"
            ]

            pactlProcess.running = true
            return
        }

        if (muted) {
            setVolume(
                Math.max(
                    previousVolume,
                    Number(device.default_volume ?? 0.2)
                )
            )
        } else {
            previousVolume =
                Math.max(draftVolume, 0.01)

            setVolume(0)
        }
    }

    onDeviceChanged: {
        if (!volumeSlider.pressed) {
            const next =
                Number(
                    device.current_volume
                    ?? device.default_volume
                    ?? device.volume
                    ?? 0
                )

            draftVolume = next

            if (next > 0)
                previousVolume = next
        }
    }

    Process {
        id: pactlProcess
        running: false
    }

    Timer {
        id: volumeSendTimer

        interval: 140
        repeat: false

        onTriggered:
            root.setVolume(root.draftVolume)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        anchors.topMargin: 8
        anchors.bottomMargin: 8

        spacing: 10

        ColumnLayout {
            Layout.preferredWidth: 110
            Layout.minimumWidth: 95
            Layout.maximumWidth: 125

            Layout.alignment: Qt.AlignVCenter

            spacing: 1

            Text {
                Layout.fillWidth: true

                text: root.interfaceName
                color: Md3Theme.surfaceContent

                font.pixelSize: 13
                font.weight: Font.DemiBold

                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle !== ""

                text: root.subtitle
                color: Md3Theme.surfaceVariantContent

                font.pixelSize: 8

                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            spacing: 2

            Md3Slider {
                id: volumeSlider

                Layout.fillWidth: true
                Layout.preferredHeight: 26

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
                Layout.preferredHeight: 34

                spacing: 6

                AudioControlButton {
                    icon: "minus"
                    enabled: !root.muted

                    onClicked:
                        root.stepVolume(-1)
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: volumeMutePill

                    implicitWidth: 94
                    implicitHeight: 32

                    radius: 16

                    color:
                        root.muted
                        ? Md3Theme.primary
                        : muteTap.pressed
                            ? Md3Theme.surfaceContainerHigh
                            : Md3Theme.surfaceContainerHighest

                    border.width:
                        root.muted
                        ? 0
                        : 1

                    border.color:
                        Md3Theme.outlineVariant

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MdiIcon {
                            name:
                                root.muted
                                ? "volume-off"
                                : "volume-high"

                            size: 17
                            selected: root.muted
                        }

                        Text {
                            text:
                                Math.round(
                                    root.draftVolume * 100
                                )
                                + "%"

                            color:
                                root.muted
                                ? Md3Theme.primaryContent
                                : Md3Theme.surfaceContent

                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    TapHandler {
                        id: muteTap

                        onTapped:
                            root.toggleMute()
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                AudioControlButton {
                    icon: "plus"
                    enabled: !root.muted

                    onClicked:
                        root.stepVolume(1)
                }
            }
        }

        AudioLinkButton {
            Layout.alignment: Qt.AlignVCenter

            implicitWidth: 38
            implicitHeight: 38

            visible:
                root.showLinkButton
                && root.pipewireSink

            onClicked:
                root.linkRequested(
                    root.interfaceName,
                    root.device
                )
        }
    }
}
