import QtQuick

Rectangle {
    id: root

    property color tintColor: Md3Theme.surfaceContainer
    property real tintOpacity: 0.94
    property color borderColor: Md3Theme.outlineVariant
    property real borderWidth: 1
    radius: Md3Theme.radiusLarge
    color: Qt.rgba(
        root.tintColor.r,
        root.tintColor.g,
        root.tintColor.b,
        root.tintOpacity
    )

    border.color: root.borderColor
    border.width: root.borderWidth
}
