import QtQuick
import QtQuick.Controls

import "../../services"

TextField {
    id: root

    implicitHeight: 52

    color: Md3Theme.surfaceContent
    placeholderTextColor: Md3Theme.surfaceVariantContent
    selectionColor: Md3Theme.primary
    selectedTextColor: Md3Theme.primaryContent

    leftPadding: 16
    rightPadding: 16

    background: Rectangle {
        radius: Md3Theme.radiusMedium
        color: Md3Theme.surfaceContainerHighest

        border.width: root.activeFocus ? 2 : 1
        border.color:
            root.activeFocus
            ? Md3Theme.primary
            : Md3Theme.outline
    }

    onActiveFocusChanged: {
        if (activeFocus)
            Keyboard.show()
    }

    Keys.onReturnPressed: event => {
        focus = false
        Keyboard.hide()
        event.accepted = true
    }

    Keys.onEnterPressed: event => {
        focus = false
        Keyboard.hide()
        event.accepted = true
    }
}
