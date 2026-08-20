import QtQuick
import QtQuick.Layouts

import "../components/audio"
import "../components/md3"
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

    Flickable {
        id: pageScroll

        anchors.fill: parent
        anchors.margins: 10

        clip: true

        contentWidth: width
        contentHeight:
            contentColumn.implicitHeight

        boundsBehavior:
            Flickable.StopAtBounds

        Column {
            id: contentColumn

            width: pageScroll.width
            spacing: 8

            // Virtual outputs.
            Repeater {
                model: root.names

                AudioInterfaceRow {
                    required property string modelData

                    width: contentColumn.width

                    interfaceName: modelData
                    device:
                        root.store.audio[modelData]

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

            // Small separator between virtual and physical outputs.
            Rectangle {
                width: contentColumn.width
                height: 1
                visible:
                    root.names.length > 0
                    && root.store.audioOutputs.length > 0

                color: Md3Theme.outlineVariant
                opacity: 0.6
            }

            // Physical outputs, same row base.
            Repeater {
                model:
                    root.store.audioOutputs

                AudioInterfaceRow {
                    required property var modelData

                    width: contentColumn.width

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
