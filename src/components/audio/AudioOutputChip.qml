import QtQuick
import QtQuick.Layouts

import "../md3"

Rectangle {
    id: root

    required property string text
    property bool checked: false
    property bool isDefault: false

    signal clicked()

    implicitHeight: 32
    implicitWidth: contentRow.implicitWidth + 22

    radius: 16

    color:
        checked
        ? Md3Theme.surfaceContainerHigh
        : Md3Theme.surfaceContainerHighest

    border.width: checked ? 2 : 1
    border.color:
        checked
        ? Md3Theme.primary
        : Md3Theme.outlineVariant

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: root.checked

            text: "✓"
            color: Md3Theme.primary

            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Text {
            text: root.text
            color: Md3Theme.surfaceContent

            font.pixelSize: 10
            font.weight: root.checked
                ? Font.DemiBold
                : Font.Normal
        }

        Text {
            visible: root.isDefault

            text: "★"
            color: Md3Theme.primary
            font.pixelSize: 9
        }
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
