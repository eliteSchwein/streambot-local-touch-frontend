import QtQuick
import QtQuick.Layouts

import "../md3"

Md3Card {
    id: root

    required property var i18n
    required property var store

    title:
        i18n.text("alerts")
        + (
            store.alertQueue.length > 0
            ? " · " + store.alertQueue.length
            : ""
        )

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5

        Text {
            visible:
                root.store.activeAlert === null
                && root.store.alertQueue.length === 0

            text: root.i18n.text("no_alerts")
            color: Md3Theme.surfaceVariantContent
            font.pixelSize: 10
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            visible: root.store.activeAlert !== null

            radius: Md3Theme.radiusMedium
            color: Md3Theme.surfaceContainerHigh

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 7
                spacing: 0

                Text {
                    text: root.i18n.text("active")
                    color: Md3Theme.primary
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true

                    text:
                        root.store.activeAlert
                        ? (
                            root.store.activeAlert.message
                            || root.store.activeAlert.channel
                            || "Alert"
                        )
                        : ""

                    color: Md3Theme.surfaceContent
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }

        Repeater {
            model: Math.min(2, root.store.alertQueue.length)

            Rectangle {
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 27

                radius: Md3Theme.radiusMedium
                color: Md3Theme.surfaceContainerHighest

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    anchors.leftMargin: 7
                    anchors.rightMargin: 7

                    text:
                        root.store.alertQueue[index].message
                        || root.store.alertQueue[index].channel
                        || "Alert"

                    color: Md3Theme.surfaceContent
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }
        }
    }
}
