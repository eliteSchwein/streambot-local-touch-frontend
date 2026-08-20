import QtQuick
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Styles

KeyboardStyle {
    id: style

    keyboardDesignWidth: 800
    keyboardDesignHeight: 300

    keyboardRelativeLeftMargin: 0.012
    keyboardRelativeRightMargin: 0.012
    keyboardRelativeTopMargin: 0.025
    keyboardRelativeBottomMargin: 0.025

    keyboardBackground: Rectangle {
        color: "#1b1b1f"
    }

    keyPanel: KeyPanel {
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 10

            color:
                control.pressed
                ? "#4f378b"
                : "#2b2930"

            border.width: 1
            border.color: "#49454f"

            Text {
                anchors.centerIn: parent

                text: control.displayText
                color: "#e6e1e5"

                font.pixelSize: Math.max(14, parent.height * 0.31)
                font.weight: Font.Medium
            }
        }
    }

    shiftKeyPanel: KeyPanel {
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 10

            color:
                control.pressed
                ? "#6750a4"
                : "#36343b"

            Text {
                anchors.centerIn: parent
                text: "⇧"
                color: "#e6e1e5"
                font.pixelSize: Math.max(18, parent.height * 0.34)
            }
        }
    }

    backspaceKeyPanel: KeyPanel {
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 10
            color: control.pressed ? "#6750a4" : "#36343b"

            Text {
                anchors.centerIn: parent
                text: "⌫"
                color: "#e6e1e5"
                font.pixelSize: Math.max(18, parent.height * 0.34)
            }
        }
    }

    enterKeyPanel: KeyPanel {
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 10
            color: control.pressed ? "#d0bcff" : "#6750a4"

            Text {
                anchors.centerIn: parent
                text: control.displayText !== "" ? control.displayText : "↵"
                color: control.pressed ? "#381e72" : "#ffffff"
                font.pixelSize: Math.max(15, parent.height * 0.30)
                font.weight: Font.DemiBold
            }
        }
    }

    spaceKeyPanel: KeyPanel {
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 10
            color: control.pressed ? "#4f378b" : "#2b2930"

            Text {
                anchors.centerIn: parent
                text: control.displayText
                color: "#e6e1e5"
                font.pixelSize: Math.max(13, parent.height * 0.25)
            }
        }
    }

    symbolKeyPanel: keyPanel
    modeKeyPanel: keyPanel
    languageKeyPanel: keyPanel

    hideKeyPanel: KeyPanel {
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: 10
            color: control.pressed ? "#6750a4" : "#36343b"

            Text {
                anchors.centerIn: parent
                text: "⌄"
                color: "#e6e1e5"
                font.pixelSize: Math.max(18, parent.height * 0.34)
            }
        }
    }

    characterPreviewMargin: 4

    characterPreviewDelegate: Item {
        property string text

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#4f378b"

            Text {
                anchors.centerIn: parent
                text: parent.parent.text
                color: "#ffffff"
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }
        }
    }

    selectionListBackground: Rectangle {
        color: "#211f26"
    }

    selectionListDelegate: SelectionListItem {
        Text {
            anchors.centerIn: parent
            text: word
            color: "#e6e1e5"
            font.pixelSize: 14
        }
    }

    selectionListHighlight: Rectangle {
        color: "#4f378b"
        radius: 8
    }
}
