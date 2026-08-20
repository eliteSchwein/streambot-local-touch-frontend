import QtQuick

import "../md3"

Rectangle {
    id: root

    signal clicked()

    implicitWidth: 42
    implicitHeight: 42

    radius: 21

    color:
        tap.pressed
        ? Md3Theme.surfaceContainerHigh
        : Md3Theme.surfaceContainerHighest

    Canvas {
        anchors.centerIn: parent
        width: 24
        height: 24

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            ctx.strokeStyle = Md3Theme.surfaceContent
            ctx.lineWidth = 2.2
            ctx.lineCap = "round"

            // Top-left chain loop.
            ctx.beginPath()
            ctx.ellipse(4, 5, 9, 6, -0.7, 0, Math.PI * 2)
            ctx.stroke()

            // Bottom-right chain loop.
            ctx.beginPath()
            ctx.ellipse(11, 13, 9, 6, -0.7, 0, Math.PI * 2)
            ctx.stroke()

            // Middle link line.
            ctx.beginPath()
            ctx.moveTo(9, 15)
            ctx.lineTo(15, 9)
            ctx.stroke()
        }

        Component.onCompleted:
            requestPaint()
    }

    TapHandler {
        id: tap
        onTapped: root.clicked()
    }
}
