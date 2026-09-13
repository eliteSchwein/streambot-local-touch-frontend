import QtQuick
import Quickshell.Io

import "../components/md3"

QtObject {
    id: root

    property string wallpaperPath: ""
    property string lastGeneratedWallpaper: ""

    function refresh() {
        const path = String(wallpaperPath ?? "")

        if (path === "") {
            lastGeneratedWallpaper = ""
            Md3Theme.resetToFallback()
            return
        }

        if (path === lastGeneratedWallpaper && Md3Theme.dynamic)
            return

        if (themeProcess.running)
            themeProcess.running = false

        themeProcess.exec([
            "/usr/lib/streambot-touch/generate-theme",
            path
        ])
    }

    onWallpaperPathChanged:
        Qt.callLater(refresh)

    Component.onCompleted:
        Qt.callLater(refresh)

    property Process themeProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.log("[theme]", text.trim())
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[theme]", text.trim())
            }
        }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.lastGeneratedWallpaper = root.wallpaperPath
                Md3Theme.reloadGeneratedTheme()
            } else {
                root.lastGeneratedWallpaper = ""
                Md3Theme.resetToFallback()
            }
        }
    }
}
