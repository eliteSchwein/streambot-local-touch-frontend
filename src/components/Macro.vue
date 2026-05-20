<script lang="ts">

import {mapState} from "pinia";
import {useAppStore} from "@/stores/app.ts";
import {sleep} from "@/helper/GeneralHelper.ts";

export default {
  props: ['macro', 'name'],
  data() {
    return {
      loading: false,
      icon: 'mdi-play',
      color: ''
    }
  },
  computed: {
    ...mapState(useAppStore, ['getRestApi']),
  },
  methods: {
    async triggerMacro() {
      if(this.loading || this.color !== '') return
      this.loading = true

      await fetch(`${this.getRestApi}/api/macro`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({macro: this.name})
      })

      this.loading = false

      this.color = 'success'
      this.icon = 'mdi-check'

      await sleep(2_500)

      this.color = ''
      this.icon = 'mdi-play'
    }
  }
}
</script>

<template>
  <v-expansion-panel
  >
    <template v-slot:title>
      <div>
        <v-btn
          :loading="loading"
          @click.stop="triggerMacro"
          :icon="icon"
          :color="color"
          class="mr-2"
          size="small"
          density="compact"
          variant="plain">
        </v-btn>
        {{ name }}
      </div>
    </template>
    <v-expansion-panel-text class="pa-0">
      <v-table>
        <thead>
          <tr>
            <th class="text-left" style="width: 220px">
              {{ $t('macro.channel') }}
            </th>
            <th class="text-left" style="width: 220px">
              {{ $t('macro.method') }}
            </th>
            <th class="text-left">
              {{ $t('macro.data') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <template v-for="task in macro.tasks">
            <tr>
              <td>{{task.channel}}</td>
              <td>{{task.method}}</td>
              <td>{{task.data}}</td>
            </tr>
          </template>
        </tbody>
      </v-table>
    </v-expansion-panel-text>
  </v-expansion-panel>
</template>

<style scoped lang="scss">

</style>
