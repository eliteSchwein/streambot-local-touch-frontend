import QtQuick
import QtQuick.Layouts

import "../md3"

Rectangle {
    id: root

    required property string interfaceName
    required property var device
    required property var outputs
    required property var i18n
    required property var websocket

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

    implicitHeight: 112

    function clampVolume(value) {
        return Math.max(
            minVolume,
            Math.min(maxVolume, value)
        )
    }

    function setVolume(value) {
        const safeValue = clampVolume(Number(value))

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

    function outputIdentifier(output) {
        return String(
            output.name
            ?? output.node_name
            ?? output.nodeName
            ?? output.description
            ?? output.id
            ?? output.index
            ?? ""
        )
    }

    function outputLabel(output) {
        return String(
            output.description
            ?? output.display_name
            ?? output.displayName
            ?? output.name
            ?? output.node_name
            ?? output.nodeName
            ?? output.id
            ?? i18n.text("audio_unknown_output")
        )
    }

    function isDefaultOutput(output) {
        return output.is_default === true
            || output.default === true
            || output.isDefault === true
    }

    function isSinkLinked(output) {
        const outputName = outputIdentifier(output)

        if (!outputName)
            return false

        const linkedOutput =
            device.linked_output
            ?? device.actual_linked_output
            ?? device.audio_output
            ?? device.output
            ?? null

        const linkedOutputs =
            device.linked_outputs
            ?? device.actual_linked_outputs
            ?? device.audio_outputs
            ?? []

        const outputLinkedInterfaces =
            output.linked_interfaces
            ?? output.active_interfaces
            ?? output.interfaces
            ?? []

        if (String(linkedOutput) === outputName)
            return true

        if (
            Array.isArray(linkedOutputs)
            && linkedOutputs.map(String).includes(outputName)
        ) {
            return true
        }

        if (
            Array.isArray(outputLinkedInterfaces)
            && outputLinkedInterfaces
                .map(String)
                .includes(interfaceName)
        ) {
            return true
        }

        return false
    }

    function toggleSink(output) {
        const outputName = outputIdentifier(output)

        if (!outputName)
            return

        const linked =
            !isSinkLinked(output)

        console.log(
            "[audio] link_sink:",
            interfaceName,
            outputName,
            linked
        )

        websocket.sendRpc(
            "link_sink",
            {
                interface: interfaceName,
                output: outputName,
                linked: linked
            }
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

        onTriggered: {
            root.setVolume(root.draftVolume)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        // Name
        ColumnLayout {
            Layout.preferredWidth: 115
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter

            spacing: 3

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                text: root.interfaceName
                color: Md3Theme.surfaceContent

                font.pixelSize: 15
                font.weight: Font.DemiBold

                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true

                visible: root.pipewireSink

                text:
                    root.device.sink_name
                    || ("streambot_" + root.interfaceName)

                color: Md3Theme.surfaceVariantContent
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }

        // Volume
        ColumnLayout {
            Layout.preferredWidth: 260
            Layout.fillHeight: true

            spacing: 4

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
                spacing: 6

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

                Md3IconButton {
                    icon: root.muted ? "🔇" : "🔊"

                    onClicked: {
                        if (root.muted) {
                            root.setVolume(
                                Number(
                                    root.device.current_volume
                                    ?? root.device.default_volume
                                    ?? root.minVolume
                                )
                            )
                        } else {
                            root.setVolume(0)
                        }
                    }
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

        // Outputs
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flow {
                id: outputFlow

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                spacing: 6

                Repeater {
                    model:
                        root.pipewireSink
                        ? root.outputs
                        : []

                    AudioOutputChip {
                        required property var modelData

                        text:
                            root.outputLabel(modelData)

                        checked:
                            root.isSinkLinked(modelData)

                        isDefault:
                            root.isDefaultOutput(modelData)

                        onClicked:
                            root.toggleSink(modelData)
                    }
                }

                Text {
                    visible:
                        !root.pipewireSink
                        || root.outputs.length === 0

                    text: "—"
                    color: Md3Theme.surfaceVariantContent
                    font.pixelSize: 13
                }
            }
        }
    }
}
