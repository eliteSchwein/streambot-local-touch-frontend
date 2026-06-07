<template>
  <v-card class="audio-mixer-card" color="grey-darken-4" elevation="0" rounded="0">
    <v-card-text class="audio-mixer-body">
      <div class="audio-table-wrap">
        <v-table density="compact" class="audio-table" hover>
          <thead>
          <tr>
            <th class="audio-name-column text-left">{{ $t('audio.name') }}</th>
            <th class="audio-volume-column text-left">{{ $t('audio.volume') }}</th>
            <th class="audio-sinks-column text-left">{{ $t('audio.outputs') }}</th>
          </tr>
          </thead>

          <tbody>
          <tr v-for="(device, key) in getAudioData" :key="key" class="audio-row">
            <td class="audio-name-column">
              <div class="audio-device-name">{{ key }}</div>
              <div v-if="isPipewireSink(device)" class="audio-device-subtitle">
                {{ device.sink_name || `streambot_${key}` }}
              </div>
            </td>

            <td class="audio-volume-column">
              <div class="audio-control-stack">
                <v-slider
                    class="audio-slider"
                    hide-details
                    :max="Number(device.max_range ?? 1)"
                    :min="Number(device.min_range ?? 0)"
                    :step="Number(device.steps_range ?? 0.01)"
                    :disabled="device.muted"
                    :model-value="getVolumeValue(String(key), device)"
                    density="compact"
                    @update:modelValue="queueVolume(String(key), Number($event))"
                    @end="flushVolume(String(key))"
                />

                <div class="audio-button-row">
                  <v-btn
                      class="audio-step-btn"
                      elevation="0"
                      size="small"
                      variant="tonal"
                      :disabled="device.muted"
                      @click="stepVolume(String(key), device, -1)"
                  >
                    <v-icon icon="mdi-minus"/>
                  </v-btn>

                  <v-btn
                      v-if="device.muted"
                      class="audio-icon-btn audio-muted-btn"
                      elevation="0"
                      size="small"
                      variant="tonal"
                      @click="unmute(String(key), device)"
                  >
                    <v-icon icon="mdi-volume-off"/>
                  </v-btn>
                  <v-btn
                      v-else
                      class="audio-icon-btn"
                      elevation="0"
                      size="small"
                      variant="tonal"
                      @click="setVolume(String(key), 0)"
                  >
                    <v-icon icon="mdi-volume-source"/>
                  </v-btn>

                  <v-btn
                      class="audio-step-btn"
                      elevation="0"
                      size="small"
                      variant="tonal"
                      :disabled="device.muted"
                      @click="stepVolume(String(key), device, 1)"
                  >
                    <v-icon icon="mdi-plus"/>
                  </v-btn>
                </div>
              </div>
            </td>

            <td class="audio-sinks-column">
              <div v-if="isPipewireSink(device) && audioOutputList.length" class="audio-sink-list">
                <label
                    v-for="output in audioOutputList"
                    :key="`${key}-${outputKey(output)}`"
                    class="audio-sink-option"
                >
                  <v-checkbox-btn
                      class="audio-sink-checkbox"
                      density="comfortable"
                      :model-value="isSinkLinked(device, output, String(key))"
                      @update:modelValue="toggleSinkLink(String(key), output, Boolean($event))"
                  />
                  <span class="audio-sink-label">{{ outputLabel(output) }}</span>
                  <v-icon
                      v-if="isDefaultOutput(output)"
                      class="audio-sink-default-icon"
                      icon="mdi-star-circle"
                      size="x-small"
                  />
                </label>
              </div>
              <span v-else class="text-disabled">—</span>
            </td>
          </tr>
          </tbody>
        </v-table>
      </div>
    </v-card-text>
  </v-card>
</template>

<script lang="ts">
import { mapState } from 'pinia'
import { useAppStore } from '@/stores/app'
import eventBus from '@/eventBus'

type AudioOutput = Record<string, any>

export default {
  data() {
    return {
      volumeDebounceTimers: {} as Record<string, ReturnType<typeof setTimeout>>,
      volumeDrafts: {} as Record<string, number>,
    }
  },

  computed: {
    ...mapState(useAppStore, [
      'getAudioData',
      'getAudioOutput',
      'getAudioOutputs',
    ]),

    audioOutputList(): AudioOutput[] {
      const payload = this.getAudioOutputs ?? this.getAudioOutput ?? {}

      const outputs = Array.isArray(payload)
          ? payload
          : Array.isArray(payload?.outputs)
              ? payload.outputs
              : Array.isArray(payload?.sinks)
                  ? payload.sinks
                  : Array.isArray(payload?.data)
                      ? payload.data
                      : Object.entries(payload ?? {}).map(([key, value]: [string, any]) => ({
                        id: key,
                        ...(typeof value === 'object' && value !== null ? value : { name: String(value) }),
                      }))

      return outputs
          .map((output: any, index: number) => ({
            id: output.id ?? output.index ?? output.name ?? output.node_name ?? output.nodeName ?? index,
            ...output,
          }))
          .filter((output: any) => this.outputIdentifier(output) !== '')
    },
  },

  methods: {
    clampVolume(volume: number, audioData: any): number {
      const min = Number(audioData.min_range ?? 0)
      const max = Number(audioData.max_range ?? 1)

      return Math.max(min, Math.min(max, volume))
    },

    getVolumeStep(audioData: any): number {
      const step = Number(audioData.steps_range ?? 0.01)

      return Number.isFinite(step) && step > 0 ? step : 0.01
    },

    getVolumeValue(audioInterface: string, audioData: any): number {
      if (this.volumeDrafts[audioInterface] !== undefined) {
        return this.volumeDrafts[audioInterface]
      }

      return Number(audioData.current_volume ?? audioData.default_volume ?? 0)
    },

    stepVolume(audioInterface: string, audioData: any, direction: number) {
      const current = this.getVolumeValue(audioInterface, audioData)
      const next = this.clampVolume(current + (this.getVolumeStep(audioData) * direction), audioData)

      this.volumeDrafts[audioInterface] = next
      this.flushVolume(audioInterface)
    },

    queueVolume(audioInterface: string, volume: number) {
      this.volumeDrafts[audioInterface] = volume

      if (this.volumeDebounceTimers[audioInterface]) {
        clearTimeout(this.volumeDebounceTimers[audioInterface])
      }

      this.volumeDebounceTimers[audioInterface] = setTimeout(() => {
        this.flushVolume(audioInterface)
      }, 160)
    },

    flushVolume(audioInterface: string) {
      const volume = this.volumeDrafts[audioInterface]

      if (volume === undefined) return

      if (this.volumeDebounceTimers[audioInterface]) {
        clearTimeout(this.volumeDebounceTimers[audioInterface])
        delete this.volumeDebounceTimers[audioInterface]
      }

      delete this.volumeDrafts[audioInterface]
      this.setVolume(audioInterface, volume)
    },

    setVolume(audioInterface: string, volume: number) {
      eventBus.$emit('websocket:send', {
        method: 'set_volume',
        params: { interface: audioInterface, volume },
      })
    },

    unmute(audioInterface: string, audioData: any) {
      this.setVolume(audioInterface, Number(audioData.current_volume ?? audioData.default_volume ?? audioData.min_range ?? 0))
    },

    isPipewireSink(device: any): boolean {
      return device?.pipewire_sink === true || device?.pipewire_sink === 'true'
    },

    outputIdentifier(output: AudioOutput): string {
      return String(
          output.name ??
          output.node_name ??
          output.nodeName ??
          output.description ??
          output.id ??
          output.index ??
          ''
      )
    },

    outputKey(output: AudioOutput): string {
      return this.outputIdentifier(output)
    },

    outputLabel(output: AudioOutput): string {
      return String(
          output.description ??
          output.display_name ??
          output.displayName ??
          output.name ??
          output.node_name ??
          output.nodeName ??
          output.id ??
          this.$t('audio.unknownOutput')
      )
    },

    isDefaultOutput(output: AudioOutput): boolean {
      return output.is_default === true || output.default === true || output.isDefault === true
    },

    isDefaultOutputActive(output: AudioOutput): boolean {
      const state = String(output.state ?? '').toUpperCase()
      return this.isDefaultOutput(output) && (output.active === true || state === 'RUNNING')
    },

    isSinkLinked(device: any, output: AudioOutput, audioInterface?: string): boolean {
      const outputName = this.outputIdentifier(output)

      if (!outputName) return false

      const interfaceName = audioInterface ? String(audioInterface) : ''
      const linkedOutput = device.linked_output ?? device.actual_linked_output ?? device.audio_output ?? device.output ?? null
      const linkedOutputs = device.linked_outputs ?? device.actual_linked_outputs ?? device.audio_outputs ?? []
      const outputLinkedInterfaces = output.linked_interfaces ?? output.active_interfaces ?? output.interfaces ?? []

      if (String(linkedOutput) === outputName) return true

      if (Array.isArray(linkedOutputs) && linkedOutputs.map(String).includes(outputName)) {
        return true
      }

      if (interfaceName && Array.isArray(outputLinkedInterfaces) && outputLinkedInterfaces.map(String).includes(interfaceName)) {
        return true
      }

      return false
    },

    toggleSinkLink(audioInterface: string, output: AudioOutput, linked: boolean) {
      const outputName = this.outputIdentifier(output)

      if (!outputName) return

      eventBus.$emit('websocket:send', {
        method: 'link_sink',
        params: {
          interface: audioInterface,
          output: outputName,
          linked,
        },
      })
    },
  },
}
</script>

<style scoped>
.audio-mixer-card {
  width: 100%;
}

.audio-mixer-body {
  padding: 6px 10px 10px;
}

.audio-table-wrap {
  max-width: 100%;
  overflow-x: auto;
}

.audio-table {
  min-width: 700px;
  background: transparent;
}

.audio-table :deep(table) {
  background: transparent;
  table-layout: fixed;
}

.audio-table :deep(th) {
  height: 28px !important;
  padding: 4px 10px !important;
  color: rgba(var(--v-theme-on-surface), 0.68);
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.07em;
  text-transform: uppercase;
}

.audio-table :deep(td) {
  padding: 7px 10px !important;
  vertical-align: middle;
}

.audio-row {
  min-height: 72px;
}

.audio-name-column {
  width: 120px;
}

.audio-volume-column {
  width: 330px;
}

.audio-sinks-column {
  width: auto;
}

.audio-device-name {
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.1;
}

.audio-device-subtitle {
  margin-top: 3px;
  color: rgba(var(--v-theme-on-surface), 0.62);
  font-size: 0.72rem;
  line-height: 1.2;
}

.audio-control-stack {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 2px;
}

.audio-button-row {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  align-items: center;
  gap: 6px;
  width: 100%;
  margin-top: 5px;
}

.audio-icon-btn,
.audio-step-btn {
  width: 100%;
  min-width: 0;
  height: 32px !important;
  padding: 0 !important;
  border-radius: 4px !important;
}

.audio-muted-btn {
  background: #4f0f0f !important;
  color: #fff !important;
}

.audio-icon-btn :deep(.v-btn__overlay),
.audio-step-btn :deep(.v-btn__overlay) {
  opacity: 0;
}

.audio-slider {
  width: 100%;
  min-width: 110px;
}

.audio-slider :deep(.v-slider-track__background),
.audio-slider :deep(.v-slider-track__fill) {
  height: 4px;
}

.audio-slider :deep(.v-slider-thumb__surface) {
  width: 16px;
  height: 16px;
}

.audio-sink-list {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 2px 10px;
  align-items: center;
}

.audio-sink-option {
  display: flex;
  align-items: center;
  min-width: 0;
  height: 24px;
  line-height: 1;
  cursor: pointer;
}

.audio-sink-checkbox {
  flex: 0 0 auto;
  margin-inline-start: -6px;
}

.audio-sink-checkbox :deep(.v-selection-control) {
  min-height: 30px;
}

.audio-sink-checkbox :deep(.v-selection-control__wrapper) {
  width: 30px;
  height: 30px;
}

.audio-sink-label {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.8rem;
}

.audio-sink-default-icon {
  flex: 0 0 auto;
  margin-left: 4px;
  opacity: 0.75;
}

@media (max-width: 760px) {
  .audio-table {
    min-width: 640px;
  }

  .audio-name-column {
    width: 150px;
  }

  .audio-volume-column {
    width: 270px;
  }

  .audio-sink-list {
    grid-template-columns: 1fr;
  }
}
</style>
