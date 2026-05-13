<script setup lang="ts">
import { nextTick, onMounted, ref, watch } from 'vue'
import { invoke } from '@tauri-apps/api/core'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  panelOpen: boolean
}>()

type WiredInterface = {
  interfaceName: string
  connected: boolean
  ip: string | null
}

type WiredSettingsState = {
  interfaces: WiredInterface[]
}

const { t } = useI18n()

const loading = ref(false)
const actionBusy = ref(false)
const actionKey = ref<string | null>(null)
const error = ref<string | null>(null)

const wired = ref<WiredSettingsState>({
  interfaces: [],
})

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

function interfaceSubtitle(item: WiredInterface) {
  if (item.connected) {
    return item.ip
        ? `${t('network.wired.connected')} [${item.ip}]`
        : t('network.wired.connected')
  }

  return t('network.wired.disconnected')
}

async function loadWiredSettings() {
  loading.value = true
  error.value = null
  await nextTick()

  try {
    wired.value = await invoke<WiredSettingsState>('get_wired_settings')
  } catch (err) {
    error.value = String(err)
  } finally {
    loading.value = false
  }
}

async function toggleInterface(item: WiredInterface, value: boolean | null) {
  const enabled = Boolean(value)
  const previous = item.connected

  item.connected = enabled
  setBusy(item.interfaceName)
  error.value = null
  await nextTick()

  try {
    await invoke('set_wired_interface_enabled', {
      interfaceName: item.interfaceName,
      enabled,
    })

    await loadWiredSettings()
  } catch (err) {
    item.connected = previous
    error.value = String(err)
  } finally {
    clearBusy()
  }
}

watch(
    () => props.panelOpen,
    (isOpen, wasOpen) => {
      if (isOpen && !wasOpen) {
        void loadWiredSettings()
      }
    },
)

onMounted(() => {
  void loadWiredSettings()
})
</script>

<template>
  <v-card rounded="md" class="wired-card" variant="tonal">
    <v-card-text class="pa-3">
      <v-container fluid class="pa-0">
        <v-row no-gutters align="center">
          <v-col cols="auto" class="pr-2">
            <v-icon icon="mdi-ethernet" />
          </v-col>

          <v-col>
            <div class="text-subtitle-1 font-weight-medium">
              {{ t('network.wired.title') }}
            </div>
            <div class="text-body-2 text-medium-emphasis">
              {{ wired.interfaces.length === 0 ? t('network.wired.no_interfaces') : t('network.wired.interface_count') + wired.interfaces.length }}
            </div>
          </v-col>
        </v-row>

        <v-row v-if="error" no-gutters class="mt-3">
          <v-col cols="12">
            <v-alert type="error" variant="tonal" density="compact">
              {{ error }}
            </v-alert>
          </v-col>
        </v-row>

        <v-row class="mt-3" density="compact">
          <v-col
              v-for="item in wired.interfaces"
              :key="item.interfaceName"
              cols="12"
              class="py-1"
          >
            <v-card rounded="md" variant="flat" class="wired-item">
              <v-card-text class="py-2 px-3">
                <v-row no-gutters align="center">
                  <v-col cols="auto" class="pr-2">
                    <v-icon :color="item.connected ? 'success' : undefined" icon="mdi-ethernet" />
                  </v-col>

                  <v-col>
                    <div class="text-body-1 font-weight-medium">
                      {{ item.interfaceName }}
                    </div>
                    <div class="text-body-2 text-medium-emphasis">
                      {{ interfaceSubtitle(item) }}
                    </div>
                  </v-col>

                  <v-col cols="auto">
                    <v-switch
                        :model-value="item.connected"
                        inset
                        hide-details
                        :loading="busyFor(item.interfaceName)"
                        :disabled="actionBusy && !busyFor(item.interfaceName)"
                        :color="item.connected ? 'primary' : undefined"
                        @update:model-value="toggleInterface(item, $event)"
                    />
                  </v-col>
                </v-row>
              </v-card-text>
            </v-card>
          </v-col>

          <v-col
              v-if="wired.interfaces.length === 0 && !loading"
              cols="12"
              class="py-1"
          >
            <v-card rounded="md" variant="flat">
              <v-card-text class="text-medium-emphasis py-3">
                {{ t('network.wired.no_interfaces') }}
              </v-card-text>
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </v-card-text>
  </v-card>
</template>

<style scoped lang="scss">
.wired-card {
  box-shadow: var(--v-shadow-3);
}

.wired-item {
  box-shadow: none !important;
}
</style>
