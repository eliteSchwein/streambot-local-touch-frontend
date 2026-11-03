import QtQuick
import QtQuick.Layouts

import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var store
    required property var websocket

    property string searchQuery: ""

    function tr(key, fallback) {
        const value = root.i18n.text(key)
        return value === key ? fallback : value
    }

    function autoMacroList() {
        const all =
            Array.isArray(store.autoMacros)
            ? store.autoMacros
            : []

        const query =
            String(searchQuery)
                .trim()
                .toLowerCase()

        const result = []

        for (const item of all) {
            if (!item)
                continue

            const name =
                String(item.name ?? "")

            if (
                query !== ""
                && !name.toLowerCase().includes(query)
            ) {
                continue
            }

            result.push(item)
        }

        result.sort((a, b) =>
            String(a.name ?? "").localeCompare(
                String(b.name ?? "")
            )
        )

        return result
    }

    readonly property var filteredAutoMacros:
        autoMacroList()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Md3TextField {
            id: searchField

            Layout.fillWidth: true
            Layout.preferredHeight: 44

            placeholderText:
                root.tr(
                    "auto_macro_search",
                    "Search auto macros"
                )

            text: root.searchQuery

            backgroundColor: Qt.rgba(
                Md3Theme.surfaceContainerHighest.r,
                Md3Theme.surfaceContainerHighest.g,
                Md3Theme.surfaceContainerHighest.b,
                0.94
            )

            onTextChanged:
                root.searchQuery = text
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent

                visible:
                    root.filteredAutoMacros.length === 0

                text:
                    root.tr(
                        "auto_macro_no_results",
                        root.i18n.text("no_auto_macros")
                    )

                color:
                    Md3Theme.surfaceVariantContent

                font.pixelSize: 14
                font.weight: Font.Medium
            }

            ListView {
                id: autoMacroListView

                anchors.fill: parent

                visible:
                    root.filteredAutoMacros.length > 0

                clip: true
                spacing: 6

                model:
                    root.filteredAutoMacros

                delegate: AutoMacroRow {
                    required property var modelData

                    width:
                        autoMacroListView.width

                    autoMacro:
                        modelData

                    websocket:
                        root.websocket

                    i18n:
                        root.i18n
                }
            }
        }
    }

    component AutoMacroRow: Item {
        id: row

        required property var autoMacro
        required property var websocket
        required property var i18n

        implicitHeight: 64

        readonly property string name:
            String(autoMacro?.name ?? "")

        readonly property bool enabled:
            autoMacro?.enabled === true

        readonly property real interval:
            Math.max(
                1,
                Number(autoMacro?.interval ?? 1)
            )

        readonly property real currentInterval:
            Math.max(
                0,
                Math.min(
                    interval,
                    Number(
                        autoMacro?.current_interval
                        ?? autoMacro?.currentInterval
                        ?? interval
                    )
                )
            )

        readonly property real progress:
            enabled ? currentInterval / interval : 0

        readonly property string statusText: {
            if (!enabled)
                return row.i18n.text("disabled")

            const remaining =
                Math.ceil(currentInterval)

            return row.i18n.text("auto_macro_next_in")
                .replace("{seconds}", remaining)
        }

        Md3GlassSurface {
            anchors.fill: parent
            radius: Md3Theme.radiusMedium
            tintColor: Md3Theme.surfaceContainer
            tintOpacity: 0.94
        }

        Rectangle {
            anchors.fill: parent
            radius: Md3Theme.radiusMedium

            color:
                rowTap.pressed
                ? Md3Theme.surfaceContainerHigh
                : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }

            width:
                parent.width * row.progress

            radius:
                Md3Theme.radiusMedium

            color:
                Md3Theme.primary

            opacity:
                row.enabled ? 0.12 : 0

            Behavior on width {
                NumberAnimation {
                    duration: 950
                    easing.type: Easing.Linear
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12

            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                spacing: 3

                Text {
                    Layout.fillWidth: true

                    text:
                        row.name

                    color:
                        Md3Theme.surfaceContent

                    font.pixelSize: 12
                    font.weight: Font.DemiBold

                    elide:
                        Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true

                    text:
                        row.statusText

                    color:
                        Md3Theme.surfaceVariantContent

                    font.pixelSize: 11

                    elide:
                        Text.ElideRight
                }
            }

            Md3Switch {
                Layout.alignment:
                    Qt.AlignVCenter

                checked:
                    row.enabled

                animated:
                    false

                onClicked: {
                    row.websocket.sendRpc(
                        "toggle_auto_macro",
                        {
                            name: row.name,
                            enable: !row.enabled
                        }
                    )
                }
            }
        }

        TapHandler {
            id: rowTap

            acceptedButtons:
                Qt.NoButton
        }
    }
}
