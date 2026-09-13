pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property color fallbackBackground: "#111318"
    readonly property color fallbackSurface: "#111318"
    readonly property color fallbackSurfaceContainer: "#1D2024"
    readonly property color fallbackSurfaceContainerHigh: "#282A2F"
    readonly property color fallbackSurfaceContainerHighest: "#33353A"
    readonly property color fallbackPrimary: "#A8C7FA"
    readonly property color fallbackPrimaryPressed: "#8FB3EE"
    readonly property color fallbackPrimaryContent: "#062E6F"
    readonly property color fallbackSecondary: "#BEC6DC"
    readonly property color fallbackSecondaryContent: "#283141"
    readonly property color fallbackSurfaceContent: "#E2E2E9"
    readonly property color fallbackSurfaceVariantContent: "#C4C6D0"
    readonly property color fallbackOutline: "#8E9099"
    readonly property color fallbackOutlineVariant: "#44474F"
    readonly property color fallbackSuccess: "#A8D5A2"
    readonly property color fallbackError: "#FFB4AB"
    readonly property color fallbackErrorContent: "#690005"
    readonly property color fallbackPrimaryContainer: "#062E6F"

    property bool dynamic: false

    property color background: fallbackBackground
    property color surface: fallbackSurface
    property color surfaceContainer: fallbackSurfaceContainer
    property color surfaceContainerHigh: fallbackSurfaceContainerHigh
    property color surfaceContainerHighest: fallbackSurfaceContainerHighest

    property color primary: fallbackPrimary
    property color primaryPressed: fallbackPrimaryPressed
    property color primaryContent: fallbackPrimaryContent
    property color primaryContainer: fallbackPrimaryContainer

    property color secondary: fallbackSecondary
    property color secondaryContent: fallbackSecondaryContent

    property color surfaceContent: fallbackSurfaceContent
    property color surfaceVariantContent: fallbackSurfaceVariantContent

    property color outline: fallbackOutline
    property color outlineVariant: fallbackOutlineVariant

    property color success: fallbackSuccess
    property color error: fallbackError
    property color errorContent: fallbackErrorContent

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 16
    readonly property int radiusExtraLarge: 28
    readonly property int touchTarget: 48

    readonly property string generatedThemePath:
        (Quickshell.env("HOME") ?? "") + "/.cache/streambot-touch/theme.json"

    function resetToFallback() {
        dynamic = false
        background = fallbackBackground
        surface = fallbackSurface
        surfaceContainer = fallbackSurfaceContainer
        surfaceContainerHigh = fallbackSurfaceContainerHigh
        surfaceContainerHighest = fallbackSurfaceContainerHighest
        primary = fallbackPrimary
        primaryPressed = fallbackPrimaryPressed
        primaryContent = fallbackPrimaryContent
        primaryContainer = fallbackPrimaryContainer
        secondary = fallbackSecondary
        secondaryContent = fallbackSecondaryContent
        surfaceContent = fallbackSurfaceContent
        surfaceVariantContent = fallbackSurfaceVariantContent
        outline = fallbackOutline
        outlineVariant = fallbackOutlineVariant
        success = fallbackSuccess
        error = fallbackError
        errorContent = fallbackErrorContent
    }

    function applyColors(data) {
        if (!data || typeof data !== "object") {
            resetToFallback()
            return
        }

        background = data.background ?? fallbackBackground
        surface = data.surface ?? fallbackSurface
        surfaceContainer = data.surface_container ?? fallbackSurfaceContainer
        surfaceContainerHigh = data.surface_container_high ?? fallbackSurfaceContainerHigh
        surfaceContainerHighest = data.surface_container_highest ?? fallbackSurfaceContainerHighest
        primary = data.primary ?? fallbackPrimary
        primaryPressed = data.primary_pressed ?? data.primary ?? fallbackPrimaryPressed
        primaryContent = data.on_primary ?? fallbackPrimaryContent
        primaryContainer = data.primary_container ?? fallbackPrimaryContainer
        secondary = data.secondary ?? fallbackSecondary
        secondaryContent = data.on_secondary ?? fallbackSecondaryContent
        surfaceContent = data.on_surface ?? fallbackSurfaceContent
        surfaceVariantContent = data.on_surface_variant ?? fallbackSurfaceVariantContent
        outline = data.outline ?? fallbackOutline
        outlineVariant = data.outline_variant ?? fallbackOutlineVariant
        error = data.error ?? fallbackError
        errorContent = data.on_error ?? fallbackErrorContent
        // Material You has no semantic success role; keep the existing green.
        success = fallbackSuccess
        dynamic = true
    }

    function reloadGeneratedTheme() {
        themeFile.reload()
    }

    property FileView themeFile: FileView {
        path: root.generatedThemePath
        blockLoading: false
        watchChanges: true
        printErrors: false

        onLoaded: root.parseThemeFile()
        onFileChanged: reload()
        onTextChanged: {
            if (loaded)
                root.parseThemeFile()
        }
    }

    function parseThemeFile() {
        if (!themeFile.loaded)
            return

        try {
            applyColors(JSON.parse(themeFile.text()))
        } catch (error) {
            console.warn("[theme] failed to parse generated Matugen theme:", error)
            resetToFallback()
        }
    }
}
