import QtQuick
import QtQuick.Layouts

import "../components/audio"
import "../dialogs"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var store

    function interfaceNames() {
        return Object.keys(
            store.audio ?? {}
        )
    }

    readonly property var names:
        interfaceNames()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        spacing: 8

        // Virtual Streambot outputs.
        ListView {
            id: interfaceList

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: parent.height * 0.64

            clip: true
            spacing: 8

            model: root.names

            delegate: AudioInterfaceRow {
                required property string modelData

                width: interfaceList.width

                interfaceName: modelData
                device: root.store.audio[modelData]

                i18n: root.i18n
                websocket: root.websocket

                onLinkRequested:
                    function(interfaceName, device) {
                        linkDialog.interfaceName =
                            interfaceName

                        linkDialog.device =
                            device

                        linkDialog.outputs =
                            root.store.audioOutputs

                        linkDialog.open()
                    }
            }
        }

        // Physical outputs.
        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: parent.height * 0.30

            contentWidth: physicalRow.implicitWidth
            contentHeight: height

            clip: true

            Row {
                id: physicalRow

                height: parent.height
                spacing: 8

                Repeater {
                    model:
                        root.store.audioOutputs

                    PhysicalAudioOutputCard {
                        required property var modelData

                        width: 250
                        height: parent.height

                        output: modelData
                    }
                }

                Text {
                    visible:
                        root.store.audioOutputs.length === 0

                    anchors.verticalCenter: parent.verticalCenter

                    text:
                        root.i18n.text(
                            "audio_no_physical_outputs"
                        )

                    color:
                        Md3Theme.surfaceVariantContent

                    font.pixelSize: 12
                }
            }
        }
    }

    AudioLinkDialog {
        id: linkDialog

        anchors.fill: parent

        i18n: root.i18n
        websocket: root.websocket

        onClosed: {
            interfaceName = ""
            device = ({})
            outputs = []
        }
    }
}
