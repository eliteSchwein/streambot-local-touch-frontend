<template>
  <template v-if="getYoloboxData.MixerList">
    <v-row>
      <v-col>
        <v-card>
          <v-card-title>{{ $t('audio.yolobox_audio_mixer') }}</v-card-title>
          <v-card-item>
            <v-row v-for="(device) in getYoloboxData.MixerList">
              <v-col>
                <v-card
                  :color="device.isSelected? 'black' : 'red-darken-4'"
                >
                  <v-card-title></v-card-title>
                  <v-card-subtitle class="px-2 pt-2">
                    {{ device.id }}
                  </v-card-subtitle>
                  <v-card-item>
                    <v-row align="center">
                      <v-col cols="auto" class="mt-5">
                        <v-btn
                          density="compact"
                          elevation="0"
                          color="transparent"
                          icon="mdi-volume-variant-off"
                          v-if="!device.isSelected"
                          @click="setYoloboxVolume(device.id, device.volume, !device.isSelected, device.delayTime, device.afv)"
                        >
                        </v-btn>
                        <v-btn
                          density="compact"
                          elevation="0"
                          color="transparent"
                          icon="mdi-volume-source"
                          @click="setYoloboxVolume(device.id, device.volume, !device.isSelected, device.delayTime, device.afv)"
                          v-else>
                        </v-btn>
                      </v-col>
                      <v-col>
                        <div>
                          <div class="text-caption">{{ $t('audio.volume') }} {{ Math.round(device.volume * 100) }}%</div>
                          <v-slider
                            hide-details
                            :max="1"
                            :min="0"
                            :step="0.05"
                            v-model="device.volume"
                            density="compact"
                            @update:modelValue="setYoloboxVolume(device.id, device.volume, device.isSelected, device.delayTime, device.afv)"
                          ></v-slider>
                        </div>
                      </v-col>
                    </v-row>
                    <template v-if="device.delayTime !== undefined">
                      <v-row align="center">
                        <v-col cols="auto" class="mt-5">
                          <v-btn
                            density="compact"
                            elevation="0"
                            color="transparent"
                            icon="mdi-priority-low"
                            v-if="!device.AFV"
                            @click="setYoloboxVolume(device.id, device.volume, device.isSelected, device.delayTime, !device.AFV)"
                          >
                          </v-btn>
                          <v-btn
                            density="compact"
                            elevation="0"
                            color="transparent"
                            icon="mdi-priority-high"
                            @click="setYoloboxVolume(device.id, device.volume, device.isSelected, device.delayTime, !device.AFV)"
                            v-else>
                          </v-btn>
                        </v-col>
                        <v-col>
                          <div>
                            <div class="text-caption">{{ $t('audio.delay') }} {{ device.delayTime }}ms</div>
                            <v-slider
                              hide-details
                              :max="device.maxDelay"
                              :min="0"
                              :step="1"
                              v-model="device.delayTime"
                              density="compact"
                              @update:modelValue="setYoloboxVolume(device.id, device.volume, device.isSelected, device.delayTime, device.afv)"
                            ></v-slider>
                          </div>
                        </v-col>
                      </v-row>
                    </template>
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
    ...mapState(useAppStore, ['getYoloboxData', 'getParsedBackendConfig']),
  },
  methods: {
    setYoloboxVolume(audioInterface: string, volume: number, isSelected: boolean, delay: number = 0, afv: boolean = false) {
      eventBus.$emit('websocket:send', {
        method: 'execute_yolobox',
        params: {"data": {"id": audioInterface, "isSelected": isSelected, "volume": volume, "AFV": afv, "delayTime": delay}, "orderID": "order_mixer_change"},
      })
    }
  }
}
</script>
