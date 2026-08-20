import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var i18n

    property bool open: false

    signal clicked()

    anchors.left: parent.left
    anchors.right: parent.right

    height: 210

    z: 1000

    Rectangle {
        id: drawer

        width: Math.min(parent.width - 32, 700)
        height: 190

        anchors.horizontalCenter: parent.horizontalCenter

        y: root.open
            ? 12
            : -height + 48

        radius: 20

        color: "#282828"

        border.width: 1
        border.color: "#404040"

        Behavior on y {
            enabled: !dragArea.drag.active

            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18

            spacing: 10

            Text {
                Layout.fillWidth: true

                text: root.i18n.text("notifications")

                color: "#aaaaaa"

                font.pixelSize: 15
                font.bold: true
            }

            Text {
                Layout.fillWidth: true

                text: root.i18n.text("notification_dummy_title")

                color: "white"

                font.pixelSize: 23
                font.bold: true
            }

            Text {
                Layout.fillWidth: true

                text: root.i18n.text("notification_dummy_text")

                color: "#cccccc"

                font.pixelSize: 17

                wrapMode: Text.Wrap
            }

            Item {
                Layout.fillHeight: true
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter

                width: 50
                height: 5

                radius: 3

                color: "#777777"
            }
        }

        MouseArea {
            id: dragArea

            anchors.fill: parent

            drag.target: drawer
            drag.axis: Drag.YAxis

            drag.minimumY: -drawer.height + 48
            drag.maximumY: 12

            onReleased: {
                const threshold = -drawer.height * 0.45

                root.open = drawer.y > threshold
            }

            onClicked: {
                root.open = !root.open
                root.clicked()
            }
        }
    }
}