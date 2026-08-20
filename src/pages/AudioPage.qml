import QtQuick
import QtQuick.Layouts

import "../components/audio"
import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var store

    function interfaceNames() {
        return Object.keys(store.audio ?? {})
    }

    readonly property var names:
        interfaceNames()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        spacing: 8

        // Table-like header, matching the old touch layout.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28

            spacing: 14

            Text {
                Layout.preferredWidth: 115

                text: root.i18n.text("audio_name")
                color: Md3Theme.surfaceVariantContent

                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            Text {
                Layout.preferredWidth: 260

                text: root.i18n.text("audio_volume")
                color: Md3Theme.surfaceVariantContent

                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true

                text: root.i18n.text("audio_outputs")
                color: Md3Theme.surfaceVariantContent

                font.pixelSize: 9
                font.weight: Font.DemiBold
            }
        }

        ListView {
            id: interfaceList

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            spacing: 8

            model: root.names

            delegate: AudioInterfaceRow {
                required property string modelData

                width: interfaceList.width

                interfaceName: modelData
                device: root.store.audio[modelData]
                outputs: root.store.audioOutputs

                i18n: root.i18n
                websocket: root.websocket
            }
        }
    }
}
