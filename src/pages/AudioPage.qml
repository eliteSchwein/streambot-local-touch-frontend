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
            Layout.preferredHeight: parent.height * 0.58

            clip: true
            spacing: 8

            model: root.names

            delegate: AudioInterfaceRow {
                required property string modelData

                width: interfaceList.width

                interfaceName: modelData
                device: root.store.audio[modelData]

                physical: false
                showLinkButton: true

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

        // Physical outputs use the same row base.
        ListView {
            id: physicalList

            Layout.fillWidth: true
            Layout.preferredHeight: parent.height * 0.36

            clip: true
            spacing: 8

            model: root.store.audioOutputs

            delegate: AudioInterfaceRow {
                required property var modelData

                width: physicalList.width

                interfaceName:
                    String(
                        modelData.description
                        ?? modelData.name
                        ?? modelData.id
                        ?? "Output"
                    )

                device: modelData

                physical: true
                showLinkButton: false

                i18n: root.i18n
                websocket: root.websocket
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
