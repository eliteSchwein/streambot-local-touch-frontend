<template>
  <v-card
    class="overflow-auto mx-auto"
    max-height="100%"
    elevation="0"
    color="transparent"
    max-width="100%"
  >
    <v-row class="mx-3 my-2">
      <template v-for="(channelPoint) in getChannelPoints?.all">
        <ChannelPoint :channelPoint="channelPoint"></ChannelPoint>
      </template>
    </v-row>
  </v-card>
</template>

<script lang="ts">
import {mapState} from "pinia";
import {useAppStore} from "@/stores/app";
export default {
  computed: {
    ...mapState(useAppStore, ['getChannelPoints']),
  }
}
</script>
