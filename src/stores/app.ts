// Utilities
import { defineStore } from 'pinia'
import { invoke } from '@tauri-apps/api/core'
import { listen, type UnlistenFn } from '@tauri-apps/api/event'

type GiveawayUser = {
  id: string
  displayName: string
}

type GiveawayWinner = {
  name: string
}

type Giveaway = {
  active: boolean
  content: string
  interval: number
  currentInterval: number
  users: GiveawayUser[]
  winner?: GiveawayWinner | null
}

type ObsAudioDevice = {
  inputUuid: string
  inputName: string
  muted: boolean
  balance: number
  volume: {
    inputVolumeMul: number
    inputVolumeDb: number
  }
}

type ObsAudioData = Record<string, ObsAudioDevice>

type YoloboxMixerDevice = {
  id: string
  isSelected: boolean
  volume: number
  delayTime?: number
  maxDelay?: number
  afv?: boolean
  AFV?: boolean
}

type YoloboxData = {
  MixerList?: YoloboxMixerDevice[]
}

type AudioDevice = {
  muted: boolean
  max_range: number
  min_range: number
  steps_range: number
  current_volume: number
  default_volume?: number
  pipewire_sink?: boolean | string
  sink_name?: string
  linked_output?: string
  actual_linked_output?: string
  audio_output?: string
  output?: string
  linked_outputs?: string[]
  actual_linked_outputs?: string[]
  audio_outputs?: string[]
  [key: string]: any
}

type AudioData = Record<string, AudioDevice>

type AudioOutput = {
  id?: string | number
  index?: string | number
  name?: string
  node_name?: string
  nodeName?: string
  description?: string
  display_name?: string
  displayName?: string
  volume?: number
  muted?: boolean
  is_default?: boolean
  default?: boolean
  isDefault?: boolean
  active?: boolean
  state?: string
  linked_interfaces?: string[]
  active_interfaces?: string[]
  interfaces?: string[]
  [key: string]: any
}

type AudioOutputs = Record<string, AudioOutput> | AudioOutput[] | {
  outputs?: AudioOutput[]
  sinks?: AudioOutput[]
  data?: AudioOutput[]
  [key: string]: any
}

type ConnectionItem = {
  type: string
  label?: string
  connected?: boolean
  authenticated?: boolean
  available?: boolean
  authAvailable?: boolean
  status?: string
  username?: string
  displayName?: string
  [key: string]: any
}

type ConnectionData = Record<string, ConnectionItem>

type WifiNetwork = {
  ssid: string
  secured: boolean
  saved: boolean
  signalPercent: number | null
}

type WifiSettingsState = {
  enabled: boolean
  connectedSsid: string | null
  connectedIp: string | null
  savedNetworks: WifiNetwork[]
  scannedNetworks: WifiNetwork[]
}

type WiredInterface = {
  interfaceName: string
  connected: boolean
  ip: string | null
}

type WiredSettingsState = {
  interfaces: WiredInterface[]
}

function isTauriRuntime(): boolean {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window
}

function sortWifiNetworks(items: WifiNetwork[]): WifiNetwork[] {
  return [...items].sort((a, b) => {
    const signalDiff = (b.signalPercent ?? -1) - (a.signalPercent ?? -1)
    if (signalDiff !== 0) return signalDiff

    return a.ssid.localeCompare(b.ssid, undefined, { sensitivity: 'base' })
  })
}

function dedupeWifiNetworks(items: WifiNetwork[]): WifiNetwork[] {
  const bySsid = new Map<string, WifiNetwork>()

  for (const item of items) {
    const ssid = item.ssid.trim()
    if (!ssid) continue

    const normalized: WifiNetwork = {
      ...item,
      ssid,
    }

    const existing = bySsid.get(ssid)

    if (!existing) {
      bySsid.set(ssid, normalized)
      continue
    }

    const existingSignal = existing.signalPercent ?? -1
    const nextSignal = normalized.signalPercent ?? -1
    const preferred = nextSignal > existingSignal ? normalized : existing

    bySsid.set(ssid, {
      ...preferred,
      saved: existing.saved || normalized.saved,
      secured: existing.secured || normalized.secured,
    })
  }

  return sortWifiNetworks([...bySsid.values()])
}

export type Alert = {
  id: string
  active?: boolean
  [key: string]: any
}

export type AutoMacro = {
  name: string
  enabled: boolean
  interval: number
  current_interval: number
}

export const useAppStore = defineStore('app', {
  state: () => ({
    assets: [],
    status: {},
    config: {
      websocketPort: 8100,
      webserverPort: 8105
    },
    games: [],
    alerts: [] as Alert[],
    autoMacros: [] as AutoMacro[],
    websocket: {
      connected: false,
      connecting: false
    },
    shieldMode: false,
    currentGame: {},
    channelPoints: {
      all: [],
      active: []
    },
    audioData: {} as AudioData,
    audioOutputs: {} as AudioOutputs,
    systemInfo: {
      components: {},
      config: {},
    },
    throttled: false,
    scene: {},
    connections: {},
    connectionData: {
      twitch: {
        type: 'twitch',
        label: 'Twitch',
        connected: false,
        authenticated: false,
        available: true,
        authAvailable: true,
      },
    } as ConnectionData,
    backendConfig: '',
    parsedBackendConfig: {},
    obsSceneData: [],
    testMode: false,
    voices: [],
    macros: {},
    variables: {},
    giveaway: {
      active: false,
      content: '',
      interval: 0,
      currentInterval: 0,
      users: [],
      winner: null,
    } as Giveaway,
    yoloboxData: {} as YoloboxData,
    obsAudioData: {} as ObsAudioData,
    musicData: {},
    networkListener: null as UnlistenFn | null,
    networkRefreshBusy: false,
    networkRefreshQueued: false,
    primaryIp: null as string | null,
    primaryIpError: null as string | null,
    wifiSettings: {
      enabled: false,
      connectedSsid: null,
      connectedIp: null,
      savedNetworks: [],
      scannedNetworks: [],
    } as WifiSettingsState,
    wiredSettings: {
      interfaces: [],
    } as WiredSettingsState,
  }),
  getters: {
    getConfig: (state) => state.config,
    getWebsocket: (state) => {
      return `ws://${location.hostname}:${state.config.websocketPort}`
    },
    getRestApi: (state) => {
      return `http://${location.hostname}:${state.config.webserverPort}`
    },
    getGames: (state) => state.games,
    getAlerts: (state) => state.alerts,
    isWebsocketConnected: (state) => state.websocket.connected,
    isWebsocketConnecting: (state) => state.websocket.connecting,
    getCurrentGame: (state) => state.currentGame,
    isShieldActive: (state) => state.shieldMode,
    getChannelPoints: (state) => state.channelPoints,
    getAudioData: (state) => state.audioData,
    getAudioOutput: (state) => state.audioOutputs,
    getAudioOutputs: (state) => state.audioOutputs,
    getSystemInfo: (state) => state.systemInfo,
    isThrottled: (state) => state.throttled,
    getScene: (state) => state.scene,
    getConnections: (state) => state.connections,
    getConnectionData: (state) => state.connectionData,
    getAvailableConnections: (state) => Object.values(state.connectionData),
    getConnectionByType: (state) => {
      return (type: string) => state.connectionData[String(type).toLowerCase()]
    },
    getConnectionAuthUrl: (state) => {
      return (type: string, returnTo: string = window.location.href) => {
        const encodedType = encodeURIComponent(String(type).toLowerCase())
        const encodedReturnTo = encodeURIComponent(returnTo)

        return `http://${location.hostname}:${state.config.webserverPort}/api/connection/auth?type=${encodedType}&returnTo=${encodedReturnTo}`
      }
    },
    getBackendConfig: (state) => state.backendConfig,
    getParsedBackendConfig: (state) => state.parsedBackendConfig,
    getObsSceneData: (state) => state.obsSceneData,
    getTestMode: (state) => state.testMode,
    getVoices: (state) => state.voices,
    getMacros: (state) => state.macros,
    getAutoMacros: (state) => state.autoMacros,
    getVariables: (state) => state.variables,
    getGiveaway: (state) => state.giveaway,
    getYoloboxData: (state) => state.yoloboxData,
    getObsAudioData: (state) => state.obsAudioData,
    getAssets: (state) => state.assets,
    getStatus: (state) => state.status,
    getMusicData: (state) => state.musicData,
    getPrimaryIp: (state) => state.primaryIp,
    getPrimaryIpError: (state) => state.primaryIpError,
    getWifiSettings: (state) => state.wifiSettings,
    getWiredSettings: (state) => state.wiredSettings,
    isNetworkRefreshBusy: (state) => state.networkRefreshBusy,
  },
  actions: {

    setPrimaryIp(ip: string | null) {
      this.primaryIp = ip
      this.$patch(state => state.primaryIp = ip)
    },
    setPrimaryIpError(error: string | null) {
      this.primaryIpError = error
      this.$patch(state => state.primaryIpError = error)
    },
    setWifiSettings(settings: WifiSettingsState) {
      const normalized = {
        ...settings,
        savedNetworks: dedupeWifiNetworks(settings.savedNetworks ?? []),
        scannedNetworks: dedupeWifiNetworks(settings.scannedNetworks ?? []),
      }

      this.wifiSettings = normalized
      this.$patch(state => state.wifiSettings = normalized)
    },
    setWiredSettings(settings: WiredSettingsState) {
      this.wiredSettings = settings
      this.$patch(state => state.wiredSettings = settings)
    },
    async loadPrimaryIpAddress() {
      if (!isTauriRuntime()) return null

      try {
        const ip = await invoke<string>('get_primary_ip_address')
        this.setPrimaryIp(ip)
        this.setPrimaryIpError(null)
        return ip
      } catch (error) {
        this.setPrimaryIp(null)
        this.setPrimaryIpError(String(error))
        return null
      }
    },
    async loadWifiSettings() {
      if (!isTauriRuntime()) return this.wifiSettings

      const settings = await invoke<WifiSettingsState>('get_wifi_settings')
      this.setWifiSettings(settings)
      return settings
    },
    async loadWiredSettings() {
      if (!isTauriRuntime()) return this.wiredSettings

      const settings = await invoke<WiredSettingsState>('get_wired_settings')
      this.setWiredSettings(settings)
      return settings
    },
    async refreshNetworkState() {
      if (!isTauriRuntime()) return

      if (this.networkRefreshBusy) {
        this.networkRefreshQueued = true
        return
      }

      this.networkRefreshBusy = true

      try {
        await Promise.allSettled([
          this.loadPrimaryIpAddress(),
          this.loadWifiSettings(),
          this.loadWiredSettings(),
        ])
      } finally {
        this.networkRefreshBusy = false

        if (this.networkRefreshQueued) {
          this.networkRefreshQueued = false
          void this.refreshNetworkState()
        }
      }
    },
    async startNetworkListener() {
      if (this.networkListener || !isTauriRuntime()) return

      await this.refreshNetworkState()

      this.networkListener = await listen('network-changed', () => {
        void this.refreshNetworkState()
      })
    },
    stopNetworkListener() {
      if (this.networkListener) {
        this.networkListener()
        this.networkListener = null
      }
    },
    async setWifiEnabled(enabled: boolean) {
      if (!isTauriRuntime()) return

      await invoke('set_wifi_enabled', { enabled })
      await this.refreshNetworkState()
    },
    async scanWifiNetworks() {
      if (!isTauriRuntime()) return [] as WifiNetwork[]

      const scannedNetworks = dedupeWifiNetworks(await invoke<WifiNetwork[]>('scan_wifi_networks'))

      this.setWifiSettings({
        ...this.wifiSettings,
        scannedNetworks,
      })

      await this.loadWifiSettings()
      return scannedNetworks
    },
    async connectToWifi(ssid: string, password?: string | null) {
      if (!isTauriRuntime()) return

      await invoke('connect_to_wifi', {
        ssid,
        password: password || null,
      })

      await this.refreshNetworkState()
    },
    async connectHiddenWifi(ssid: string, password?: string | null) {
      if (!isTauriRuntime()) return

      await invoke('connect_hidden_wifi', {
        ssid,
        password: password || null,
      })

      await this.refreshNetworkState()
    },
    async forgetSavedWifi(ssid: string) {
      if (!isTauriRuntime()) return

      await invoke('forget_saved_wifi', { ssid })
      await this.refreshNetworkState()
    },
    async setWiredInterfaceEnabled(interfaceName: string, enabled: boolean) {
      if (!isTauriRuntime()) return

      await invoke('set_wired_interface_enabled', {
        interfaceName,
        enabled,
      })

      await this.refreshNetworkState()
    },
    async fetchConfig() {
      const request = await fetch(`/config.json`, { cache: "no-store" })
      const config = await request.json()

      this.$patch(state => state.config = {
        websocketPort: config.websocket.port,
        webserverPort: config.webserver.port,
      })
    },
    async fetchGames() {
      const request = await fetch(`${this.getRestApi}/api/games/all`, { cache: "no-store" })
      const data = (await request.json()).data

      this.games = data

      this.$patch(state => state.games = data)
    },
    setAlerts(alerts: Alert[]) {
      this.alerts = alerts
      this.$patch(state => state.alerts = alerts)
    },
    setWebsocketConnected(connected: boolean) {
      this.websocket.connected = connected
      this.$patch(state => state.websocket.connected = connected)
    },
    setWebsocketConnecting(connecting: boolean) {
      this.websocket.connecting = connecting
      this.$patch(state => state.websocket.connecting = connecting)
    },
    setCurrentGame(currentGame: any) {
      this.currentGame = currentGame
      this.$patch(state => state.currentGame = currentGame)
    },
    setShieldActive(shieldMode: boolean) {
      this.shieldMode = shieldMode
      this.$patch(state => state.shieldMode = shieldMode)
    },
    setChannelPoints(channelPoints: any) {
      this.channelPoints = channelPoints
      this.$patch(state => state.channelPoints = channelPoints)
    },
    setAudioData(audioData: AudioData) {
      this.audioData = audioData
      this.$patch(state => state.audioData = audioData)
    },
    setAudioOutput(audioOutputs: AudioOutputs) {
      this.audioOutputs = audioOutputs
      this.$patch(state => state.audioOutputs = audioOutputs)
    },
    setAudioOutputs(audioOutputs: AudioOutputs) {
      this.audioOutputs = audioOutputs
      this.$patch(state => state.audioOutputs = audioOutputs)
    },
    setThrottled(throttled: boolean) {
      this.throttled = throttled
      this.$patch(state => state.throttled = throttled)
    },
    setSystemInfo(systemInfo: any) {
      this.systemInfo = systemInfo
      this.$patch(state => state.systemInfo = systemInfo)
    },
    setScene(scene: {}) {
      this.scene = scene
      this.$patch(state => state.scene = scene)
    },
    setConnections(connections: {}) {
      this.connections = connections
      this.$patch(state => state.connections = connections)
    },
    normalizeConnectionData(data: any): ConnectionData {
      const source = data?.connections ?? data
      const normalized: ConnectionData = {}

      if (Array.isArray(source)) {
        for (const item of source) {
          const type = String(item?.type ?? '').toLowerCase()
          if (!type) continue

          normalized[type] = this.normalizeConnectionItem(type, item)
        }

        return normalized
      }

      if (source && typeof source === 'object') {
        for (const [rawType, value] of Object.entries(source)) {
          const type = String((value as any)?.type ?? rawType).toLowerCase()
          if (!type) continue

          normalized[type] = this.normalizeConnectionItem(type, value)
        }
      }

      return normalized
    },
    normalizeConnectionItem(type: string, data: any): ConnectionItem {
      const item = data && typeof data === 'object' ? data : {}
      const authenticated = Boolean(item.authenticated ?? item.connected ?? false)
      const connected = Boolean(item.connected ?? authenticated)

      return {
        ...item,
        type,
        label: item.label ?? this.formatConnectionLabel(type),
        connected,
        authenticated,
        available: item.available ?? true,
        authAvailable: item.authAvailable ?? true,
      }
    },
    formatConnectionLabel(type: string): string {
      if (!type) return 'Unknown'

      return type.charAt(0).toUpperCase() + type.slice(1)
    },
    setConnectionData(data: any) {
      const normalized = this.normalizeConnectionData(data)

      this.connectionData = {
        ...this.connectionData,
        ...normalized,
      }

      this.$patch(state => state.connectionData = this.connectionData)
    },
    setConnection(type: string, data: any) {
      const normalizedType = String(type).toLowerCase()
      if (!normalizedType) return

      this.connectionData[normalizedType] = this.normalizeConnectionItem(normalizedType, data)
      this.$patch(state => state.connectionData = this.connectionData)
    },
    async fetchConnectionData(): Promise<ConnectionData> {
      try {
        const request = await fetch(`${this.getRestApi}/api/connection`, { cache: "no-store" })

        if (!request.ok) {
          console.warn(`connection data request failed: ${request.status}`)
          return this.connectionData
        }

        const contentType = request.headers.get('content-type') ?? ''
        const rawResponse = await request.text()

        if (!contentType.includes('application/json')) {
          console.warn('connection data request did not return JSON')
          return this.connectionData
        }

        const response = JSON.parse(rawResponse)
        const data = response?.data ?? response

        this.setConnectionData(data)
      } catch (error) {
        console.warn(error)
      }

      return this.connectionData
    },
    setBackendConfig(config: string, parsedConfig: any) {
      this.backendConfig = config
      this.parsedBackendConfig = parsedConfig
      this.$patch(state => state.backendConfig = config)
      this.$patch(state => state.parsedBackendConfig = parsedConfig)
    },
    setObsSceneData(obsSceneData: []) {
      this.obsSceneData = obsSceneData
      this.$patch(state => state.obsSceneData = obsSceneData)
    },
    setTestMode(testMode: boolean) {
      this.testMode = testMode
      this.$patch(state => state.testMode = testMode)
    },
    setVoices(voices: []) {
      this.voices = voices
      this.$patch(state => state.voices = voices)
    },
    setMacros(macros: {}) {
      this.macros = macros
      this.$patch(state => state.macros = macros)
    },
    setAutoMacros(autoMacros: AutoMacro[]) {
      this.autoMacros = autoMacros
      this.$patch(state => state.autoMacros = autoMacros)
    },
    setVariables(variables: {}) {
      this.variables = variables
      this.$patch(state => state.variables = variables)
    },
    setGiveaway(giveaway: Giveaway) {
      this.giveaway = giveaway
      this.$patch(state => state.giveaway = giveaway)
    },
    setYoloboxData(yoloboxData: YoloboxData) {
      this.yoloboxData = yoloboxData
      this.$patch(state => state.yoloboxData = yoloboxData)
    },
    setObsAudioData(obsAudioData: {}) {
      this.obsAudioData = obsAudioData
      this.$patch(state => state.obsAudioData = obsAudioData)
    },
    setAssets(assets: []) {
      this.assets = assets
      this.$patch(state => state.assets = assets)
    },
    setStatus(status: any) {
      this.status = status
      this.$patch(state => state.status = status)
    },
    setMusicData(musicData: any) {
      this.musicData = musicData
      this.$patch(state => state.musicData = musicData)
    },
    async fetchStatus(): Promise<any> {
      let status = ''
      try {
        status = (await (await fetch(`${this.getRestApi}/api/status`, { cache: "no-store" })).json()).data
      } catch (error) {
        console.warn(error)
      }

      this.setStatus(status)
      return status
    }
  }
})
