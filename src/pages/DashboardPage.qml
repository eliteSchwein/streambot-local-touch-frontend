import QtQuick
import QtQuick.Layouts

import "../components/dashboard"
import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var store
    required property var config

    property bool editing: false

    readonly property var dashboard:
        config.normalizeTouchDashboard(
            config.touchDashboard
        )

    function columnCards(side) {
        const columns =
            dashboard.columns ?? ({})

        const value =
            side === "left"
            ? columns.left
            : columns.right

        return Array.isArray(value)
            ? value
            : []
    }

    // Equal weight for all list cards, so cards in one column share its
    // height evenly (music keeps its own compact size).
    function cardHeight(card) {
        switch (card) {
        case "interactions":
        case "auto_macros":
        case "macros":
            return 180
        default:
            return -1
        }
    }

    RowLayout {
        // Do not render the live dashboard underneath the editor. The editor
        // itself is transparent so the global wallpaper remains visible.
        visible: !root.editing

        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Repeater {
            model: [
                root.columnCards("left"),
                root.columnCards("right")
            ]

            delegate: ColumnLayout {
                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Repeater {
                    model: modelData

                    delegate: Loader {
                        id: cardLoader

                        required property string modelData

                        property bool built: false
                        property int cardIndex: index

                        Layout.fillWidth: true

                        opacity:
                            built ? 1 : 0

                        // Every configured card participates in filling the
                        // complete column. preferredHeight only acts as the
                        // ratio/weight between the cards (equal for all
                        // list cards).
                        Layout.fillHeight: true
                        Layout.preferredHeight:
                            modelData === "music"
                            ? 1
                            : root.cardHeight(modelData)

                        sourceComponent: {
                            switch (modelData) {
                            case "interactions":
                                return interactionsComponent
                            case "auto_macros":
                                return autoMacrosComponent
                            case "macros":
                                return macrosComponent
                            case "music":
                                return musicComponent
                            default:
                                return null
                            }
                        }

                        Component.onCompleted:
                            cardBuildTimer.start()

                        Timer {
                            id: cardBuildTimer

                            interval:
                                40 + cardLoader.cardIndex * 70

                            repeat: false

                            onTriggered:
                                cardLoader.built = true
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

            }
        }
    }


    Component {
        id: interactionsComponent

        InteractionsCard {
            i18n: root.i18n
            store: root.store
            websocket: root.websocket
        }
    }

    Component {
        id: autoMacrosComponent

        AutoMacrosCard {
            i18n: root.i18n
            store: root.store
            websocket: root.websocket

            autoMacroNames:
                root.dashboard.auto_macro_names
                ?? []
        }
    }

    Component {
        id: macrosComponent

        DashboardMacrosCard {
            i18n: root.i18n
            store: root.store
            websocket: root.websocket

            macroNames:
                root.dashboard.macro_names
                ?? []
        }
    }

    Component {
        id: musicComponent

        MusicPlayerCard {
            i18n: root.i18n
            websocket: root.websocket
            store: root.store
        }
    }

    DashboardEditor {
        anchors.fill: parent
        visible: root.editing

        i18n: root.i18n
        config: root.config
        store: root.store

        onClosed:
            root.editing = false
    }
}
