<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

type WifiNetwork = {
  ssid: string
  secured: boolean
  saved: boolean
  signalPercent: number | null
}

const { t } = useI18n()

const props = defineProps<{
  modelValue: boolean
  network: WifiNetwork | null
  hidden?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'submit', payload: { ssid: string; password: string }): void
}>()

const localSsid = ref('')
const localPassword = ref('')
const revealPassword = ref(false)

const activeField = ref<'ssid' | 'password' | null>(null)

const dialogOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const isSecured = computed(() => Boolean(props.hidden || props.network?.secured))
const isSavedNetwork = computed(() => Boolean(props.network?.saved && !props.hidden))

const submitLabel = computed(() => {
  if (isSavedNetwork.value && !localPassword.value.trim()) {
    return t('network.connect')
  }

  return t('network.connect')
})

watch(
    () => [props.modelValue, props.network, props.hidden] as const,
    ([open]) => {
      if (!open) return

      localSsid.value = props.hidden ? '' : (props.network?.ssid ?? '')
      localPassword.value = ''
      revealPassword.value = false
      activeField.value = props.hidden ? 'ssid' : null
    },
    { immediate: true },
)

function closeDialog() {
  dialogOpen.value = false
  activeField.value = null
}

function submit() {
  const ssid = localSsid.value.trim()
  if (!ssid) return

  emit('submit', {
    ssid,
    password: localPassword.value,
  })
}
</script>

<template>
  <v-dialog v-model="dialogOpen" max-width="900" persistent>
    <v-card rounded="lg">
      <v-card-title>
        {{
          hidden
              ? t('network.wifi.hidden')
              : t('network.wifi.connect_to', { ssid: network?.ssid ?? '' })
        }}
      </v-card-title>

      <v-card-text class="wifi-dialog__content">
        <div class="wifi-dialog__fields">
          <v-text-field
              v-model="localSsid"
              :label="t('network.wifi.ssid')"
              variant="outlined"
              density="comfortable"
              :readonly="true"
          />

          <v-text-field
              v-if="isSecured"
              v-model="localPassword"
              :label="t('network.wifi.password')"
              :type="revealPassword ? 'text' : 'password'"
              variant="outlined"
              density="comfortable"
              :readonly="true"
              :append-inner-icon="revealPassword ? 'mdi-eye-off' : 'mdi-eye'"
              :hint="isSavedNetwork ? t('network.wifi.empty_saved') : undefined"
              :persistent-hint="isSavedNetwork"
              @click:append-inner.stop="revealPassword = !revealPassword"
          />
        </div>
      </v-card-text>

      <v-card-actions>
        <v-spacer />

        <v-btn variant="text" @click="closeDialog">
          {{ t('network.cancel') }}
        </v-btn>

        <v-btn
            color="primary"
            :disabled="!localSsid.trim()"
            @click="submit"
        >
          {{ submitLabel }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<style scoped>
.wifi-dialog__content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.wifi-dialog__fields {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
</style>