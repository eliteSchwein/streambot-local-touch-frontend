pragma Singleton

import QtQuick

QtObject {
    readonly property color background: "#111318"
    readonly property color surface: "#111318"

    readonly property color surfaceContainer: "#1D2024"
    readonly property color surfaceContainerHigh: "#282A2F"

    readonly property color primary: "#A8C7FA"
    readonly property color primaryContent: "#062E6F"

    readonly property color surfaceContent: "#E2E2E9"
    readonly property color surfaceVariantContent: "#C4C6D0"

    readonly property color outlineVariant: "#44474F"

    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 16
    readonly property int radiusExtraLarge: 28

    readonly property int touchTarget: 48
}