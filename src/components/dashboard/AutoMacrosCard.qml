import QtQuick
import QtQuick.Layouts

import "../md3"

Md3Card {
    id: root

    required property var i18n
    required property var store
    required property var websocket

    title: ""

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

            delegate: Item {
                id: macroRow

                required property var modelData

                width: macroList.width
                height: 48

                readonly property real progress: {
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

                    return remaining / interval
                }

                // Base card surface.
                Rectangle {
                    anchors.fill: parent

                    radius: Md3Theme.radiusMedium
                    color: Md3Theme.surfaceContainerHighest
                }

                // Whole-row progress background.
                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width:
                        parent.width
                        * macroRow.progress

                    radius: Md3Theme.radiusMedium

                    // Keep it subtle so text/switch remain readable.
                    color: Md3Theme.surfaceContainerHigh

                    opacity:
                        modelData.enabled
                        ? 0.95
                        : 0

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

                // Slight primary accent over the progress area.
                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width:
                        parent.width
                        * macroRow.progress

                    radius: Md3Theme.radiusMedium
                    color: Md3Theme.primary
                    opacity:
                        modelData.enabled
                        ? 0.10
                        : 0

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
                    anchors.leftMargin: 12
                    anchors.rightMargin: 9
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

                    Md3Switch {
                        Layout.alignment: Qt.AlignVCenter

                        checked: modelData.enabled === true
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
                }
            }
        }
    }
}
