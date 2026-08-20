import QtQuick

Item {
    id: root
    property string icon: "home"
    property bool selected: false
    property bool badge: false
    signal clicked()

    implicitWidth: 72
    implicitHeight: 42

    Rectangle {
        anchors.centerIn: parent
        width: 56
        height: 32
        radius: 18
        color: root.selected ? Md3Theme.primary : "transparent"

        MdiIcon {
            anchors.centerIn: parent
            name: root.icon
            size: 21
            selected: root.selected
        }

        Rectangle {
            visible: root.badge
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.rightMargin: 5
            width: 8
            height: 8
            radius: 4
            color: Md3Theme.error
            border.width: 1
            border.color: Md3Theme.surfaceContainer
        }
    }

    TapHandler { onTapped: root.clicked() }
}
