import QtQuick
import QtQuick.Layouts

import "../components/md3"
import "../services"

Item {
    id: root

    property string title: ""
    property string supportingText: ""

    default property alias dialogContent: body.data
    property alias actions: actionRow.data

    property bool openedState: false

    signal opened()
    signal closed()

    visible: openedState
    anchors.fill: parent
    z: 500000

    function open() {
        if (openedState)
            return

        openedState = true
        opened()
    }

    function close() {
        if (!openedState)
            return

        KeyboardController.hide()
        openedState = false
        closed()
    }

    // Modal dim layer. Tapping outside the dialog only dismisses
    // keyboard focus; it does not close the dialog.
    Rectangle {
        anchors.fill: parent
        color: "#99000000"

        TapHandler {
            onTapped: KeyboardController.hide()
        }
    }

    FocusScope {
        id: dialogFocusSink

        width: 1
        height: 1
        focus: false
    }

    Rectangle {
        id: dialogSurface

        width: Math.min(
            420,
            root.width - 32
        )

        implicitHeight: dialogLayout.implicitHeight
        height: implicitHeight

        x: Math.round(
            (root.width - width) / 2
        )

        y: {
            const centered =
                Math.round(
                    (root.height - height) / 2
                )

            if (!KeyboardController.visible)
                return centered

            // Move dialog upward while keyboard is visible.
            const keyboardTop =
                root.height
                - Math.min(
                    260,
                    root.height * 0.43
                )

            return Math.max(
                12,
                Math.min(
                    centered - 40,
                    keyboardTop - height - 12
                )
            )
        }

        radius: Md3Theme.radiusExtraLarge
        color: Md3Theme.surfaceContainerHigh

        border.width: 1
        border.color: Md3Theme.outlineVariant

        Behavior on y {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        // Tapping blank dialog surface dismisses keyboard focus.
        TapHandler {
            onTapped: KeyboardController.hide()
        }

        ColumnLayout {
            id: dialogLayout

            anchors {
                left: parent.left
                right: parent.right
            }

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
                Layout.topMargin:
                    root.title !== "" ? 8 : 0

                visible:
                    root.supportingText !== ""

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

    onOpened: {
        KeyboardController.focusSink =
            dialogFocusSink
    }

    onClosed: {
        if (
            KeyboardController.focusSink
            === dialogFocusSink
        ) {
            KeyboardController.focusSink = null
        }
    }
}
