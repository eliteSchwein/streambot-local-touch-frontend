import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string language: "en"
    property var translations: ({})

    readonly property string localePath:
        Qt.resolvedUrl("../locales/" + (language === "de" ? "de" : "en") + ".json")

    property FileView localeFile: FileView {
        path: root.localePath
        blockLoading: true
        watchChanges: true
        printErrors: false

        onLoaded: root.loadTranslations()
        onFileChanged: reload()

        onTextChanged: {
            if (loaded)
                root.loadTranslations()
        }
    }

    function loadTranslations() {
        if (!localeFile.loaded)
            return

        try {
            translations = JSON.parse(localeFile.text())
        } catch (error) {
            console.warn("[i18n] parse error:", error)
            translations = ({})
        }
    }

    function text(key) {
        return translations[key] !== undefined
            ? translations[key]
            : key
    }
}
