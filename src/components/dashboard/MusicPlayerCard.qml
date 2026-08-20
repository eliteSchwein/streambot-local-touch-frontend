import QtQuick
import QtQuick.Layouts

import "../md3"

Md3Card {
    id: root

    required property var i18n
    required property var websocket
    required property var store

    title: ""

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

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }

            width: Math.min(parent.width, 430)
            spacing: 12

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
                    elide: Text.ElideRight
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 92

                Row {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                    }

                    height: parent.height
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
                                    * Number(
                                        root.store.cava[index] ?? 0
                                    )
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
