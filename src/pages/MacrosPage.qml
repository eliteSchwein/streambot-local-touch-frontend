import QtQuick
import QtQuick.Layouts

import "../components/macros"
import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var store
    required property string restUrl

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
                && !JSON.stringify(macro)
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

        // Search only; no pointless page header.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            spacing: 8

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                radius: 20
                color: Md3Theme.surfaceContainer

                MdiIcon {
                    anchors.centerIn: parent

                    name: "magnify"
                    size: 19
                }
            }

            Md3TextField {
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

                    restUrl:
                        root.restUrl

                    i18n:
                        root.i18n
                }
            }
        }
    }
}
