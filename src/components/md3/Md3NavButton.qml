import QtQuick

Item {
    id: root
    property string icon: "home"
    property bool selected: false
    property bool badge: false
    property int badgeCount: 0
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
            visible: root.badge || root.badgeCount > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -2
            anchors.rightMargin: 1
            width: badgeText.visible
                ? Math.max(18, badgeText.implicitWidth + 8)
                : 8
            height: badgeText.visible ? 18 : 8
            radius: height / 2
            color: Md3Theme.error
            border.width: 1
            border.color: Md3Theme.surfaceContainer

            Text {
                id: badgeText
                anchors.centerIn: parent
                visible: root.badgeCount > 0
                text: root.badgeCount > 99
                    ? "99+"
                    : String(root.badgeCount)
                color: Md3Theme.errorContent
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }
    }

    TapHandler { onTapped: root.clicked() }
}
