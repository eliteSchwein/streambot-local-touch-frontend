import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: "⌂"
    property string text: ""
    property bool selected: false

    signal clicked()

    implicitWidth: 110
    implicitHeight: 46

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 1

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 54
            height: 26
            radius: 14

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
                font.pixelSize: 18
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.text
            color:
                root.selected
                ? Md3Theme.surfaceContent
                : Md3Theme.surfaceVariantContent
            font.pixelSize: 10
            font.weight: root.selected ? Font.DemiBold : Font.Normal
        }
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
