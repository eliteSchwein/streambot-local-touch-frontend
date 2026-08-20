import QtQuick

QtObject {
    id: root

    property var music: ({})
    property var playlist: ({})
    property var audio: ({})
    property var audioOutputs: []
    property var autoMacros: []
    property var macros: ({})
    property var channelPoints: []
    property var activeChannelPoints: []
    property var alertQueue: []
    property var activeAlert: null
    property var updateManager: ({})
    property var systemStorage: null

    readonly property bool updatesAvailable: {
        const managers = updateManager ?? ({})
        for (const name in managers) {
            if (managers[name]?.update_available === true)
                return true
        }
        return false
    }

    // CAVA preview from notify_music_cava target=music_preview.
    property var cava: [0, 0, 0, 0, 0]

    function handleMessage(data) {
        if (!data || typeof data !== "object")
            return

        const method = data.method
        const params = data.params

        switch (method) {
        case "notify_music_update":
            music = params ?? ({})
            break

        case "notify_playlist_update":
            playlist = params ?? ({})
            break

        case "notify_audio_update":
            audio = params ?? ({})
            break

        case "notify_audio_outputs_update":
            audioOutputs = Array.isArray(params)
                ? params
                : (
                    params && Array.isArray(params.outputs)
                    ? params.outputs
                    : []
                )
            break

        case "notify_auto_macros_update":
            autoMacros = Array.isArray(params) ? params : []
            break

        case "notify_macro_update":
            macros =
                params && params.macros
                ? params.macros
                : ({})
            break

        case "notify_channel_point_update":
            channelPoints =
                params && Array.isArray(params.all)
                ? params.all
                : []

            activeChannelPoints =
                params && Array.isArray(params.active)
                ? params.active
                : []
            break

        case "notify_update_manager":
            updateManager = params && typeof params === "object" ? params : ({})
            break

        case "notify_storage_update":
            systemStorage = normalizeSystemStorage(params)
            console.log(
                "[system-storage] update:",
                JSON.stringify(systemStorage)
            )
            break

        case "notify_alert_query":
            alertQueue = Array.isArray(params) ? params : []
            break

        case "notify_alert":
            if (params && params.action === "hide") {
                if (
                    activeAlert
                    && activeAlert["event-uuid"]
                    === params["event-uuid"]
                ) {
                    activeAlert = null
                }
            } else if (params) {
                activeAlert = params
            }
            break

        case "notify_music_cava":
            if (params && String(params.target) === "music_preview")
                parseCava(String(params.raw ?? ""))
            break
        }
    }

    function firstNumber(values) {
        for (const value of values) {
            if (
                value === undefined
                || value === null
                || value === ""
            ) {
                continue
            }

            const numberValue = Number(value)

            if (Number.isFinite(numberValue))
                return numberValue
        }

        return null
    }

    function normalizeSystemStorage(value) {
        if (
            !value
            || typeof value !== "object"
        ) {
            return null
        }

        // Mirrors the old Vue StorageCard normalization.
        // `data` is additionally supported because several backend responses
        // use the standard { data, status } envelope.
        const raw =
            value.content
            ?? value.storage
            ?? value.info
            ?? value.data
            ?? value

        if (
            !raw
            || typeof raw !== "object"
        ) {
            return null
        }

        const used = firstNumber([
            raw.used,
            raw.storageUsed,
            raw.usedBytes,
            raw.disk?.used,
            raw.root?.used
        ])

        const free = firstNumber([
            raw.free,
            raw.storageFree,
            raw.freeBytes,
            raw.available,
            raw.disk?.free,
            raw.root?.free
        ])

        const total = firstNumber([
            raw.total,
            raw.storageTotal,
            raw.totalBytes,
            raw.disk?.total,
            raw.root?.total
        ])

        const normalized = ({})

        for (const key in raw)
            normalized[key] = raw[key]

        normalized.used = used ?? 0
        normalized.free = free ?? 0
        normalized.total = total ?? 0
        normalized.folders =
            raw.folders
            ?? raw.directories
            ?? raw.paths
            ?? ({})

        return normalized
    }

    function parseCava(raw) {
        const lines = raw.split(/\r?\n/)

        for (const line of lines) {
            if (!line.trim())
                continue

            let values = line
                .trim()
                .split(/[;,\s]+/)
                .map(value => Number(value))
                .filter(value => Number.isFinite(value))

            if (values.length > 1)
                values = values.slice(0, -1)

            if (values.length === 0)
                continue

            const next = []

            for (let i = 0; i < 5; i++) {
                const target = Math.max(
                    0,
                    Math.min(100, values[i] ?? 0)
                )

                const current = Number(cava[i] ?? 0)

                next.push(
                    target > current
                    ? current + (target - current) * 0.45
                    : Math.max(target, current - 6)
                )
            }

            cava = next
        }
    }

    function formatTime(ms) {
        const seconds = Math.max(0, Math.floor(Number(ms ?? 0) / 1000))
        const minutes = Math.floor(seconds / 60)
        const rest = seconds % 60
        return minutes + ":" + String(rest).padStart(2, "0")
    }

    function formatCountdown(seconds) {
        const value = Math.max(0, Math.floor(Number(seconds ?? 0)))
        const minutes = Math.floor(value / 60)
        const rest = value % 60
        return minutes + ":" + String(rest).padStart(2, "0")
    }

}
