import QtQuick
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

    property var leftCards: []
    property var rightCards: []
    property var macroNames: []

    readonly property var cardOptions: [
        ["", root.i18n.text("dashboard_empty")],
        ["interactions", root.i18n.text("dashboard_card_interactions")],
        ["auto_macros", root.i18n.text("dashboard_card_auto_macros")],
        ["macros", root.i18n.text("dashboard_card_macros")],
        ["music", root.i18n.text("dashboard_card_music")]
    ]

    function optionLabels() {
        return cardOptions.map(option => option[1])
    }

    function cardFromOptionIndex(index) {
        if (
            index < 0
            || index >= cardOptions.length
        ) {
            return ""
        }

        return cardOptions[index][0]
    }

    function optionIndexFor(card) {
        for (let i = 0; i < cardOptions.length; i++) {
            if (cardOptions[i][0] === card)
                return i
        }

        return 0
    }

    function normalizedColumn(cards) {
        if (!Array.isArray(cards))
            return []

        const result = []

        for (const raw of cards) {
            const card = String(raw ?? "")

            if (
                card === ""
                || result.includes(card)
            ) {
                continue
            }

            result.push(card)

            if (card === "music")
                return ["music"]

            if (result.length >= 2)
                break
        }

        return result
    }

    function columnCards(side) {
        return side === "left"
            ? leftCards
            : rightCards
    }

    function setColumnCards(side, cards) {
        const normalized = normalizedColumn(cards)

        if (side === "left")
            leftCards = normalized
        else
            rightCards = normalized
    }

    function cardAt(side, slot) {
        const cards = columnCards(side)

        if (
            !Array.isArray(cards)
            || slot < 0
            || slot >= cards.length
        ) {
            return ""
        }

        return String(cards[slot] ?? "")
    }

    function removeCardEverywhere(card, exceptSide, exceptSlot) {
        if (card === "")
            return

        function clean(side, cards) {
            const result = []

            for (let i = 0; i < cards.length; i++) {
                if (
                    cards[i] === card
                    && !(side === exceptSide && i === exceptSlot)
                ) {
                    continue
                }

                result.push(cards[i])
            }

            return result
        }

        leftCards = clean("left", leftCards)
        rightCards = clean("right", rightCards)
    }

    function setSlot(side, slot, card) {
        let cards = columnCards(side).slice()

        while (cards.length <= slot)
            cards.push("")

        const previous = cards[slot] ?? ""
        cards[slot] = card

        // Remove empty gaps.
        cards = cards.filter(value => String(value ?? "") !== "")

        if (card !== "")
            removeCardEverywhere(card, side, slot)

        // Re-read after removeCardEverywhere, because it can update both
        // column properties.
        cards = columnCards(side).slice()

        while (cards.length <= slot)
            cards.push("")

        cards[slot] = card
        cards = cards.filter(value => String(value ?? "") !== "")

        // Music owns the whole column.
        if (card === "music") {
            cards = ["music"]
        } else {
            // Selecting a normal card replaces Music in this column.
            cards = cards.filter(value => value !== "music")

            if (!cards.includes(card) && card !== "")
                cards.splice(Math.min(slot, cards.length), 0, card)

            cards = normalizedColumn(cards)
        }

        // If the previous card was only in this slot and got replaced, no
        // special handling is needed; the normalized array already removed it.
        setColumnCards(side, cards)
    }

    function load() {
        const dashboard =
            config.normalizeTouchDashboard(
                config.touchDashboard
            )

        leftCards =
            Array.isArray(dashboard.columns?.left)
            ? dashboard.columns.left.slice(0, 2)
            : []

        rightCards =
            Array.isArray(dashboard.columns?.right)
            ? dashboard.columns.right.slice(0, 2)
            : []

        macroNames =
            Array.isArray(dashboard.macro_names)
            ? dashboard.macro_names.slice(0, 4)
            : []
    }

    function availableMacroNames() {
        const result = []

        for (const name in (store.macros ?? ({}))) {
            const value = String(name)

            if (
                value.startsWith("event_")
                || value.startsWith("channel_point_")
                || value.startsWith("command_")
            ) {
                continue
            }

            result.push(value)
        }

        result.sort((a, b) => a.localeCompare(b))
        return result
    }

    function macroOptionLabels() {
        return [root.i18n.text("dashboard_empty")]
            .concat(availableMacroNames())
    }

    function macroIndexFor(slot) {
        const current =
            String(macroNames[slot] ?? "")

        if (current === "")
            return 0

        const index =
            availableMacroNames().indexOf(current)

        return index >= 0
            ? index + 1
            : 0
    }

    function setMacroSlot(slot, index) {
        const values = macroNames.slice()

        while (values.length <= slot)
            values.push("")

        values[slot] =
            index <= 0
            ? ""
            : availableMacroNames()[index - 1]

        const result = []

        for (const value of values) {
            const name = String(value ?? "").trim()

            if (
                name !== ""
                && !result.includes(name)
            ) {
                result.push(name)
            }

            if (result.length >= 4)
                break
        }

        macroNames = result
    }

    readonly property bool macrosUsed:
        leftCards.includes("macros")
        || rightCards.includes("macros")

    function save() {
        config.setTouchDashboard({
            version: 1,
            columns: {
                left: normalizedColumn(leftCards),
                right: normalizedColumn(rightCards)
            },
            macro_names: macroNames.slice(0, 4)
        })

        closed()
    }

    Component.onCompleted:
        load()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            spacing: 8

            Text {
                Layout.fillWidth: true

                text: root.i18n.text("dashboard_edit")
                color: Md3Theme.surfaceContent

                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Md3Button {
                text: root.i18n.text("dashboard_reset")
                outlined: true
                implicitHeight: 34

                onClicked: {
                    const defaults =
                        root.config.defaultTouchDashboard()

                    root.leftCards =
                        defaults.columns.left.slice()

                    root.rightCards =
                        defaults.columns.right.slice()

                    root.macroNames = []
                }
            }

            Md3Button {
                text: root.i18n.text("cancel")
                outlined: true
                implicitHeight: 34

                onClicked:
                    root.closed()
            }

            Md3Button {
                text: root.i18n.text("save")
                implicitHeight: 34

                onClicked:
                    root.save()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Repeater {
                model: ["left", "right"]

                delegate: Md3Card {
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    title:
                        modelData === "left"
                        ? root.i18n.text("dashboard_left_column")
                        : root.i18n.text("dashboard_right_column")

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        Repeater {
                            model: 2

                            delegate: ColumnLayout {
                                required property int index

                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true

                                    text:
                                        root.i18n.text("dashboard_slot")
                                        + " "
                                        + (index + 1)

                                    color: Md3Theme.surfaceVariantContent
                                    font.pixelSize: 10
                                }

                                Md3Select {
                                    Layout.fillWidth: true
                                    implicitHeight: 42

                                    enabled:
                                        index === 0
                                        || root.cardAt(
                                            parent.parent.parent.parent.modelData,
                                            0
                                        ) !== "music"

                                    model:
                                        root.optionLabels()

                                    currentIndex:
                                        root.optionIndexFor(
                                            root.cardAt(
                                                parent.parent.parent.parent.modelData,
                                                index
                                            )
                                        )

                                    onActivated: selectedIndex => {
                                        root.setSlot(
                                            parent.parent.parent.parent.modelData,
                                            index,
                                            root.cardFromOptionIndex(
                                                selectedIndex
                                            )
                                        )
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true

                            visible:
                                root.cardAt(
                                    modelData,
                                    0
                                ) === "music"

                            text:
                                root.i18n.text(
                                    "dashboard_music_full_column"
                                )

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 9
                            wrapMode: Text.Wrap
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1

                            visible:
                                root.macrosUsed

                            color: Md3Theme.outlineVariant
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 5

                            visible:
                                root.macrosUsed

                            Text {
                                Layout.fillWidth: true

                                text:
                                    root.i18n.text(
                                        "dashboard_macro_selection"
                                    )

                                color: Md3Theme.surfaceContent
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 5
                                columnSpacing: 5

                                Repeater {
                                    model: 4

                                    delegate: Md3Select {
                                        required property int index

                                        Layout.fillWidth: true
                                        implicitHeight: 38

                                        model:
                                            root.macroOptionLabels()

                                        currentIndex:
                                            root.macroIndexFor(
                                                index
                                            )

                                        onActivated:
                                            selectedIndex => {
                                                root.setMacroSlot(
                                                    index,
                                                    selectedIndex
                                                )
                                            }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }
        }
    }
}
