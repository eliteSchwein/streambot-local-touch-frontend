<template>
  <v-expansion-panels class="speedtest-card" variant="accordion">
    <v-expansion-panel>
      <v-expansion-panel-title>
        {{ $t('recovery.speedtest') }}
      </v-expansion-panel-title>

      <v-expansion-panel-text>
        <div class="speedtest-card__content">
          <div class="speedtest-card__grid">
            <div class="speedtest-card__metric">
              <div class="speedtest-card__label">Ping</div>
              <div class="speedtest-card__value">{{ pingText }}</div>
            </div>

            <div class="speedtest-card__metric">
              <div class="speedtest-card__label">Download</div>
              <div class="speedtest-card__value">{{ downloadText }}</div>
            </div>

            <div class="speedtest-card__metric">
              <div class="speedtest-card__label">Upload</div>
              <div class="speedtest-card__value">{{ uploadText }}</div>
            </div>
          </div>

          <v-progress-linear
              v-if="running"
              indeterminate
              class="speedtest-card__progress"
          />

          <v-alert
              v-if="error"
              type="error"
              density="compact"
              class="speedtest-card__error"
          >
            {{ error }}
          </v-alert>

          <v-btn
              block
              color="primary"
              :loading="running"
              :disabled="running"
              @click="runSpeedtest"
          >
            {{ $t('recovery.run_speedtest') }}
          </v-btn>
        </div>
      </v-expansion-panel-text>
    </v-expansion-panel>
  </v-expansion-panels>
</template>

<script lang="ts">
const SPEEDTEST_BASE = "https://brrt.tludwig.dev"

export default {
  name: "SpeedtestCard",

  data() {
    return {
      running: false,
      pingMs: null as number | null,
      downloadMbps: null as number | null,
      uploadMbps: null as number | null,
      error: null as string | null,
    }
  },

  computed: {
    pingText(): string {
      return this.pingMs === null ? "—" : `${this.pingMs.toFixed(0)} ms`
    },

    downloadText(): string {
      return this.downloadMbps === null ? "—" : `${this.downloadMbps.toFixed(1)} Mbps`
    },

    uploadText(): string {
      return this.uploadMbps === null ? "—" : `${this.uploadMbps.toFixed(1)} Mbps`
    },
  },

  methods: {
    async runSpeedtest() {
      this.running = true
      this.error = null
      this.pingMs = null
      this.downloadMbps = null
      this.uploadMbps = null

      try {
        this.pingMs = await this.measurePing()
        this.downloadMbps = await this.measureDownload()
        this.uploadMbps = await this.measureUpload()
      } catch (error: any) {
        this.error = error?.message || String(error)
      } finally {
        this.running = false
      }
    },

    async measurePing(): Promise<number> {
      const samples: number[] = []

      for (let i = 0; i < 5; i++) {
        const start = performance.now()

        await fetch(`${SPEEDTEST_BASE}/empty.php?r=${Math.random()}`, {
          method: "GET",
          cache: "no-store",
        })

        samples.push(performance.now() - start)
      }

      samples.sort((a, b) => a - b)
      return samples[Math.floor(samples.length / 2)]
    },

    async measureDownload(): Promise<number> {
      const start = performance.now()

      const response = await fetch(`${SPEEDTEST_BASE}/downloading?n=${Math.random()}`, {
        method: "GET",
        cache: "no-store",
      })

      if (!response.ok) {
        throw new Error(`Download failed: HTTP ${response.status}`)
      }

      const blob = await response.blob()
      const seconds = (performance.now() - start) / 1000
      const bits = blob.size * 8

      return bits / seconds / 1_000_000
    },

    async measureUpload(): Promise<number> {
      const sizeBytes = 20 * 1024 * 1024
      const payload = new Uint8Array(sizeBytes)

      const start = performance.now()

      const response = await fetch(`${SPEEDTEST_BASE}/upload?n=${Math.random()}`, {
        method: "POST",
        body: payload,
        cache: "no-store",
      })

      if (!response.ok) {
        throw new Error(`Upload failed: HTTP ${response.status}`)
      }

      const seconds = (performance.now() - start) / 1000
      const bits = sizeBytes * 8

      return bits / seconds / 1_000_000
    },
  },
}
</script>

<style lang="scss" scoped>
.speedtest-card {
  width: 100%;
}

.speedtest-card__content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.speedtest-card__grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.speedtest-card__metric {
  padding: 16px;
  border-radius: 16px;
  background: rgba(var(--v-theme-surface-variant), 0.35);
}

.speedtest-card__label {
  font-size: 0.75rem;
  opacity: 0.7;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.speedtest-card__value {
  margin-top: 6px;
  font-size: 1.4rem;
  font-weight: 600;
}

.speedtest-card__progress,
.speedtest-card__error {
  margin-top: 4px;
}
</style>