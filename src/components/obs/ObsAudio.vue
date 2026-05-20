<template>
  <template v-if="Object.keys(getObsAudioData).length > 0">
    <v-row>
      <v-col>
        <v-card>
          <v-card-title>{{ $t('audio.obs_audio_mixer') }}</v-card-title>
          <v-card-item>
            <v-row v-for="(device) in getObsAudioData">
              <v-col>
                <v-card
                  :color="device.muted === false? 'black' : 'red-darken-4'"
                >
                  <v-card-title></v-card-title>
                  <v-card-subtitle class="px-2 pt-2">
                    {{ device.inputName }}
                  </v-card-subtitle>
                  <v-card-item>
                    <v-row align="center">
                      <v-col cols="auto" class="mt-5">
                        <v-btn
                          density="compact"
                          elevation="0"
                          color="transparent"
                          icon="mdi-volume-variant-off"
                          v-if="device.muted"
                          @click="toggleInputMute(device.inputUuid)"
                        >
                        </v-btn>
                        <v-btn
                          density="compact"
                          elevation="0"
                          color="transparent"
                          icon="mdi-volume-source"
                          @click="toggleInputMute(device.inputUuid)"
                          v-else>
                        </v-btn>
                      </v-col>
                      <v-col>
                        <div>
                          <div class="text-caption">{{ $t('audio.volume') }} {{ Math.round(device.volume.inputVolumeMul * 100) }}%</div>
                          <v-slider
                            hide-details
                            :max="0"
                            :min="-100"
                            :step="0.05"
                            v-model="device.volume.inputVolumeDb"
                            density="compact"
                            @update:modelValue="setInputVolume(device.inputUuid, device.volume.inputVolumeDb)"
                          ></v-slider>
                        </div>
                      </v-col>
                      <v-col cols="2">
                        <div>
                          <div class="text-caption">{{ $t('audio.balance') }}</div>
                          <v-slider
                            hide-details
                            :max="1"
                            :min="0"
                            :step="0.01"
                            v-model="device.balance"
                            density="compact"
                            @update:modelValue="setAudioBalance(device.inputUuid, device.balance)"
                          ></v-slider>
                        </div>
                      </v-col>
                    </v-row>
                  </v-card-item>
                </v-card>
              </v-col>
            </v-row>
          </v-card-item>
        </v-card>
      </v-col>
    </v-row>
  </template>
</template>

<script lang="ts">
import {mapState} from "pinia";
import {useAppStore} from "@/stores/app";
import eventBus from "@/eventBus";

export default {
  computed: {
    ...mapState(useAppStore, ['getParsedBackendConfig', 'getObsAudioData']),
  },
  methods: {
    setInputVolume(inputUuid: string, volume: number) {
      eventBus.$emit('websocket:send', {
        method: 'obs_trigger_command',
        params: {"method": "SetInputVolume", "data": {"inputUuid": inputUuid, "inputVolumeDb": volume}},
      })
    },
    toggleInputMute(inputUuid: string) {
      eventBus.$emit('websocket:send', {
        method: 'obs_trigger_command',
        params: {"method": "ToggleInputMute", "data": {"inputUuid": inputUuid}},
      })
    },
    setAudioBalance(inputUuid: string, balance: number) {
      eventBus.$emit('websocket:send', {
        method: 'obs_trigger_command',
        params: {"method": "SetInputAudioBalance", "data": {"inputUuid": inputUuid, "inputAudioBalance": balance}},
      })
    }
  }
}
</script>
