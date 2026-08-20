import QtQuick
import QtQuick.Layouts

import "../md3"

Md3Card {
    id: root

    required property var i18n
    required property var store
    required property var websocket

    title: ""
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            visible:
                root.store.activeAlert === null
                && root.store.alertQueue.length === 0

            text: root.i18n.text("no_alerts")
            color: Md3Theme.surfaceVariantContent
            font.pixelSize: 13
        }

        ListView {
            id: alertList

            anchors.fill: parent
            clip: true
            spacing: 5

            model: root.store.alertQueue

            delegate: Rectangle {
                required property var modelData

                width: alertList.width
                height: 42

                radius: Md3Theme.radiusMedium

                color:
                    modelData.active === true
                    ? Md3Theme.surfaceContainerHigh
                    : Md3Theme.surfaceContainerHighest

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        width: 7
                        height: 7
                        radius: 4

                        color:
                            modelData.active === true
                            ? Md3Theme.success
                            : Md3Theme.outline
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            Layout.fillWidth: true

                            text:
                                modelData.message
                                || modelData.channel
                                || "Alert"

                            color: Md3Theme.surfaceContent
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true

                            text:
                                String(modelData["event-uuid"] ?? "")

                            visible: text !== ""

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 8
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Md3IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        icon: "×"

                        onClicked: {
                            root.websocket.sendRpc(
                                "remove_event",
                                {
                                    "event-uuid":
                                        modelData["event-uuid"]
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}
