import QtQuick
import QtQuick.Layouts
import "../components/system"

Item {
    required property var i18n
    required property var websocket
    required property var store

    RowLayout {
        anchors.fill:parent
        anchors.margins:10
        spacing:8

        SystemStorageCard {
            Layout.fillWidth:true
            Layout.fillHeight:true
            i18n:parent.parent.i18n
            storage:parent.parent.store.systemStorage??({})
        }

        UpdateManagerCard {
            Layout.fillWidth:true
            Layout.fillHeight:true
            i18n:parent.parent.i18n
            managers:parent.parent.store.updateManager
            websocket:parent.parent.websocket
        }
    }
}
