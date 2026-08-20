import QtQuick
import QtQuick.Layouts

import "../components/dashboard"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var store

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        ColumnLayout {
            Layout.preferredWidth: parent.width * 0.39
            Layout.fillHeight: true
            spacing: 8

            AlertsCard {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height * 0.28

                i18n: root.i18n
                store: root.store
                websocket: root.websocket
            }

            AutoMacrosCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                i18n: root.i18n
                store: root.store
                websocket: root.websocket
            }

            RotateSceneCard {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height * 0.26

                i18n: root.i18n
                store: root.store
            }
        }

        MusicPlayerCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 320

            i18n: root.i18n
            websocket: root.websocket
            store: root.store
        }
    }
}
