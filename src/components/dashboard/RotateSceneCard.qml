import QtQuick
import QtQuick.Layouts

import "../md3"

Md3Card {
    id: root

    required property var i18n
    required property var store

    title: i18n.text("rotate_scene")

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        property var rotations: root.store.rotationList()

        Text {
            anchors.centerIn: parent

            visible: parent.rotations.length === 0

            text: root.i18n.text("no_rotations")
            color: Md3Theme.surfaceVariantContent
            font.pixelSize: 10
        }

        ListView {
            id: rotationList

            anchors.fill: parent
            visible: parent.rotations.length > 0

            clip: true
            spacing: 5
            model: parent.rotations

            delegate: Rectangle {
                required property var modelData

                width: rotationList.width
                height: 44

                radius: Md3Theme.radiusMedium

                color:
                    root.store.rotatingRuntime.active === true
                    && root.store.rotatingRuntime.name === modelData.name
                    ? Md3Theme.surfaceContainerHigh
                    : Md3Theme.surfaceContainerHighest

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        text: modelData.name
                        color: Md3Theme.surfaceContent

                        font.pixelSize: 10
                        font.weight: Font.Medium

                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: intervalText.implicitWidth + 14
                        implicitHeight: 22

                        radius: 11
                        color: Md3Theme.surfaceContainerHigh

                        Text {
                            id: intervalText
                            anchors.centerIn: parent

                            text:
                                Number(modelData.interval ?? 0)
                                + "s"

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 8
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: sceneText.implicitWidth + 14
                        implicitHeight: 22

                        radius: 11
                        color: Md3Theme.surfaceContainerHigh

                        Text {
                            id: sceneText
                            anchors.centerIn: parent

                            text:
                                String(
                                    Array.isArray(modelData.scenes)
                                    ? modelData.scenes.length
                                    : 0
                                )

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 8
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        width: 9
                        height: 9
                        radius: 5

                        color:
                            root.store.rotatingRuntime.active === true
                            && root.store.rotatingRuntime.name === modelData.name
                            ? Md3Theme.primary
                            : Md3Theme.outline
                    }
                }
            }
        }
    }
}
