<template>
  <v-card color="grey-darken-4">
    <v-card-title class="d-flex align-center justify-space-between">
      <span>
        {{ songRequestEnabled ? $t('music_playlist.song_requests') : $t('music_playlist.music_playlist') }}
      </span>

      <div class="d-flex align-center ga-2 music-playlist-actions">
        <v-text-field
            v-model="searchQuery"
            class="music-playlist-search mr-3"
            density="compact"
            variant="outlined"
            prepend-inner-icon="mdi-magnify"
            :label="$t('music_playlist.search')"
            clearable
            hide-details
            readonly
        />

        <v-switch
            density="compact"
            :label="$t('music_playlist.song_requests')"
            :model-value="songRequestEnabled"
            hide-details
            @click="toggleSongRequest"
        />

        <v-btn
            icon="mdi-refresh"
            variant="text"
            @click="refreshList"
        />
      </div>
    </v-card-title>

    <v-card-text>
      <v-alert
          v-if="visibleItems.length === 0"
          type="info"
          color="grey-darken-3"
          :text="songRequestEnabled ? $t('music_playlist.no_song_requests') : $t('music_playlist.no_music')"
      />

      <v-list
          v-else
          density="compact"
          bg-color="transparent"
          class="music-playlist-list"
      >
        <v-list-item
            v-for="item in visibleItems"
            :key="getItemKey(item)"
            :title="getFilename(item)"
            :active="isCurrentSong(item)"
            :class="{ 'current-song': isCurrentSong(item) }"
        >
          <template #append>
            <v-btn
                icon="mdi-delete"
                size="small"
                variant="text"
                color="red"
                @click="deleteVisibleItem(item)"
            />
          </template>
        </v-list-item>
      </v-list>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import { mapState } from 'pinia'
import { useAppStore } from '@/stores/app'
import eventBus from '@/eventBus'

export default {

  data() {
    return {
      files: [] as any[],
      loading: false,
      searchQuery: '',
      searchDebounce: null as ReturnType<typeof setTimeout> | null,
    }
  },

  computed: {
    ...mapState(useAppStore, ['getMusicData', 'getWebsocket']),

    music(): any {
      return this.getMusicData ?? {}
    },

    songRequestEnabled(): boolean {
      return this.music?.songrequest?.enabled ?? false
    },

    songRequestItems(): any[] {
      return this.music?.playlist ?? []
    },

    normalizedSearchQuery(): string {
      return this.searchQuery.trim().toLowerCase()
    },

    shouldSearch(): boolean {
      return this.normalizedSearchQuery.length >= 2
    },

    filteredSongRequestItems(): any[] {
      if (!this.shouldSearch) return this.songRequestItems

      return this.songRequestItems.filter((item: any) => {
        const haystack = [
          item?.title,
          item?.filename,
          item?.path,
          item?.requested_by,
          item?.requestedBy,
          item?.user,
        ]
            .filter(Boolean)
            .join(' ')
            .toLowerCase()

        return haystack.includes(this.normalizedSearchQuery)
      })
    },

    visibleItems(): any[] {
      return this.songRequestEnabled
          ? this.filteredSongRequestItems
          : this.files
    },
  },

  watch: {
    searchQuery() {
      this.queueSearchRefresh()
    },

    songRequestEnabled() {
      if (!this.songRequestEnabled) {
        this.queueSearchRefresh(0)
      }
    },
  },

  async mounted() {
    await this.fetchFiles()
  },

  beforeUnmount() {
    if (this.searchDebounce) {
      clearTimeout(this.searchDebounce)
      this.searchDebounce = null
    }
  },

  methods: {
    async refreshList() {
      if (!this.songRequestEnabled) {
        await this.fetchFiles()
      }
    },

    queueSearchRefresh(delay = 250) {
      if (this.searchDebounce) {
        clearTimeout(this.searchDebounce)
        this.searchDebounce = null
      }

      if (this.songRequestEnabled) return

      this.searchDebounce = setTimeout(() => {
        void this.fetchFiles()
      }, delay)
    },

    async fetchFiles() {
      if (!this.getWebsocket) return

      this.loading = true

      try {
        const params = this.shouldSearch
            ? { search: this.searchQuery.trim() }
            : {}

        const response = await this.requestMusicWebsocket('music_playlist', params)
        this.files = response?.files ?? response?.data?.files ?? []
      } finally {
        this.loading = false
      }
    },

    requestMusicWebsocket(method: string, params: Record<string, any> = {}, timeout = 10_000): Promise<any> {
      return new Promise((resolve, reject) => {
        eventBus.$emit('websocket:request', {
          method,
          params,
          timeout,
          resolve,
          reject,
        })
      })
    },

    sendMusicWebsocket(method: string, params: Record<string, any> = {}) {
      eventBus.$emit('websocket:send', {
        method,
        params,
      })
    },

    async toggleSongRequest() {
      await this.requestMusicWebsocket('music_songrequest_toggle')

      if (!this.songRequestEnabled) {
        await this.fetchFiles()
      }
    },

    async deleteVisibleItem(item: any) {
      if (this.songRequestEnabled) {
        await this.deleteSongRequest(item)
        return
      }

      await this.deleteFile(this.getFilename(item))
    },

    async deleteFile(filename: string) {
      await this.requestMusicWebsocket('music_delete', { filename })
      await this.fetchFiles()
    },

    async deleteSongRequest(item: any) {
      await this.requestMusicWebsocket('music_delete', {
        filename: this.getFilename(item),
        path: this.getItemPath(item),
      })
    },

    getFilename(item: any): string {
      const file = item?.filename ?? item?.path ?? ''
      return file.split(/[\\/]/).pop() ?? file
    },

    getItemKey(item: any): string {
      return item?.id ?? item?.filename ?? item?.path ?? this.getFilename(item)
    },

    getItemPath(item: any): string {
      return item?.filename ?? item?.path ?? ''
    },

    getCurrentPath(): string {
      return this.music?.track?.path ?? this.music?.track?.filename ?? ''
    },

    isCurrentSong(item: any): boolean {
      const itemPath = this.getItemPath(item)
      const currentPath = this.getCurrentPath()

      if (!itemPath || !currentPath) return false

      return itemPath === currentPath ||
          this.getFilename(item) === currentPath.split(/[\\/]/).pop()
    },
  },
}
</script>

<style scoped>
.music-playlist-actions {
  min-width: 0;
}

.music-playlist-search {
  width: min(36vw, 360px);
  min-width: 180px;
}

.current-song {
  background: rgba(255, 255, 255, 0.12);
  border-radius: 8px;
}

.music-playlist-list {
  max-height: calc(100vh - 152px);
  overflow-y: auto;
}
</style>