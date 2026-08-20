import QtQuick
import QtQuick.Layouts

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
        const value = Number(device.steps_range ?? 0.01)

        return Number.isFinite(value) && value > 0
            ? value
            : 0.01
    }

    readonly property bool muted:
        device.muted === true

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

    implicitHeight: 88

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

        if (physical) {
            // No guessed backend RPC for physical-output volume.
            // This row remains live/read-only until the RPC name is exposed.
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
        if (physical)
            return

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
                ?? device.volume
                ?? 0
            )
        }
    }

    Timer {
        id: volumeSendTimer

        interval: 160
        repeat: false

        onTriggered: {
            if (!root.physical)
                root.setVolume(root.draftVolume)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // Much tighter label area than v33.
        ColumnLayout {
            Layout.preferredWidth: 92
            Layout.minimumWidth: 82
            Layout.maximumWidth: 110
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

        // Controls now immediately follow label block.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: 2

            Md3Slider {
                id: volumeSlider

                Layout.fillWidth: true

                from: root.minVolume
                to: root.maxVolume
                stepSize: root.stepVolumeValue

                enabled:
                    !root.physical
                    && !root.muted

                value: root.draftVolume

                onMoved: {
                    if (root.physical)
                        return

                    root.draftVolume = value
                    volumeSendTimer.restart()
                }

                onPressedChanged: {
                    if (
                        !pressed
                        && !root.physical
                    ) {
                        volumeSendTimer.stop()
                        root.setVolume(value)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Md3IconButton {
                    visible: !root.physical

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
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    Layout.fillWidth: true
                }

                Md3IconButton {
                    visible: !root.physical

                    icon: "+"
                    enabled: !root.muted

                    onClicked:
                        root.stepVolume(1)
                }
            }
        }

        AudioLinkButton {
            Layout.alignment: Qt.AlignVCenter

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
