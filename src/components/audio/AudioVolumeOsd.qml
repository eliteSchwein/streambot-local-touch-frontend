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
            return "alert-circle-outline"

        if (normalized === "tts")
            return "message-text-outline"

        if (normalized === "music")
            return "music"

        return "volume-high"
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
        interval: 100
        repeat: false

        onTriggered:
            root.setVolume(volumeSlider.value)
    }

    // Transparent full-screen dismiss layer. This exists only while the OSD
    // is visible and prevents clicks from leaking to the UI below.
    MouseArea {
        anchors.fill: parent
        z: 0

        enabled: root.visible

        onClicked:
            root.dismiss()
    }

    Rectangle {
        id: card

        z: 1

        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 14
        }

        width: Math.min(340, parent.width - 20)
        height:
            root.targetKind === "physical"
                ? 82
                : 64

        radius: 24
        color: Md3Theme.surfaceContainerHigh

        border.width: 1
        border.color: Md3Theme.outlineVariant

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 12
                topMargin: 9
                bottomMargin: 9
            }

            spacing: 4

            Text {
                visible: root.targetKind === "physical"

                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 16 : 0

                text: root.displayName
                color: Md3Theme.surfaceVariantContent

                font.pixelSize: 11
                font.weight: Font.Medium

                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34

                    radius: 17

                    color:
                        muteTap.pressed
                            ? Md3Theme.primaryContainer
                            : Md3Theme.surfaceContainerHighest

                    MdiIcon {
                        anchors.centerIn: parent

                        name:
                            root.muted
                                ? "volume-off"
                                : root.iconType

                        size: 18
                    }

                    TapHandler {
                        id: muteTap

                        onTapped: {
                            root.toggleMute()
                            root.restartHideTimer()
                        }
                    }
                }

                Md3Slider {
                    id: volumeSlider

                    Layout.fillWidth: true
                    Layout.preferredHeight: 30

                    from: root.minVolume
                    to: root.maxVolume
                    stepSize: root.stepVolume

                    value: root.volume
                    enabled: true

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

                Text {
                    Layout.preferredWidth: 42

                    horizontalAlignment: Text.AlignRight

                    text: root.percent + "%"
                    color: Md3Theme.surfaceContent

                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
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
