import QtQuick
import QtQuick.Layouts

import "md3"
import "../services"

Item {
    id: root

    required property string language

    property bool shift: false
    property bool symbols: false

    readonly property var row1:
        symbols
        ? ["1","2","3","4","5","6","7","8","9","0"]
        : ["q","w","e","r","t",
           language === "de" ? "z" : "y",
           "u","i","o","p"]

    readonly property var row2:
        symbols
        ? ["@","#","€","_","&","-","+","(",")"]
        : (
            language === "de"
            ? ["a","s","d","f","g","h","j","k","l","ö"]
            : ["a","s","d","f","g","h","j","k","l"]
        )

    readonly property var row3:
        symbols
        ? ["*","\"","'",";",":","!","?","="]
        : (
            language === "de"
            ? ["y","x","c","v","b","n","m","ä","ü"]
            : ["z","x","c","v","b","n","m"]
        )

    visible: KeyboardController.visible
    z: 1000000
    height: visible
        ? Math.min(250, parent.height * 0.42)
        : 0

    Rectangle {
        anchors.fill: parent
        color: Md3Theme.surfaceContainer
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 5

        // Row 1
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            Repeater {
                model: root.row1

                Rectangle {
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    radius: 8
                    color: keyTap.pressed
                        ? Md3Theme.primary
                        : Md3Theme.surfaceContainerHighest

                    Text {
                        anchors.centerIn: parent
                        text: root.shift && !root.symbols
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
        }

        // Row 2, slightly inset like Android/Gboard.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            Item { Layout.preferredWidth: 18 }

            Repeater {
                model: root.row2

                Rectangle {
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8

                    color: keyTap2.pressed
                        ? Md3Theme.primary
                        : Md3Theme.surfaceContainerHighest

                    Text {
                        anchors.centerIn: parent
                        text: root.shift && !root.symbols
                            ? modelData.toUpperCase()
                            : modelData
                        color: keyTap2.pressed
                            ? Md3Theme.primaryContent
                            : Md3Theme.surfaceContent
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }

                    TapHandler {
                        id: keyTap2
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

            Item { Layout.preferredWidth: 18 }
        }

        // Row 3: shift + letters + backspace.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            Rectangle {
                Layout.preferredWidth: 58
                Layout.fillHeight: true
                radius: 8

                color: shiftTap.pressed || root.shift
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHigh

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

            Repeater {
                model: root.row3

                Rectangle {
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8

                    color: keyTap3.pressed
                        ? Md3Theme.primary
                        : Md3Theme.surfaceContainerHighest

                    Text {
                        anchors.centerIn: parent
                        text: root.shift && !root.symbols
                            ? modelData.toUpperCase()
                            : modelData
                        color: keyTap3.pressed
                            ? Md3Theme.primaryContent
                            : Md3Theme.surfaceContent
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }

                    TapHandler {
                        id: keyTap3
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

            Rectangle {
                Layout.preferredWidth: 58
                Layout.fillHeight: true
                radius: 8

                color: backspaceTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: "⌫"
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 20
                }

                TapHandler {
                    id: backspaceTap
                    onTapped: KeyboardController.backspace()
                }
            }
        }

        // Bottom row: Android/Gboard-ish.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            Rectangle {
                Layout.preferredWidth: 64
                Layout.fillHeight: true
                radius: 8

                color: symbolsTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: root.symbols ? "ABC" : "?123"
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                TapHandler {
                    id: symbolsTap
                    onTapped: root.symbols = !root.symbols
                }
            }

            Rectangle {
                Layout.preferredWidth: 48
                Layout.fillHeight: true
                radius: 8
                color: commaTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

                Text {
                    anchors.centerIn: parent
                    text: root.language === "de" ? "," : ","
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 18
                }

                TapHandler {
                    id: commaTap
                    onTapped: KeyboardController.insert(",")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8

                color: spaceTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

                Text {
                    anchors.centerIn: parent
                    text: root.language === "de" ? "Deutsch" : "English"
                    color: Md3Theme.surfaceVariantContent
                    font.pixelSize: 11
                }

                TapHandler {
                    id: spaceTap
                    onTapped: KeyboardController.insert(" ")
                }
            }

            Rectangle {
                Layout.preferredWidth: 48
                Layout.fillHeight: true
                radius: 8
                color: periodTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHighest

                Text {
                    anchors.centerIn: parent
                    text: "."
                    color: Md3Theme.surfaceContent
                    font.pixelSize: 18
                }

                TapHandler {
                    id: periodTap
                    onTapped: KeyboardController.insert(".")
                }
            }

            Rectangle {
                Layout.preferredWidth: 58
                Layout.fillHeight: true
                radius: 8

                color: hideTap.pressed
                    ? Md3Theme.primary
                    : Md3Theme.surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: "⌄"
                    color: Md3Theme.surfaceContent
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
