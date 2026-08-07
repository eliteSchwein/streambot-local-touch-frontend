<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import QrcodeVue from 'qrcode.vue'
import { useAppStore } from '@/stores/app'

const { t } = useI18n()
const appStore = useAppStore()

const remoteIp = computed(() => appStore.getPrimaryIp)
const error = computed(() => appStore.getPrimaryIpError)

const targetAddress = computed(() => {
  return remoteIp.value
      ? `http://${remoteIp.value}:8105/commander`
      : 'http://—:8105/commander'
})
</script>

<template>
  <v-card rounded="md" variant="tonal" class="admin-settings-card">
    <v-card-text class="pa-3">
      <div class="admin-settings-card__body">
        <div class="admin-settings-card__qr">
          <QrcodeVue
              v-if="remoteIp"
              :value="targetAddress"
              :size="116"
              level="M"
              render-as="svg"
          />

          <v-icon
              v-else
              icon="mdi-wifi-alert"
              size="52"
              class="admin-settings-card__placeholder"
          />
        </div>

        <div class="admin-settings-card__description text-body-2 text-medium-emphasis">
          {{ t('remote.subtitle') }}
        </div>
      </div>

      <div class="admin-settings-card__address">
        {{ targetAddress }}
      </div>

      <v-alert
          v-if="error"
          type="warning"
          density="compact"
          variant="tonal"
          class="mt-2"
      >
        {{ t('remote.ip_error') }}
      </v-alert>
    </v-card-text>
  </v-card>
</template>

<style scoped lang="scss">
.admin-settings-card__body {
  display: flex;
  align-items: center;
  gap: 14px;
  min-width: 0;
}

.admin-settings-card__qr {
  display: flex;
  flex: 0 0 116px;
  align-items: center;
  justify-content: center;
  width: 116px;
  height: 116px;
  overflow: hidden;
  background: white;
}

.admin-settings-card__qr :deep(svg) {
  display: block;
  width: 116px;
  height: 116px;
}

.admin-settings-card__placeholder {
  color: rgb(var(--v-theme-surface));
  opacity: 0.55;
}

.admin-settings-card__description {
  flex: 1 1 auto;
  min-width: 0;
  line-height: 1.35;
}

.admin-settings-card__address {
  width: 100%;
  margin-top: 12px;
  padding: 8px 10px;
  border-radius: 8px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.76rem;
  line-height: 1.35;
  overflow-wrap: anywhere;
  word-break: break-word;
  background: rgba(var(--v-theme-primary), 0.12);
  color: rgb(var(--v-theme-primary));
}

@media (max-width: 420px) {
  .admin-settings-card__body {
    align-items: flex-start;
  }

  .admin-settings-card__qr {
    flex-basis: 104px;
    width: 104px;
    height: 104px;
  }

  .admin-settings-card__qr :deep(svg) {
    width: 104px;
    height: 104px;
  }
}
</style>
