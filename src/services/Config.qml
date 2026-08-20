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

    function loadSharedSettings() {
        language = "en"

        if (!settingsFile.loaded)
            return

        try {
            const data = JSON.parse(settingsFile.text())

            if (
                typeof data.language === "string"
                && data.language.trim() !== ""
            ) {
                language = data.language
            }
        } catch (error) {
            console.warn(
                "[config] failed to parse streambot-settings.json:",
                error
            )
        }
    }
}
