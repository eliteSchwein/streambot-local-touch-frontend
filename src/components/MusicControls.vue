<template>
  <v-card
      class="music-controls"
      color="grey-darken-3"
      rounded
  >
    <v-card-title class="d-flex align-center justify-space-between">
      <span>{{ $t('music.title') }}</span>
      <v-spacer />
      <v-switch
          density="compact"
          :label="$t('music.song_requests')"
          :model-value="music?.songrequest?.enabled ?? false"
          @click="toggleSongRequest"
          hide-details
      />
    </v-card-title>

    <v-card-text>
      <div class="text-subtitle-1 font-weight-bold text-truncate">
        {{ music.title || $t('music.no_song') }}
      </div>

      <div class="text-body-2 text-grey-lighten-1 text-truncate">
        {{ music.artist || $t('music.unknown_artist') }}
      </div>

      <div class="music-control-buttons">
        <v-btn icon="mdi-skip-previous" @click="callMusicApi('back')" />
        <v-btn
            :icon="isPlaying ? 'mdi-pause' : 'mdi-play'"
            @click="callMusicApi(isPlaying ? 'pause' : 'play')"
        />
        <v-btn icon="mdi-skip-next" @click="callMusicApi('next')" />
      </div>

      <v-progress-linear
          class="music-progress"
          :model-value="music.progress_percentage ?? 0"
          height="8"
          rounded
      />

      <div class="d-flex justify-space-between text-caption mt-1">
        <span>{{ formatTime(music.position) }}</span>
        <span>{{ formatTime(music.duration) }}</span>
      </div>

      <div class="text-caption mt-4 mb-2">
        Playlist: {{ music.playlist_length ?? 0 }} Songs
      </div>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import { mapState } from 'pinia'
import { useAppStore } from '@/stores/app'

export default {
  computed: {
    ...mapState(useAppStore, ['getMusicData', 'getRestApi']),

    music(): any {
      return this.getMusicData ?? {}
    },

    isPlaying(): boolean {
      return this.music.status === 'playing'
    },
  },

  methods: {
    async callMusicApi(action: string) {
      await fetch(`${this.getRestApi}/api/music/${action}`, {
        cache: 'no-store',
      })
    },

    formatTime(ms: number = 0): string {
      const seconds = Math.floor(ms / 1000)
      const minutes = Math.floor(seconds / 60)
      const rest = seconds % 60

      return `${minutes}:${String(rest).padStart(2, '0')}`
    },

    async toggleSongRequest() {
      await fetch(`${this.getRestApi}/api/music/songrequest/toggle`, {
        method: 'POST',
      })
    },
  },
}
</script>

<style scoped>
.music-controls {
  width: 100%;
  overflow: hidden;
}

.music-control-buttons {
  display: flex;
  justify-content: center;
  gap: 8px;
  margin-top: 20px;
  margin-bottom: 20px;
}

.music-progress {
  margin-top: 0;
}
</style>