pragma Singleton

import QtQuick

QtObject {
    id: root

    property var target: null
    property var focusSink: null

    readonly property bool visible:
        target !== null

    function attach(item) {
        target = item
    }

    function detach(item) {
        if (target === item)
            target = null
    }

    function hide() {
        const oldTarget = target
        target = null

        if (oldTarget !== null)
            oldTarget.focus = false

        if (
            focusSink !== null
            && focusSink.forceActiveFocus !== undefined
        ) {
            focusSink.forceActiveFocus()
        }
    }

    function insert(text) {
        if (target === null)
            return

        target.insert(
            target.cursorPosition,
            text
        )
    }

    function backspace() {
        if (target === null)
            return

        if (target.selectionStart !== target.selectionEnd) {
            target.remove(
                target.selectionStart,
                target.selectionEnd
            )
            return
        }

        const pos = target.cursorPosition

        if (pos > 0)
            target.remove(pos - 1, pos)
    }
}
