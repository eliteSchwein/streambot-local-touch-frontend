import QtQuick
import QtQuick.Effects

Item {
    id: root

    property color tintColor: Md3Theme.surfaceContainer
    property real tintOpacity: 0.88
    property real blurAmount: 0.42
    property int blurMaximum: 32
    property real radius: Md3Theme.radiusLarge
    property color borderColor: Md3Theme.outlineVariant
    property real borderWidth: 1

    clip: true

    readonly property var wallpaper: Md3Theme.wallpaperItem
    readonly property bool hasWallpaper:
        wallpaper !== null
        && wallpaper !== undefined
        && wallpaper.visible === true
        && wallpaper.source !== ""

    ShaderEffectSource {
        id: backdropSource
        anchors.fill: parent
        sourceItem: root.wallpaper
        live: true
        hideSource: false
        smooth: true
        visible: false

        sourceRect: {
            if (!root.hasWallpaper)
                return Qt.rect(0, 0, 0, 0)

            const point = root.mapToItem(root.wallpaper, 0, 0)
            return Qt.rect(point.x, point.y, root.width, root.height)
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: backdropSource
        visible: root.hasWallpaper
        blurEnabled: root.hasWallpaper
        blur: root.blurAmount
        blurMax: root.blurMaximum
        autoPaddingEnabled: false
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tintColor
        opacity: root.hasWallpaper ? root.tintOpacity : 1
        border.width: root.borderWidth
        border.color: root.borderColor
    }
}
