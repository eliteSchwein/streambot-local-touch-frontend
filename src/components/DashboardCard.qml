import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""

    default property alias content: contentLayout.data

    Layout.fillWidth: true

    implicitHeight: Math.max(150, contentLayout.implicitHeight + 72)

    radius: 18
    color: "#202020"

    border.width: 1
    border.color: "#303030"

    ColumnLayout {
        id: contentLayout

        anchors.fill: parent
        anchors.margins: 20

        spacing: 12

        Text {
            Layout.fillWidth: true

            text: root.title
            color: "white"

            font.pixelSize: 22
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            visible: root.subtitle !== ""

            text: root.subtitle
            color: "#999999"

            font.pixelSize: 15
            wrapMode: Text.Wrap
        }
    }
}