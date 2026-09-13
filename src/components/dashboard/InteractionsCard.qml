import QtQuick
import QtQuick.Layouts

import "../md3"

Md3Card {
    id: root

    required property var i18n
    required property var store
    required property var websocket
    backgroundOpacity: 0.88

    function sourceLabel(source) {
        switch (String(source ?? "other")) {
        case "command":
            return root.i18n.text("interaction_source_command")
        case "event":
            return root.i18n.text("interaction_source_event")
        case "channel_point":
            return root.i18n.text("interaction_source_channel_point")
        case "api":
            return root.i18n.text("interaction_source_api")
        default:
            return root.i18n.text("interaction_source_other")
        }
    }

    function stateLabel(state) {
        switch (String(state ?? "queued")) {
        case "active":
            return root.i18n.text("interaction_state_active")
        case "finished":
            return root.i18n.text("interaction_state_finished")
        case "cancelled":
            return root.i18n.text("interaction_state_cancelled")
        case "failed":
            return root.i18n.text("interaction_state_failed")
        default:
            return root.i18n.text("interaction_state_queued")
        }
    }

    function formatSeconds(value) {
        const seconds = Math.max(0, Math.ceil(Number(value) || 0))
        const minutes = Math.floor(seconds / 60)
        const remaining = seconds % 60

        if (minutes > 0)
            return minutes + ":" + (remaining < 10 ? "0" : "") + remaining

        return seconds + "s"
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            visible: root.store.interactions.length === 0

            text: root.i18n.text("no_interactions")
            color: Md3Theme.surfaceVariantContent
            font.pixelSize: 13
        }

        ListView {
            id: interactionList

            anchors.fill: parent
            clip: true
            spacing: 5

            model: root.store.interactions

            delegate: Rectangle {
                id: interactionRow

                required property var modelData

                width: interactionList.width
                height: 58

                radius: Md3Theme.radiusMedium

                color:
                    modelData.state === "active"
                    ? Md3Theme.surfaceContainerHigh
                    : Md3Theme.surfaceContainerHighest

                Rectangle {
                    visible:
                        interactionRow.modelData.state === "active"
                        && Number(interactionRow.modelData.duration) > 0

                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    height: 3
                    radius: 2

                    width: {
                        const duration = Number(interactionRow.modelData.duration) || 0
                        const remaining = Number(interactionRow.modelData.eta_seconds) || 0

                        if (duration <= 0)
                            return 0

                        const progress = Math.max(
                            0,
                            Math.min(1, (duration - remaining) / duration)
                        )

                        return parent.width * progress
                    }

                    color: Md3Theme.success

                    Behavior on width {
                        NumberAnimation {
                            duration: 900
                            easing.type: Easing.Linear
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        width: 8
                        height: 8
                        radius: 4

                        color:
                            interactionRow.modelData.state === "active"
                            ? Md3Theme.success
                            : interactionRow.modelData.state === "failed"
                                ? Md3Theme.error
                                : Md3Theme.outline
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true

                            text:
                                interactionRow.modelData.name
                                || root.i18n.text("interaction")

                            color: Md3Theme.surfaceContent
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true

                            text: {
                                const parts = [
                                    root.sourceLabel(interactionRow.modelData.source),
                                    root.stateLabel(interactionRow.modelData.state)
                                ]

                                const eta = Number(interactionRow.modelData.eta_seconds) || 0
                                if (eta > 0)
                                    parts.push(root.i18n.text("interaction_eta") + " " + root.formatSeconds(eta))

                                const alerts = Number(interactionRow.modelData.alert_count) || 0
                                if (alerts > 0)
                                    parts.push(root.i18n.text("interaction_alerts") + " " + alerts)

                                return parts.join(" · ")
                            }

                            color:
                                interactionRow.modelData.state === "failed"
                                ? Md3Theme.error
                                : Md3Theme.surfaceVariantContent

                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true

                            text: String(interactionRow.modelData.uuid ?? "")
                            visible: text !== ""

                            color: Md3Theme.outline
                            font.pixelSize: 7
                            elide: Text.ElideMiddle
                        }
                    }

                    Md3IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        icon: "×"

                        onClicked: {
                            root.websocket.sendRpc(
                                "remove_interaction",
                                {
                                    uuid: interactionRow.modelData.uuid
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}
