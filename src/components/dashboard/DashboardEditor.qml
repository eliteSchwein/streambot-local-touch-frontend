import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../md3"

Rectangle {
    id: root

    required property var i18n
    required property var config
    required property var store

    signal closed()

    color: Md3Theme.background
    z: 1000

    property var cardOrder: [
        "interactions",
        "auto_macros",
        "macros",
        "music"
    ]

    property var locations: ({})
    property var macroNames: []

    function labelFor(card) {
        switch (card) {
        case "interactions":
            return i18n.text("dashboard_card_interactions")
        case "auto_macros":
            return i18n.text("dashboard_card_auto_macros")
        case "macros":
            return i18n.text("dashboard_card_macros")
        case "music":
            return i18n.text("dashboard_card_music")
        default:
            return card
        }
    }

    function availableMacroNames() {
        const result = []

        for (const name in (store.macros ?? ({}))) {
            if (
                String(name).startsWith("event_")
                || String(name).startsWith("channel_point_")
                || String(name).startsWith("command_")
            ) {
                continue
            }

            result.push(String(name))
        }

        result.sort((a, b) => a.localeCompare(b))
        return result
    }

    function locationFor(card) {
        return String(locations?.[card] ?? "hidden")
    }

    function setLocation(card, location) {
        const next = Object.assign({}, locations)

        if (location === "left" || location === "right") {
            // A music card owns its entire column.
            if (card === "music") {
                for (const other of cardOrder) {
                    if (other !== "music" && next[other] === location)
                        next[other] = "hidden"
                }
            } else if (next.music === location) {
                next.music = "hidden"
            }

            // Maximum two compact cards per non-music column.
            if (card !== "music") {
                let used = 0

                for (const other of cardOrder) {
                    if (
                        other !== card
                        && other !== "music"
                        && next[other] === location
                    ) {
                        used++
                    }
                }

                if (used >= 2)
                    return
            }
        }

        next[card] = location
        locations = next
    }

    function load() {
        const dashboard =
            config.normalizeTouchDashboard(
                config.touchDashboard
            )

        const next = ({})

        for (const card of cardOrder)
            next[card] = "hidden"

        for (const card of dashboard.columns.left)
            next[card] = "left"

        for (const card of dashboard.columns.right)
            next[card] = "right"

        locations = next
        macroNames =
            Array.isArray(dashboard.macro_names)
            ? dashboard.macro_names.slice(0, 4)
            : []
    }

    function cardsFor(location) {
        const result = []

        for (const card of cardOrder) {
            if (locations?.[card] === location)
                result.push(card)
        }

        return result
    }

    function setMacroSlot(index, name) {
        const next = macroNames.slice()

        while (next.length <= index)
            next.push("")

        next[index] = name === "—" ? "" : name

        const cleaned = []
        for (const value of next) {
            const macro = String(value ?? "").trim()

            if (
                macro !== ""
                && !cleaned.includes(macro)
            ) {
                cleaned.push(macro)
            }

            if (cleaned.length >= 4)
                break
        }

        macroNames = cleaned
    }

    function save() {
        config.setTouchDashboard({
            version: 1,
            columns: {
                left: cardsFor("left"),
                right: cardsFor("right")
            },
            macro_names: macroNames
        })

        closed()
    }

    Component.onCompleted: load()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 8

            Text {
                Layout.fillWidth: true

                text: root.i18n.text("dashboard_edit")
                color: Md3Theme.surfaceContent

                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Md3Button {
                text: root.i18n.text("dashboard_reset")
                outlined: true
                implicitHeight: 36

                onClicked: {
                    root.config.setTouchDashboard(
                        root.config.defaultTouchDashboard()
                    )
                    root.load()
                }
            }

            Md3Button {
                text: root.i18n.text("cancel")
                outlined: true
                implicitHeight: 36

                onClicked: root.closed()
            }

            Md3Button {
                text: root.i18n.text("save")
                implicitHeight: 36

                onClicked: root.save()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Md3Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: root.i18n.text("dashboard_cards")

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6

                    Repeater {
                        model: root.cardOrder

                        delegate: RowLayout {
                            required property string modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: root.labelFor(modelData)
                                color: Md3Theme.surfaceContent
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }

                            ButtonGroup {
                                id: locationGroup
                            }

                            Repeater {
                                model: [
                                    ["hidden", root.i18n.text("dashboard_hidden")],
                                    ["left", root.i18n.text("dashboard_left")],
                                    ["right", root.i18n.text("dashboard_right")]
                                ]

                                delegate: Button {
                                    required property var modelData

                                    implicitWidth: 65
                                    implicitHeight: 32

                                    checkable: true
                                    checked:
                                        root.locationFor(parent.parent.modelData)
                                        === modelData[0]

                                    ButtonGroup.group: locationGroup

                                    text: modelData[1]

                                    onClicked:
                                        root.setLocation(
                                            parent.parent.modelData,
                                            modelData[0]
                                        )
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 4

                        text: root.i18n.text("dashboard_limits_hint")
                        color: Md3Theme.surfaceVariantContent

                        font.pixelSize: 9
                        wrapMode: Text.Wrap
                    }
                }
            }

            Md3Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: root.i18n.text("dashboard_macro_selection")

                GridLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: 4

                        delegate: Md3Select {
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 42

                            model:
                                ["—"].concat(
                                    root.availableMacroNames()
                                )

                            currentIndex: {
                                const current =
                                    root.macroNames[index]
                                    ?? ""

                                if (current === "")
                                    return 0

                                const pos =
                                    root.availableMacroNames()
                                        .indexOf(current)

                                return pos >= 0
                                    ? pos + 1
                                    : 0
                            }

                            onActivated:
                                root.setMacroSlot(
                                    index,
                                    model[currentIndex]
                                )
                        }
                    }
                }
            }
        }
    }
}
