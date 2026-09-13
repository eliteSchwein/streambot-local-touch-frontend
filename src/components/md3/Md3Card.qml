import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property color backgroundColor: Md3Theme.surfaceContainer
    property real backgroundOpacity: 0.88
    property real radius: Md3Theme.radiusLarge

    default property alias content: contentColumn.data

    implicitHeight: Math.max(100, contentColumn.implicitHeight + 28)

    Md3GlassSurface {
        anchors.fill: parent
        tintColor: root.backgroundColor
        tintOpacity: root.backgroundOpacity
        radius: root.radius
    }

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
