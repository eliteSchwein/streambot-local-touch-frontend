import QtQuick
import QtQuick.Layouts

import "md3"
import "../services"

Item {
    id: root

    required property string language

    property bool shift: false
    property bool symbols: false

    readonly property var enRows: [
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l"],
        ["z","x","c","v","b","n","m"]
    ]

    readonly property var deRows: [
        ["q","w","e","r","t","z","u","i","o","p","ü"],
        ["a","s","d","f","g","h","j","k","l","ö","ä"],
        ["y","x","c","v","b","n","m"]
    ]

    readonly property var symbolRows: [
        ["1","2","3","4","5","6","7","8","9","0"],
        ["@","#","€","_","&","-","+","(",")","/"],
        ["*","\"",":",";","!","?","'","="]
    ]

    readonly property var rows:
        symbols
        ? symbolRows
        : (language === "de" ? deRows : enRows)

    z: 1000000
    visible: KeyboardController.visible
    height: visible ? Math.min(260, parent.height * 0.43) : 0

    Rectangle {
        anchors.fill: parent
        color: Md3Theme.surfaceContainer
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        Repeater {
            model: root.rows

            RowLayout {
                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Item {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0.25
                }

                Repeater {
                    model: modelData

                    Rectangle {
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        radius: Md3Theme.radiusMedium
                        color: keyTap.pressed
                            ? Md3Theme.primary
                            : Md3Theme.surfaceContainerHighest

                        Text {
                            anchors.centerIn: parent

                            text:
                                root.shift && !root.symbols
                                ? modelData.toUpperCase()
                                : modelData

                            color: keyTap.pressed
                                ? Md3Theme.primaryContent
                                : Md3Theme.surfaceContent

                            font.pixelSize: 17
                            font.weight: Font.Medium
                        }

                        TapHandler {
                            id: keyTap

                            onTapped: {
                                const value =
                                    root.shift && !root.symbols
                                    ? modelData.toUpperCase()
                                    : modelData

                                KeyboardController.insert(value)

                                if (root.shift)
                                    root.shift = false
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0.25
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.25

                radius: Md3Theme.radiusMedium
                color: shiftTap.pressed || root.shift
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

                Text {
                    anchors.centerIn: parent
                    text: "⇧"
                    color: root.shift
                        ? Md3Theme.primaryContent
                        : Md3Theme.surfaceContent
                    font.pixelSize: 20
                }

                TapHandler {
                    id: shiftTap
                    onTapped: root.shift = !root.shift
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.4

                radius: Md3Theme.radiusMedium
                color: symbolsTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

                Text {
                    anchors.centerIn: parent
                    text: root.symbols ? "ABC" : "?123"
                    color: symbolsTap.pressed
                        ? Md3Theme.primaryContent
                        : Md3Theme.surfaceContent
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                TapHandler {
                    id: symbolsTap
                    onTapped: root.symbols = !root.symbols
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 4.5

                radius: Md3Theme.radiusMedium
                color: spaceTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

                Text {
                    anchors.centerIn: parent
                    text: root.language === "de" ? "Deutsch" : "English"
                    color: spaceTap.pressed
                        ? Md3Theme.primaryContent
                        : Md3Theme.surfaceVariantContent
                    font.pixelSize: 12
                }

                TapHandler {
                    id: spaceTap
                    onTapped: KeyboardController.insert(" ")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.25

                radius: Md3Theme.radiusMedium
                color: backspaceTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

                Text {
                    anchors.centerIn: parent
                    text: "⌫"
                    color: backspaceTap.pressed
                        ? Md3Theme.primaryContent
                        : Md3Theme.surfaceContent
                    font.pixelSize: 20
                }

                TapHandler {
                    id: backspaceTap
                    onTapped: KeyboardController.backspace()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1.25

                radius: Md3Theme.radiusMedium
                color: hideTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

                Text {
                    anchors.centerIn: parent
                    text: "⌄"
                    color: hideTap.pressed
                        ? Md3Theme.primaryContent
                        : Md3Theme.surfaceContent
                    font.pixelSize: 20
                }

                TapHandler {
                    id: hideTap
                    onTapped: KeyboardController.hide()
                }
            }
        }
    }
}
