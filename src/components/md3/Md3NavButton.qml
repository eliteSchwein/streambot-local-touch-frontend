import QtQuick

Item {
    id: root

    property string icon: "⌂"
    property bool selected: false

    signal clicked()

    implicitWidth: 72
    implicitHeight: 42

    Rectangle {
        anchors.centerIn: parent

        width: 56
        height: 32
        radius: 18

        color:
            root.selected
            ? Md3Theme.primary
            : "transparent"

        Text {
            anchors.centerIn: parent

            text: root.icon

            color:
                root.selected
                ? Md3Theme.primaryContent
                : Md3Theme.surfaceVariantContent

            font.pixelSize: 20
            font.weight: Font.DemiBold
        }
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
