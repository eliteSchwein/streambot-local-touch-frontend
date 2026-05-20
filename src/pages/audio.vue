<template>
  <v-card
    class="overflow-auto mx-auto px-5 py-5"
    max-height="100%"
    min-height="100%"
    elevation="0"
    color="transparent"
    max-width="100%"
  >
    <v-row>
      <v-col sm="6" md="6" lg="6" xl="4">
        <v-card>
          <v-card-title>{{ $t('audio.bot_audio_mixer') }}</v-card-title>
          <v-card-item>
            <v-row v-for="(device, key) in getAudioData" :key="key">
              <v-col>
                <v-card
                  color="black"
                >
                  <v-card-title></v-card-title>
                  <v-card-subtitle class="px-2 pt-2">
                    {{ key }}
                  </v-card-subtitle>
                  <v-card-item>
                    <v-row align="center">
                      <v-col cols="auto">
                        <v-btn
                          density="compact"
                          elevation="0"
                          color="transparent"
                          icon="mdi-volume-variant-off"
                          v-if="device.muted"
                          @click="unmute(key, device)"
                          style="color: #EF5350!important;"
                        >
                        </v-btn>
                        <v-btn
                          density="compact"
                          elevation="0"
                          color="transparent"
                          icon="mdi-volume-source"
                          @click="setVolume(key, 0)"
                          v-else>
                        </v-btn>
                      </v-col>
                      <v-col>
                        <v-slider
                          hide-details
                          :max="device.max_range"
                          :min="device.min_range"
                          :step="device.steps_range"
                          :disabled="device.muted"
                          v-model="device.current_volume"
                          density="compact"
                          @update:modelValue="setVolume(key, device.current_volume)"
                        ></v-slider>
                      </v-col>
                    </v-row>
                  </v-card-item>
                </v-card>
              </v-col>
            </v-row>
          </v-card-item>
        </v-card>
      </v-col>
      <v-col v-if="getYoloboxData.MixerList" sm="6" md="6" lg="6" xl="4">
        <YoloboxAudio/>
      </v-col>
      <v-col v-if="Object.keys(getObsAudioData).length > 0" sm="6" md="6" lg="6" xl="4">
        <ObsAudio/>
      </v-col>
    </v-row>
  </v-card>
</template>

<script lang="ts">
import {mapState} from "pinia";
import {useAppStore} from "@/stores/app";
import eventBus from "@/eventBus";
export default {
  computed: {
    ...mapState(useAppStore, ['getAudioData', 'getYoloboxData', 'getObsAudioData', 'getParsedBackendConfig']),
  },
  methods: {
    setVolume(audioInterface: string, volume: number) {
      eventBus.$emit('websocket:send', {
        method: 'set_volume',
        params: {'interface': audioInterface, 'volume': volume},
      })
    },
    unmute(audioInterface: string, audioData: any) {
      this.setVolume(audioInterface, audioData.current_volume);
    }
  }
}
</script>
