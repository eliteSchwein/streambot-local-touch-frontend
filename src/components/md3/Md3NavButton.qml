import QtQuick

Item {
    id: root

    property string icon: "home"
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

        MdiIcon {
            anchors.centerIn: parent

            name: root.icon
            size: 21
            selected: root.selected
        }
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
