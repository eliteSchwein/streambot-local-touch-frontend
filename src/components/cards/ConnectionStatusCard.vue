<template>
  <v-card class="connection-status-card" elevation="0">
    <v-list density="comfortable" class="connection-status-card__list">
      <v-list-item
          v-for="connection in normalizedConnections"
          :key="connection.key"
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
          {{ connection.subtitle }}
        </v-list-item-subtitle>

        <template #append>
          <v-btn
              size="small"
              variant="tonal"
              :disabled="connection.authAvailable === false"
              @click="openAuth(connection)"
          >
            {{ connection.connected ? $t('recovery.connections.reauth') : $t('recovery.connections.auth') }}
          </v-btn>
        </template>
      </v-list-item>
    </v-list>
  </v-card>
</template>

<script lang="ts">
import { useAppStore } from '@/stores/app'

type ConnectionItem = {
  key: string
  type: string
  authType?: 'control' | 'message'
  label: string
  subtitle: string
  connected: boolean
  authAvailable: boolean
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
    integrations(): any {
      return (this.appStore as any).getIntegrations ?? {}
    },

    connections(): any {
      return (this.appStore as any).getConnections ?? {}
    },

    normalizedConnections(): ConnectionItem[] {
      const baseConnections = this.getBaseConnections()
          .filter((connection: any) => String(connection.type ?? '').toLowerCase() !== 'twitch')
          .map((connection: any) => this.normalizeConnection(connection))

      return [
        this.normalizeTwitchControlConnection(),
        this.normalizeTwitchMessageConnection(),
        ...baseConnections,
      ]
    },
  },

  methods: {
    getBaseConnections(): any[] {
      const availableConnections = (this.appStore as any).getAvailableConnections

      if (Array.isArray(availableConnections)) {
        return availableConnections
      }

      return Object.entries(this.connections ?? {}).map(([type, data]: any) => ({
        type,
        ...(data ?? {}),
      }))
    },

    normalizeTwitchControlConnection(): ConnectionItem {
      const twitchConnection = this.connections?.twitch ?? {}
      const authenticated = Boolean(this.integrations?.twitch?.control)
      const connected = Boolean(twitchConnection.connected ?? twitchConnection.authenticated ?? authenticated)

      return {
        key: 'twitch_control',
        type: 'twitch',
        authType: 'control',
        label: String(this.$t('recovery.connections.twitch_control')),
        subtitle: connected
            ? this.statusText(twitchConnection.message ?? this.$t('recovery.connections.connected'))
            : authenticated
                ? String(this.$t('recovery.connections.authenticated_not_connected'))
                : String(this.$t('recovery.connections.primary_auth_missing')),
        connected,
        authAvailable: true,
      }
    },

    normalizeTwitchMessageConnection(): ConnectionItem {
      const authenticated = Boolean(this.integrations?.twitch?.message)

      return {
        key: 'twitch_message',
        type: 'twitch',
        authType: 'message',
        label: String(this.$t('recovery.connections.twitch_message')),
        subtitle: authenticated
            ? String(this.$t('recovery.connections.authenticated'))
            : String(this.$t('recovery.connections.optional_auth_missing')),
        connected: authenticated,
        authAvailable: true,
      }
    },

    normalizeConnection(connection: any): ConnectionItem {
      const type = String(connection.type ?? '').toLowerCase()
      const connected = Boolean(connection.connected ?? connection.authenticated)

      return {
        ...connection,
        key: type,
        type,
        label: connection.label ?? this.formatLabel(type),
        subtitle: connected
            ? String(this.$t('recovery.connections.connected'))
            : String(this.$t('recovery.connections.not_connected')),
        connected,
        authAvailable: connection.authAvailable ?? true,
      }
    },

    openAuth(connection: ConnectionItem) {
      if (connection.type === 'twitch') {
        const authType = connection.authType ?? 'control'
        const returnTo = encodeURIComponent(this.getRecoveryReturnUrl())

        window.location.href = `${this.appStore.getRestApi}/api/auth/twitch?type=${authType}&returnTo=${returnTo}`
        return
      }

      const getConnectionAuthUrl = (this.appStore as any).getConnectionAuthUrl

      if (typeof getConnectionAuthUrl === 'function') {
        window.location.href = getConnectionAuthUrl(connection.type, this.getRecoveryReturnUrl())
        return
      }

      window.location.href = `${this.appStore.getRestApi}/api/connection/auth?type=${connection.type}&returnTo=${encodeURIComponent(this.getRecoveryReturnUrl())}`
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

    statusText(value: any): string {
      if (!value) return String(this.$t('recovery.connections.connected'))

      return String(value)
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