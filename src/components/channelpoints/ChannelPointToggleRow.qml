import QtQuick
import QtQuick.Layouts

import "../md3"

Rectangle {
    id: root

    required property var channelPoint
    required property var websocket
    required property var i18n

    property bool localActive:
        channelPoint.active === true

    property bool pending: false
    property int requestId: -1

    readonly property string displayName:
        String(
            channelPoint.label
            ?? channelPoint.name
            ?? channelPoint.twitch_label
            ?? channelPoint.twitch_name
            ?? "Channel Point"
        )

    readonly property string subtitle:
        String(
            channelPoint.twitch_label
            ?? channelPoint.twitch_name
            ?? ""
        )

    implicitHeight: 58

    radius: Md3Theme.radiusMedium
    color: Md3Theme.surfaceContainer

    border.width: 1
    border.color: Md3Theme.outlineVariant

    function toggle() {
        if (
            pending
            || !websocket.connected
        ) {
            return
        }

        pending = true
        localActive = !localActive

        requestId = websocket.sendRpc(
            "toggle_channel_point",
            {
                state: "toggle",
                channel_point: channelPoint
            }
        )

        if (requestId < 0) {
            localActive = !localActive
            pending = false
            requestId = -1
            return
        }

        responseTimeout.restart()
    }

    onChannelPointChanged: {
        // The websocket notification is the source of truth.
        localActive =
            channelPoint.active === true
    }

    Connections {
        target: root.websocket

        function onRpcResponse(id, data) {
            if (
                root.requestId < 0
                || id !== root.requestId
            ) {
                return
            }

            responseTimeout.stop()
            root.requestId = -1

            const failed =
                data
                && (
                    data.error !== undefined
                    || (
                        data.result
                        && typeof data.result === "object"
                        && data.result.success === false
                    )
                )

            if (failed) {
                root.localActive =
                    !root.localActive
            }

            root.pending = false
        }
    }

    Timer {
        id: responseTimeout

        interval: 10000
        repeat: false

        onTriggered: {
            root.localActive =
                !root.localActive

            root.requestId = -1
            root.pending = false
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12

        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            spacing: 1

            Text {
                Layout.fillWidth: true

                text: root.displayName
                color: Md3Theme.surfaceContent

                font.pixelSize: 13
                font.weight: Font.DemiBold

                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                Layout.fillWidth: true

                visible:
                    root.subtitle !== ""
                    && root.subtitle !== root.displayName

                text: root.subtitle

                color:
                    Md3Theme.surfaceVariantContent

                font.pixelSize: 8

                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        Md3Switch {
            Layout.alignment: Qt.AlignVCenter

            checked: root.localActive
            animated: !root.pending

            onClicked:
                root.toggle()
        }
    }
}
