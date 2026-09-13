import QtQuick
import QtQuick.Effects

Item {
    id: root

    property color tintColor: Md3Theme.surfaceContainer
    property real tintOpacity: 0.94
    property bool blurEnabled: false
    property real blurAmount: 0.42
    property int blurMaximum: 32
    property real radius: Md3Theme.radiusLarge
    property color borderColor: Md3Theme.outlineVariant
    property real borderWidth: 1

    readonly property var wallpaper: Md3Theme.wallpaperItem
    readonly property bool hasWallpaper:
        wallpaper !== null
        && wallpaper !== undefined
        && wallpaper.visible === true
        && wallpaper.source !== ""

    readonly property point wallpaperOffset: {
        if (!root.hasWallpaper)
            return Qt.point(0, 0)

        return root.mapToItem(root.wallpaper, 0, 0)
    }

    // Render the wallpaper again at the exact same window size/position, but
    // inside a viewport the size of this card. This avoids sourceRect sampling
    // bugs for delegates nested in ListViews and page layouts.
    Item {
        id: backdropViewport
        anchors.fill: parent
        clip: true
        visible: root.blurEnabled && root.hasWallpaper

        Image {
            id: localWallpaper

            width: root.wallpaper ? root.wallpaper.width : 0
            height: root.wallpaper ? root.wallpaper.height : 0

            x: -root.wallpaperOffset.x
            y: -root.wallpaperOffset.y

            source: root.wallpaper ? root.wallpaper.source : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
        }
    }

    ShaderEffectSource {
        id: backdropSource
        anchors.fill: parent
        sourceItem: backdropViewport
        live: true
        hideSource: true
        smooth: true
        visible: false
    }

    Rectangle {
        id: roundedMask
        anchors.fill: parent
        radius: root.radius
        color: "white"
        visible: false
        layer.enabled: true
        antialiasing: true
    }

    MultiEffect {
        anchors.fill: parent
        source: backdropSource
        visible: root.blurEnabled && root.hasWallpaper
        blurEnabled: root.blurEnabled && root.hasWallpaper
        blur: root.blurAmount
        blurMax: root.blurMaximum
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: roundedMask
        maskThresholdMin: 0.5
        maskThresholdMax: 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tintColor
        opacity: root.hasWallpaper ? root.tintOpacity : 1
        border.width: root.borderWidth
        border.color: root.borderColor
        antialiasing: true
    }
}
