import QtQuick
import QtQuick.Layouts

import "../components/channelpoints"
import "../components/macros"
import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var store
    required property var websocket

    property int currentTab: 0
    property string macroSearchQuery: ""
    property string autoMacroSearchQuery: ""
    property string channelPointSearchQuery: ""

    function tr(key, fallback) {
        const value = root.i18n.text(key)
        return value === key ? fallback : value
    }

    function macroList() {
        const result = []
        const macros = store.macros ?? ({})

        const query =
            String(macroSearchQuery)
                .trim()
                .toLowerCase()

        for (const name in macros) {
            const macro = macros[name] ?? ({})

            if (
                query !== ""
                && !String(name).toLowerCase().includes(query)
            ) {
                continue
            }

            result.push({
                name: name,
                macro: macro
            })
        }

        result.sort((a, b) => a.name.localeCompare(b.name))

        return result
    }

    function autoMacroList() {
        const all =
            Array.isArray(store.autoMacros)
            ? store.autoMacros
            : []

        const query =
            String(autoMacroSearchQuery)
                .trim()
                .toLowerCase()

        const result = []

        for (const item of all) {
            if (!item)
                continue

            const name = String(item.name ?? "")

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

    function channelPointList() {
        const result =
            Array.from(store.channelPoints ?? [])

        const query =
            String(channelPointSearchQuery)
                .trim()
                .toLowerCase()

        const filtered = result.filter(point => {
            if (query === "")
                return true

            const values = [
                point?.label,
                point?.name,
                point?.twitch_label,
                point?.twitch_name
            ]

            return values.some(value =>
                String(value ?? "")
                    .toLowerCase()
                    .includes(query)
            )
        })

        filtered.sort((a, b) =>
            String(a.label ?? a.name ?? "").localeCompare(
                String(b.label ?? b.name ?? "")
            )
        )

        return filtered
    }

    readonly property var filteredMacros:
        macroList()

    readonly property var filteredAutoMacros:
        autoMacroList()

    readonly property var filteredChannelPoints:
        channelPointList()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            radius: 22
            color: Qt.rgba(
                Md3Theme.surfaceContainerHighest.r,
                Md3Theme.surfaceContainerHighest.g,
                Md3Theme.surfaceContainerHighest.b,
                0.94
            )

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                SegmentTab {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    text: root.i18n.text("macros")
                    iconName: "dialpad"
                    selected: root.currentTab === 0

                    onTapped:
                        root.currentTab = 0
                }

                SegmentTab {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    text: root.i18n.text("auto_macros")
                    iconName: "auto-mode"
                    selected: root.currentTab === 1

                    onTapped:
                        root.currentTab = 1
                }

                SegmentTab {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    text: root.i18n.text("channel_points")
                    iconName: "motion-play-outline"
                    selected: root.currentTab === 2

                    onTapped:
                        root.currentTab = 2
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 8
                visible: root.currentTab === 0

                Md3TextField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44

                    placeholderText:
                        root.i18n.text("macro_search")

                    text:
                        root.macroSearchQuery

                    backgroundColor: Qt.rgba(
                        Md3Theme.surfaceContainerHighest.r,
                        Md3Theme.surfaceContainerHighest.g,
                        Md3Theme.surfaceContainerHighest.b,
                        0.94
                    )

                    onTextChanged:
                        root.macroSearchQuery = text
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: root.filteredMacros.length === 0
                        text: root.i18n.text("macro_no_results")
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    ListView {
                        id: macroListView

                        anchors.fill: parent
                        visible: root.filteredMacros.length > 0
                        clip: true
                        spacing: 6
                        model: root.filteredMacros

                        delegate: MacroRow {
                            required property var modelData

                            width: macroListView.width
                            name: modelData.name
                            macro: modelData.macro
                            websocket: root.websocket
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 8
                visible: root.currentTab === 1

                Md3TextField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44

                    placeholderText:
                        root.tr(
                            "auto_macro_search",
                            "Search auto macros"
                        )

                    text:
                        root.autoMacroSearchQuery

                    backgroundColor: Qt.rgba(
                        Md3Theme.surfaceContainerHighest.r,
                        Md3Theme.surfaceContainerHighest.g,
                        Md3Theme.surfaceContainerHighest.b,
                        0.94
                    )

                    onTextChanged:
                        root.autoMacroSearchQuery = text
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: root.filteredAutoMacros.length === 0
                        text: root.tr(
                            "auto_macro_no_results",
                            root.i18n.text("no_auto_macros")
                        )
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    ListView {
                        id: autoMacroListView

                        anchors.fill: parent
                        visible: root.filteredAutoMacros.length > 0
                        clip: true
                        spacing: 6
                        model: root.filteredAutoMacros

                        delegate: AutoMacroRow {
                            required property var modelData

                            width: autoMacroListView.width
                            autoMacro: modelData
                            websocket: root.websocket
                            i18n: root.i18n
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 8
                visible: root.currentTab === 2

                Md3TextField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44

                    placeholderText:
                        root.i18n.text("channel_points_search")

                    text:
                        root.channelPointSearchQuery

                    backgroundColor: Qt.rgba(
                        Md3Theme.surfaceContainerHighest.r,
                        Md3Theme.surfaceContainerHighest.g,
                        Md3Theme.surfaceContainerHighest.b,
                        0.94
                    )

                    onTextChanged:
                        root.channelPointSearchQuery = text
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: root.filteredChannelPoints.length === 0

                        text:
                            root.channelPointSearchQuery.trim() !== ""
                            ? root.i18n.text("channel_points_no_results")
                            : root.i18n.text("channel_points_empty")

                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    ListView {
                        id: channelPointListView

                        anchors.fill: parent
                        visible: root.filteredChannelPoints.length > 0
                        clip: true
                        spacing: 6
                        model: root.filteredChannelPoints

                        delegate: ChannelPointToggleRow {
                            required property var modelData

                            width: channelPointListView.width
                            channelPoint: modelData
                            websocket: root.websocket
                            i18n: root.i18n
                        }
                    }
                }
            }
        }
    }

    component SegmentTab: Rectangle {
        id: tab

        required property string text
        required property string iconName
        property bool selected: false

        signal tapped()

        radius: 18

        color:
            selected
            ? Md3Theme.primary
            : (
                tabMouse.pressed
                ? Md3Theme.surfaceContainerHigh
                : "transparent"
            )

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            MdiIcon {
                anchors.verticalCenter: parent.verticalCenter

                name: tab.iconName
                size: 16
                selected: tab.selected
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: tab.text
                color:
                    tab.selected
                    ? Md3Theme.primaryContent
                    : Md3Theme.surfaceVariantContent

                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: tabMouse

            anchors.fill: parent

            onClicked:
                tab.tapped()
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

        // While a temporary interval is active the backend counts down
        // from it instead of the configured one.
        readonly property real interval:
            Math.max(
                0.05,
                Number(autoMacro?.temporary_interval_ms) > 0
                    ? Number(autoMacro.temporary_interval_ms) / 1000
                    : Number(autoMacro?.interval ?? 1)
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

            return row.i18n.text("auto_macro_next_in")
                .replace("{seconds}", Math.ceil(currentInterval))
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
            color: rowTap.pressed
                ? Md3Theme.surfaceContainerHigh
                : "transparent"

            Behavior on color {
                ColorAnimation { duration: 100 }
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }

            width: parent.width * row.progress
            radius: Md3Theme.radiusMedium
            color: Md3Theme.primary
            opacity: row.enabled ? 0.12 : 0

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
                    text: row.name
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: row.statusText
                    color: Md3Theme.surfaceVariantContent
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Md3Switch {
                Layout.alignment: Qt.AlignVCenter
                checked: row.enabled
                animated: false

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
            acceptedButtons: Qt.NoButton
        }
    }
}
