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
            spacing: 4
            model: parent.rotations

            delegate: Rectangle {
                required property var modelData

                width: rotationList.width
                height: 32

                radius: Md3Theme.radiusMedium

                color:
                    root.store.rotatingRuntime.active === true
                    && root.store.rotatingRuntime.name === modelData.name
                    ? Md3Theme.surfaceContainerHigh
                    : Md3Theme.surfaceContainerHighest

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 7

                    Text {
                        Layout.fillWidth: true

                        text: modelData.name
                        color: Md3Theme.surfaceContent

                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        text: Number(modelData.interval ?? 0) + "s"
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 8
                    }

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4

                        color:
                            root.store.rotatingRuntime.active === true
                            && root.store.rotatingRuntime.name === modelData.name
                            ? Md3Theme.success
                            : Md3Theme.outline
                    }
                }
            }
        }
    }
}
