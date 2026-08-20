import QtQuick
import QtQuick.Layouts

import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var store

    readonly property var music: store.music ?? ({})
    readonly property bool playing: music.status === "playing"

    function musicAction(action) {
        websocket.sendRpc(
            "music_" + String(action).replace(/-/g, "_"),
            {}
        )
    }

    function toggleSongRequests() {
        websocket.sendRpc("music_songrequest_toggle", {})
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // LEFT COLUMN
        ColumnLayout {
            Layout.preferredWidth: parent.width * 0.40
            Layout.fillHeight: true
            spacing: 8

            // ALERTS
            Md3Card {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height * 0.27

                title:
                    root.i18n.text("alerts")
                    + (
                        root.store.alertQueue.length > 0
                        ? " · " + root.store.alertQueue.length
                        : ""
                    )

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        visible:
                            root.store.activeAlert === null
                            && root.store.alertQueue.length === 0

                        text: root.i18n.text("no_alerts")
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 10
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        visible: root.store.activeAlert !== null

                        radius: Md3Theme.radiusMedium
                        color: Md3Theme.surfaceContainerHigh

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 0

                            Text {
                                text: root.i18n.text("active")
                                color: Md3Theme.primary
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true

                                text:
                                    root.store.activeAlert
                                    ? (
                                        root.store.activeAlert.message
                                        || root.store.activeAlert.channel
                                        || "Alert"
                                    )
                                    : ""

                                color: Md3Theme.surfaceContent
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Repeater {
                        model: Math.min(2, root.store.alertQueue.length)

                        Rectangle {
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: 27
                            radius: Md3Theme.radiusMedium
                            color: Md3Theme.surfaceContainerHighest

                            Text {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                anchors.leftMargin: 7
                                anchors.rightMargin: 7

                                text:
                                    root.store.alertQueue[index].message
                                    || root.store.alertQueue[index].channel
                                    || "Alert"

                                color: Md3Theme.surfaceContent
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // AUTO MACROS
            Md3Card {
                Layout.fillWidth: true
                Layout.fillHeight: true

                title: root.i18n.text("auto_macros")

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: root.store.autoMacros.length === 0

                        text: root.i18n.text("no_auto_macros")
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 10
                    }

                    ListView {
                        id: macroList
                        anchors.fill: parent
                        visible: root.store.autoMacros.length > 0
                        clip: true
                        spacing: 5
                        model: root.store.autoMacros

                        delegate: Rectangle {
                            required property var modelData

                            width: macroList.width
                            height: 48
                            radius: Md3Theme.radiusMedium
                            color: Md3Theme.surfaceContainerHighest

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 7
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: Md3Theme.surfaceContent
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text:
                                            root.store.formatCountdown(
                                                modelData.current_interval
                                            )

                                        color: Md3Theme.surfaceVariantContent
                                        font.pixelSize: 8
                                    }

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4

                                        color:
                                            modelData.enabled
                                            ? Md3Theme.success
                                            : Md3Theme.outline
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 5

                                    radius: 3
                                    color: Md3Theme.surfaceContainerHigh

                                    Rectangle {
                                        height: parent.height
                                        radius: parent.radius
                                        color:
                                            modelData.enabled
                                            ? Md3Theme.primary
                                            : Md3Theme.outline

                                        width: {
                                            const interval =
                                                Math.max(
                                                    1,
                                                    Number(modelData.interval ?? 1)
                                                )

                                            const remaining =
                                                Math.max(
                                                    0,
                                                    Math.min(
                                                        interval,
                                                        Number(
                                                            modelData.current_interval
                                                            ?? interval
                                                        )
                                                    )
                                                )

                                            return parent.width
                                                * (
                                                    1
                                                    - remaining / interval
                                                )
                                        }

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 180
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ROTATE SCENE
            Md3Card {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height * 0.27

                title: root.i18n.text("rotate_scene")

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    property var rotations: root.store.rotationList()

                    Text {
                        anchors.centerIn: parent
                        visible: parent.rotations.length === 0

                        text: root.i18n.text("no_rotations")
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 10
                    }

                    ListView {
                        id: rotationList
                        anchors.fill: parent
                        visible: parent.rotations.length > 0
                        clip: true
                        spacing: 4
                        model: parent.rotations

                        delegate: Rectangle {
                            required property var modelData

                            width: rotationList.width
                            height: 32
                            radius: Md3Theme.radiusMedium

                            color:
                                root.store.rotatingRuntime.active === true
                                && root.store.rotatingRuntime.name === modelData.name
                                ? Md3Theme.surfaceContainerHigh
                                : Md3Theme.surfaceContainerHighest

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 7

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: Md3Theme.surfaceContent
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: Number(modelData.interval ?? 0) + "s"
                                    color: Md3Theme.surfaceVariantContent
                                    font.pixelSize: 8
                                }

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4

                                    color:
                                        root.store.rotatingRuntime.active === true
                                        && root.store.rotatingRuntime.name === modelData.name
                                        ? Md3Theme.success
                                        : Md3Theme.outline
                                }
                            }
                        }
                    }
                }
            }
        }

        // RIGHT: MEDIA PLAYER ONLY
        Md3Card {
            Layout.fillWidth: true
            Layout.fillHeight: true

            title: ""

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // Track header
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true

                        text:
                            root.music.title
                            || root.i18n.text("no_song")

                        color: Md3Theme.surfaceContent
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.fillWidth: true

                        text:
                            root.music.artist
                            || root.i18n.text("unknown_artist")

                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // CAVA visualizer from websocket notify_music_cava
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Row {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                        }

                        height: Math.min(95, parent.height)
                        spacing: 8

                        Repeater {
                            model: 5

                            Rectangle {
                                required property int index

                                width: 12
                                height:
                                    Math.max(
                                        5,
                                        parent.height
                                        * Number(root.store.cava[index] ?? 0)
                                        / 100
                                    )

                                anchors.bottom: parent.bottom

                                radius: 6
                                color: Md3Theme.primary

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 28
                                    }
                                }
                            }
                        }
                    }
                }

                // Controls
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    Md3IconButton {
                        icon: "⤨"
                        selected: root.music.shuffle === true
                        onClicked: root.musicAction("shuffle")
                    }

                    Md3IconButton {
                        icon: "◀"
                        onClicked: root.musicAction("back")
                    }

                    Md3IconButton {
                        icon: root.playing ? "Ⅱ" : "▶"
                        filled: true

                        onClicked: {
                            root.musicAction(
                                root.playing
                                ? "pause"
                                : "play"
                            )
                        }
                    }

                    Md3IconButton {
                        icon: "▶"
                        onClicked: root.musicAction("next")
                    }

                    Md3IconButton {
                        icon: "↻"

                        selected:
                            root.music.loop === true
                            || root.music.loop_file === true

                        onClicked: root.musicAction("loop")
                    }
                }

                // Progress
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 7
                        radius: 4
                        color: Md3Theme.surfaceContainerHighest

                        Rectangle {
                            width:
                                parent.width
                                * Math.max(
                                    0,
                                    Math.min(
                                        100,
                                        Number(
                                            root.music.progress_percentage ?? 0
                                        )
                                    )
                                )
                                / 100

                            height: parent.height
                            radius: parent.radius
                            color: Md3Theme.primary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true

                            text:
                                root.store.formatTime(
                                    root.music.position
                                )

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 10
                        }

                        Text {
                            text:
                                root.store.formatTime(
                                    root.music.duration
                                )

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 10
                        }
                    }
                }

                // Song requests
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Text {
                        text: root.i18n.text("song_requests")
                        color: Md3Theme.surfaceVariantContent
                        font.pixelSize: 10
                    }

                    Md3Switch {
                        checked:
                            root.music.songrequest
                            && root.music.songrequest.enabled === true

                        onClicked: root.toggleSongRequests()
                    }
                }
            }
        }
    }
}
