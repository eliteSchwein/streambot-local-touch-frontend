import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""

    default property alias content: contentColumn.data

    radius: Md3Theme.radiusLarge
    color: Md3Theme.surfaceContainer

    border.width: 1
    border.color: Md3Theme.outlineVariant

    implicitHeight: Math.max(100, contentColumn.implicitHeight + 28)

    ColumnLayout {
        id: contentColumn

        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Text {
            visible: root.title !== ""
            text: root.title
            color: Md3Theme.surfaceContent
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Text {
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Md3Theme.surfaceVariantContent
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }
}
