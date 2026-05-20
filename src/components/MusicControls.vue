<template>
  <v-card
    class="music-controls"
    color="grey-darken-3"
    rounded
  >
    <div class="music-controls-content">
      <v-card-title class="d-flex align-center justify-space-between">
        <span>{{ $t('music.title') }}</span>
        <v-spacer></v-spacer>
        <v-switch
          density="compact"
          :label="$t('music.song_requests')"
          :model-value="music?.songrequest?.enabled ?? false"
          @click="toggleSongRequest"
          hide-details
        />
      </v-card-title>

      <v-card-text>
        <div class="music-controls-main">
          <div class="music-cava-background" aria-hidden="true">
            <div
              v-for="(value, index) in smoothedCavaValues"
              :key="index"
              class="music-cava-bar"
              :style="{ height: getCavaBarHeight(value) }"
            />
          </div>

          <div class="music-controls-main-content">
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

            <div class="music-cava-spacer" aria-hidden="true" />

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
          </div>
        </div>

        <div class="text-caption mt-4 mb-2">
          Playlist: {{ music.playlist_length ?? 0 }} Songs
        </div>
      </v-card-text>
    </div>
  </v-card>
</template>

<script lang="ts">
import { mapState } from 'pinia'
import { useAppStore } from '@/stores/app'

export default {
  data() {
    return {
      playlistItemRefs: {} as Record<string, any>,
      cavaBuffer: '',
      expectedCavaBarCount: 0,
      cavaValues: [] as number[],
      smoothedCavaValues: [] as number[],
      cavaSmoothing: 0.45,
      cavaFalloff: 6,
    }
  },

  watch: {
    getMusicCavaData: {
      handler(data: any) {
        if (!data?.raw) return
        this.handleCavaData(data)
      },
      deep: false,
      immediate: false,
    },

    'music.track.title'() {
      this.$nextTick(() => this.scrollToCurrentSong())
    },

    'music.track.path'() {
      this.$nextTick(() => this.scrollToCurrentSong())
    },

    'music.track.filename'() {
      this.$nextTick(() => this.scrollToCurrentSong())
    },
  },

  computed: {
    ...mapState(useAppStore, ['getMusicData', 'getMusicCavaData', 'getRestApi']),

    music(): any {
      return this.getMusicData ?? {}
    },

    playlist(): any[] {
      return this.music.playlist ?? []
    },

    isPlaying(): boolean {
      return this.music.status === 'playing'
    },
  },

  mounted() {
    this.resetCava()

    if (this.getMusicCavaData?.raw) {
      this.handleCavaData(this.getMusicCavaData)
    }
  },

  methods: {
    handleCavaData(data: any) {
      const frames = this.parseCavaFrames(String(data?.raw ?? ''))

      for (const values of frames) {
        if (!values.length) continue

        if (!this.expectedCavaBarCount) {
          this.expectedCavaBarCount = values.length
          this.ensureCavaBars(values.length)
        }

        if (values.length !== this.expectedCavaBarCount) {
          this.expectedCavaBarCount = values.length
          this.ensureCavaBars(values.length)
        }

        this.cavaValues = values
        this.smoothCavaValues()
      }
    },

    parseCavaFrames(raw: string): number[][] {
      if (!raw) return []

      this.cavaBuffer += raw

      const lines = this.cavaBuffer.split(/\r?\n/)
      this.cavaBuffer = lines.pop() ?? ''

      return lines
        .map(line => line.trim())
        .filter(line => line.length > 0)
        .map(line => {
          const values = line
            .split(/[;,\s]+/)
            .map(value => Number(value))
            .filter(value => Number.isFinite(value))
            .map(value => Math.max(0, Math.min(100, value)))

          return values.length > 1 ? values.slice(0, -1) : values
        })
        .filter(values => values.length > 0)
    },

    ensureCavaBars(count: number) {
      if (this.smoothedCavaValues.length === count) return

      this.smoothedCavaValues = new Array(count).fill(0)
    },

    smoothCavaValues() {
      const smoothed = [...this.smoothedCavaValues]

      for (let i = 0; i < this.cavaValues.length; i++) {
        const target = this.cavaValues[i] ?? 0
        const current = smoothed[i] ?? 0

        if (target > current) {
          smoothed[i] = current + (target - current) * this.cavaSmoothing
        } else {
          smoothed[i] = Math.max(target, current - this.cavaFalloff)
        }
      }

      this.smoothedCavaValues = smoothed
    },

    getCavaBarHeight(value: number): string {
      return value > 0
        ? `${Math.max(3, value)}%`
        : '0%'
    },

    getItemPath(item: any): string {
      return item.filename ?? item.path ?? ''
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

    scrollToCurrentSong() {
      const current = this.playlist.find(item => this.isCurrentSong(item))
      if (!current) return

      const key = this.getFilename(current)
      const ref = this.playlistItemRefs[key]
      const element = ref?.$el ?? ref

      element?.scrollIntoView?.({
        block: 'center',
        behavior: 'smooth',
      })
    },

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

    getFilename(item: any): string {
      const file = item.filename ?? item.path ?? ''

      return file.split(/[\\/]/).pop() ?? file
    },

    async toggleSongRequest() {
      await fetch(`${this.getRestApi}/api/music/songrequest/toggle`, {
        method: 'POST'
      })
    },

    resetCava() {
      this.cavaBuffer = ''
      this.expectedCavaBarCount = 0
      this.cavaValues = []
      this.smoothedCavaValues = []
    },
  },
}
</script>

<style scoped>
.music-controls {
  position: relative;
  width: 100%;
  overflow: hidden;
}

.music-controls-main {
  position: relative;
  overflow: hidden;
  margin-left: -16px;
  margin-right: -16px;
  padding-left: 16px;
  padding-right: 16px;
}

.music-cava-background {
  position: absolute;
  left: 20px;
  right: 20px;
  bottom: 32px;
  height: 95px;
  z-index: 1;
  display: flex;
  align-items: flex-end;
  gap: 3px;
  opacity: 0.32;
  pointer-events: none;
}

.music-control-buttons {
  position: relative;
  z-index: 3;
  display: flex;
  justify-content: center;
  gap: 8px;
  margin-top: 20px;
  margin-bottom: 0;
}

.music-cava-spacer {
  height: 30px;
}

.music-progress {
  position: relative;
  z-index: 4;
  margin-top: 0;
}

.music-cava-bar {
  flex: 1 1 0;
  min-width: 2px;
  max-height: 100%;
  border-radius: 2px 2px 0 0;
  background: currentColor;
  transition: height 80ms linear;
}

.music-controls-main-content,
.music-controls-content {
  position: relative;
}

.music-controls-content {
  z-index: 1;
}

.music-controls-main-content {
  z-index: 2;
}
</style>
