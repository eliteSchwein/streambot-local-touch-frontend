<template>
  <v-card
      class="overflow-auto mx-auto"
      max-height="100%"
      max-width="100%"
      elevation="0"
      color="transparent"
  >
    <div class="mt-5 mx-5">
      <v-expansion-panels
          variant="accordion"
          class="mb-3"
      >
        <v-expansion-panel value="speedtest">
          <v-expansion-panel-title>
            <div class="recovery-panel-title">
              <v-icon icon="mdi-speedometer" class="mr-2" />
              <span>{{ $t('recovery.speedtest') }}</span>
            </div>
          </v-expansion-panel-title>

          <v-expansion-panel-text>
            <SpeedtestCard />
          </v-expansion-panel-text>
        </v-expansion-panel>

        <v-expansion-panel value="connections">
          <v-expansion-panel-title>
            <div class="recovery-panel-title">
              <v-icon icon="mdi-connection" class="mr-2" />
              <span>{{ $t('recovery.connections.title') }}</span>
            </div>
          </v-expansion-panel-title>

          <v-expansion-panel-text>
            <ConnectionStatusCard />
          </v-expansion-panel-text>
        </v-expansion-panel>

        <v-expansion-panel value="tools">
          <v-expansion-panel-title>
            <div class="recovery-panel-title">
              <v-icon icon="mdi-tools" class="mr-2" />
              <span>{{ $t('recovery.tools') }}</span>
            </div>
          </v-expansion-panel-title>

          <v-expansion-panel-text> <v-alert
              :text="$t('recovery.warning')"
              type="warning"
              icon="mdi-alert-circle"
              class="mb-3"
          />

            <v-card :text="$t('recovery.delete_auth_text')" class="mb-2">
              <v-card-actions>
                <v-btn @click="triggerRecoveryApi('delete_auth')">
                  DELETE AUTH
                </v-btn>
              </v-card-actions>
            </v-card>

            <v-card :text="$t('recovery.reload_text')" class="mb-2">
              <v-card-actions>
                <v-btn @click="triggerRecoveryApi('reload')">
                  RELOAD
                </v-btn>
              </v-card-actions>
            </v-card>

            <v-card :text="$t('recovery.compress_assets_text')" class="mb-2">
              <v-card-actions>
                <v-btn @click="triggerRecoveryApi('compress_assets')">
                  COMPRESS ASSETS
                </v-btn>
              </v-card-actions>
            </v-card>
          </v-expansion-panel-text>
        </v-expansion-panel>


      </v-expansion-panels>
    </div>
  </v-card>
</template>

<script lang="ts">
import {mapState} from "pinia";
import {useAppStore} from "@/stores/app";
import SpeedtestCard from "@/components/cards/SpeedtestCard.vue";
import ConnectionStatusCard from "@/components/cards/ConnectionStatusCard.vue";

export default {
  name: 'Recovery',
  components: {SpeedtestCard, ConnectionStatusCard},
  computed: {
    ...mapState(useAppStore, ['getRestApi']),
  },
  methods: {
    async triggerRecoveryApi(endpoint: string) {
      await fetch(`${this.getRestApi}/api/recovery/${endpoint}`)
    }
  }
}
</script>

<style lang="scss" scoped>
.recovery-panel-title {
  display: flex;
  align-items: center;
}
</style>
