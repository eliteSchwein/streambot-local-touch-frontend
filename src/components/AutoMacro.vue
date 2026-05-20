<script setup lang="ts">

import eventBus from "@/eventBus.ts";
defineProps({
  autoMacro: {}
})

function toggleAutoMacro(autoMacro: any) {
  autoMacro.enabled = !autoMacro.enabled
  eventBus.$emit('websocket:send', {
    method: 'toggle_auto_macro',
    params: {'name': autoMacro.name, 'enable': autoMacro.enabled}
  })
}

</script>

<template>
  <v-toolbar
    flat
    density="compact"
    rounded
    class="mb-2"
  >
    <v-toolbar-title class="d-flex align-center" style="font-size: 1rem">
      {{autoMacro.name}}
    </v-toolbar-title>
    <v-progress-linear
      :active="autoMacro.enabled"
      :model-value="100 / autoMacro.interval * autoMacro.current_interval"
      location="bottom"
      absolute
      rounded
      color="grey-darken-1"
    ></v-progress-linear>
    <template v-slot:append>
      <div class="d-flex ga-1 mr-3">
        <v-switch
          hide-details
          density="compact"
          :model-value="autoMacro.enabled"
          @click="toggleAutoMacro(autoMacro)"
        ></v-switch>
      </div>
    </template>
  </v-toolbar>
</template>

<style scoped lang="scss">

</style>
