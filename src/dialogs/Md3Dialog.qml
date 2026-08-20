import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../components/md3"

Popup {
    id: root

    property string title: ""
    default property alias dialogContent: contentColumn.data

    modal: true
    focus: true

    width: Math.min(400, Overlay.overlay ? Overlay.overlay.width - 32 : 400)
    padding: 0

    anchors.centerIn: Overlay.overlay

    closePolicy: Popup.CloseOnEscape

    background: Rectangle {
        radius: Md3Theme.radiusExtraLarge
        color: Md3Theme.surfaceContainerHigh
        border.width: 1
        border.color: Md3Theme.outlineVariant
    }

    contentItem: ColumnLayout {
        id: contentColumn

        spacing: 16

        // Actual dialog padding. Child dialogs no longer need to fake this.
        anchors.margins: 24

        Text {
            visible: root.title !== ""
            Layout.fillWidth: true

            text: root.title
            color: Md3Theme.surfaceContent

            font.pixelSize: 20
            font.weight: Font.DemiBold

            wrapMode: Text.Wrap
        }
    }
}
