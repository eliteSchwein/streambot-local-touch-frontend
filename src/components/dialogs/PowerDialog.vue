<script lang="ts">
import eventBus from "@/eventBus";

export default {
  mounted(): any {
    eventBus.$on('dialog:show', (target: string) => {
      if(target === 'power') {
        this.show = true
      }
    })
  },
  data () {
    return {
      show: false
    }
  },
  methods: {
    async rebootSystem() {
      eventBus.$emit('websocket:send', {
        method: 'halt_system',
        params: {'target': 'reboot'}
      })
    },
    async shutdownSystem() {
      eventBus.$emit('websocket:send', {
        method: 'halt_system',
        params: {'target': 'halt'}
      })
    },
  }
}
</script>

<template>
  <v-dialog
    width="500"
    :model-value="show"
    persistent
  >
    <v-card
      v-if="show">
      <v-toolbar
          flat
          density="compact"
        >
        <v-toolbar-title class="d-flex align-center">
          {{ $t('power.shutdown_question') }}
        </v-toolbar-title>
        <v-btn icon="mdi-close" @click="show = false"></v-btn>
      </v-toolbar>
      <v-card-text>
        <v-row>
          <v-col>
            <v-btn
              prepend-icon="mdi-reload"
              variant="outlined"
              color="warning"
              width="100%"
              @click="rebootSystem()"
            >
              {{ $t('power.restart') }}
            </v-btn>
          </v-col>
          <v-col>
            <v-btn
              prepend-icon="mdi-power"
              variant="outlined"
              color="red"
              width="100%"
              @click="shutdownSystem()"
            >
              {{ $t('power.shutdown') }}
            </v-btn>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<style scoped lang="scss">

</style>
