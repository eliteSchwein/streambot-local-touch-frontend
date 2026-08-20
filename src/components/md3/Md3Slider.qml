import QtQuick
import QtQuick.Controls

Slider {
    id: root

    implicitHeight: 40

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2

        width: root.availableWidth
        height: 6
        radius: 3

        color: Md3Theme.surfaceContainerHighest

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Md3Theme.primary
        }
    }

    handle: Rectangle {
        x: root.leftPadding
           + root.visualPosition * (root.availableWidth - width)

        y: root.topPadding
           + root.availableHeight / 2
           - height / 2

        width: 18
        height: 18
        radius: 9

        color: Md3Theme.primary
    }
}
