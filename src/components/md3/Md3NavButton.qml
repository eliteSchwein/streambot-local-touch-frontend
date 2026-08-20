import QtQuick

Item {
    id: root

    property string icon: "home"
    property bool selected: false

    signal clicked()

    implicitWidth: 72
    implicitHeight: 42

    Rectangle {
        anchors.centerIn: parent

        width: 56
        height: 32
        radius: 18

        color:
            root.selected
            ? Md3Theme.primary
            : "transparent"

        // Home icon.
        Text {
            anchors.centerIn: parent
            visible: root.icon === "home"

            text: "⌂"
            color:
                root.selected
                ? Md3Theme.primaryContent
                : Md3Theme.surfaceVariantContent

            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

        // Speaker icon drawn using Canvas, independent of icon fonts.
        Canvas {
            id: speakerCanvas

            anchors.centerIn: parent
            width: 26
            height: 22

            visible: root.icon === "speaker"

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                ctx.fillStyle =
                    root.selected
                    ? Md3Theme.primaryContent
                    : Md3Theme.surfaceVariantContent

                // Speaker box.
                ctx.fillRect(2, 8, 6, 7)

                // Speaker cone.
                ctx.beginPath()
                ctx.moveTo(8, 8)
                ctx.lineTo(14, 3)
                ctx.lineTo(14, 20)
                ctx.lineTo(8, 15)
                ctx.closePath()
                ctx.fill()

                ctx.strokeStyle = ctx.fillStyle
                ctx.lineWidth = 2
                ctx.lineCap = "round"

                // Inner wave.
                ctx.beginPath()
                ctx.arc(13, 11.5, 5, -0.8, 0.8)
                ctx.stroke()

                // Outer wave.
                ctx.beginPath()
                ctx.arc(13, 11.5, 9, -0.72, 0.72)
                ctx.stroke()
            }

            Connections {
                target: Md3Theme

                function onPrimaryChanged() {
                    speakerCanvas.requestPaint()
                }
            }

            onVisibleChanged: {
                if (visible)
                    requestPaint()
            }

            Component.onCompleted:
                requestPaint()
        }
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
