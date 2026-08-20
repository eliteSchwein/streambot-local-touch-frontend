import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ---------------------------------------------------------------------
    // Paths
    // ---------------------------------------------------------------------

    readonly property string homePath:
        Quickshell.env("HOME") ?? ""

    readonly property string defaultConfigPath:
        homePath + "/.config/streambot/streambot-touch.cfg"

    readonly property string settingsPath:
        homePath + "/.config/streambot/streambot-settings.json"

    // Allows --app-config to still override the normal location.
    readonly property string configPath: {
        const overridePath = Quickshell.env("STREAMBOT_TOUCH_CONFIG")

        if (overridePath !== null && overridePath !== "")
            return overridePath

        return defaultConfigPath
    }


    // ---------------------------------------------------------------------
    // Defaults
    // ---------------------------------------------------------------------

    property string host: "127.0.0.1"
    property int websocketPort: 8100
    property int restPort: 8105

    property string language: "en"


    // ---------------------------------------------------------------------
    // Convenience URLs
    // ---------------------------------------------------------------------

    readonly property string websocketUrl:
        "ws://" + host + ":" + websocketPort

    readonly property string restUrl:
        "http://" + host + ":" + restPort


    // ---------------------------------------------------------------------
    // Config files
    // ---------------------------------------------------------------------

    property FileView touchConfigFile: FileView {
        path: root.configPath

        blockLoading: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            root.loadTouchConfig()
        }

        onFileChanged: {
            reload()
        }

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

        onLoaded: {
            root.loadSharedSettings()
        }

        onFileChanged: {
            reload()
        }

        onTextChanged: {
            if (loaded)
                root.loadSharedSettings()
        }
    }


    // ---------------------------------------------------------------------
    // Loading
    // ---------------------------------------------------------------------

    function resetConnectionDefaults() {
        host = "127.0.0.1"
        websocketPort = 8100
        restPort = 8105
    }

    function loadTouchConfig() {
        resetConnectionDefaults()

        if (!touchConfigFile.loaded)
            return

        const text = touchConfigFile.text()

        if (!text || text.trim() === "")
            return

        parseTouchConfig(text)

        console.log(
            "[config] connection:",
            host,
            websocketPort,
            restPort
        )
    }

    function loadSharedSettings() {
        // The shared settings file is NOT our config.
        // We intentionally care about exactly one key.
        language = "en"

        if (!settingsFile.loaded)
            return

        const text = settingsFile.text()

        if (!text || text.trim() === "")
            return

        try {
            const data = JSON.parse(text)

            if (
                typeof data.language === "string"
                && data.language.trim() !== ""
            ) {
                language = data.language
            }

            console.log("[config] language:", language)
        } catch (error) {
            console.warn(
                "[config] failed to parse streambot-settings.json:",
                error
            )
        }
    }


    // ---------------------------------------------------------------------
    // streambot-touch.cfg parser
    // ---------------------------------------------------------------------

    function parseTouchConfig(text) {
        const lines = text.split(/\r?\n/)

        let section = ""

        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim()

            if (
                line === ""
                || line.startsWith("#")
                || line.startsWith(";")
            ) {
                continue
            }

            if (line.startsWith("[") && line.endsWith("]")) {
                section = line
                    .substring(1, line.length - 1)
                    .trim()
                    .toLowerCase()

                continue
            }

            // We currently only support values from [connection].
            if (section !== "connection")
                continue

            const separator = line.indexOf(":")

            if (separator === -1)
                continue

            const key = line
                .substring(0, separator)
                .trim()
                .toLowerCase()

            const value = line
                .substring(separator + 1)
                .trim()

            switch (key) {
                case "host":
                    if (value !== "")
                        host = value
                    break

                case "websocketport": {
                    const port = parseInt(value)

                    if (!isNaN(port) && port > 0 && port <= 65535)
                        websocketPort = port

                    break
                }

                case "restport": {
                    const port = parseInt(value)

                    if (!isNaN(port) && port > 0 && port <= 65535)
                        restPort = port

                    break
                }
            }
        }
    }


    Component.onCompleted: {
        loadTouchConfig()
        loadSharedSettings()
    }
}