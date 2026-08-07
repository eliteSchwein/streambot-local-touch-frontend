<script setup lang="ts">
import { computed } from 'vue'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()

const saving = computed(() => appStore.getReloadUpdate?.finished === false)
</script>

<template>
  <v-dialog
      :model-value="saving"
      width="420"
      persistent
      scrim="black"
  >
    <v-card rounded="lg">
      <v-card-text class="saving-dialog__content">
        <v-progress-circular
            indeterminate
            color="primary"
            size="42"
            width="4"
        />

        <div class="text-body-1 font-weight-medium">
          {{ $t('header.saving_please_wait') }}
        </div>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<style scoped>
.saving-dialog__content {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  padding: 24px;
}
</style>
