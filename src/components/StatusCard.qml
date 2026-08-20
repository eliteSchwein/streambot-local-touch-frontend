import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: ""
    property string value: ""

    width: 520
    height: 100
    radius: 12
    color: "#242424"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Text {
            Layout.fillWidth: true
            text: root.title
            color: "#aaaaaa"
            font.pixelSize: 20
        }

        Text {
            text: root.value
            color: "white"
            font.pixelSize: 20
            font.bold: true
        }
    }
}
