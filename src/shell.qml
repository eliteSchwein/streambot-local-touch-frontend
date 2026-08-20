import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ShellRoot {
    id: root

    readonly property string configPath:
        Quickshell.env("STREAMBOT_TOUCH_CONFIG") ?? ""

    PanelWindow {
        id: window

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        focusable: true
        color: "#121212"

        Rectangle {
            anchors.fill: parent
            color: "#121212"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 24

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Streambot Touch"
                    color: "white"
                    font.pixelSize: 42
                    font.bold: true
                }

                StatusCard {
                    Layout.alignment: Qt.AlignHCenter
                    title: "Quickshell"
                    value: "It works!"
                }

                StatusCard {
                    Layout.alignment: Qt.AlignHCenter
                    title: "Config"
                    value: root.configPath !== ""
                        ? root.configPath
                        : "No config specified"
                }

                Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Test button"

                    onClicked: {
                        console.log("Button pressed")
                        console.log("Config:", root.configPath)
                    }
                }
            }
        }
    }
}
