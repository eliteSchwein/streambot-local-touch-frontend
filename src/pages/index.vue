<template>
  <v-card
      class="overflow-auto mx-auto"
      max-height="100%"
      max-width="100%"
      elevation="0"
      color="transparent"
  >
    <div class="dashboard-layout mx-2">
      <div class="dashboard-layout__left">
        <giveaway class="mt-3" />

        <template v-if="getAlerts.length === 0">
          <v-alert
              class="mt-3"
              type="info"
              color="gray-darken-3"
              :text="$t('dashboard.no_alerts')"
          />
        </template>
        <template v-else>
          <div class="mt-3">
            <v-expansion-panels>
              <template v-for="alert in getAlerts" :key="alert.id">
                <activeAlert :alert="alert" />
              </template>
            </v-expansion-panels>
          </div>
        </template>

        <template v-if="getAutoMacros.length === 0">
          <v-alert
              class="mt-3"
              type="info"
              color="gray-darken-3"
              :text="$t('dashboard.no_auto_macros')"
          />
        </template>
        <template v-else>
          <div class="mt-3">
            <template v-for="autoMacro in getAutoMacros" :key="autoMacro.name">
              <autoMacro :autoMacro="autoMacro" />
            </template>
          </div>
        </template>
      </div>

      <div class="dashboard-layout__right">
        <MusicControls class="mt-3" />
      </div>
    </div>
  </v-card>
</template>

<script lang="ts">
import { mapState } from 'pinia'
import { useAppStore } from '@/stores/app'
import Giveaway from '@/components/Giveaway.vue'
import MusicControls from '@/components/MusicControls.vue'

export default {
  components: {
    Giveaway,
    MusicControls,
  },
  computed: {
    ...mapState(useAppStore, ['getAlerts', 'getAutoMacros']),
  },
}
</script>

<style lang="scss">
.dashboard-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 380px;
  gap: 10px;
  align-items: start;
}

.dashboard-layout__left,
.dashboard-layout__right {
  min-width: 0;
}
</style>
