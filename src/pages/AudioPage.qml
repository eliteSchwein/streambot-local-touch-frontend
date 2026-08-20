import QtQuick
import QtQuick.Layouts

import "../components/audio"

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

    ListView {
        id: interfaceList

        anchors.fill: parent
        anchors.margins: 10

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
