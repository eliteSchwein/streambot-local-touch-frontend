import QtQuick
import QtQuick.Layouts

import "../md3"

Item {
    id: root

    required property var store
    property bool suppressed: false

    // Don't show an OSD for the initial state sent after websocket registration.
    property bool virtualSnapshotReady: false
    property bool physicalSnapshotReady: false

    property var virtualVolumes: ({})
    property var physicalVolumes: ({})

    property string displayName: ""
    property string iconType: "output"
    property real volume: 0
    property bool muted: false

    readonly property int percent:
        Math.round(
            Math.max(
                0,
                Math.min(1, root.volume)
            ) * 100
        )

    visible: opacity > 0
    opacity: 0
    z: 7000000

    function effectiveVolume(device) {
        if (!device)
            return 0

        if (device.muted === true)
            return 0

        const value = Number(
            device.current_volume
            ?? device.volume
            ?? device.default_volume
            ?? 0
        )

        return Number.isFinite(value)
            ? Math.max(0, Math.min(1, value))
            : 0
    }

    function iconForInterface(name) {
        const normalized =
            String(name ?? "").trim().toLowerCase()

        if (normalized === "alert")
            return "alert"

        if (normalized === "tts")
            return "tts"

        if (normalized === "music")
            return "music"

        return "output"
    }

    function labelForInterface(name) {
        const normalized =
            String(name ?? "").trim().toLowerCase()

        if (normalized === "alert")
            return "Alert"

        if (normalized === "tts")
            return "TTS"

        if (normalized === "music")
            return "Music"

        return String(name ?? "Audio")
    }

    function physicalKey(output) {
        return String(
            (output && output.name)
            ?? (output && output.id)
            ?? (output && output.description)
            ?? ""
        )
    }

    function physicalLabel(output) {
        return String(
            (output && output.description)
            ?? (output && output.name)
            ?? (output && output.id)
            ?? "Output"
        )
    }

    function showOsd(name, type, value, isMuted) {
        if (root.suppressed)
            return

        console.log(
            "[audio-osd]",
            name,
            Math.round((Number(value) || 0) * 100) + "%"
        )

        root.displayName = name
        root.iconType = type
        root.volume = Math.max(
            0,
            Math.min(1, Number(value) || 0)
        )
        root.muted = isMuted === true || root.volume <= 0

        iconCanvas.requestPaint()

        hideTimer.restart()

        showAnimation.stop()
        hideAnimation.stop()
        showAnimation.start()
    }

    function handleVirtualAudio(params) {
        if (!params || typeof params !== "object")
            return

        const next = ({})
        const names = Object.keys(params)

        for (const name of names) {
            const device = params[name]
            next[name] = {
                volume: root.effectiveVolume(device),
                muted: device && device.muted === true
            }
        }

        if (!root.virtualSnapshotReady) {
            root.virtualVolumes = next
            root.virtualSnapshotReady = true
            return
        }

        const previous = root.virtualVolumes

        for (const name of names) {
            const before = previous[name]
            const after = next[name]

            if (!before)
                continue

            if (
                Math.abs(
                    Number(before.volume)
                    - Number(after.volume)
                ) > 0.0005
                || before.muted !== after.muted
            ) {
                root.showOsd(
                    root.labelForInterface(name),
                    root.iconForInterface(name),
                    after.volume,
                    after.muted
                )
            }
        }

        root.virtualVolumes = next
    }

    function handlePhysicalAudio(params) {
        if (!Array.isArray(params))
            return

        const next = ({})

        for (const output of params) {
            const key = root.physicalKey(output)

            if (!key)
                continue

            next[key] = {
                volume: root.effectiveVolume(output),
                muted: output && output.muted === true,
                label: root.physicalLabel(output)
            }
        }

        if (!root.physicalSnapshotReady) {
            root.physicalVolumes = next
            root.physicalSnapshotReady = true
            return
        }

        const previous = root.physicalVolumes

        for (const key of Object.keys(next)) {
            const before = previous[key]
            const after = next[key]

            if (!before)
                continue

            if (
                Math.abs(
                    Number(before.volume)
                    - Number(after.volume)
                ) > 0.0005
                || before.muted !== after.muted
            ) {
                root.showOsd(
                    after.label,
                    "output",
                    after.volume,
                    after.muted
                )
            }
        }

        root.physicalVolumes = next
    }

    function handleMessage(data) {
        if (!data || !data.method)
            return

        if (data.method === "notify_audio_update") {
            root.handleVirtualAudio(data.params)
            return
        }

        if (data.method === "notify_audio_outputs_update")
            root.handlePhysicalAudio(data.params)
    }

    onSuppressedChanged: {
        if (suppressed) {
            hideTimer.stop()
            showAnimation.stop()
            hideAnimation.stop()
            opacity = 0
        }
    }

    function snapshotStore() {
        const audio =
            root.store && root.store.audio
                ? root.store.audio
                : ({})

        const outputs =
            root.store && Array.isArray(root.store.audioOutputs)
                ? root.store.audioOutputs
                : []

        // Always compare/update snapshots, even while suppressed. This prevents
        // a volume change made on the Audio page from popping up later when
        // the user leaves that page.
        root.handleVirtualAudio(audio)
        root.handlePhysicalAudio(outputs)
    }

    Timer {
        id: storeWatchTimer

        interval: 100
        repeat: true
        running: true

        onTriggered:
            root.snapshotStore()
    }

    Component.onCompleted:
        Qt.callLater(root.snapshotStore)

    anchors {
        top: parent.top
        horizontalCenter: parent.horizontalCenter
        topMargin: 16
    }

    width: Math.min(360, parent.width - 24)
    height: 78

    transform: Scale {
        id: osdScale
        origin.x: root.width / 2
        origin.y: 0
        xScale: 0.96
        yScale: 0.96
    }

    Rectangle {
        anchors.fill: parent

        radius: Md3Theme.radiusLarge
        color: Md3Theme.surfaceContainerHigh

        border.width: 1
        border.color: Md3Theme.outlineVariant

        RowLayout {
            anchors {
                fill: parent
                margins: 12
            }

            spacing: 12

            Rectangle {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46

                radius: 23
                color: Md3Theme.primary

                Canvas {
                    id: iconCanvas

                    anchors.centerIn: parent
                    width: 27
                    height: 27

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()

                        ctx.strokeStyle =
                            Md3Theme.primaryContent
                        ctx.fillStyle =
                            Md3Theme.primaryContent

                        ctx.lineWidth = 2
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"

                        if (root.iconType === "music") {
                            // Music note.
                            ctx.beginPath()
                            ctx.moveTo(15, 5)
                            ctx.lineTo(15, 18)
                            ctx.moveTo(15, 7)
                            ctx.lineTo(22, 5)
                            ctx.lineTo(22, 16)
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.arc(11, 20, 4, 0, Math.PI * 2)
                            ctx.fill()

                            ctx.beginPath()
                            ctx.arc(18, 18, 4, 0, Math.PI * 2)
                            ctx.fill()
                            return
                        }

                        if (root.iconType === "tts") {
                            // Speech bubble with TTS-ish sound bars.
                            ctx.strokeRect(3, 5, 20, 14)

                            ctx.beginPath()
                            ctx.moveTo(8, 19)
                            ctx.lineTo(6, 23)
                            ctx.lineTo(12, 19)
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.moveTo(8, 10)
                            ctx.lineTo(8, 14)
                            ctx.moveTo(12, 9)
                            ctx.lineTo(12, 15)
                            ctx.moveTo(16, 10)
                            ctx.lineTo(16, 14)
                            ctx.moveTo(20, 11)
                            ctx.lineTo(20, 13)
                            ctx.stroke()
                            return
                        }

                        if (root.iconType === "alert") {
                            // Bell.
                            ctx.beginPath()
                            ctx.moveTo(7, 18)
                            ctx.lineTo(20, 18)
                            ctx.quadraticCurveTo(18, 16, 18, 12)
                            ctx.quadraticCurveTo(18, 7, 13.5, 7)
                            ctx.quadraticCurveTo(9, 7, 9, 12)
                            ctx.quadraticCurveTo(9, 16, 7, 18)
                            ctx.closePath()
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.arc(13.5, 21, 1.5, 0, Math.PI * 2)
                            ctx.fill()
                            return
                        }

                        // Physical output / generic speaker.
                        ctx.fillRect(3, 10, 6, 7)

                        ctx.beginPath()
                        ctx.moveTo(9, 10)
                        ctx.lineTo(15, 6)
                        ctx.lineTo(15, 21)
                        ctx.lineTo(9, 17)
                        ctx.closePath()
                        ctx.fill()

                        if (!root.muted) {
                            ctx.beginPath()
                            ctx.arc(15, 13.5, 5, -0.75, 0.75)
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.arc(15, 13.5, 8, -0.7, 0.7)
                            ctx.stroke()
                        } else {
                            ctx.beginPath()
                            ctx.moveTo(18, 10)
                            ctx.lineTo(24, 17)
                            ctx.moveTo(24, 10)
                            ctx.lineTo(18, 17)
                            ctx.stroke()
                        }
                    }

                    Component.onCompleted:
                        requestPaint()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true

                        text: root.displayName
                        color: Md3Theme.surfaceContent

                        font.pixelSize: 13
                        font.weight: Font.DemiBold

                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.percent + "%"
                        color: Md3Theme.surfaceContent

                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6

                    radius: 3
                    color: Md3Theme.surfaceContainerHighest

                    Rectangle {
                        width:
                            parent.width
                            * Math.max(
                                0,
                                Math.min(1, root.volume)
                            )

                        height: parent.height
                        radius: 3
                        color: Md3Theme.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: 90
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: hideTimer

        interval: 1400
        repeat: false

        onTriggered:
            hideAnimation.start()
    }

    ParallelAnimation {
        id: showAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            from: root.opacity
            to: 1
            duration: 110
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: osdScale
            property: "xScale"
            from: osdScale.xScale
            to: 1
            duration: 130
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: osdScale
            property: "yScale"
            from: osdScale.yScale
            to: 1
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: hideAnimation

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: 160
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: osdScale
            property: "xScale"
            to: 0.97
            duration: 160
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: osdScale
            property: "yScale"
            to: 0.97
            duration: 160
            easing.type: Easing.InCubic
        }
    }
}
