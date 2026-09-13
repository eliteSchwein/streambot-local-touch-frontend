import QtQuick
import QtQuick.Layouts

import "../components/channelpoints"
import "../components/md3"

Item {
    id: root

    required property var i18n
    required property var websocket
    required property var store

    property string searchQuery: ""

    function sortedPoints() {
        const result = Array.from(
            store.channelPoints ?? []
        )

        const query =
            String(searchQuery)
                .trim()
                .toLowerCase()

        const filtered = result.filter(point => {
            if (query === "")
                return true

            const values = [
                point?.label,
                point?.name,
                point?.twitch_label,
                point?.twitch_name
            ]

            return values.some(value =>
                String(value ?? "")
                    .toLowerCase()
                    .includes(query)
            )
        })

        filtered.sort(
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

        return filtered
    }

    readonly property var points:
        sortedPoints()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10

        spacing: 8

        Md3TextField {
            id: searchField

            Layout.fillWidth: true
            Layout.preferredHeight: 44

            placeholderText:
                root.i18n.text(
                    "channel_points_search"
                )

            text: root.searchQuery

            backgroundColor: Qt.rgba(
                Md3Theme.surfaceContainerHighest.r,
                Md3Theme.surfaceContainerHighest.g,
                Md3Theme.surfaceContainerHighest.b,
                0.94
            )

            onTextChanged:
                root.searchQuery = text
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent

                visible:
                    root.points.length === 0

                text:
                    root.searchQuery.trim() !== ""
                    ? root.i18n.text(
                        "channel_points_no_results"
                    )
                    : root.i18n.text(
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
    }
}
