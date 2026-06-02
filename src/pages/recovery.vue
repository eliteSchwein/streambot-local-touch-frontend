<template>
  <v-card
    class="overflow-auto mx-auto"
    max-height="100%"
    max-width="100%"
    elevation="0"
    color="transparent"
  >
    <div
      class="mt-5 mx-5">
      <SpeedtestCard class="mb-3"/>
      <v-alert
        :text="$t('recovery.warning')"
        type="warning"
        icon="mdi-alert-circle"
        class="mb-3"
      ></v-alert>
      <v-card :text="$t('recovery.delete_auth_text')" class="mb-2">
        <v-card-actions>
          <v-btn @click="triggerRecoveryApi('delete_auth')">AUTH RESET</v-btn>
        </v-card-actions>
      </v-card>
      <v-card :text="$t('recovery.reload_text')" class="mb-2">
        <v-card-actions>
          <v-btn @click="triggerRecoveryApi('reload')">BOT RELOAD</v-btn>
        </v-card-actions>
      </v-card>
      <v-card :text="$t('recovery.compress_assets_text')" class="mb-2">
        <v-card-actions>
          <v-btn @click="triggerRecoveryApi('compress_assets')">COMPRESS ASSETS</v-btn>
        </v-card-actions>
      </v-card>
    </div>
  </v-card>
</template>

<script lang="ts">
import {mapState} from "pinia";
import {useAppStore} from "@/stores/app";
import SpeedtestCard from "@/components/cards/SpeedtestCard.vue";

export default {
  components: {SpeedtestCard},
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

<style lang="scss">
</style>
