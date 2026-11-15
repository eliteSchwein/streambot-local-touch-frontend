import QtQuick

// Indeterminate circular progress (rotating 3/4 ring).
Item {
    id: root

    property color color: Md3Theme.primary
    property real size: 20
    property real strokeWidth: 2.5
    property bool running: visible

    implicitWidth: size
    implicitHeight: size

    Canvas {
        id: ring
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()

            const radius = Math.min(width, height) / 2 - root.strokeWidth
            ctx.lineWidth = root.strokeWidth
            ctx.lineCap = "round"
            ctx.strokeStyle = root.color
            ctx.beginPath()
            ctx.arc(width / 2, height / 2, radius, 0, Math.PI * 1.5)
            ctx.stroke()
        }

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.running
        }
    }

    onColorChanged: ring.requestPaint()
    onStrokeWidthChanged: ring.requestPaint()
    onSizeChanged: ring.requestPaint()
}
