import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../components/md3"
import "../services"

Popup {
    id: root

    property string title: ""
    property string supportingText: ""

    default property alias dialogContent: body.data
    property alias actions: actionRow.data

    modal: true
    focus: true
    padding: 0

    width: Math.min(
        420,
        Overlay.overlay ? Overlay.overlay.width - 32 : 420
    )

    anchors.centerIn: Overlay.overlay
    closePolicy: Popup.CloseOnEscape

    onClosed: {
        Keyboard.hide()
    }

    background: Rectangle {
        radius: Md3Theme.radiusExtraLarge
        color: Md3Theme.surfaceContainerHigh

        border.width: 1
        border.color: Md3Theme.outlineVariant
    }

    contentItem: ColumnLayout {
        id: dialogLayout
        spacing: 0

        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                if (root.activeFocusItem !== null) {
                    root.activeFocusItem.focus = false
                    Keyboard.hide()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24

            visible: root.title !== ""

            text: root.title
            color: Md3Theme.surfaceContent

            font.pixelSize: 20
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: root.title !== "" ? 8 : 0

            visible: root.supportingText !== ""

            text: root.supportingText
            color: Md3Theme.surfaceVariantContent

            font.pixelSize: 13
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            id: body

            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 18

            spacing: 14
        }

        RowLayout {
            id: actionRow

            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.topMargin: 20

            spacing: 10

            Item {
                Layout.fillWidth: true
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
        }
    }
}
