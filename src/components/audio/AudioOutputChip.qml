import QtQuick
import QtQuick.Layouts

import "../md3"

Rectangle {
    id: root

    required property string text

    property bool checked: false
    property bool isDefault: false

    signal clicked()

    implicitHeight: 34
    implicitWidth: Math.max(
        82,
        contentRow.implicitWidth + 24
    )

    radius: 17

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
        spacing: 6

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
            font.weight:
                root.checked
                ? Font.DemiBold
                : Font.Normal

            verticalAlignment: Text.AlignVCenter
        }

        Text {
            visible: root.isDefault

            text: "★"
            color: Md3Theme.primary
            font.pixelSize: 9
        }
    }

    TapHandler {
        id: tap

        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds

        onTapped: {
            console.log(
                "[audio] output chip:",
                root.text,
                "checked:",
                root.checked
            )

            root.clicked()
        }
    }
}
