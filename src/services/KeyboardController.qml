pragma Singleton

import QtQuick

QtObject {
    id: root

    property var target: null
    property bool visible: target !== null

    function attach(item) {
        target = item
    }

    function detach(item) {
        if (target === item)
            target = null
    }

    function hide() {
        if (target !== null)
            target.focus = false

        target = null
    }

    function insert(text) {
        if (target === null)
            return

        if (target.insert !== undefined) {
            target.insert(target.cursorPosition, text)
            return
        }

        target.text += text
    }

    function backspace() {
        if (target === null)
            return

        const pos = target.cursorPosition

        if (target.selectionStart !== target.selectionEnd) {
            target.remove(target.selectionStart, target.selectionEnd)
            return
        }

        if (pos > 0)
            target.remove(pos - 1, pos)
    }

    function submit() {
        if (target === null)
            return

        if (target.accepted !== undefined)
            target.accepted()

        hide()
    }
}
