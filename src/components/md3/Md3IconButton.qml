import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property bool selected: false
    property bool filled: false

    signal clicked()

    implicitWidth: filled ? 46 : 40
    implicitHeight: implicitWidth

    radius: width / 2

    color:
        selected || filled
        ? Md3Theme.primary
        : tap.pressed
            ? Md3Theme.surfaceContainerHigh
            : "transparent"

    Text {
        anchors.centerIn: parent

        text: root.icon
        color:
            root.selected || root.filled
            ? Md3Theme.primaryContent
            : Md3Theme.surfaceContent

        font.pixelSize: root.filled ? 22 : 19
        font.weight: Font.DemiBold
    }

    TapHandler {
        id: tap
        onTapped: root.clicked()
    }
}
