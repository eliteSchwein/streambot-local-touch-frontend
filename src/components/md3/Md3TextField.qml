import QtQuick
import QtQuick.Controls

import "../../services"

TextField {
    id: root

    implicitHeight: 52

    property color backgroundColor: Md3Theme.surfaceContainerHighest

    color: Md3Theme.surfaceContent
    placeholderTextColor: Md3Theme.surfaceVariantContent
    selectionColor: Md3Theme.primary
    selectedTextColor: Md3Theme.primaryContent

    leftPadding: 16
    rightPadding: 16

    background: Rectangle {
        radius: Md3Theme.radiusMedium
        color: root.backgroundColor

        border.width: root.activeFocus ? 2 : 1
        border.color:
            root.activeFocus
            ? Md3Theme.primary
            : Md3Theme.outline
    }

    onActiveFocusChanged: {
        if (activeFocus)
            KeyboardController.attach(root)
    }

    Component.onDestruction: {
        KeyboardController.detach(root)
    }
}
