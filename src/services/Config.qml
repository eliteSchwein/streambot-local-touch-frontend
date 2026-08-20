import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id: root
    readonly property string homePath: Quickshell.env("HOME") ?? ""
    readonly property string defaultConfigPath: homePath + "/.config/streambot/streambot-touch.cfg"
    readonly property string settingsPath: homePath + "/.config/streambot/streambot-settings.json"
    readonly property string configPath: {
        const p = Quickshell.env("STREAMBOT_TOUCH_CONFIG")
        return p !== null && p !== "" ? p : defaultConfigPath
    }
    property string host: "127.0.0.1"
    property int websocketPort: 8100
    property int restPort: 8105
    property string language: "en"
    readonly property string websocketUrl: "ws://" + host + ":" + websocketPort
    readonly property string restUrl: "http://" + host + ":" + restPort
    property FileView cfg: FileView {
        path: root.configPath; blockLoading: true; watchChanges: true; printErrors: false
        onLoaded: root.loadCfg(); onFileChanged: reload(); onTextChanged: { if (loaded) root.loadCfg() }
    }
    property FileView settings: FileView {
        path: root.settingsPath; blockLoading: true; watchChanges: true; printErrors: false
        onLoaded: root.loadSettings(); onFileChanged: reload(); onTextChanged: { if (loaded) root.loadSettings() }
    }
    function loadCfg() {
        host="127.0.0.1"; websocketPort=8100; restPort=8105
        if (!cfg.loaded) return
        let section=""
        for (const raw of cfg.text().split(/\r?\n/)) {
            const line=raw.trim()
            if (!line || line.startsWith("#") || line.startsWith(";")) continue
            if (line.startsWith("[") && line.endsWith("]")) { section=line.slice(1,-1).trim().toLowerCase(); continue }
            if (section !== "connection") continue
            const pos=line.indexOf(":"); if (pos < 0) continue
            const key=line.slice(0,pos).trim().toLowerCase(), value=line.slice(pos+1).trim()
            if (key==="host" && value) host=value
            if (key==="websocketport") { const p=parseInt(value); if (p>0 && p<=65535) websocketPort=p }
            if (key==="restport") { const p=parseInt(value); if (p>0 && p<=65535) restPort=p }
        }
    }
    function loadSettings() {
        language="en"
        if (!settings.loaded) return
        try {
            const d=JSON.parse(settings.text())
            if (typeof d.language === "string" && d.language.trim()) language=d.language
        } catch(e) { console.warn("[config] settings parse error:",e) }
    }
}
