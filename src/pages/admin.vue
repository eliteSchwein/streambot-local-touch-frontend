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
  <div class="admin-page">
    <v-card class="admin-card" rounded="xl">
      <v-card-text class="admin-card-content">
        <div class="admin-header">
          <v-icon icon="mdi-qrcode" size="30" />
          <div class="admin-header-text">
            <div class="admin-title">
              {{ t('remote.title') }}
            </div>
            <div class="admin-subtitle">
              {{ t('remote.subtitle') }}
            </div>
          </div>
        </div>

        <div class="qr-shell">
          <QrcodeVue
              v-if="remoteIp"
              :value="targetAddress"
              :size="220"
              level="M"
              render-as="svg"
          />

          <v-icon
              v-else
              icon="mdi-wifi-alert"
              size="88"
              class="qr-placeholder"
          />
        </div>

        <div class="target-address" :title="targetAddress">
          {{ targetAddress }}
        </div>

        <v-alert
            v-if="error"
            type="warning"
            density="compact"
            variant="tonal"
            class="admin-alert"
        >
          {{ t('remote.ip_error') }}
        </v-alert>
      </v-card-text>
    </v-card>
  </div>
</template>

<style scoped lang="scss">
.admin-page {
  position: fixed;
  top: 0;
  right: 0;
  bottom: 15px;
  left: 0;
  display: grid;
  place-items: center;
  padding: 16px;
  overflow: hidden;
}

.admin-card {
  width: min(390px, calc(100vw - 32px));
  max-height: calc(100vh - 128px);
  overflow: hidden;
  backdrop-filter: blur(10px);
}

.admin-card-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  padding: 22px !important;
}

.admin-header {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
}

.admin-header-text {
  min-width: 0;
}

.admin-title {
  font-size: 1.1rem;
  font-weight: 700;
  line-height: 1.15;
}

.admin-subtitle {
  margin-top: 4px;
  font-size: 0.8rem;
  line-height: 1.25;
  opacity: 0.72;
}

.qr-shell {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 180px;
  height: 180px;
  padding: 0;
}

.qr-shell :deep(svg) {
  display: block;
  width: 220px;
  height: 220px;
}

.qr-placeholder {
  opacity: 0.45;
}

.target-address {
  max-width: 100%;
  padding: 9px 14px;
  border-radius: 999px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.78rem;
  background: rgba(var(--v-theme-primary), 0.12);
  color: rgb(var(--v-theme-primary));
}

.admin-alert {
  width: 100%;
}
</style>
