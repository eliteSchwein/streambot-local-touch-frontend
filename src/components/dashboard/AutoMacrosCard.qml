import QtQuick
import QtQuick.Layouts

import "../md3"

Md3Card {
    id: root

    required property var i18n
    required property var store
    required property var websocket

    title: i18n.text("auto_macros")

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent

            visible: root.store.autoMacros.length === 0

            text: root.i18n.text("no_auto_macros")
            color: Md3Theme.surfaceVariantContent
            font.pixelSize: 10
        }

        ListView {
            id: macroList

            anchors.fill: parent
            visible: root.store.autoMacros.length > 0

            clip: true
            spacing: 6
            model: root.store.autoMacros

            delegate: Rectangle {
                id: macroRow

                required property var modelData

                width: macroList.width
                height: 48

                radius: Md3Theme.radiusMedium
                color: Md3Theme.surfaceContainerHighest

                Text {
                    anchors {
                        left: parent.left
                        leftMargin: 12
                        right: macroSwitch.left
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }

                    // Leave a little room for the bottom progress strip.
                    anchors.verticalCenterOffset: -2

                    text: modelData.name
                    color: Md3Theme.surfaceContent

                    font.pixelSize: 11
                    font.weight: Font.Medium

                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                Md3Switch {
                    id: macroSwitch

                    anchors {
                        right: parent.right
                        rightMargin: 9
                        verticalCenter: parent.verticalCenter
                    }

                    anchors.verticalCenterOffset: -2

                    checked: modelData.enabled === true

                    // notify_auto_macros_update arrives every second and the
                    // JS-array model is rebound. Do not replay the thumb
                    // animation on each server update.
                    animated: false

                    onClicked: {
                        root.websocket.sendRpc(
                            "toggle_auto_macro",
                            {
                                name: modelData.name,
                                enable: !modelData.enabled
                            }
                        )
                    }
                }

                // Same position/meaning as the old Vuetify
                // v-progress-linear location="bottom" absolute.
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    height: 4

                    color:
                        modelData.enabled
                        ? Md3Theme.surfaceContainerHigh
                        : "transparent"

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }

                        radius: 2

                        color: Md3Theme.outline

                        width: {
                            if (!modelData.enabled)
                                return 0

                            const interval =
                                Math.max(
                                    1,
                                    Number(modelData.interval ?? 1)
                                )

                            const remaining =
                                Math.max(
                                    0,
                                    Math.min(
                                        interval,
                                        Number(
                                            modelData.current_interval
                                            ?? interval
                                        )
                                    )
                                )

                            // Exactly the old touch behavior:
                            // 100 / interval * current_interval.
                            return parent.width
                                * remaining / interval
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }
            }
        }
    }
}
