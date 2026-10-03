import QtQuick
import QtQuick.Layouts

import "../components/md3"
import "../components/system"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var store
    required property var config

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        SystemStorageCard {
            Layout.fillWidth: true
            Layout.fillHeight: true

            i18n: root.i18n
            storage: root.store.systemStorage ?? ({})
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            UpdateManagerCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                i18n: root.i18n
                managers: root.store.updateManager
                websocket: root.websocket
            }

            Md3Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 118

                title: root.i18n.text("language")

                Md3Select {
                    Layout.fillWidth: true

                    model: [
                        root.i18n.text("english"),
                        root.i18n.text("german")
                    ]

                    currentIndex:
                        root.config.language === "de"
                        ? 1
                        : 0

                    onActivated: index => {
                        root.config.setLanguage(
                            index === 1 ? "de" : "en"
                        )
                    }
                }
            }
        }
    }
}
