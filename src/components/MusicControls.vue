<template>
  <v-card
      class="music-controls"
      color="grey-darken-3"
      rounded
  >
    <v-card-title>
      {{ $t('music.title') }}
    </v-card-title>

    <v-card-text class="pt-0">
      <div class="music-player">
        <div class="music-player__header">
          <div class="music-player__track">
            <div class="text-subtitle-1 font-weight-bold text-truncate">
              {{ music.title || $t('music.no_song') }}
            </div>

            <div class="text-body-2 text-medium-emphasis text-truncate">
              {{ music.artist || $t('music.unknown_artist') }}
            </div>
          </div>

          <v-switch
              class="music-player__song-requests"
              density="compact"
              :label="$t('music.song_requests')"
              :model-value="music?.songrequest?.enabled ?? false"
              @click="toggleSongRequest"
              hide-details
          />
        </div>

        <div class="music-player__controls">
          <div
              class="music-player__visualizer"
              aria-hidden="true"
          >
            <div
                v-for="(value, index) in smoothedCavaValues"
                :key="index"
                class="music-player__visualizer-bar"
                :style="{ height: getCavaBarHeight(value) }"
            />
          </div>

          <v-btn
              icon="mdi-shuffle-variant"
              size="40"
              :color="isShuffleEnabled ? 'primary' : undefined"
              @click="callMusicApi('shuffle')"
          />

          <v-btn
              icon="mdi-skip-previous"
              size="40"
              @click="callMusicApi('back')"
          />

          <v-btn
              class="music-player__main-button"
              :icon="isPlaying ? 'mdi-pause' : 'mdi-play'"
              color="primary"
              size="46"
              @click="callMusicApi(isPlaying ? 'pause' : 'play')"
          />

          <v-btn
              icon="mdi-skip-next"
              size="40"
              @click="callMusicApi('next')"
          />

          <v-btn
              icon="mdi-repeat"
              size="40"
              :color="isLoopEnabled ? 'primary' : undefined"
              @click="callMusicApi('loop')"
          />
        </div>

        <div class="music-player__progress">
          <v-progress-linear
              :model-value="music.progress_percentage ?? 0"
              color="primary"
              height="7"
              rounded
          />

          <div class="d-flex justify-space-between text-caption text-medium-emphasis mt-1">
            <span>{{ formatTime(music.position) }}</span>
            <span>{{ formatTime(music.duration) }}</span>
          </div>
        </div>
      </div>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import { mapState } from 'pinia'
import { WebsocketEvent } from 'websocket-ts'
import { useAppStore } from '@/stores/app'
import eventBus from '@/eventBus'
import { getWebsocketClient } from '@/plugins/websocketInstance'

export default defineComponent({
  name: 'MusicControls',

  data() {
    return {
      cavaBuffer: '',
      cavaValues: [] as number[],
      smoothedCavaValues: [] as number[],
      cavaSmoothing: 0.45,
      cavaFalloff: 6,
      cavaSocket: undefined as any,
      cavaSocketMessageListener: undefined as ((...args: any[]) => void) | undefined,
      cavaConnectedListener: undefined as (() => void) | undefined,
    }
  },

  computed: {
    ...mapState(useAppStore, ['getMusicData', 'getWebsocket']),

    music(): any {
      return this.getMusicData ?? {}
    },

    cavaBarCount(): number {
      return 5
    },

    isPlaying(): boolean {
      return this.music.status === 'playing'
    },

    isShuffleEnabled(): boolean {
      return this.music.shuffle === true
    },

    isLoopEnabled(): boolean {
      return this.music.loop === true || this.music.loop_file === true
    },
  },

  watch: {
    cavaBarCount: {
      immediate: true,
      handler(count: number) {
        this.ensureCavaBars(count)
      },
    },
  },

  mounted() {
    this.ensureCavaBars(this.cavaBarCount)

    this.cavaSocketMessageListener = (...args: any[]) => {
      const event = args.length > 1 ? args[1] : args[0]
      const raw = event?.data ?? event

      if (typeof raw !== 'string') return

      let message: any

      try {
        message = JSON.parse(raw)
      } catch {
        return
      }

      if (message?.method !== 'notify_music_cava') return

      const data = message?.params ?? {}
      const target = String(data?.target ?? '').trim()

      if (target !== 'music_preview') return

      this.handleCavaData(data)
    }

    this.cavaConnectedListener = () => {
      this.attachCavaSocketListener()
    }

    eventBus.$on('websocket:connected', this.cavaConnectedListener)

    this.attachCavaSocketListener()
  },

  beforeUnmount() {
    if (this.cavaConnectedListener) {
      eventBus.$off('websocket:connected', this.cavaConnectedListener)
      this.cavaConnectedListener = undefined
    }

    this.detachCavaSocketListener()
    this.cavaSocketMessageListener = undefined
  },

  methods: {
    attachCavaSocketListener() {
      const socket = getWebsocketClient()?.getWebsocket() as any

      if (!socket || !this.cavaSocketMessageListener) return
      if (this.cavaSocket === socket) return

      this.detachCavaSocketListener()
      this.cavaSocket = socket

      try {
        socket.addEventListener(WebsocketEvent.message, this.cavaSocketMessageListener)
      } catch {
        socket.addEventListener('message', this.cavaSocketMessageListener)
      }
    },

    detachCavaSocketListener() {
      const socket = this.cavaSocket as any

      if (!socket || !this.cavaSocketMessageListener) {
        this.cavaSocket = undefined
        return
      }

      try {
        socket.removeEventListener(WebsocketEvent.message, this.cavaSocketMessageListener)
      } catch {
        socket.removeEventListener('message', this.cavaSocketMessageListener)
      }

      this.cavaSocket = undefined
    },

    handleCavaData(data: any) {
      const frames = this.parseCavaFrames(String(data?.raw ?? ''))
      const barCount = this.cavaBarCount

      for (const values of frames) {
        if (!values.length) continue

        const normalizedValues = values.slice(0, barCount)

        while (normalizedValues.length < barCount) {
          normalizedValues.push(0)
        }

        this.cavaValues = normalizedValues
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

      for (let i = 0; i < this.cavaBarCount; i++) {
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

    async callMusicApi(action: string) {
      if (!this.getWebsocket) return
      await this.requestMusicWebsocket(this.getMusicWebsocketMethod(action))
    },

    getMusicWebsocketMethod(action: string): string {
      return `music_${String(action ?? '').replace(/-/g, '_')}`
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

    formatTime(ms: number = 0): string {
      const seconds = Math.floor(ms / 1000)
      const minutes = Math.floor(seconds / 60)
      const rest = seconds % 60

      return `${minutes}:${String(rest).padStart(2, '0')}`
    },

    async toggleSongRequest() {
      await this.requestMusicWebsocket('music_songrequest_toggle')
    },
  },
})
</script>

<style scoped>
.music-controls {
  width: 100%;
  overflow: hidden;
}

.music-player {
  position: relative;
  padding: 16px;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.035);
}

.music-player::before {
  content: "";
  position: absolute;
  top: -80px;
  right: -70px;
  width: 180px;
  height: 180px;
  border-radius: 50%;
  background: rgba(var(--v-theme-primary), 0.10);
  filter: blur(42px);
  pointer-events: none;
}

.music-player__header,
.music-player__controls,
.music-player__progress {
  position: relative;
  z-index: 1;
}

.music-player__header {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}

.music-player__track {
  min-width: 0;
  flex: 1;
}

.music-player__song-requests {
  flex: 0 0 auto;
}

.music-player__controls {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 7px;
  margin-top: 18px;
  min-height: 46px;
}

.music-player__visualizer {
  position: absolute;
  left: 2px;
  width: 30px;
  height: 36px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  gap: 2px;
  padding: 6px 4px;
  border-radius: 10px;
}

.music-player__visualizer-bar {
  width: 3px;
  min-height: 3px;
  max-height: 100%;
  border-radius: 999px;
  background: rgb(var(--v-theme-primary));
  transition: height 16ms linear;
}

.music-player__main-button {
  box-shadow: 0 5px 14px rgba(var(--v-theme-primary), 0.22);
}

.music-player__progress {
  margin-top: 16px;
}

@media (max-width: 390px) {
  .music-player {
    padding: 14px;
  }

  .music-player__controls {
    gap: 5px;
  }

  .music-player__visualizer {
    width: 28px;
    padding-inline: 3px;
  }
}
</style>
