<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { invoke } from '@tauri-apps/api/core'
import SettingsPanel from './panels/SettingsPanel.vue'

type NetworkStatus = {
  ethernetConnected: boolean
  wifiConnected: boolean
  ssid: string | null
  signalPercent: number | null
  quality: string | null
}

type SettingsPanelExposed = {
  open: () => void
  close: () => void
  toggle: () => void
}

const settingsPanel = ref<SettingsPanelExposed | null>(null)

const network = ref<NetworkStatus | null>(null)
const error = ref<string | null>(null)

let intervalId: number | null = null

const wifiIcon = computed(() => {
  if (!network.value?.wifiConnected) {
    return 'mdi-wifi-off'
  }

  const signal = network.value.signalPercent ?? 0

  if (signal >= 75) return 'mdi-wifi-strength-4'
  if (signal >= 50) return 'mdi-wifi-strength-3'
  if (signal >= 25) return 'mdi-wifi-strength-2'
  return 'mdi-wifi-strength-1'
})

const wifiTitle = computed(() => {
  if (error.value) return `Network error: ${error.value}`
  if (!network.value?.wifiConnected) return 'Wi-Fi disconnected'

  const parts = ['Wi-Fi connected']

  if (network.value.ssid) parts.push(network.value.ssid)
  if (network.value.signalPercent !== null) parts.push(`${network.value.signalPercent}%`)
  if (network.value.quality) parts.push(network.value.quality)

  return parts.join(' • ')
})

const ethernetTitle = computed(() => {
  if (error.value) return `Network error: ${error.value}`
  return network.value?.ethernetConnected
      ? 'Ethernet connected'
      : 'Ethernet disconnected'
})

async function refreshNetwork() {
  try {
    network.value = await invoke<NetworkStatus>('get_network_status')
    error.value = null
  } catch (err) {
    error.value = String(err)
  }
}

function toggleSettings() {
  settingsPanel.value?.toggle()
}

onMounted(() => {
  void refreshNetwork()

  intervalId = window.setInterval(() => {
    void refreshNetwork()
  }, 5000)
})

onUnmounted(() => {
  if (intervalId !== null) {
    window.clearInterval(intervalId)
  }
})
</script>

<template>
  <v-app-bar
      height="28"
      density="compact"
      class="header-bar"
      @click="toggleSettings"
  >
    <div class="header-content">
      <div class="header-title-slot">
        <div class="header-title">
          <!---
          Notifications Placeholder or something
          -->
        </div>
      </div>

      <div class="network-icons">
        <div
            class="network-icon"
            :class="{ 'network-icon--inactive': !network?.ethernetConnected }"
            :title="ethernetTitle"
        >
          <v-icon icon="mdi-ethernet" size="16" />
        </div>

        <div
            class="network-icon"
            :class="{ 'network-icon--inactive': !network?.wifiConnected }"
            :title="wifiTitle"
        >
          <v-icon :icon="wifiIcon" size="16" />
        </div>
      </div>
    </div>
  </v-app-bar>

  <SettingsPanel ref="settingsPanel" />
</template>

<style scoped lang="scss">
.header-bar {
  position: relative !important;
  user-select: none;
  cursor: pointer;
}

.header-bar :deep(.v-toolbar__content) {
  height: 28px !important;
  min-height: 28px !important;
  padding: 0 !important;
}

.header-content {
  display: flex;
  align-items: center;
  width: 100%;
  min-width: 0;
  height: 28px;
  padding: 0 8px 0 10px;
}

.header-title-slot {
  flex: 1 1 auto;
  min-width: 0;
  margin-right: 6px;
}

.header-title {
  display: block;
  width: 100%;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  line-height: 1;
  font-size: 0.72rem;
  font-weight: 500;
}

.network-icons {
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 0 0 auto;
  color: white;
}

.network-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
}

.network-icon--inactive {
  opacity: 0.35;
}
</style>