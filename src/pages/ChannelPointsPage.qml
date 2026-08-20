import QtQuick

import "../components/channelpoints"
import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var store

    function sortedPoints() {
        const result = Array.from(
            store.channelPoints ?? []
        )

        result.sort(
            (a, b) =>
                String(
                    a.label
                    ?? a.name
                    ?? ""
                ).localeCompare(
                    String(
                        b.label
                        ?? b.name
                        ?? ""
                    )
                )
        )

        return result
    }

    readonly property var points:
        sortedPoints()

    Text {
        anchors.centerIn: parent

        visible:
            root.points.length === 0

        text:
            root.i18n.text(
                "channel_points_empty"
            )

        color:
            Md3Theme.surfaceVariantContent

        font.pixelSize: 14
        font.weight: Font.Medium
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.margins: 10

        visible:
            root.points.length > 0

        clip: true
        spacing: 6

        model:
            root.points

        delegate: ChannelPointToggleRow {
            required property var modelData

            width: list.width

            channelPoint:
                modelData

            websocket:
                root.websocket

            i18n:
                root.i18n
        }
    }
}
