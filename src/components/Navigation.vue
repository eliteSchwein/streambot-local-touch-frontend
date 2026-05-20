<script lang="ts">
import eventBus from '@/eventBus.ts'

export default {
  methods: {
    showPowerMenu() {
      eventBus.$emit('dialog:show', 'power')
    },
  },
}
</script>

<template>
  <v-bottom-navigation density="compact">
    <v-btn to="/">
      <v-icon>mdi-home-variant</v-icon>
    </v-btn>
    <v-btn to="/songlist">
      <v-icon>mdi-music</v-icon>
    </v-btn>
    <v-btn to="/audio">
      <v-icon>mdi-volume-high</v-icon>
    </v-btn>
    <v-btn to="/macros">
      <v-icon>mdi-dialpad</v-icon>
    </v-btn>
    <v-btn to="/channelPoints">
      <v-icon>mdi-motion-play-outline</v-icon>
    </v-btn>
    <v-btn to="/admin">
      <v-icon>mdi-view-dashboard</v-icon>
    </v-btn>
    <v-btn to="/recovery">
      <v-icon>mdi-heart-cog</v-icon>
    </v-btn>
    <v-btn @click="showPowerMenu" variant="plain">
      <v-icon>mdi-power</v-icon>
    </v-btn>
  </v-bottom-navigation>
</template>

<style scoped lang="scss">
:deep(.v-icon) {
  font-size: 24px;
}
</style>