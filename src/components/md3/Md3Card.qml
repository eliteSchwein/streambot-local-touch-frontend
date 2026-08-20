import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""

    default property alias content: body.data

    radius: Md3Theme.radiusLarge
    color: Md3Theme.surfaceContainer

    border.width: 1
    border.color: Md3Theme.outlineVariant

    implicitHeight: Math.max(
        120,
        body.implicitHeight + 32
    )

    ColumnLayout {
        id: body

        anchors.fill: parent
        anchors.margins: 16

        spacing: 10

        Text {
            visible: root.title !== ""

            text: root.title
            color: Md3Theme.surfaceContent

            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        Text {
            visible: root.subtitle !== ""

            text: root.subtitle
            color: Md3Theme.surfaceVariantContent

            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
    }
}