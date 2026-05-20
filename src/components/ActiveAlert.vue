<script setup lang="ts">

import {formatSeconds} from "@/helper/GeneralHelper.ts";
import eventBus from "@/eventBus.ts";

defineProps({
  alert: {
    type: Object,
    default: null,
  },
})

function removeAlert(eventUuid: string) {
  eventBus.$emit('websocket:send', {
    method: 'remove_event',
    params: {'event-uuid': eventUuid}
  })
}

</script>

<template>
  <v-expansion-panel
    :color="alert.active ? 'green-darken-2' : 'grey-darken-3'"
    :title="$t('alert.title') + ': ' + alert['event-uuid'] + ' - ' + formatSeconds(alert.duration)"
  >
    <v-expansion-panel-text class="pa-0">
      <v-table>
        <thead>
        <tr>
          <th class="text-left" style="width: 220px">
            {{ $t('alert.name') }}
          </th>
          <th class="text-left">
            {{ $t('alert.value') }}
          </th>
        </tr>
        </thead>
        <tbody>
        <tr>
          <td><v-icon icon="mdi-broadcast"></v-icon> {{ $t('alert.channel') }}</td>
          <td>{{alert.channel}}</td>
        </tr>
        <tr v-if="alert.icon">
          <td><v-icon icon="mdi-circle-slice-1"></v-icon> {{ $t('alert.icon') }}</td>
          <td>{{alert.icon}}</td>
        </tr>
        <tr v-if="alert.message">
          <td><v-icon icon="mdi-message"></v-icon> {{ $t('alert.message') }}</td>
          <td>{{alert.message}}</td>
        </tr>
        <tr v-if="alert.sound">
          <td><v-icon icon="mdi-volume-low"></v-icon> {{ $t('alert.sound') }}</td>
          <td>{{alert.sound}}</td>
        </tr>
        <tr v-if="alert.video">
          <td><v-icon icon="mdi-video"></v-icon> {{ $t('alert.video') }}</td>
          <td>{{alert.video}}</td>
        </tr>
        <tr v-if="alert.lamp_color">
          <td><v-icon icon="mdi-lamp"></v-icon> {{ $t('alert.lamp_color') }}</td>
          <td>{{alert.lamp_color}}</td>
        </tr>
        </tbody>
      </v-table>

      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn
          variant="text"
          :color="alert.active ? 'error': ''"
          @click="removeAlert(alert['event-uuid'])"
        >
          <v-icon icon="mdi-trash-can"></v-icon>
        </v-btn>
      </v-card-actions>
    </v-expansion-panel-text>
  </v-expansion-panel>
</template>

<style scoped lang="scss">

</style>
