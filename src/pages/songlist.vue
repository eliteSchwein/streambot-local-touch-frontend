<template>
  <v-card color="grey-darken-4">
    <v-card-title class="d-flex align-center justify-space-between">
      <span>
        {{ songRequestEnabled ? $t('music_playlist.song_requests') : $t('music_playlist.music_playlist') }}
      </span>

      <div class="d-flex align-center ga-2">
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

export default {
  data() {
    return {
      files: [] as any[],
      loading: false,
    }
  },

  computed: {
    ...mapState(useAppStore, ['getRestApi', 'getMusicData']),

    music(): any {
      return this.getMusicData ?? {}
    },

    songRequestEnabled(): boolean {
      return this.music?.songrequest?.enabled ?? false
    },

    songRequestItems(): any[] {
      return this.music?.playlist ?? []
    },

    visibleItems(): any[] {
      return this.songRequestEnabled
          ? this.songRequestItems
          : this.files
    },
  },

  async mounted() {
    await this.fetchFiles()
  },

  methods: {
    async refreshList() {
      if (!this.songRequestEnabled) {
        await this.fetchFiles()
      }
    },

    async fetchFiles() {
      this.loading = true

      try {
        const request = await fetch(`${this.getRestApi}/api/music/playlist`, {
          cache: 'no-store',
        })

        const response = await request.json()
        this.files = response?.data?.files ?? []
      } finally {
        this.loading = false
      }
    },

    async toggleSongRequest() {
      await fetch(`${this.getRestApi}/api/music/songrequest/toggle`, {
        method: 'POST',
      })
    },

    async deleteVisibleItem(item: any) {
      if (this.songRequestEnabled) {
        await this.deleteSongRequest(item)
        return
      }

      await this.deleteFile(this.getFilename(item))
    },

    async deleteFile(filename: string) {
      await fetch(`${this.getRestApi}/api/music/playlist/delete`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ filename }),
      })

      await this.fetchFiles()
    },

    async deleteSongRequest(item: any) {
      const filename = this.getFilename(item)

      await fetch(`${this.getRestApi}/api/music/delete`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ filename }),
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
.current-song {
  background: rgba(255, 255, 255, 0.12);
  border-radius: 8px;
}

.music-playlist-list {
  max-height: calc(100vh - 152px);
  overflow-y: auto;
}
</style>