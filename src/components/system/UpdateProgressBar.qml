import QtQuick
import "../md3"

// Thin MD3 style progress bar. A negative value shows an indeterminate bar.
Item {
    id: root
    property real value: -1
    property real barHeight: 6
    property color barColor: Md3Theme.primary

    readonly property bool indeterminate: value < 0

    implicitHeight: barHeight
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Md3Theme.surfaceContainerHighest
    }

    Rectangle {
        visible: !root.indeterminate
        height: parent.height
        width: parent.width * Math.max(0, Math.min(100, root.value)) / 100
        radius: height / 2
        color: root.barColor

        Behavior on width {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: runner
        visible: root.indeterminate
        height: parent.height
        width: parent.width * 0.3
        radius: height / 2
        color: root.barColor

        NumberAnimation on x {
            running: root.indeterminate && root.visible
            from: -runner.width
            to: root.width
            duration: 1200
            loops: Animation.Infinite
        }
    }
}
