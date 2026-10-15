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
    property var interactions: []
    property var updateManager: ({})
    property var systemStorage: null
    property var systemInfo: ({})

    // Backend websocket contract:
    //   first notification after registration -> complete endpoint state
    //   later notifications                -> only changed keys
    //
    // Keep one accumulated snapshot per notify_* endpoint. Objects are
    // recursively merged, arrays/scalars/null replace the previous value.
    property var endpointSnapshots: ({})

    readonly property bool updatesAvailable: {
        const managers = updateManager ?? ({})
        for (const name in managers) {
            if (managers[name]?.update_available === true)
                return true
        }
        return false
    }

    // CAVA preview from dedicated /cava/music_preview websocket.
    property var cava: [0, 0, 0, 0, 0]

    function isPlainObject(value) {
        return (
            value !== null
            && typeof value === "object"
            && !Array.isArray(value)
        )
    }

    function cloneValue(value) {
        if (Array.isArray(value))
            return value.map(item => cloneValue(item))

        if (isPlainObject(value)) {
            const out = ({})

            for (const key in value)
                out[key] = cloneValue(value[key])

            return out
        }

        return value
    }

    function mergePartialState(previous, patch) {
        // Explicit null is meaningful: it clears/replaces the old value.
        if (patch === null)
            return null

        // Arrays are atomic websocket values. If an array changed, the
        // backend sends that key again and the complete array replaces the
        // previous one.
        if (Array.isArray(patch))
            return cloneValue(patch)

        if (!isPlainObject(patch))
            return patch

        const result =
            isPlainObject(previous)
            ? cloneValue(previous)
            : ({})

        for (const key in patch) {
            const nextValue = patch[key]

            if (
                isPlainObject(nextValue)
                && isPlainObject(result[key])
            ) {
                result[key] =
                    mergePartialState(
                        result[key],
                        nextValue
                    )
            } else {
                result[key] =
                    cloneValue(nextValue)
            }
        }

        return result
    }

    function mergeEndpointSnapshot(method, params) {
        const key = String(method ?? "")

        if (key === "")
            return cloneValue(params)

        const current =
            endpointSnapshots[key]

        const merged =
            mergePartialState(
                current,
                params
            )

        const snapshots =
            Object.assign(
                {},
                endpointSnapshots
            )

        snapshots[key] = merged
        endpointSnapshots = snapshots

        return merged
    }

    function resetEndpointSnapshots() {
        endpointSnapshots = ({})
    }

    function handleMessage(data) {
        if (!data || typeof data !== "object")
            return

        const method = data.method
        const params = data.params

        switch (method) {
        case "notify_music_update": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? ({})
                )

            music = state ?? ({})
            break
        }

        case "notify_playlist_update": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? ({})
                )

            playlist = state ?? ({})
            break
        }

        case "notify_audio_update": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? ({})
                )

            audio = state ?? ({})
            break
        }

        case "notify_audio_outputs_update": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? []
                )

            audioOutputs = Array.isArray(state)
                ? state
                : (
                    state && Array.isArray(state.outputs)
                    ? state.outputs
                    : []
                )
            break
        }

        case "notify_auto_macros_update": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? []
                )

            autoMacros = Array.isArray(state)
                ? state
                : (
                    state && Array.isArray(state.auto_macros)
                    ? state.auto_macros
                    : (
                        state && Array.isArray(state.autoMacros)
                        ? state.autoMacros
                        : []
                    )
                )
            break
        }

        case "notify_macro_update": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? ({})
                )

            macros =
                state && state.macros
                ? state.macros
                : (
                    state && isPlainObject(state)
                    ? state
                    : ({})
                )
            break
        }

        case "notify_channel_point_update": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? ({})
                )

            channelPoints =
                state && Array.isArray(state.all)
                ? state.all
                : []

            activeChannelPoints =
                state && Array.isArray(state.active)
                ? state.active
                : []

            break
        }

        case "notify_update_manager": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? ({})
                )

            updateManager =
                normalizeUpdateManager(state)

            break
        }

        case "notify_storage_update": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? ({})
                )

            systemStorage =
                normalizeSystemStorage(state)

            break
        }

        case "notify_system_info": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? ({})
                )

            systemInfo =
                normalizeSystemInfo(state)

            break
        }

        case "notify_interaction_queue": {
            const state =
                mergeEndpointSnapshot(
                    method,
                    params ?? []
                )

            interactions =
                Array.isArray(state)
                ? state
                : (
                    state && Array.isArray(state.queue)
                    ? state.queue
                    : []
                )

            break
        }

        case "notify_interaction":
            handleInteractionNotification(params)
            break

        case "notify_music_cava":
            if (params && String(params.target) === "music_preview")
                parseCava(String(params.raw ?? ""))
            break
        }
    }

    function handleInteractionNotification(params) {
        if (!params || typeof params !== "object")
            return

        const action = String(params.action ?? "")
        const interaction = params.interaction

        if (!interaction || !interaction.uuid)
            return

        if (
            action === "finish"
            || action === "cancel"
            || action === "failed"
        ) {
            interactions = interactions.filter(
                item => item && item.uuid !== interaction.uuid
            )
            return
        }

        const next = interactions.slice()
        const index = next.findIndex(
            item => item && item.uuid === interaction.uuid
        )

        if (index >= 0) {
            const merged = ({})
            const current = next[index]

            for (const key in current)
                merged[key] = current[key]

            for (const key in interaction)
                merged[key] = interaction[key]

            next[index] = merged
        } else {
            next.push(interaction)
        }

        interactions = next
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

            if (typeof value === "string") {
                const parsed = parseFloat(value)
                if (Number.isFinite(parsed))
                    return parsed
            }
        }

        return null
    }

    function findMetricByMethod(value, method, entryNames) {
        if (value === undefined || value === null)
            return null

        if (Array.isArray(value)) {
            for (const item of value) {
                const found = findMetricByMethod(item, method, entryNames)
                if (found !== null)
                    return found
            }
            return null
        }

        if (typeof value !== "object")
            return null

        if (String(value.method ?? "") === method) {
            const candidates = []

            for (const entry of entryNames)
                candidates.push(value[entry])

            candidates.push(
                value.value,
                value.result,
                value.data,
                value.current,
                value.raw
            )

            const direct = firstNumber(candidates)
            if (direct !== null)
                return direct

            for (const candidate of candidates) {
                if (!candidate || typeof candidate !== "object")
                    continue

                const nested = firstNumber([
                    candidate.value,
                    candidate.result,
                    candidate.currentLoad,
                    candidate.current_load,
                    candidate.main,
                    candidate.temperature,
                    candidate.temp,
                    candidate.percent,
                    candidate.usage_percent,
                    candidate.usagePercent
                ])

                if (nested !== null)
                    return nested
            }
        }

        for (const key in value) {
            const found = findMetricByMethod(value[key], method, entryNames)
            if (found !== null)
                return found
        }

        return null
    }

    function findNumberByKeys(value, keys, nestedKeys) {
        if (value === undefined || value === null)
            return null

        if (Array.isArray(value)) {
            for (const item of value) {
                const found = findNumberByKeys(item, keys, nestedKeys)
                if (found !== null)
                    return found
            }
            return null
        }

        if (typeof value !== "object")
            return null

        for (const key of keys) {
            if (!(key in value))
                continue

            const candidate = value[key]
            const direct = firstNumber([candidate])
            if (direct !== null)
                return direct

            if (candidate && typeof candidate === "object") {
                const nestedCandidates = []
                for (const nestedKey of nestedKeys)
                    nestedCandidates.push(candidate[nestedKey])

                const nested = firstNumber(nestedCandidates)
                if (nested !== null)
                    return nested
            }
        }

        for (const key in value) {
            const found = findNumberByKeys(value[key], keys, nestedKeys)
            if (found !== null)
                return found
        }

        return null
    }

    function normalizeSystemInfo(value) {
        if (!value || typeof value !== "object")
            return ({})

        // Backend 2.0 notifications may arrive either as the system-info
        // object itself or wrapped in the common content/data/info envelope.
        const raw =
            value.content
            ?? value.data
            ?? value.info
            ?? value.system_info
            ?? value.systemInfo
            ?? value

        if (!raw || typeof raw !== "object")
            return ({})

        const components =
            raw.components && typeof raw.components === "object"
            ? raw.components
            : ({})

        const memory =
            components.memory && typeof components.memory === "object"
            ? components.memory
            : (
                raw.memory && typeof raw.memory === "object"
                ? raw.memory
                : ({})
            )

        const storage =
            components.storage && typeof components.storage === "object"
            ? components.storage
            : (
                raw.storage && typeof raw.storage === "object"
                ? raw.storage
                : ({})
            )

        const internal =
            storage.internal && typeof storage.internal === "object"
            ? storage.internal
            : ({})

        const cpu =
            components.cpu && typeof components.cpu === "object"
            ? components.cpu
            : (
                raw.cpu && typeof raw.cpu === "object"
                ? raw.cpu
                : ({})
            )

        const currentLoad =
            components.currentLoad
            ?? components.current_load
            ?? components.cpuLoad
            ?? components.cpu_load
            ?? cpu.currentLoad
            ?? cpu.current_load
            ?? cpu.load
            ?? raw.currentLoad
            ?? raw.current_load
            ?? raw.cpuLoad
            ?? raw.cpu_load
            ?? ({})

        const cpuTemperature =
            components.cpuTemperature
            ?? components.cpu_temperature
            ?? components.cpuTemp
            ?? components.cpu_temp
            ?? cpu.temperature
            ?? cpu.temp
            ?? raw.cpuTemperature
            ?? raw.cpu_temperature
            ?? raw.cpuTemp
            ?? raw.cpu_temp
            ?? ({})

        const cpuUsage = firstNumber([
            currentLoad,
            currentLoad?.currentLoad,
            currentLoad?.current_load,
            currentLoad?.usage_percent,
            currentLoad?.usagePercent,
            currentLoad?.usage,
            currentLoad?.percent,
            cpu?.usage_percent,
            cpu?.usagePercent,
            cpu?.usage,
            cpu?.load,
            cpu?.percent,
            components.system_cpu_usage?.cpu,
            components.systemCpuUsage?.cpu,
            components.cpu_usage,
            components.cpuUsage,
            raw.system_cpu_usage?.cpu,
            raw.systemCpuUsage?.cpu,
            raw.cpu_usage,
            raw.cpuUsage,
            findMetricByMethod(
                raw,
                "currentLoad",
                ["currentLoad", "current_load"]
            ),
            findNumberByKeys(
                raw,
                ["currentLoad", "current_load", "cpu_usage", "cpuUsage"],
                [
                    "currentLoad",
                    "current_load",
                    "value",
                    "result",
                    "usage_percent",
                    "usagePercent",
                    "usage",
                    "percent"
                ]
            )
        ])

        const cpuTemp = firstNumber([
            cpuTemperature,
            cpuTemperature?.main,
            cpuTemperature?.temperature,
            cpuTemperature?.temp,
            cpuTemperature?.max,
            cpu?.temperature,
            cpu?.temp,
            components.cpu_temperature,
            components.cpuTemperature,
            components.cpu_temp,
            components.cpuTemp,
            raw.cpu_temperature,
            raw.cpuTemperature,
            raw.cpu_temp,
            raw.cpuTemp,
            findMetricByMethod(
                raw,
                "cpuTemperature",
                ["main", "temperature", "temp"]
            ),
            findNumberByKeys(
                raw,
                ["cpuTemperature", "cpu_temperature", "cpuTemp", "cpu_temp"],
                ["main", "value", "result", "temperature", "temp", "max"]
            )
        ])

        const ramUsage = firstNumber([
            memory?.usage_percent,
            memory?.usagePercent,
            memory?.percent,
            memory?.usage,
            components.ram?.usage_percent,
            components.ram?.usagePercent,
            components.ram?.percent,
            components.ram_usage,
            components.ramUsage,
            raw.ram_usage,
            raw.ramUsage
        ])

        const internalStorageUsage = firstNumber([
            internal?.usage_percent,
            internal?.usagePercent,
            internal?.percent,
            internal?.usage,
            components.internal_storage_usage,
            components.internalStorageUsage,
            raw.internal_storage_usage,
            raw.internalStorageUsage
        ])

        return {
            cpu_usage: cpuUsage,
            cpu_temperature: cpuTemp,
            ram_usage: ramUsage,
            internal_storage_usage: internalStorageUsage,
            raw: raw
        }
    }

    function normalizeUpdateManager(value) {
        if (!value || typeof value !== "object")
            return ({})

        const source =
            value.managers && typeof value.managers === "object"
            ? value.managers
            : value

        const normalized = ({})

        for (const name in source) {
            const input = source[name]
            if (!input || typeof input !== "object")
                continue

            const manager = ({})
            for (const key in input)
                manager[key] = input[key]

            if (name === "system") {
                manager.updates = Array.isArray(input.updates)
                    ? input.updates.slice()
                    : []

                manager.update_available =
                    manager.updates.length > 0
                    || input.update_available === true
            }

            normalized[name] = manager
        }

        return normalized
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
