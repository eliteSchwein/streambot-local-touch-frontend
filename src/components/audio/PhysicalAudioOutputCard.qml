import QtQuick
import QtQuick.Layouts

import "../md3"

Rectangle {
    id: root

    required property var output

    implicitHeight: 72

    radius: Md3Theme.radiusLarge
    color: Md3Theme.surfaceContainer

    border.width: 1
    border.color: Md3Theme.outlineVariant

    function label() {
        return String(
            output.description
            ?? output.name
            ?? output.id
            ?? "Output"
        )
    }

    function stateText() {
        const state =
            String(output.state ?? "")
                .toUpperCase()

        if (state === "RUNNING")
            return "RUNNING"

        if (state === "SUSPENDED")
            return "SUSPENDED"

        if (state === "IDLE")
            return "IDLE"

        return state
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Text {
                    Layout.fillWidth: true

                    text: root.label()
                    color: Md3Theme.surfaceContent

                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    visible:
                        root.output.is_default === true
                        || root.output.default === true

                    text: "★"
                    color: Md3Theme.primary
                    font.pixelSize: 10
                }
            }

            Text {
                Layout.fillWidth: true

                text:
                    String(root.output.name ?? "")

                color: Md3Theme.surfaceVariantContent
                font.pixelSize: 8
                elide: Text.ElideRight
            }

            Text {
                text:
                    root.stateText()

                color:
                    root.output.active === true
                    ? Md3Theme.primary
                    : Md3Theme.surfaceVariantContent

                font.pixelSize: 8
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter

            text:
                root.output.volume === null
                || root.output.volume === undefined
                ? "—"
                : Math.round(
                    Number(root.output.volume) * 100
                ) + "%"

            color: Md3Theme.surfaceContent

            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
}
