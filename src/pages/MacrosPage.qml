import QtQuick
import QtQuick.Layouts

import "../components/macros"
import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var store
    required property var websocket

    property string searchQuery: ""

    function macroList() {
        const result = []

        const macros =
            store.macros ?? ({})

        const query =
            String(searchQuery)
                .trim()
                .toLowerCase()

        for (const name in macros) {
            const macro =
                macros[name] ?? ({})

            if (
                query !== ""
                && !String(name)
                    .toLowerCase()
                    .includes(query)
            ) {
                continue
            }

            result.push({
                name: name,
                macro: macro
            })
        }

        result.sort(
            (a, b) =>
                a.name.localeCompare(b.name)
        )

        return result
    }

    readonly property var filteredMacros:
        macroList()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        spacing: 8

        Md3TextField {
            id: searchField

            Layout.fillWidth: true
            Layout.preferredHeight: 44

            placeholderText:
                root.i18n.text(
                    "macro_search"
                )

            text: root.searchQuery

            onTextChanged:
                root.searchQuery = text
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent

                visible:
                    root.filteredMacros.length === 0

                text:
                    root.i18n.text(
                        "macro_no_results"
                    )

                color:
                    Md3Theme.surfaceVariantContent

                font.pixelSize: 14
                font.weight: Font.Medium
            }

            ListView {
                id: macroListView

                anchors.fill: parent

                visible:
                    root.filteredMacros.length > 0

                clip: true
                spacing: 6

                model:
                    root.filteredMacros

                delegate: MacroRow {
                    required property var modelData

                    width:
                        macroListView.width

                    name:
                        modelData.name

                    macro:
                        modelData.macro

                    websocket:
                        root.websocket
                }
            }
        }
    }
}
