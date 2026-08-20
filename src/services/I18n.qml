import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string language: "en"
    property var translations: ({})

    readonly property string localePath:
        Qt.resolvedUrl("../locales/" + language + ".json")

    property FileView localeFile: FileView {
        path: root.localePath

        blockLoading: true
        watchChanges: true
        printErrors: false

        onLoaded: {
            root.loadTranslations()
        }

        onFileChanged: {
            reload()
        }

        onTextChanged: {
            if (loaded)
                root.loadTranslations()
        }
    }

    function loadTranslations() {
        translations = {}

        if (!localeFile.loaded)
            return

        const text = localeFile.text()

        if (!text || text.trim() === "")
            return

        try {
            translations = JSON.parse(text)

            console.log(
                "[i18n] loaded language:",
                language
            )
        } catch (error) {
            console.warn(
                "[i18n] failed to parse locale:",
                localePath,
                error
            )
        }
    }

    function text(key) {
        if (translations[key] !== undefined)
            return translations[key]

        return key
    }

    onLanguageChanged: {
        localeFile.reload()
    }
}