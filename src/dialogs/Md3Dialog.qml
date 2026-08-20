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

    x: Overlay.overlay
        ? Math.round((Overlay.overlay.width - width) / 2)
        : 0

    y: {
        if (!Overlay.overlay)
            return 0

        const centered =
            Math.round((Overlay.overlay.height - height) / 2)

        if (!KeyboardController.visible)
            return centered

        // Keep the dialog visually above the keyboard instead of
        // allowing the keyboard to cover its lower controls.
        return Math.max(
            12,
            Math.round(centered - Overlay.overlay.height * 0.18)
        )
    }

    Behavior on y {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
    closePolicy: Popup.CloseOnEscape

    onClosed: KeyboardController.clearFocus()

    background: Rectangle {
        radius: Md3Theme.radiusExtraLarge
        color: Md3Theme.surfaceContainerHigh

        border.width: 1
        border.color: Md3Theme.outlineVariant

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds

            onTapped: {
                KeyboardController.clearFocus()
            }
        }
    }

    contentItem: ColumnLayout {
        id: dialogLayout
        spacing: 0

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
