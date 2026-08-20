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
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 48

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
                    anchors.fill: parent
                    anchors.margins: 10
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

                TapHandler {
                    onTapped:
                        root.toggleOutput(modelData)
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
