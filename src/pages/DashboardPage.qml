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

    function cardHeight(card) {
        switch (card) {
        case "interactions":
            return 155
        case "auto_macros":
            return 190
        case "macros":
            return 190
        default:
            return -1
        }
    }

    RowLayout {
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
                        required property string modelData

                        Layout.fillWidth: true

                        // Every configured card participates in filling the
                        // complete column. preferredHeight only acts as the
                        // ratio/weight between two cards (Interactions stays
                        // more compact than Auto Macros / Macros).
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
