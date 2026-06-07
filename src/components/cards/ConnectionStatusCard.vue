<template>
  <v-card class="connection-status-card" elevation="0">
    <v-list density="comfortable" class="connection-status-card__list">
      <v-list-item
          v-for="connection in normalizedConnections"
          :key="connection.type"
      >
        <template #prepend>
          <v-icon
              :icon="connection.connected ? 'mdi-check-circle' : 'mdi-close-circle'"
              :color="connection.connected ? 'success' : 'error'"
          />
        </template>

        <v-list-item-title>
          {{ connection.label }}
        </v-list-item-title>

        <v-list-item-subtitle>
          {{ connection.connected ? $t('recovery.connections.connected') : $t('recovery.connections.not_connected') }}
        </v-list-item-subtitle>

        <template #append>
          <v-btn
              size="small"
              variant="tonal"
              :disabled="connection.authAvailable === false"
              @click="openAuth(connection.type)"
          >
            {{ $t('recovery.connections.auth') }}
          </v-btn>
        </template>
      </v-list-item>
    </v-list>
  </v-card>
</template>

<script lang="ts">
import { useAppStore } from '@/stores/app'

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

export default {
  name: 'ConnectionStatusCard',
  data() {
    return {
      appStore: useAppStore(),
    }
  },
  computed: {
    normalizedConnections(): ConnectionItem[] {
      const connections = this.appStore.getAvailableConnections as ConnectionItem[]

      return connections.map((connection: ConnectionItem) => {
        const type = String(connection.type ?? '').toLowerCase()
        const connected = Boolean(connection.connected ?? connection.authenticated)

        return {
          ...connection,
          type,
          label: connection.label ?? this.formatLabel(type),
          connected,
          authAvailable: connection.authAvailable ?? true,
        }
      })
    },
  },
  methods: {
    openAuth(type: string) {
      window.location.href = this.appStore.getConnectionAuthUrl(type, this.getRecoveryReturnUrl())
    },
    getRecoveryReturnUrl(): string {
      const recoveryPath = window.location.pathname.startsWith('/commander')
          ? '/commander/recovery'
          : '/recovery'

      return `${window.location.origin}${recoveryPath}`
    },
    formatLabel(type: string): string {
      if (!type) return String(this.$t('recovery.connections.unknown'))

      return type.charAt(0).toUpperCase() + type.slice(1)
    },
  },
}
</script>

<style lang="scss" scoped>
.connection-status-card {
  width: 100%;

  &__list {
    background: transparent;
  }
}
</style>
