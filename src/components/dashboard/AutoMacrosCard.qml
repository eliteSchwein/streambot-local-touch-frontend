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

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    anchors.bottomMargin: 5
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        text: modelData.name
                        color: Md3Theme.surfaceContent

                        font.pixelSize: 11
                        font.weight: Font.Medium

                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter

                        text:
                            root.store.formatCountdown(
                                modelData.current_interval
                            )

                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 8
                        verticalAlignment: Text.AlignVCenter
                    }

                    Md3Switch {
                        Layout.alignment: Qt.AlignVCenter

                        checked: modelData.enabled === true

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
                }

                // Matches the old v-progress-linear location="bottom".
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    height: 4

                    color: Md3Theme.surfaceContainerHigh

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }

                        radius: 2

                        color:
                            modelData.enabled
                            ? Md3Theme.primary
                            : Md3Theme.outline

                        width: {
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

                            // Inverted from v25: full after reset,
                            // drains as current_interval approaches zero.
                            return parent.width
                                * remaining / interval
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 180
                            }
                        }
                    }
                }
            }
        }
    }
}
