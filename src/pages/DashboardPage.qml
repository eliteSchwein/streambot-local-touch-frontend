import QtQuick
import QtQuick.Layouts

import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var store

    function musicAction(action) {
        websocket.sendRpc(
            "music_" + String(action).replace(/-/g, "_"),
            {}
        )
    }

    function toggleSongRequests() {
        websocket.sendRpc(
            "music_songrequest_toggle",
            {}
        )
    }

    readonly property var music: store.music ?? ({})
    readonly property bool playing: music.status === "playing"

    GridLayout {
        anchors.fill: parent
        anchors.margins: 10

        columns: 12
        rows: 2

        columnSpacing: 8
        rowSpacing: 8

        // ----------------------------------------------------------
        // MUSIC - design based on old Tauri MusicControls.vue
        // ----------------------------------------------------------
        Md3Card {
            Layout.columnSpan: 7
            Layout.rowSpan: 1
            Layout.fillWidth: true
            Layout.fillHeight: true

            title: ""

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true

                            text:
                                root.music.title
                                || root.i18n.text("no_song")

                            color: Md3Theme.surfaceContent

                            font.pixelSize: 15
                            font.weight: Font.DemiBold

                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true

                            text:
                                root.music.artist
                                || root.i18n.text("unknown_artist")

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 10

                            elide: Text.ElideRight
                        }
                    }

                    RowLayout {
                        spacing: 4

                        Text {
                            text: root.i18n.text("song_requests")
                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 9
                        }

                        Md3Switch {
                            checked:
                                root.music.songrequest
                                && root.music.songrequest.enabled === true

                            onClicked: root.toggleSongRequests()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        // Five CAVA bars at the left, matching old control.
                        Item {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 38

                            Row {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 2

                                Repeater {
                                    model: 5

                                    Rectangle {
                                        required property int index

                                        width: 4
                                        height:
                                            Math.max(
                                                3,
                                                (parent.height)
                                                * Number(root.store.cava[index] ?? 0)
                                                / 100
                                            )

                                        anchors.bottom: parent.bottom

                                        radius: 2
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
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

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
                                    Math.min(
                                        100,
                                        Number(root.music.progress_percentage ?? 0)
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
                            text: root.store.formatTime(root.music.position)
                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 9
                        }

                        Text {
                            text: root.store.formatTime(root.music.duration)
                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------------
        // AUTO MACROS
        // ----------------------------------------------------------
        Md3Card {
            Layout.columnSpan: 5
            Layout.rowSpan: 1
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
                    font.pixelSize: 11
                }

                ListView {
                    id: macroList

                    anchors.fill: parent
                    clip: true
                    spacing: 4

                    visible: root.store.autoMacros.length > 0

                    model: root.store.autoMacros

                    delegate: Rectangle {
                        required property var modelData

                        width: macroList.width
                        height: 36

                        radius: Md3Theme.radiusMedium
                        color: Md3Theme.surfaceContainerHighest

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 6

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true

                                    text: modelData.name
                                    color: Md3Theme.surfaceContent

                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold

                                    elide: Text.ElideRight
                                }

                                Text {
                                    text:
                                        root.store.formatCountdown(
                                            modelData.current_interval
                                        )

                                    color:
                                        Md3Theme.surfaceVariantContent

                                    font.pixelSize: 8
                                }
                            }

                            // State only until exact backend RPC name is added.
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
                    }
                }
            }
        }

        // ----------------------------------------------------------
        // AUDIO
        // ----------------------------------------------------------
        Md3Card {
            Layout.columnSpan: 4
            Layout.rowSpan: 1
            Layout.fillWidth: true
            Layout.fillHeight: true

            title: root.i18n.text("audio")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: [
                        {
                            key: "music",
                            label: root.i18n.text("music_volume")
                        },
                        {
                            key: "tts",
                            label: root.i18n.text("tts_volume")
                        },
                        {
                            key: "alert",
                            label: root.i18n.text("alert_volume")
                        }
                    ]

                    RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            Layout.preferredWidth: 40

                            text: modelData.label
                            color: Md3Theme.surfaceContent
                            font.pixelSize: 9
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
                                        Math.min(
                                            1,
                                            Number(
                                                root.store.audio[modelData.key]
                                                ? root.store.audio[modelData.key].current_volume
                                                : 0
                                            )
                                        )
                                    )

                                height: parent.height
                                radius: parent.radius
                                color: Md3Theme.primary
                            }
                        }

                        Text {
                            Layout.preferredWidth: 28

                            text:
                                Math.round(
                                    Number(
                                        root.store.audio[modelData.key]
                                        ? root.store.audio[modelData.key].current_volume
                                        : 0
                                    )
                                    * 100
                                )
                                + "%"

                            color: Md3Theme.surfaceVariantContent
                            font.pixelSize: 8
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------------
        // ROTATE SCENE
        // ----------------------------------------------------------
        Md3Card {
            Layout.columnSpan: 4
            Layout.rowSpan: 1
            Layout.fillWidth: true
            Layout.fillHeight: true

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
                    clip: true
                    spacing: 4

                    visible: parent.rotations.length > 0
                    model: parent.rotations

                    delegate: Rectangle {
                        required property var modelData

                        width: rotationList.width
                        height: 34
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
                                text:
                                    Number(modelData.interval ?? 0)
                                    + "s"

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

        // ----------------------------------------------------------
        // ALERTS
        // ----------------------------------------------------------
        Md3Card {
            Layout.columnSpan: 4
            Layout.rowSpan: 1
            Layout.fillWidth: true
            Layout.fillHeight: true

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
                    Layout.preferredHeight: 42

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
                        Layout.preferredHeight: 30

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
    }
}
