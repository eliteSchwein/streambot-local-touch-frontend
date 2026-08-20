pragma Singleton
import QtQuick

QtObject {
    readonly property color background: "#111318"
    readonly property color surface: "#111318"
    readonly property color surfaceContainer: "#1D2024"
    readonly property color surfaceContainerHigh: "#282A2F"
    readonly property color surfaceContainerHighest: "#33353A"

    readonly property color primary: "#A8C7FA"
    readonly property color primaryPressed: "#8FB3EE"
    readonly property color primaryContent: "#062E6F"

    readonly property color secondary: "#BEC6DC"
    readonly property color secondaryContent: "#283141"

    readonly property color surfaceContent: "#E2E2E9"
    readonly property color surfaceVariantContent: "#C4C6D0"

    readonly property color outline: "#8E9099"
    readonly property color outlineVariant: "#44474F"

    readonly property color success: "#A8D5A2"
    readonly property color error: "#FFB4AB"

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 16
    readonly property int radiusExtraLarge: 28
    readonly property int touchTarget: 48
}
