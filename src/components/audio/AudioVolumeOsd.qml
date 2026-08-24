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
    property bool shown: false

    readonly property int percent:
        Math.round(
            Math.max(
                0,
                Math.min(1, root.volume)
            ) * 100
        )

    readonly property real volumeFraction:
        root.maxVolume > root.minVolume
            ? Math.max(
                0,
                Math.min(
                    1,
                    (root.volume - root.minVolume)
                    / (root.maxVolume - root.minVolume)
                )
            )
            : 0

    anchors.fill: parent

    visible: root.shown && !root.suppressed
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
            return "bell-outline"

        if (normalized === "tts")
            return "account-voice"

        if (normalized === "music")
            return "music"

        return "speaker"
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

        const sameTarget =
            root.targetKind === String(kind ?? "")
            && root.targetId === String(id ?? "")

        if (!root.interacting || !sameTarget) {
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
        }

        const remembered =
            Number(previousValue)

        if (Number.isFinite(remembered) && remembered > root.minVolume) {
            root.previousVolume = remembered
        } else if (root.volume > root.minVolume) {
            root.previousVolume = root.volume
        }


        root.shown = true
        root.restartHideTimer()
    }

    function restartHideTimer() {
        hideTimer.stop()

        if (!root.interacting && !root.suppressed)
            hideTimer.start()
    }

    function dismiss() {
        hideTimer.stop()
        volumeSendTimer.stop()
        root.interacting = false
        root.shown = false
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
            root.muted = !root.muted

            pactlProcess.command = [
                "pactl",
                "set-sink-mute",
                root.targetId,
                "toggle"
            ]
            pactlProcess.running = true
            root.restartHideTimer()
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
                    Number((device && device.min_range) ?? 0),
                    Number((device && device.max_range) ?? 1),
                    Number((device && device.steps_range) ?? 0.01),
                    Number((device && device.current_volume) ?? after.volume)
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
            root.shown = false
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

        interval: 90
        repeat: false

        onTriggered:
            root.setVolume(root.volume)
    }

    // Full-screen transparent backdrop. Tapping anywhere outside the rail
    // dismisses the OSD and consumes the tap.
    MouseArea {
        anchors.fill: parent
        z: 0
        enabled: root.visible

        onClicked:
            root.dismiss()
    }

    Item {
        id: osdContainer
        z: 1

        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 12
        }

        width:
            root.targetKind === "physical"
                ? Math.min(190, parent.width - 20)
                : 76

        height:
            root.targetKind === "physical"
                ? 250
                : 218

        // Consume empty-space taps inside the OSD itself.
        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: rail

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }

            width: 68
            height: 214
            radius: 34

            color: Md3Theme.surfaceContainerHigh

            border.width: 1
            border.color: Md3Theme.outlineVariant

            Column {
                anchors {
                    fill: parent
                    topMargin: 8
                    bottomMargin: 8
                }

                spacing: 7

                Rectangle {
                    id: muteButton

                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 42
                    height: 42
                    radius: 21

                    color:
                        muteTap.pressed
                            ? Md3Theme.primaryContainer
                            : (
                                root.muted
                                    ? Md3Theme.primary
                                    : Md3Theme.surfaceContainerHighest
                            )

                    MdiIcon {
                        anchors.centerIn: parent

                        name:
                            root.muted
                                ? "volume-off"
                                : root.iconType

                        size: 23
                    }

                    TapHandler {
                        id: muteTap

                        onTapped: {
                            root.toggleMute()
                            root.restartHideTimer()
                        }
                    }
                }

                Item {
                    id: verticalSlider

                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 42
                    height: 126

                    Rectangle {
                        id: sliderTrack

                        anchors.centerIn: parent

                        width: 28
                        height: 118
                        radius: 14

                        color: Md3Theme.surfaceContainerHighest

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }

                            height:
                                root.muted
                                    ? 0
                                    : parent.height
                                      * root.volumeFraction

                            radius: 14
                            color: Md3Theme.primary

                            Behavior on height {
                                enabled: !root.interacting

                                NumberAnimation {
                                    duration: 80
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter

                            y:
                                parent.height
                                - (root.muted
                                    ? 0
                                    : parent.height
                                      * root.volumeFraction)
                                - height / 2

                            width: 20
                            height: 20
                            radius: 10

                            color: Md3Theme.primaryContent
                            border.width: 3
                            border.color: Md3Theme.primary

                            visible: !root.muted
                        }
                    }

                    MouseArea {
                        anchors.fill: parent

                        function updateVolume(mouseY) {
                            const trackTop =
                                sliderTrack.y

                            const localY =
                                Math.max(
                                    0,
                                    Math.min(
                                        sliderTrack.height,
                                        mouseY - trackTop
                                    )
                                )

                            const fraction =
                                1
                                - localY
                                  / sliderTrack.height

                            const raw =
                                root.minVolume
                                + fraction
                                  * (
                                      root.maxVolume
                                      - root.minVolume
                                  )

                            const step =
                                Math.max(
                                    0.001,
                                    root.stepVolume
                                )

                            root.volume =
                                root.clampVolume(
                                    Math.round(raw / step)
                                    * step
                                )

                            root.muted =
                                root.volume
                                <= root.minVolume

                            volumeSendTimer.restart()
                        }

                        onPressed: mouse => {
                            root.interacting = true
                            hideTimer.stop()
                            updateVolume(mouse.y)
                        }

                        onPositionChanged: mouse => {
                            if (pressed)
                                updateVolume(mouse.y)
                        }

                        onReleased: {
                            volumeSendTimer.stop()
                            root.setVolume(root.volume)
                            root.interacting = false
                            root.restartHideTimer()
                        }

                        onCanceled: {
                            root.interacting = false
                            root.restartHideTimer()
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text:
                        root.muted
                            ? "0%"
                            : root.percent + "%"

                    color: Md3Theme.surfaceContent

                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        Rectangle {
            visible: root.targetKind === "physical"

            anchors {
                top: rail.bottom
                horizontalCenter: parent.horizontalCenter
                topMargin: 6
            }

            width:
                Math.min(
                    parent.width,
                    Math.max(
                        88,
                        physicalLabel.implicitWidth + 20
                    )
                )

            height: 26
            radius: 13

            color: Md3Theme.surfaceContainerHigh

            border.width: 1
            border.color: Md3Theme.outlineVariant

            Text {
                id: physicalLabel

                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }

                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter

                text: root.displayName
                color: Md3Theme.surfaceVariantContent

                font.pixelSize: 10
                font.weight: Font.Medium

                elide: Text.ElideMiddle
            }
        }
    }

    Timer {
        id: hideTimer

        interval: 4500
        repeat: false

        onTriggered: {
            if (root.interacting) {
                restart()
                return
            }

            root.dismiss()
        }
    }
}
