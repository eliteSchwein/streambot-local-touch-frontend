import QtQuick
import QtQuick.Controls

Control {
    id: root

    property string text: ""
    property bool outlined: false

    signal clicked()

    implicitHeight: 44
    implicitWidth: Math.max(88, label.implicitWidth + 32)

    enabled: true

    contentItem: Text {
        id: label

        text: root.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        color: root.outlined
            ? Md3Theme.primary
            : Md3Theme.primaryContent

        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    background: Rectangle {
        radius: height / 2

        color: {
            if (!root.enabled)
                return Md3Theme.surfaceContainerHigh

            if (root.outlined)
                return mouse.pressed
                    ? Md3Theme.surfaceContainerHigh
                    : "transparent"

            return mouse.pressed
                ? Md3Theme.primaryPressed
                : Md3Theme.primary
        }

        border.width: root.outlined ? 1 : 0
        border.color: root.outlined
            ? Md3Theme.outline
            : "transparent"
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.enabled

        onClicked: root.clicked()
    }
}
