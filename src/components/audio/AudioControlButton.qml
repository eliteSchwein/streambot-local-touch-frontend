import QtQuick

import "../md3"

Rectangle {
    id: root

    property string icon: "minus"
    property bool selected: false

    signal clicked()

    implicitWidth: 34
    implicitHeight: 34

    radius: 17

    color:
        selected
        ? Md3Theme.primary
        : tap.pressed
            ? Md3Theme.surfaceContainerHigh
            : Md3Theme.surfaceContainerHighest

    border.width: selected ? 0 : 1
    border.color: Md3Theme.outlineVariant

    Canvas {
        id: canvas

        anchors.centerIn: parent
        width: 20
        height: 20

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const fg =
                root.selected
                ? Md3Theme.primaryContent
                : Md3Theme.surfaceContent

            ctx.strokeStyle = fg
            ctx.fillStyle = fg
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            if (root.icon === "minus") {
                ctx.beginPath()
                ctx.moveTo(4, 10)
                ctx.lineTo(16, 10)
                ctx.stroke()
                return
            }

            if (root.icon === "plus") {
                ctx.beginPath()
                ctx.moveTo(4, 10)
                ctx.lineTo(16, 10)
                ctx.moveTo(10, 4)
                ctx.lineTo(10, 16)
                ctx.stroke()
                return
            }

            // Speaker base.
            ctx.fillRect(2, 8, 5, 5)

            ctx.beginPath()
            ctx.moveTo(7, 8)
            ctx.lineTo(12, 4)
            ctx.lineTo(12, 16)
            ctx.lineTo(7, 13)
            ctx.closePath()
            ctx.fill()

            if (root.icon === "mute") {
                ctx.beginPath()
                ctx.moveTo(14, 7)
                ctx.lineTo(19, 13)
                ctx.moveTo(19, 7)
                ctx.lineTo(14, 13)
                ctx.stroke()
                return
            }

            // Volume waves.
            ctx.beginPath()
            ctx.arc(12, 10, 4, -0.75, 0.75)
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(12, 10, 7, -0.7, 0.7)
            ctx.stroke()
        }

        Component.onCompleted:
            requestPaint()

        onVisibleChanged: {
            if (visible)
                requestPaint()
        }
    }

    TapHandler {
        id: tap
        onTapped: root.clicked()
    }
}
