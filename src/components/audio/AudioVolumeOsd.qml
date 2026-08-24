import QtQuick
import QtQuick.Layouts
import Quickshell.Io

import "../md3"

Item {
    id: root

    required property var websocket
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

    property string targetKind: ""
    property string targetId: ""
    property real minVolume: 0
    property real maxVolume: 1
    property real stepVolume: 0.05
    property real previousVolume: 0.2
    property bool interacting: false

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

    function showOsd(
        name,
        type,
        value,
        isMuted,
        kind,
        id,
        minValue,
        maxValue,
        stepValue,
        previousValue
    ) {
        if (root.suppressed)
            return

        root.displayName = name
        root.iconType = type
        root.targetKind = String(kind ?? "")
        root.targetId = String(id ?? "")

        root.minVolume =
            Number.isFinite(Number(minValue))
                ? Number(minValue)
                : 0

        root.maxVolume =
            Number.isFinite(Number(maxValue))
                ? Number(maxValue)
                : 1

        root.stepVolume =
            Number.isFinite(Number(stepValue))
            && Number(stepValue) > 0
                ? Number(stepValue)
                : (
                    root.targetKind === "virtual"
                        ? 0.01
                        : 0.05
                )

        root.volume = Math.max(
            root.minVolume,
            Math.min(
                root.maxVolume,
                Number(value) || 0
            )
        )

        root.muted =
            isMuted === true
            || root.volume <= root.minVolume

        const remembered =
            Number(previousValue)

        if (Number.isFinite(remembered) && remembered > root.minVolume) {
            root.previousVolume = remembered
        } else if (root.volume > root.minVolume) {
            root.previousVolume = root.volume
        }

        iconCanvas.requestPaint()

        showAnimation.stop()
        hideAnimation.stop()
        showAnimation.start()

        root.restartHideTimer()
    }

    function restartHideTimer() {
        hideTimer.stop()

        if (!root.interacting && !root.suppressed)
            hideTimer.start()
    }

    function clampVolume(value) {
        return Math.max(
            root.minVolume,
            Math.min(root.maxVolume, Number(value))
        )
    }

    function setVolume(value) {
        const safeValue =
            root.clampVolume(value)

        if (safeValue > root.minVolume)
            root.previousVolume = safeValue

        root.volume = safeValue
        root.muted =
            safeValue <= root.minVolume

        iconCanvas.requestPaint()
        root.restartHideTimer()

        if (!root.targetId)
            return

        if (root.targetKind === "virtual") {
            root.websocket.sendRpc(
                "set_volume",
                {
                    interface: root.targetId,
                    volume: safeValue
                }
            )
            return
        }

        if (root.targetKind === "physical") {
            pactlProcess.command = [
                "pactl",
                "set-sink-volume",
                root.targetId,
                Math.round(safeValue * 100) + "%"
            ]
            pactlProcess.running = true
        }
    }

    function stepVolume(direction) {
        root.setVolume(
            root.volume
            + root.stepVolume * direction
        )
    }

    function toggleMute() {
        root.restartHideTimer()

        if (!root.targetId)
            return

        if (root.targetKind === "physical") {
            pactlProcess.command = [
                "pactl",
                "set-sink-mute",
                root.targetId,
                "toggle"
            ]
            pactlProcess.running = true
            return
        }

        if (root.muted) {
            root.setVolume(
                Math.max(
                    root.previousVolume,
                    root.minVolume + root.stepVolume
                )
            )
        } else {
            root.previousVolume =
                Math.max(
                    root.volume,
                    root.minVolume + root.stepVolume
                )

            root.setVolume(root.minVolume)
        }
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
                const device = params[name]

                root.showOsd(
                    root.labelForInterface(name),
                    root.iconForInterface(name),
                    after.volume,
                    after.muted,
                    "virtual",
                    name,
                    Number(device && device.min_range ?? 0),
                    Number(device && device.max_range ?? 1),
                    Number(device && device.steps_range ?? 0.01),
                    Number(device && device.current_volume ?? after.volume)
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
                    after.muted,
                    "physical",
                    key,
                    0,
                    1,
                    0.05,
                    after.volume
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

    Connections {
        target: root.websocket

        function onJsonReceived(data) {
            root.handleMessage(data)
        }

        function onConnectionChanged(connected) {
            if (!connected) {
                root.virtualSnapshotReady = false
                root.physicalSnapshotReady = false
                root.virtualVolumes = ({})
                root.physicalVolumes = ({})
            }
        }
    }

    Process {
        id: pactlProcess
        running: false
    }

    Timer {
        id: volumeSendTimer

        interval: 120
        repeat: false

        onTriggered:
            root.setVolume(volumeSlider.value)
    }

    anchors {
        top: parent.top
        horizontalCenter: parent.horizontalCenter
        topMargin: 16
    }

    width: Math.min(410, parent.width - 24)
    height: 148

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

        ColumnLayout {
            anchors {
                fill: parent
                margins: 12
            }

            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38

                    radius: 19
                    color: Md3Theme.primary

                    Canvas {
                        id: iconCanvas

                        anchors.centerIn: parent
                        width: 24
                        height: 24

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
                                ctx.beginPath()
                                ctx.moveTo(13, 4)
                                ctx.lineTo(13, 16)
                                ctx.moveTo(13, 6)
                                ctx.lineTo(20, 4)
                                ctx.lineTo(20, 14)
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(9, 18, 3.5, 0, Math.PI * 2)
                                ctx.fill()

                                ctx.beginPath()
                                ctx.arc(17, 16, 3.5, 0, Math.PI * 2)
                                ctx.fill()
                                return
                            }

                            if (root.iconType === "tts") {
                                ctx.strokeRect(3, 5, 18, 12)

                                ctx.beginPath()
                                ctx.moveTo(8, 17)
                                ctx.lineTo(6, 21)
                                ctx.lineTo(11, 17)
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.moveTo(8, 9)
                                ctx.lineTo(8, 13)
                                ctx.moveTo(12, 8)
                                ctx.lineTo(12, 14)
                                ctx.moveTo(16, 9)
                                ctx.lineTo(16, 13)
                                ctx.stroke()
                                return
                            }

                            if (root.iconType === "alert") {
                                ctx.beginPath()
                                ctx.moveTo(6, 16)
                                ctx.lineTo(18, 16)
                                ctx.quadraticCurveTo(16, 14, 16, 10)
                                ctx.quadraticCurveTo(16, 6, 12, 6)
                                ctx.quadraticCurveTo(8, 6, 8, 10)
                                ctx.quadraticCurveTo(8, 14, 6, 16)
                                ctx.closePath()
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(12, 19, 1.4, 0, Math.PI * 2)
                                ctx.fill()
                                return
                            }

                            ctx.fillRect(2, 8, 5, 6)

                            ctx.beginPath()
                            ctx.moveTo(7, 8)
                            ctx.lineTo(12, 5)
                            ctx.lineTo(12, 17)
                            ctx.lineTo(7, 14)
                            ctx.closePath()
                            ctx.fill()

                            if (root.muted) {
                                ctx.beginPath()
                                ctx.moveTo(15, 8)
                                ctx.lineTo(21, 15)
                                ctx.moveTo(21, 8)
                                ctx.lineTo(15, 15)
                                ctx.stroke()
                            } else {
                                ctx.beginPath()
                                ctx.arc(12, 11, 4, -0.75, 0.75)
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(12, 11, 7, -0.7, 0.7)
                                ctx.stroke()
                            }
                        }

                        Component.onCompleted:
                            requestPaint()
                    }
                }

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

                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
            }

            Md3Slider {
                id: volumeSlider

                Layout.fillWidth: true
                Layout.preferredHeight: 28

                from: root.minVolume
                to: root.maxVolume
                stepSize: root.stepVolume

                value: root.volume
                enabled: !root.muted

                onMoved: {
                    root.volume = value
                    root.muted =
                        value <= root.minVolume

                    volumeSendTimer.restart()
                    root.restartHideTimer()
                }

                onPressedChanged: {
                    root.interacting = pressed

                    if (pressed) {
                        hideTimer.stop()
                        return
                    }

                    volumeSendTimer.stop()
                    root.setVolume(value)
                    root.restartHideTimer()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                AudioControlButton {
                    icon: "minus"
                    enabled: !root.muted

                    onClicked: {
                        root.stepVolume(-1)
                        root.restartHideTimer()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 128
                    Layout.preferredHeight: 34

                    radius: 17

                    color:
                        root.muted
                            ? Md3Theme.primary
                            : muteTap.pressed
                                ? Md3Theme.surfaceContainerHigh
                                : Md3Theme.surfaceContainerHighest

                    border.width:
                        root.muted
                            ? 0
                            : 1

                    border.color:
                        Md3Theme.outlineVariant

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MdiIcon {
                            name:
                                root.muted
                                    ? "volume-off"
                                    : "volume-high"

                            size: 17
                            selected: root.muted
                        }

                        Text {
                            text:
                                root.muted
                                    ? "Mute"
                                    : root.percent + "%"

                            color:
                                root.muted
                                    ? Md3Theme.primaryContent
                                    : Md3Theme.surfaceContent

                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    TapHandler {
                        id: muteTap

                        onTapped: {
                            root.toggleMute()
                            root.restartHideTimer()
                        }
                    }
                }

                AudioControlButton {
                    icon: "plus"
                    enabled: !root.muted

                    onClicked: {
                        root.stepVolume(1)
                        root.restartHideTimer()
                    }
                }
            }
        }
    }

    Timer {
        id: hideTimer

        interval: 5000
        repeat: false

        onTriggered: {
            if (root.interacting) {
                restart()
                return
            }

            hideAnimation.start()
        }
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
