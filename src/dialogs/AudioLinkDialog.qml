import QtQuick
import QtQuick.Layouts

import "../components/md3"

Md3Dialog {
    id: root

    required property var i18n
    required property var websocket

    property string interfaceName: ""
    property var device: ({})
    property var outputs: []

    title:
        i18n
            .text("audio_link_outputs_for")
            .replace("%1", interfaceName)

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

    function isLinked(output) {
        const outputName = outputIdentifier(output)

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
            && outputLinkedInterfaces.map(String).includes(interfaceName)
        ) {
            return true
        }

        return false
    }

    readonly property bool perLink:
        device?.per_link_control === true

    readonly property real minVolume: Number(device?.min_range ?? 0)
    readonly property real maxVolume: Number(device?.max_range ?? 1)
    readonly property real stepVolume: {
        const value = Number(device?.steps_range ?? 0.01)
        return Number.isFinite(value) && value > 0 ? value : 0.01
    }

    function linkVolume(output) {
        const value = Number(device?.link_volumes?.[outputIdentifier(output)])
        return Number.isFinite(value)
            ? value
            : Number(device?.current_volume ?? device?.default_volume ?? 0)
    }

    function setLinkVolume(output, value) {
        websocket.sendRpc(
            "set_link_volume",
            {
                interface: interfaceName,
                output: outputIdentifier(output),
                volume: Math.max(minVolume, Math.min(maxVolume, Number(value)))
            }
        )
    }

    function setPerLink(enabled) {
        websocket.sendRpc(
            "set_per_link_control",
            {
                interface: interfaceName,
                enabled: enabled
            }
        )
    }

    // Linked outputs that are currently not available (e.g. unplugged).
    readonly property var offlineLinks: {
        const linked = Array.isArray(device?.linked_outputs) ? device.linked_outputs.map(String) : []
        const available = (outputs ?? []).map(output => outputIdentifier(output))
        return linked.filter(name => !available.includes(name))
    }

    // Readable name for an ALSA sink of a device that is not connected (e.g.
    // "alsa_output.usb-MOTU_M2_M2MA094DXA-00.HiFi__Line__sink" -> "MOTU M2 · Line").
    function prettySinkName(name) {
        const raw = String(name ?? "")
        // Bluetooth: "bluez_output.AA_BB_CC_DD_EE_FF.1" -> "Bluetooth AA:BB:CC:DD:EE:FF"
        const bluetooth = raw.match(/^bluez_output\.([0-9a-f]{2}(?:_[0-9a-f]{2}){5})/i)
        if (bluetooth)
            return "Bluetooth " + bluetooth[1].replace(/_/g, ":")
        const match = raw.match(/^alsa_output\.(?:usb|pci|platform|bluez)[-_](.+)\.([^.]+)$/)
        if (!match)
            return raw

        const parts = match[1].split("_").filter(part => part.length > 0)
        if (parts.length > 1 && /\d.*-\d+$/.test(parts[parts.length - 1]))
            parts.pop()

        const device = /^[0-9a-f]{4}$/i.test(parts[0] ?? "") ? "" : parts.join(" ")
        const profile = match[2]
            .replace(/^HiFi__/i, "").replace(/__(sink|source)$/i, "")
            .replace(/^analog-stereo$/i, "").replace(/[_-]+/g, " ").trim()

        return [device, profile].filter(part => part.length > 0).join(" · ") || raw
    }

    function removeLink(outputName) {
        websocket.sendRpc(
            "link_sink",
            {
                interface: interfaceName,
                output: outputName,
                linked: false
            }
        )
    }

    function toggleOutput(output) {
        const outputName = outputIdentifier(output)

        if (!outputName)
            return

        const linked = !isLinked(output)

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

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        // Per-link volume control toggle.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.i18n.text("audio_per_link_control")
                color: Md3Theme.surfaceContent
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Md3Switch {
                checked: root.perLink
                onClicked: root.setPerLink(!root.perLink)
            }
        }

        Text {
            Layout.fillWidth: true

            visible: root.outputs.length === 0

            text: root.i18n.text("audio_no_physical_outputs")
            color: Md3Theme.surfaceVariantContent

            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: root.outputs

            Rectangle {
                id: outputRow
                required property var modelData

                readonly property bool showLinkVolume:
                    root.perLink && root.isLinked(modelData)

                Layout.fillWidth: true
                Layout.preferredHeight: showLinkVolume ? 88 : 48

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                clip: true

                radius: Md3Theme.radiusMedium
                color:
                    root.isLinked(modelData)
                    ? Md3Theme.surfaceContainerHigh
                    : Md3Theme.surfaceContainerHighest

                border.width:
                    root.isLinked(modelData)
                    ? 2
                    : 1

                border.color:
                    root.isLinked(modelData)
                    ? Md3Theme.primary
                    : Md3Theme.outlineVariant

                RowLayout {
                    id: outputHeader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 48
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        Layout.preferredWidth: 20
                        Layout.alignment: Qt.AlignVCenter

                        text:
                            root.isLinked(modelData)
                            ? "✓"
                            : ""

                        color: Md3Theme.primary
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true

                            text: root.outputLabel(modelData)
                            color: Md3Theme.surfaceContent

                            font.pixelSize: 11
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true

                            text:
                                root.outputIdentifier(modelData)

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        visible: root.isDefaultOutput(modelData)

                        text: "★"
                        color: Md3Theme.primary
                        font.pixelSize: 12
                    }
                }

                // Only the header toggles the link, so the slider stays usable.
                Item {
                    anchors.fill: outputHeader

                    TapHandler {
                        onTapped:
                            root.toggleOutput(outputRow.modelData)
                    }
                }

                // Per-link volume of this channel -> output link.
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: outputHeader.bottom
                    anchors.leftMargin: 38
                    anchors.rightMargin: 10
                    height: 36
                    spacing: 8

                    visible: outputRow.showLinkVolume
                    opacity: outputRow.showLinkVolume ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 180 }
                    }

                    Md3Slider {
                        id: linkSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32

                        from: root.minVolume
                        to: root.maxVolume
                        stepSize: root.stepVolume
                        enabled: root.device?.muted !== true

                        // Follow backend updates, except while dragging.
                        Binding on value {
                            value: root.linkVolume(outputRow.modelData)
                            when: !linkSlider.pressed
                        }

                        onPressedChanged: {
                            if (!pressed)
                                root.setLinkVolume(outputRow.modelData, value)
                        }
                    }

                    Text {
                        Layout.preferredWidth: 38
                        text: Math.round(linkSlider.value * 100) + "%"
                        color: Md3Theme.surfaceContent
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // Links to outputs that are not connected; they can be removed.
        Repeater {
            model: root.offlineLinks

            Rectangle {
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 48

                radius: Md3Theme.radiusMedium
                color: Md3Theme.surfaceContainerHighest
                border.width: 1
                border.color: Md3Theme.outlineVariant
                opacity: 0.75

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 8

                    MdiIcon {
                        name: "link-variant-off"
                        size: 16
                    }

                    // Width 0 + fill: long names elide instead of pushing
                    // the remove button out of the row.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        Layout.minimumWidth: 0
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: root.prettySinkName(modelData)
                            color: Md3Theme.surfaceContent
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.i18n.text("audio_not_connected")
                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }
                    }

                    Md3Button {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.i18n.text("audio_remove_link")
                        implicitHeight: 34
                        onClicked: root.removeLink(modelData)
                    }
                }
            }
        }
    }

    actions: [
        Md3Button {
            text: root.i18n.text("close")
            onClicked: root.close()
        }
    ]
}
