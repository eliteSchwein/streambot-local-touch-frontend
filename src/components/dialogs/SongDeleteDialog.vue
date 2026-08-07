<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()

const props = defineProps<{
  modelValue: boolean
  song: any | null
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'confirm'): void
}>()

const dialogOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
})

const filename = computed(() => {
  const file = props.song?.filename ?? props.song?.path ?? ''
  return String(file).split(/[\\/]/).pop() ?? String(file)
})

function closeDialog() {
  if (props.loading) return
  dialogOpen.value = false
}
</script>

<template>
  <v-dialog
      v-model="dialogOpen"
      max-width="620"
      persistent
  >
    <v-card rounded="lg">
      <v-card-title>
        {{ t('music_playlist.delete_title') }}
      </v-card-title>

      <v-card-text>
        {{ t('music_playlist.delete_question', { song: filename }) }}
      </v-card-text>

      <v-card-actions>
        <v-spacer />

        <v-btn
            variant="text"
            :disabled="loading"
            @click="closeDialog"
        >
          {{ t('music_playlist.cancel') }}
        </v-btn>

        <v-btn
            color="error"
            :loading="loading"
            :disabled="loading"
            @click="emit('confirm')"
        >
          {{ t('music_playlist.delete') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
