import QtQuick
import QtQuick.Layouts

import "../macros"
import "../md3"

Md3Card {
    id: root

    required property var i18n
    required property var store
    required property var websocket

    property var macroNames: []

    backgroundOpacity: 0.88
    title: ""

    function entries() {
        const result = []
        const names =
            Array.isArray(macroNames)
            ? macroNames.slice(0, 4)
            : []

        for (const name of names) {
            const macro =
                root.store.macros?.[name]

            if (macro !== undefined) {
                result.push({
                    name: name,
                    macro: macro
                })
            }
        }

        return result
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent

            visible: root.entries().length === 0

            text: root.i18n.text("dashboard_no_macros")
            color: Md3Theme.surfaceVariantContent

            font.pixelSize: 10
        }

        ListView {
            id: list

            anchors.fill: parent

            visible: root.entries().length > 0
            clip: true
            spacing: 6
            interactive: false

            model: root.entries()

            delegate: MacroRow {
                required property var modelData

                width: list.width
                height: 46

                name: modelData.name
                macro: modelData.macro
                websocket: root.websocket
            }
        }
    }
}
