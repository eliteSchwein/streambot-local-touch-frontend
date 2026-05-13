<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import { invoke } from '@tauri-apps/api/core'
import { useI18n } from 'vue-i18n'
import WifiNetworkDialog from '../dialogs/WifiNetworkDialog.vue'
import KeyboardOverlay from '../overlays/KeyboardOverlay.vue'

const props = defineProps<{
  panelOpen: boolean
}>()

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

const { t } = useI18n()

const loading = ref(false)
const scanning = ref(false)
const actionBusy = ref(false)
const actionKey = ref<string | null>(null)
const error = ref<string | null>(null)
const availableFilter = ref('')
const filterKeyboardVisible = ref(false)

const wifi = ref<WifiSettingsState>({
  enabled: false,
  connectedSsid: null,
  connectedIp: null,
  savedNetworks: [],
  scannedNetworks: [],
})

const dialogOpen = ref(false)
const hiddenMode = ref(false)
const selectedNetwork = ref<WifiNetwork | null>(null)

const statusText = computed(() => {
  if (!wifi.value.enabled) return t('network.wifi.disabled')

  if (wifi.value.connectedSsid) {
    return wifi.value.connectedIp
        ? `${t('network.wifi.connected_to', { ssid: wifi.value.connectedSsid })} [${wifi.value.connectedIp}]`
        : t('network.wifi.connected_to', { ssid: wifi.value.connectedSsid })
  }

  return t('network.wifi.not_connected')
})

const filteredScannedNetworks = computed(() => {
  const query = availableFilter.value.trim().toLowerCase()

  if (!query) return wifi.value.scannedNetworks

  return wifi.value.scannedNetworks.filter((network) =>
      network.ssid.toLowerCase().includes(query),
  )
})

const availableListScrollable = computed(() => filteredScannedNetworks.value.length > 5)

const filterKeyboardTitle = computed(() => t('network.wifi.filter_ssid'))


function openFilterKeyboard() {
  if (!wifi.value.enabled) return
  filterKeyboardVisible.value = true
}

function closeFilterKeyboard() {
  filterKeyboardVisible.value = false
}

function submitFilterKeyboard() {
  filterKeyboardVisible.value = false
}

function sortNetworks(items: WifiNetwork[]) {
  return [...items].sort((a, b) => {
    const signalDiff = (b.signalPercent ?? -1) - (a.signalPercent ?? -1)
    if (signalDiff !== 0) return signalDiff

    return a.ssid.localeCompare(b.ssid, undefined, { sensitivity: 'base' })
  })
}

function dedupeNetworks(items: WifiNetwork[]) {
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

  return sortNetworks([...bySsid.values()])
}

function applyWifiState(state: WifiSettingsState) {
  wifi.value = {
    ...state,
    savedNetworks: dedupeNetworks(state.savedNetworks),
    scannedNetworks: dedupeNetworks(state.scannedNetworks),
  }
}

function signalIcon(signalPercent: number | null, secured: boolean) {
  if (secured) return 'mdi-wifi-lock'
  return signalPercent !== null && signalPercent >= 1 ? 'mdi-wifi' : 'mdi-wifi-off'
}

function networkMetaParts(network: WifiNetwork) {
  const parts: Array<{ text: string; connected?: boolean; saved?: boolean }> = []

  if (wifi.value.connectedSsid === network.ssid) {
    parts.push({ text: t('network.wifi.connected'), connected: true })
  }

  if (network.saved) {
    parts.push({ text: t('network.wifi.saved'), saved: true })
  } else {
    parts.push({ text: network.secured ? t('network.wifi.secured') : t('network.wifi.open') })
  }

  if (network.signalPercent !== null) {
    parts.push({ text: `${network.signalPercent}%` })
  }

  return parts
}

function setBusy(key: string) {
  actionBusy.value = true
  actionKey.value = key
}

function clearBusy() {
  actionBusy.value = false
  actionKey.value = null
}

function busyFor(key: string) {
  return actionBusy.value && actionKey.value === key
}

async function loadWifiSettings() {
  loading.value = true
  error.value = null
  await nextTick()

  try {
    const state = await invoke<WifiSettingsState>('get_wifi_settings')
    applyWifiState(state)
  } catch (err) {
    error.value = String(err)
  } finally {
    loading.value = false
  }
}

async function refreshAvailableNetworks(silent = false) {
  if (!wifi.value.enabled) {
    wifi.value.scannedNetworks = []
    return
  }

  if (!silent) {
    scanning.value = true
    await nextTick()
  }

  error.value = null

  try {
    const scannedNetworks = await invoke<WifiNetwork[]>('scan_wifi_networks')
    wifi.value.scannedNetworks = dedupeNetworks(scannedNetworks)
  } catch (err) {
    error.value = String(err)
  } finally {
    if (!silent) {
      scanning.value = false
    }
  }
}

async function toggleWifiEnabled(value: boolean | null) {
  const enabled = Boolean(value)
  const previous = wifi.value.enabled

  wifi.value.enabled = enabled
  error.value = null
  await nextTick()

  try {
    await invoke('set_wifi_enabled', { enabled })
    await loadWifiSettings()

    if (enabled) {
      await refreshAvailableNetworks(true)
    } else {
      wifi.value.scannedNetworks = []
      availableFilter.value = ''
      closeFilterKeyboard()
    }
  } catch (err) {
    wifi.value.enabled = previous
    error.value = String(err)
  }
}

function openNetworkDialog(network: WifiNetwork) {
  selectedNetwork.value = network
  hiddenMode.value = false
  dialogOpen.value = true
}

function openHiddenDialog() {
  selectedNetwork.value = null
  hiddenMode.value = true
  dialogOpen.value = true
}

async function connectSavedNetwork(network: WifiNetwork) {
  setBusy(`connect-${network.ssid}`)
  error.value = null
  await nextTick()

  try {
    await invoke('connect_to_wifi', {
      ssid: network.ssid,
      password: null,
    })

    await loadWifiSettings()

    if (wifi.value.enabled) {
      await refreshAvailableNetworks(true)
    }
  } catch (err) {
    error.value = String(err)
  } finally {
    clearBusy()
  }
}

async function forgetSavedNetwork(network: WifiNetwork) {
  setBusy(`forget-${network.ssid}`)
  error.value = null
  await nextTick()

  try {
    await invoke('forget_saved_wifi', {
      ssid: network.ssid,
    })

    await loadWifiSettings()

    if (wifi.value.enabled) {
      await refreshAvailableNetworks(true)
    }
  } catch (err) {
    error.value = String(err)
  } finally {
    clearBusy()
  }
}

async function submitDialog(payload: { ssid: string; password: string }) {
  const ssid = payload.ssid.trim()
  const password = payload.password.trim() ? payload.password : null

  if (!ssid) return

  setBusy(hiddenMode.value ? 'hidden' : `connect-${ssid}`)
  error.value = null
  await nextTick()

  try {
    await invoke(hiddenMode.value ? 'connect_hidden_wifi' : 'connect_to_wifi', {
      ssid,
      password,
    })

    dialogOpen.value = false
    await loadWifiSettings()

    if (wifi.value.enabled) {
      await refreshAvailableNetworks(true)
    }
  } catch (err) {
    error.value = String(err)
  } finally {
    clearBusy()
  }
}

watch(
    () => props.panelOpen,
    (isOpen, wasOpen) => {
      if (isOpen && !wasOpen) {
        void loadWifiSettings()

        if (wifi.value.enabled) {
          void refreshAvailableNetworks(true)
        }
      }

      if (!isOpen) {
        closeFilterKeyboard()
      }
    },
)

onMounted(() => {
  void loadWifiSettings()
})
</script>

<template>
  <v-card rounded="md" class="wifi-card" variant="tonal">
    <v-card-text class="pa-3">
      <v-container fluid class="pa-0">
        <v-row no-gutters align="center">
          <v-col cols="auto" class="pr-2">
            <v-icon icon="mdi-wifi" />
          </v-col>

          <v-col>
            <div class="text-subtitle-1 font-weight-medium">
              {{ t('network.wifi.title') }}
            </div>
            <div class="text-body-2 text-medium-emphasis">
              {{ statusText }}
            </div>
          </v-col>

          <v-col cols="auto" class="mr-1">
            <v-btn
                icon
                variant="text"
                size="small"
                :disabled="!wifi.enabled"
                :loading="scanning"
                @click="refreshAvailableNetworks()"
            >
              <v-icon icon="mdi-refresh" />
            </v-btn>
          </v-col>

          <v-col cols="auto" class="mr-1">
            <v-btn
                icon
                variant="text"
                size="small"
                :disabled="!wifi.enabled || actionBusy"
                @click="openHiddenDialog"
            >
              <v-icon icon="mdi-wifi-plus" />
            </v-btn>
          </v-col>

          <v-col cols="auto">
            <v-switch
                :model-value="wifi.enabled"
                inset
                hide-details
                :disabled="actionBusy"
                :color="wifi.enabled ? 'primary' : undefined"
                @update:model-value="toggleWifiEnabled"
            />
          </v-col>
        </v-row>

        <v-row v-if="error" no-gutters class="mt-3">
          <v-col cols="12">
            <v-alert type="error" variant="tonal" density="compact">
              {{ error }}
            </v-alert>
          </v-col>
        </v-row>

        <template v-if="wifi.enabled">
          <v-row no-gutters class="mt-3 mb-2">
            <v-col cols="12">
              <div class="text-subtitle-2 font-weight-medium mb-2">
                {{ t('network.wifi.available_networks') }}
              </div>

              <v-text-field
                  v-model="availableFilter"
                  variant="outlined"
                  density="compact"
                  hide-details
                  readonly
                  prepend-inner-icon="mdi-magnify"
                  :label="t('network.wifi.filter_ssid')"
                  @click="openFilterKeyboard"
                  @click:control="openFilterKeyboard"
                  @click:prepend-inner="openFilterKeyboard"
                  @focus="openFilterKeyboard"
                  @pointerdown.prevent="openFilterKeyboard"
              />
            </v-col>
          </v-row>

          <div
              class="available-networks"
              :class="{ 'available-networks--scrollable': availableListScrollable }"
          >
            <v-row density="compact" class="mt-1">
              <v-col
                  v-for="networkItem in filteredScannedNetworks"
                  :key="`scan-${networkItem.ssid}`"
                  cols="12"
                  class="py-1"
              >
                <v-card
                    rounded="md"
                    variant="flat"
                    class="network-item"
                    @click="openNetworkDialog(networkItem)"
                >
                  <v-card-text class="py-2 px-3">
                    <v-row no-gutters align="center">
                      <v-col cols="auto" class="pr-2">
                        <v-icon :icon="signalIcon(networkItem.signalPercent, networkItem.secured)" />
                      </v-col>

                      <v-col>
                        <div class="text-body-1 font-weight-medium">
                          {{ networkItem.ssid }}
                        </div>
                        <div class="text-body-2 text-medium-emphasis">
                          <template
                              v-for="(part, index) in networkMetaParts(networkItem)"
                              :key="`${networkItem.ssid}-${part.text}-${index}`"
                          >
                            <span :class="{ 'text-success': part.connected || part.saved }">
                              {{ part.text }}
                            </span>
                            <span v-if="index < networkMetaParts(networkItem).length - 1"> • </span>
                          </template>
                        </div>
                      </v-col>

                      <v-col
                          v-if="networkItem.saved && wifi.connectedSsid !== networkItem.ssid"
                          cols="auto"
                      >
                        <v-btn
                            icon
                            variant="text"
                            size="small"
                            :loading="busyFor(`connect-${networkItem.ssid}`)"
                            :disabled="actionBusy && !busyFor(`connect-${networkItem.ssid}`)"
                            @click.stop="connectSavedNetwork(networkItem)"
                        >
                          <v-icon icon="mdi-check" />
                        </v-btn>
                      </v-col>

                      <v-col cols="auto">
                        <v-btn
                            icon
                            variant="text"
                            size="small"
                            :disabled="actionBusy"
                            @click.stop="openNetworkDialog(networkItem)"
                        >
                          <v-icon :icon="networkItem.saved ? 'mdi-pencil' : 'mdi-plus'" />
                        </v-btn>
                      </v-col>
                    </v-row>
                  </v-card-text>
                </v-card>
              </v-col>

              <v-col
                  v-if="filteredScannedNetworks.length === 0 && !loading"
                  cols="12"
                  class="py-1"
              >
                <v-card rounded="md" variant="flat">
                  <v-card-text class="text-medium-emphasis py-3">
                    {{ availableFilter ? t('network.wifi.no_matching_networks') : t('network.wifi.no_networks') }}
                  </v-card-text>
                </v-card>
              </v-col>
            </v-row>
          </div>
        </template>

        <v-row class="mt-3">
          <v-col cols="12">
            <v-expansion-panels variant="accordion" elevation="0">
              <v-expansion-panel rounded="md" class="saved-panel">
                <v-expansion-panel-title>
                  {{ t('network.wifi.saved_networks') }}
                </v-expansion-panel-title>

                <v-expansion-panel-text>
                  <template v-if="wifi.savedNetworks.length === 0">
                    <div class="px-5 py-3">
                      {{ t('network.wifi.no_saved_networks') }}
                    </div>
                  </template>
                  <template v-else>
                    <div class="pa-3">
                      <v-row density="compact">
                        <v-col
                            v-for="networkItem in wifi.savedNetworks"
                            :key="`saved-${networkItem.ssid}`"
                            cols="12"
                            class="py-1"
                        >
                          <v-card rounded="md" variant="flat" class="saved-network-item">
                            <v-card-text class="py-2 px-3">
                              <v-row no-gutters align="center">
                                <v-col cols="auto" class="pr-2">
                                  <v-icon :icon="signalIcon(networkItem.signalPercent, networkItem.secured)" />
                                </v-col>

                                <v-col>
                                  <div class="text-body-1 font-weight-medium">
                                    {{ networkItem.ssid }}
                                  </div>
                                  <div class="text-body-2 text-medium-emphasis">
                                    <template
                                        v-for="(part, index) in networkMetaParts(networkItem)"
                                        :key="`${networkItem.ssid}-${part.text}-${index}`"
                                    >
                                      <span :class="{ 'text-success': part.connected || part.saved }">
                                        {{ part.text }}
                                      </span>
                                      <span v-if="index < networkMetaParts(networkItem).length - 1"> • </span>
                                    </template>
                                  </div>
                                </v-col>

                                <v-col cols="auto">
                                  <v-btn
                                      icon
                                      variant="text"
                                      size="small"
                                      :loading="busyFor(`connect-${networkItem.ssid}`)"
                                      :disabled="actionBusy && !busyFor(`connect-${networkItem.ssid}`)"
                                      @click.stop="connectSavedNetwork(networkItem)"
                                  >
                                    <v-icon icon="mdi-wifi-check" />
                                  </v-btn>
                                </v-col>

                                <v-col cols="auto">
                                  <v-btn
                                      icon
                                      variant="text"
                                      size="small"
                                      color="error"
                                      :loading="busyFor(`forget-${networkItem.ssid}`)"
                                      :disabled="actionBusy && !busyFor(`forget-${networkItem.ssid}`)"
                                      @click.stop="forgetSavedNetwork(networkItem)"
                                  >
                                    <v-icon icon="mdi-delete-outline" />
                                  </v-btn>
                                </v-col>
                              </v-row>
                            </v-card-text>
                          </v-card>
                        </v-col>
                      </v-row>
                    </div>
                  </template>
                </v-expansion-panel-text>
              </v-expansion-panel>
            </v-expansion-panels>
          </v-col>
        </v-row>
      </v-container>
    </v-card-text>
  </v-card>

  <WifiNetworkDialog
      v-model="dialogOpen"
      :network="selectedNetwork"
      :hidden="hiddenMode"
      @submit="submitDialog"
  />

  <KeyboardOverlay
      v-model="availableFilter"
      :visible="filterKeyboardVisible"
      :title="filterKeyboardTitle"
      layout="default"
      @enter="submitFilterKeyboard"
      @close="closeFilterKeyboard"
  />
</template>

<style scoped lang="scss">
.wifi-card {
  box-shadow: var(--v-shadow-3);
}

.available-networks--scrollable {
  max-height: 360px;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 2px;
}

.network-item,
.saved-network-item {
  cursor: pointer;
}

.saved-network-item,
.saved-panel {
  box-shadow: none !important;
}

:deep(.v-expansion-panel-text__wrapper) {
  padding: 8px 0 0 0 !important;
}
</style>
