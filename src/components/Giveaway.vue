<script lang="ts">
import {mapState} from "pinia";
import {useAppStore} from "@/stores/app";
import eventBus from "@/eventBus.ts";

export default {
  data() {
    return {
      giveawayTemplate: {
        content: '',
        interval: null,
      },
      times: [
        {
          title: '1 min',
          value: 1,
        },
        {
          title: '5 min',
          value: 5,
        },
        {
          title: '10 min',
          value: 10,
        },
        {
          title: '15 min',
          value: 15,
        },
        {
          title: '30 min',
          value: 30,
        },
        {
          title: '1h',
          value: 60,
        }
      ],
    }
  },
  computed: {
    ...mapState(useAppStore, ['getGiveaway']),
  },
  methods: {
    sendGiveaway() {
      eventBus.$emit('websocket:send', {
        method: 'start_giveaway',
        params: {'content': this.giveawayTemplate.content, 'duration': this.giveawayTemplate.interval}
      })
    },
    stopGiveaway() {
      eventBus.$emit('websocket:send', {
        method: 'stop_giveaway',
        params: {}
      })
    },
    deleteUser(userId: string) {
      eventBus.$emit('websocket:send', {
        method: 'remove_giveaway_user',
        params: {'user': userId}
      })
    }
  }
}
</script>

<template>
<v-card
  color="grey-darken-3"
  rounded="3"
  :subtitle="$t('giveaway.title')"
>
  <v-card-item v-if="getGiveaway.winner">
    <v-toolbar
      flat
      density="compact"
      rounded
      class="mb-2"
      color="green-darken-2"
    >
      <v-toolbar-title class="d-flex align-center" style="font-size: 1rem">
        {{ $t('giveaway.winner') }}: {{ getGiveaway.winner.name }}
      </v-toolbar-title>
      <template v-slot:append>
        <div class="d-flex ga-1">
          <v-btn icon="mdi-broom" @click="stopGiveaway"></v-btn>
        </div>
      </template>
    </v-toolbar>
  </v-card-item>
  <v-card-item v-else-if="getGiveaway.active">
    <v-toolbar
      flat
      density="compact"
      rounded
      class="mb-2"
      color="teal-darken-3"
    >
      <v-toolbar-title class="d-flex align-center" style="font-size: 1rem">
        {{ $t('giveaway.active') }}: {{ getGiveaway.content }}
      </v-toolbar-title>
      <v-progress-linear
        :model-value="100 / getGiveaway.interval * getGiveaway.currentInterval"
        location="bottom"
        absolute
        rounded
        color="teal-lighten-1"
      />
      <template v-slot:append>
        <div class="d-flex ga-1">
          <v-btn icon="mdi-stop-circle" @click="stopGiveaway"></v-btn>
        </div>
      </template>
    </v-toolbar>
    <v-expansion-panels>
      <v-expansion-panel
          :title="getGiveaway.users.length + ' ' + $t('giveaway.participants')"
          color="grey-darken-2">
        <v-expansion-panel-text class="pa-0">
          <v-table>
            <thead>
            <tr>
              <th class="text-left">
                {{ $t('giveaway.name') }}
              </th>
              <th class="text-left" style="width: 50px">
              </th>
            </tr>
            </thead>
            <tbody>
              <template v-for="user in getGiveaway.users">
                <tr>
                  <td>{{user.displayName}}</td>
                  <td>
                    <v-btn icon="mdi-trash-can" color="red" variant="text" density="compact" @click="deleteUser(user.id)"></v-btn>
                  </td>
                </tr>
              </template>
            </tbody>
          </v-table>
        </v-expansion-panel-text>
      </v-expansion-panel>
    </v-expansion-panels>
  </v-card-item>
  <v-card-item v-else>
    <v-row>
      <v-col cols="12" md="6" xl="8">
        <v-text-field
          class="mt-1"
          :label="$t('giveaway.content_label')"
          variant="outlined"
          v-model="giveawayTemplate.content"
          density="compact"
          hide-details
        ></v-text-field>
      </v-col>
      <v-col cols="6" md="3" xl="2">
        <v-select
          class="mt-1"
          :label="$t('giveaway.duration')"
          :items="times"
          v-model="giveawayTemplate.interval"
          variant="outlined"
          density="compact"
          hide-details
        ></v-select>
      </v-col>
      <v-col cols="6" md="3" xl="2">
        <v-btn @click="sendGiveaway" prepend-icon="mdi-send" variant="tonal" class="mt-1" width="100%">
          {{ $t('giveaway.create') }}
        </v-btn>
      </v-col>
    </v-row>
  </v-card-item>
</v-card>
</template>

<style scoped lang="scss">

</style>
