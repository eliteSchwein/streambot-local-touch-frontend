import QtQuick
import QtQuick.Layouts

import "../components/md3"

Rectangle {
    id: root

    required property string icon
    required property string title
    property string supportingText: ""
    property bool destructive: false

    signal clicked()

    implicitHeight: 72
    radius: Md3Theme.radiusLarge

    color:
        tap.pressed
        ? Md3Theme.surfaceContainerHighest
        : Md3Theme.surfaceContainer

    border.width: 1
    border.color:
        destructive
        ? Md3Theme.error
        : Md3Theme.outlineVariant

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            Layout.alignment: Qt.AlignVCenter

            radius: 21

            color:
                root.destructive
                ? Md3Theme.error
                : Md3Theme.surfaceContainerHighest

            MdiIcon {
                anchors.centerIn: parent

                name: root.icon
                size: 21
                selected: root.destructive
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true

                text: root.title
                color: Md3Theme.surfaceContent

                font.pixelSize: 13
                font.weight: Font.DemiBold

                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true

                visible: root.supportingText !== ""
                text: root.supportingText

                color: Md3Theme.surfaceVariantContent

                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }
    }

    TapHandler {
        id: tap
        onTapped: root.clicked()
    }
}
