import QtQuick
import QtQuick.Layouts

import "../md3"

Rectangle {
    id: root

    required property var i18n
    required property var websocket
    required property var store

    radius: Md3Theme.radiusLarge
    color: Md3Theme.surfaceContainer

    border.width: 1
    border.color: Md3Theme.outlineVariant

    readonly property var music:
        store.music ?? ({})

    readonly property bool playing:
        music.status === "playing"

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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18

        spacing: 10

        // Title / artist
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

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true

                text:
                    root.music.artist
                    || root.i18n.text("unknown_artist")

                color: Md3Theme.surfaceVariantContent
                font.pixelSize: 12

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        // CAVA
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 90

            Row {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                }

                height: Math.min(110, parent.height)
                spacing: 9

                Repeater {
                    model: 5

                    Rectangle {
                        required property int index

                        width: 14

                        height:
                            Math.max(
                                6,
                                parent.height
                                * Number(
                                    root.store.cava[index] ?? 0
                                )
                                / 100
                            )

                        anchors.bottom: parent.bottom

                        radius: 7
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

        // Transport controls
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 58

            RowLayout {
                anchors.centerIn: parent
                spacing: 12

                Md3IconButton {
                    icon: "⤨"
                    selected: root.music.shuffle === true

                    onClicked:
                        root.musicAction("shuffle")
                }

                Md3IconButton {
                    icon: "◀"

                    onClicked:
                        root.musicAction("back")
                }

                Md3IconButton {
                    icon:
                        root.playing
                        ? "Ⅱ"
                        : "▶"

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

                    onClicked:
                        root.musicAction("next")
                }

                Md3IconButton {
                    icon: "↻"

                    selected:
                        root.music.loop === true
                        || root.music.loop_file === true

                    onClicked:
                        root.musicAction("loop")
                }
            }
        }

        // Music progress
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 7

                radius: 4
                color: Md3Theme.surfaceContainerHighest

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }

                    width:
                        parent.width
                        * Math.max(
                            0,
                            Math.min(
                                100,
                                Number(
                                    root.music.progress_percentage
                                    ?? 0
                                )
                            )
                        )
                        / 100

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

                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text:
                        root.store.formatTime(
                            root.music.duration
                        )

                    color: Md3Theme.surfaceVariantContent
                    font.pixelSize: 10

                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Song requests
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: root.i18n.text("song_requests")
                    color: Md3Theme.surfaceVariantContent
                    font.pixelSize: 10

                    verticalAlignment: Text.AlignVCenter
                }

                Md3Switch {
                    checked:
                        root.music.songrequest
                        && root.music.songrequest.enabled === true

                    onClicked:
                        root.toggleSongRequests()
                }
            }
        }
    }
}
