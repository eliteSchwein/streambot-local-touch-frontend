import QtQuick
import QtQuick.Layouts

import "../md3"

Md3Card {
    id: root

    required property var i18n
    required property var store

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
            spacing: 5
            model: root.store.autoMacros

            delegate: Rectangle {
                required property var modelData

                width: macroList.width
                height: 48

                radius: Md3Theme.radiusMedium
                color: Md3Theme.surfaceContainerHighest

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true

                            text: modelData.name
                            color: Md3Theme.surfaceContent

                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            text:
                                root.store.formatCountdown(
                                    modelData.current_interval
                                )

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 8
                        }

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4

                            color:
                                modelData.enabled
                                ? Md3Theme.success
                                : Md3Theme.outline
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5

                        radius: 3
                        color: Md3Theme.surfaceContainerHigh

                        Rectangle {
                            height: parent.height
                            radius: parent.radius

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

                                return parent.width
                                    * (1 - remaining / interval)
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
}
