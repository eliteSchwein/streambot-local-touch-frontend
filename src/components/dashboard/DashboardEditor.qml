import QtQuick
import QtQuick.Layouts

import "../md3"
import "../../services"

Rectangle {
    id: root

    required property var i18n
    required property var config
    required property var store

    signal closed()

    // Keep the normal dashboard wallpaper visible while editing.
    // Cards/dialogs still provide their own surfaces for readability.
    color: "transparent"
    z: 1000

    property var leftCards: []
    property var rightCards: []
    property var macroNames: []
    property var autoMacroNames: []

    property bool selectorOpen: false
    property string selectorType: ""
    property string selectorSearch: ""
    property var selectorSelection: []

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

        autoMacroNames =
            Array.isArray(dashboard.auto_macro_names)
            ? dashboard.auto_macro_names.slice(0, 4)
            : []
    }

    function availableMacroNames() {
        const result = []

        for (const name in (store.macros ?? ({}))) {
            const value = String(name)

            // Dashboard macro picker intentionally excludes generated /
            // integration-backed macros.
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

    function availableAutoMacroNames() {
        const result = []
        const all =
            Array.isArray(store.autoMacros)
            ? store.autoMacros
            : []

        for (const entry of all) {
            const name = String(entry?.name ?? "").trim()

            if (
                name !== ""
                && !result.includes(name)
            ) {
                result.push(name)
            }
        }

        result.sort((a, b) => a.localeCompare(b))
        return result
    }

    function selectorCandidates() {
        const source =
            selectorType === "macros"
            ? availableMacroNames()
            : availableAutoMacroNames()

        const query =
            String(selectorSearch ?? "")
                .trim()
                .toLowerCase()

        if (query === "")
            return source

        return source.filter(name =>
            name.toLowerCase().includes(query)
        )
    }

    function openSelector(type) {
        selectorType = type
        selectorSearch = ""
        selectorSelection =
            type === "macros"
            ? macroNames.slice(0, 4)
            : autoMacroNames.slice(0, 4)

        selectorOpen = true
    }

    function selectorContains(name) {
        return selectorSelection.includes(name)
    }

    function toggleSelectorName(name) {
        const next = selectorSelection.slice()
        const index = next.indexOf(name)

        if (index >= 0) {
            next.splice(index, 1)
        } else {
            if (next.length >= 4)
                return

            next.push(name)
        }

        selectorSelection = next
    }

    function applySelector() {
        if (selectorType === "macros")
            macroNames = selectorSelection.slice(0, 4)
        else
            autoMacroNames = selectorSelection.slice(0, 4)

        KeyboardController.hide()
        selectorOpen = false
    }

    function selectionSummary(values, emptyText) {
        if (!Array.isArray(values) || values.length === 0)
            return emptyText

        return values.join(", ")
    }

    readonly property bool macrosUsed:
        leftCards.includes("macros")
        || rightCards.includes("macros")

    readonly property bool autoMacrosUsed:
        leftCards.includes("auto_macros")
        || rightCards.includes("auto_macros")

    function save() {
        config.setTouchDashboard({
            version: 1,
            columns: {
                left: normalizedColumn(leftCards),
                right: normalizedColumn(rightCards)
            },
            macro_names: macroNames.slice(0, 4),
            auto_macro_names: autoMacroNames.slice(0, 4)
        })

        closed()
    }

    onVisibleChanged: {
        if (
            visible
            && config.sharedSettingsLoaded
        ) {
            load()
        }
    }

    Connections {
        target: root.config

        function onSharedSettingsLoadedChanged() {
            if (
                root.visible
                && root.config.sharedSettingsLoaded
            ) {
                root.load()
            }
        }

        function onTouchDashboardChanged() {
            // Keep the editor in sync with direct file changes while it is
            // open, but do not overwrite an active selector operation.
            if (
                root.visible
                && root.config.sharedSettingsLoaded
                && !root.selectorOpen
            ) {
                root.load()
            }
        }
    }

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
                    root.autoMacroNames = []
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
                                root.columnCards(
                                    modelData
                                ).includes("macros")
                                || root.columnCards(
                                    modelData
                                ).includes("auto_macros")

                            color: Md3Theme.outlineVariant
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            visible:
                                root.columnCards(
                                    modelData
                                ).includes("macros")

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

                            Md3Button {
                                Layout.fillWidth: true
                                implicitHeight: 40
                                outlined: true

                                text:
                                    root.macroNames.length > 0
                                    ? root.i18n.text("dashboard_selected")
                                      + " "
                                      + root.macroNames.length
                                      + "/4"
                                    : root.i18n.text(
                                        "dashboard_choose_macros"
                                    )

                                onClicked:
                                    root.openSelector("macros")
                            }

                            Text {
                                Layout.fillWidth: true

                                visible:
                                    root.macroNames.length > 0

                                text:
                                    root.selectionSummary(
                                        root.macroNames,
                                        ""
                                    )

                                color: Md3Theme.surfaceVariantContent
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            visible:
                                root.columnCards(
                                    modelData
                                ).includes("auto_macros")

                            Text {
                                Layout.fillWidth: true

                                text:
                                    root.i18n.text(
                                        "dashboard_auto_macro_selection"
                                    )

                                color: Md3Theme.surfaceContent
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Md3Button {
                                Layout.fillWidth: true
                                implicitHeight: 40
                                outlined: true

                                text:
                                    root.autoMacroNames.length > 0
                                    ? root.i18n.text("dashboard_selected")
                                      + " "
                                      + root.autoMacroNames.length
                                      + "/4"
                                    : root.i18n.text(
                                        "dashboard_choose_auto_macros"
                                    )

                                onClicked:
                                    root.openSelector("auto_macros")
                            }

                            Text {
                                Layout.fillWidth: true

                                visible:
                                    root.autoMacroNames.length > 0

                                text:
                                    root.selectionSummary(
                                        root.autoMacroNames,
                                        ""
                                    )

                                color: Md3Theme.surfaceVariantContent
                                font.pixelSize: 9
                                elide: Text.ElideRight
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


    Item {
        id: selectorDialogLayer

        anchors.fill: parent
        z: 6000000

        visible: root.selectorOpen

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.62)

            TapHandler {
                onTapped: {
                    KeyboardController.hide()
                    root.selectorOpen = false
                    root.selectorSearch = ""
                }
            }
        }

        Rectangle {
            id: selectorDialog

            width:
                Math.min(
                    selectorDialogLayer.width - 80,
                    640
                )

            readonly property real keyboardHeight:
                KeyboardController.visible
                ? KeyboardController.keyboardHeight
                : 0

            readonly property real keyboardGap: -42

            readonly property real availableHeight:
                Math.max(
                    170,
                    selectorDialogLayer.height
                    - keyboardHeight
                    - keyboardGap
                    - 8
                )

            height:
                Math.min(
                    430,
                    availableHeight
                )

            clip: true

            x:
                Math.round(
                    (selectorDialogLayer.width - width) / 2
                )

            y: {
                if (KeyboardController.visible) {
                    // Keep the dialog visually attached to the keyboard with
                    // just a small breathing gap instead of pinning it to the
                    // top of the screen.
                    return Math.max(
                        8,
                        selectorDialogLayer.height
                        - keyboardHeight
                        - height
                        - keyboardGap
                    )
                }

                const desired =
                    Math.round(
                        (selectorDialogLayer.height - height) / 2
                    ) + 30

                return Math.max(
                    8,
                    Math.min(
                        desired,
                        selectorDialogLayer.height
                        - height
                        - 8
                    )
                )
            }

            Behavior on y {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            radius: Md3Theme.radiusExtraLarge
            color: Md3Theme.surfaceContainer

            border.width: 1
            border.color: Md3Theme.outlineVariant

            // Eat taps inside the dialog so the backdrop doesn't close it.
            TapHandler {
                onTapped: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 9

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    spacing: 8

                    Text {
                        Layout.fillWidth: true

                        text:
                            root.selectorType === "macros"
                            ? root.i18n.text(
                                "dashboard_choose_macros"
                            )
                            : root.i18n.text(
                                "dashboard_choose_auto_macros"
                            )

                        color: Md3Theme.surfaceContent
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text:
                            root.selectorSelection.length
                            + "/4"

                        color:
                            root.selectorSelection.length >= 4
                            ? Md3Theme.primary
                            : Md3Theme.surfaceVariantContent

                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                Md3TextField {
                    id: selectorSearchField

                    Layout.fillWidth: true
                    implicitHeight: 44

                    placeholderText:
                        root.i18n.text(
                            "dashboard_search"
                        )

                    text:
                        root.selectorSearch

                    onTextChanged:
                        root.selectorSearch = text
                }

                ListView {
                    id: selectorList

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
                    spacing: 5

                    model:
                        root.selectorCandidates()

                    delegate: Rectangle {
                        required property string modelData

                        width: selectorList.width
                        height: 44
                        radius: Md3Theme.radiusMedium

                        color:
                            selectorTap.pressed
                            ? Md3Theme.surfaceContainerHigh
                            : (
                                root.selectorContains(modelData)
                                ? Md3Theme.primaryContainer
                                : Md3Theme.surfaceContainerHighest
                            )

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                Layout.fillWidth: true

                                text: modelData
                                color: Md3Theme.surfaceContent

                                font.pixelSize: 11
                                font.weight:
                                    root.selectorContains(modelData)
                                    ? Font.DemiBold
                                    : Font.Medium

                                elide: Text.ElideRight
                            }

                            Text {
                                visible:
                                    root.selectorContains(modelData)

                                text: "✓"
                                color: Md3Theme.primary

                                font.pixelSize: 18
                                font.weight: Font.Bold
                            }
                        }

                        TapHandler {
                            id: selectorTap

                            enabled:
                                root.selectorContains(modelData)
                                || root.selectorSelection.length < 4

                            onTapped:
                                root.toggleSelectorName(
                                    modelData
                                )
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                    }

                    Md3Button {
                        text:
                            root.i18n.text("cancel")
                        outlined: true
                        implicitHeight: 36

                        onClicked: {
                            KeyboardController.hide()
                            root.selectorOpen = false
                            root.selectorSearch = ""
                        }
                    }

                    Md3Button {
                        text:
                            root.i18n.text("apply")
                        implicitHeight: 36

                        onClicked:
                            root.applySelector()
                    }
                }
            }
        }
    }

}
