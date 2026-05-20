<script setup lang="ts">
import { nextTick, onMounted, ref, watch } from 'vue'
import { invoke } from '@tauri-apps/api/core'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  panelOpen: boolean
}>()

type StreambotSettings = {
  language: string
}

const { t, locale } = useI18n()

const loading = ref(false)
const actionBusy = ref(false)
const error = ref<string | null>(null)
const language = ref('en')

const languages = [
  { title: 'English', value: 'en' },
  { title: 'Deutsch', value: 'de' },
]

async function loadLanguageSettings() {
  loading.value = true
  error.value = null
  await nextTick()

  try {
    const settings = await invoke<StreambotSettings>('get_streambot_settings')

    language.value = settings.language
    locale.value = settings.language
  } catch (err) {
    error.value = String(err)
  } finally {
    loading.value = false
  }
}

async function updateLanguage(value: string) {
  const previous = language.value

  language.value = value
  locale.value = value
  actionBusy.value = true
  error.value = null
  await nextTick()

  try {
    const settings = await invoke<StreambotSettings>('set_streambot_language', {
      language: value,
    })

    language.value = settings.language
    locale.value = settings.language
  } catch (err) {
    language.value = previous
    locale.value = previous
    error.value = String(err)
  } finally {
    actionBusy.value = false
  }
}

watch(
    () => props.panelOpen,
    (isOpen, wasOpen) => {
      if (isOpen && !wasOpen) {
        void loadLanguageSettings()
      }
    },
)

onMounted(() => {
  void loadLanguageSettings()
})
</script>

<template>
  <v-card rounded="md" class="language-card" variant="tonal">
    <v-card-text class="pa-3">
      <v-container fluid class="pa-0">
        <v-row no-gutters align="center">
          <v-col cols="auto" class="pr-2">
            <v-icon icon="mdi-translate" />
          </v-col>

          <v-col>
            <div class="text-subtitle-1 font-weight-medium">
              {{ t('settings.language') }}
            </div>
            <div class="text-body-2 text-medium-emphasis">
              {{ t('settings.language_subtitle') }}
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

        <v-row no-gutters class="mt-3">
          <v-col cols="12">
            <v-select
                v-model="language"
                :items="languages"
                item-title="title"
                item-value="value"
                variant="outlined"
                density="compact"
                hide-details
                :loading="loading || actionBusy"
                :disabled="loading || actionBusy"
                @update:model-value="updateLanguage"
            />
          </v-col>
        </v-row>
      </v-container>
    </v-card-text>
  </v-card>
</template>

<style scoped lang="scss">
.language-card {
  margin-top: 16px;
  box-shadow: var(--v-shadow-3);
}
</style>