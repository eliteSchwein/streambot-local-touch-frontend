import QtQuick
import QtQuick.Layouts

import "../components/md3"

Md3Dialog {
    id: root

    required property var i18n
    required property var network

    signal deleteRequested(var connection)

    title: root.i18n.text("saved_wifi")

    width: Math.min(
        520,
        parent ? parent.width - 32 : 520
    )

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(
            360,
            Math.max(100, savedList.contentHeight)
        )

        Text {
            anchors.centerIn: parent

            visible:
                root.network.knownWifiNetworks.length === 0

            text: root.i18n.text("no_saved_wifi")
            color: Md3Theme.surfaceVariantContent

            font.pixelSize: 13
        }

        ListView {
            id: savedList

            anchors.fill: parent

            visible:
                root.network.knownWifiNetworks.length > 0

            clip: true
            spacing: 8

            model: root.network.knownWifiNetworks

            delegate: Rectangle {
                required property var modelData

                width: savedList.width
                height: 54

                radius: Md3Theme.radiusMedium
                color: Md3Theme.surfaceContainerHighest

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true

                            text: modelData.name
                            color: Md3Theme.surfaceContent

                            font.pixelSize: 13
                            font.weight: Font.DemiBold

                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true

                            text: modelData.connected
                                ? root.i18n.text("connected")
                                : root.i18n.text("disconnected")

                            color: modelData.connected
                                ? Md3Theme.success
                                : Md3Theme.surfaceVariantContent

                            font.pixelSize: 10
                        }
                    }

                    Md3Button {
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 34
                        implicitWidth: Math.max(72, contentItem.implicitWidth + 24)

                        text: root.i18n.text("delete")
                        outlined: true

                        onClicked: {
                            root.deleteRequested(modelData)
                        }
                    }
                }
            }
        }
    }

    actions: [
        Md3Button {
            text: root.i18n.text("cancel")
            outlined: true
            onClicked: root.close()
        }
    ]

}
