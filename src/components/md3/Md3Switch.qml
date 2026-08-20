import QtQuick
import QtQuick.Controls

Switch {
    id: root

    implicitWidth: 52
    implicitHeight: 32

    indicator: Rectangle {
        width: 48
        height: 28
        radius: 14

        color: root.checked
            ? Md3Theme.primary
            : Md3Theme.surfaceContainerHighest

        border.width: root.checked ? 0 : 1
        border.color: Md3Theme.outline

        Rectangle {
            width: root.checked ? 20 : 16
            height: width
            radius: width / 2

            x: root.checked
                ? parent.width - width - 4
                : 4

            anchors.verticalCenter: parent.verticalCenter

            color: root.checked
                ? Md3Theme.primaryContent
                : Md3Theme.surfaceVariantContent

            Behavior on x {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 140
                }
            }
        }
    }

    contentItem: Item {}
}
