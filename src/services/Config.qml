import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string homePath:
        Quickshell.env("HOME") ?? ""

    readonly property string defaultConfigPath:
        homePath + "/.config/streambot/streambot-touch.cfg"

    readonly property string settingsPath:
        homePath + "/.config/streambot/streambot-settings.json"

    readonly property string configPath: {
        const overridePath = Quickshell.env("STREAMBOT_TOUCH_CONFIG")

        if (overridePath !== null && overridePath !== "")
            return overridePath

        return defaultConfigPath
    }

    property string host: "127.0.0.1"
    property int websocketPort: 8100
    property int restPort: 8105
    property string language: "en"
    property string touchWallpaper: ""
    property var wallpaperFiles: []
    property var touchDashboard: defaultTouchDashboard()
    property bool sharedSettingsLoaded: false

    function defaultTouchDashboard() {
        // Exact legacy dashboard:
        // left = Interactions above Auto Macros, right = Music full column.
        return {
            version: 1,
            columns: {
                left: [
                    "interactions",
                    "auto_macros"
                ],
                right: [
                    "music"
                ]
            },
            macro_names: [],
            auto_macro_names: []
        }
    }

    function normalizeTouchDashboard(value) {
        const fallback = defaultTouchDashboard()

        if (!value || typeof value !== "object")
            return fallback

        const allowed = [
            "interactions",
            "auto_macros",
            "macros",
            "music"
        ]

        function cleanColumn(column) {
            if (!Array.isArray(column))
                return []

            const result = []

            for (const raw of column) {
                const name = String(raw ?? "")

                if (
                    allowed.includes(name)
                    && !result.includes(name)
                ) {
                    result.push(name)
                }
            }

            // Music always owns the complete column.
            if (result.includes("music"))
                return ["music"]

            // A 7-inch screen has room for at most two compact cards
            // in one non-music column.
            return result.slice(0, 2)
        }

        const columns =
            value.columns
            && typeof value.columns === "object"
            ? value.columns
            : ({})

        let left = cleanColumn(columns.left)
        let right = cleanColumn(columns.right)

        // Do not render the same card twice.
        right = right.filter(card => !left.includes(card))

        const macros = []
        const configuredMacros =
            Array.isArray(value.macro_names)
            ? value.macro_names
            : []

        for (const raw of configuredMacros) {
            const name = String(raw ?? "").trim()

            if (
                name !== ""
                && !macros.includes(name)
            ) {
                macros.push(name)
            }

            if (macros.length >= 4)
                break
        }

        const autoMacros = []
        const configuredAutoMacros =
            Array.isArray(value.auto_macro_names)
            ? value.auto_macro_names
            : []

        for (const raw of configuredAutoMacros) {
            const name = String(raw ?? "").trim()

            if (
                name !== ""
                && !autoMacros.includes(name)
            ) {
                autoMacros.push(name)
            }

            if (autoMacros.length >= 4)
                break
        }

        return {
            version: 1,
            columns: {
                left: left,
                right: right
            },
            macro_names: macros,
            auto_macro_names: autoMacros
        }
    }


    readonly property string assetRootPath:
        homePath + "/.config/streambot/assets"

    readonly property string touchWallpaperPath: {
        const value = String(touchWallpaper ?? "").trim().replace(/\\/g, "/")
        if (value === "")
            return ""

        const normalized = value.replace(/^\/+/, "")
        if (normalized === "" || normalized.split("/").includes(".."))
            return ""

        return assetRootPath + "/" + normalized
    }

    readonly property string touchWallpaperUrl:
        touchWallpaperPath === "" ? "" : "file://" + touchWallpaperPath

    function refreshWallpapers() {
        if (wallpaperScanProcess.running)
            wallpaperScanProcess.running = false

        Qt.callLater(function() {
            wallpaperScanProcess.exec([
                "sh",
                "-c",
                "cd \"$1\" 2>/dev/null || exit 0; "
                + "find . -type f \\( "
                + "-iname '*.png' -o "
                + "-iname '*.jpg' -o "
                + "-iname '*.jpeg' -o "
                + "-iname '*.webp' "
                + "\\) -print "
                + "| sed 's#^./##' "
                + "| sort",
                "sh",
                assetRootPath
            ])
        })
    }

    function setTouchWallpaper(value) {
        const normalized =
            String(value ?? "")
                .trim()
                .replace(/\\/g, "/")
                .replace(/^\/+/, "")

        if (normalized.split("/").includes(".."))
            return false

        let data = {}

        if (settingsFile.loaded) {
            const currentText = settingsFile.text()

            if (currentText && currentText.trim() !== "") {
                try {
                    data = JSON.parse(currentText)
                } catch (error) {
                    console.warn(
                        "[config] cannot save touch_wallpaper because streambot-settings.json is invalid:",
                        error
                    )
                    return false
                }
            }
        }

        data.touch_wallpaper = normalized

        try {
            settingsFile.setText(
                JSON.stringify(data, null, 2) + "\n"
            )

            touchWallpaper = normalized

            console.log(
                "[config] saved touch_wallpaper:",
                normalized
            )

            return true
        } catch (error) {
            console.warn(
                "[config] failed to save touch_wallpaper:",
                error
            )

            return false
        }
    }

    property Process wallpaperScanProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const files =
                    text
                        .split(/\r?\n/)
                        .map(value => value.trim())
                        .filter(value => value !== "")

                const current =
                    String(root.touchWallpaper ?? "").trim()

                if (
                    current !== ""
                    && !files.includes(current)
                ) {
                    files.unshift(current)
                }

                root.wallpaperFiles = files
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[config] wallpaper scan:", text.trim())
            }
        }
    }

    Component.onCompleted:
        Qt.callLater(refreshWallpapers)

    readonly property string websocketUrl:
        "ws://" + host + ":" + websocketPort

    readonly property string restUrl:
        "http://" + host + ":" + restPort

    property FileView touchConfigFile: FileView {
        path: root.configPath
        blockLoading: true
        watchChanges: true
        printErrors: false

        onLoaded: root.loadTouchConfig()
        onFileChanged: reload()

        onTextChanged: {
            if (loaded)
                root.loadTouchConfig()
        }
    }

    property FileView settingsFile: FileView {
        path: root.settingsPath
        blockLoading: true
        watchChanges: true
        printErrors: false

        onLoaded: root.loadSharedSettings()
        onFileChanged: reload()

        onTextChanged: {
            if (loaded)
                root.loadSharedSettings()
        }
    }

    function loadTouchConfig() {
        host = "127.0.0.1"
        websocketPort = 8100
        restPort = 8105

        if (!touchConfigFile.loaded)
            return

        let section = ""

        for (const rawLine of touchConfigFile.text().split(/\r?\n/)) {
            const line = rawLine.trim()

            if (
                line === ""
                || line.startsWith("#")
                || line.startsWith(";")
            ) {
                continue
            }

            if (line.startsWith("[") && line.endsWith("]")) {
                section = line
                    .slice(1, -1)
                    .trim()
                    .toLowerCase()

                continue
            }

            if (section !== "connection")
                continue

            const separator = line.indexOf(":")

            if (separator < 0)
                continue

            const key = line
                .slice(0, separator)
                .trim()
                .toLowerCase()

            const value = line
                .slice(separator + 1)
                .trim()

            if (key === "host" && value !== "")
                host = value

            if (key === "websocketport") {
                const port = parseInt(value)

                if (!isNaN(port) && port > 0 && port <= 65535)
                    websocketPort = port
            }

            if (key === "restport") {
                const port = parseInt(value)

                if (!isNaN(port) && port > 0 && port <= 65535)
                    restPort = port
            }
        }
    }

    function setTouchDashboard(value) {
        const normalized = normalizeTouchDashboard(value)

        let data = {}

        if (settingsFile.loaded) {
            const currentText = settingsFile.text()

            if (currentText && currentText.trim() !== "") {
                try {
                    data = JSON.parse(currentText)
                } catch (error) {
                    console.warn(
                        "[config] cannot save touch_dashboard because streambot-settings.json is invalid:",
                        error
                    )
                    return false
                }
            }
        }

        data.touch_dashboard = normalized

        try {
            settingsFile.setText(
                JSON.stringify(data, null, 2) + "\n"
            )

            touchDashboard = normalized

            console.log(
                "[config] saved touch_dashboard:",
                JSON.stringify(normalized)
            )

            return true
        } catch (error) {
            console.warn(
                "[config] failed to save touch_dashboard:",
                error
            )

            return false
        }
    }

    function setLanguage(newLanguage) {
        if (newLanguage !== "en" && newLanguage !== "de")
            return

        let data = {}

        if (settingsFile.loaded) {
            const currentText = settingsFile.text()

            if (currentText && currentText.trim() !== "") {
                try {
                    data = JSON.parse(currentText)
                } catch (error) {
                    console.warn(
                        "[config] cannot save language because streambot-settings.json is invalid:",
                        error
                    )
                    return
                }
            }
        }

        data.language = newLanguage

        try {
            settingsFile.setText(
                JSON.stringify(data, null, 2) + "\n"
            )

            language = newLanguage

            console.log(
                "[config] saved language:",
                newLanguage
            )
        } catch (error) {
            console.warn(
                "[config] failed to save language:",
                error
            )
        }
    }

    function loadSharedSettings() {
        if (!settingsFile.loaded)
            return

        language = "en"
        touchWallpaper = ""
        touchDashboard = defaultTouchDashboard()

        try {
            const data = JSON.parse(settingsFile.text())

            if (
                typeof data.language === "string"
                && data.language.trim() !== ""
            ) {
                language = data.language
            }

            if (typeof data.touch_wallpaper === "string")
                touchWallpaper = data.touch_wallpaper.trim()

            if (
                data.touch_dashboard
                && typeof data.touch_dashboard === "object"
            ) {
                touchDashboard =
                    normalizeTouchDashboard(
                        data.touch_dashboard
                    )
            } else {
                // Backwards-compatible fallback for existing installations:
                // no touch_dashboard key means use the original dashboard.
                touchDashboard = defaultTouchDashboard()
            }
        } catch (error) {
            console.warn(
                "[config] failed to parse streambot-settings.json:",
                error
            )
        }

        sharedSettingsLoaded = true
    }

    function handleMessage(data) {
        if (!data || data.method !== "notify_settings_update")
            return

        const params = data.params
        if (!params || typeof params !== "object")
            return

        const settings =
            params.system_config
            && typeof params.system_config === "object"
            ? params.system_config
            : params

        if (typeof settings.language === "string" && settings.language.trim() !== "")
            language = settings.language.trim()

        if (typeof settings.touch_wallpaper === "string")
            touchWallpaper = settings.touch_wallpaper.trim()

        // touch_dashboard is intentionally NOT consumed from
        // notify_settings_update. It is local Touch configuration and is
        // loaded directly from streambot-settings.json by settingsFile,
        // exactly like the persisted local settings path.
    }

}
