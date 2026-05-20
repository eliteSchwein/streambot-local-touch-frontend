<script setup lang="ts">
import { useAppStore } from '@/stores/app';

const appOption = useAppStore();

type ChannelPoint = {
  name: string
  active: boolean
  background: string
  image: string
}

defineProps<{
  channelPoint: ChannelPoint
}>()

const loading = ref<boolean | undefined>(false);

function getBackgroundColor(channelPoint: any) {
  if(channelPoint.active) {
    return channelPoint.background;
  }

  return "grey-darken-3"
}

async function toggleChannelPoint(channelPoint: any) {
  if(loading.value) return

  loading.value = true

  const method = channelPoint.active ? "disable" : "enable";

  channelPoint.active = false

  await fetch(`${appOption.getRestApi}/api/channel_points/toggle`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({channel_point: channelPoint, state: method})
  })

  loading.value = false
}

</script>

<template>
  <v-col class="mt-3" cols="12" sm="6" md="4" xl="3" xxl="2">
    <v-card
      :color="getBackgroundColor(channelPoint)"
      @click.stop="toggleChannelPoint(channelPoint)"
      height="100%"
    >
      <v-card-item style="max-height: 100px">
        <v-row
          align-content="center"
          justify="center"
          align="center"
        >
          <v-col>
            <v-img
              :src="channelPoint.image"
              cover
              :style="{ 'max-width': '80px', 'filter': channelPoint.active === true ? 'none' : 'grayscale(100%)' }"
            >
              <div class="d-flex align-center justify-center fill-height " :style="{ backdropFilter: loading ? 'blur(2px)' : 'none' }" v-if="loading">
                <v-progress-circular
                  color="grey-lighten-4"
                  indeterminate
                ></v-progress-circular>
              </div>
            </v-img>
          </v-col>
          <v-col>
            {{channelPoint.name}}
          </v-col>
          <v-col>
            <v-row
              justify="center"
            >
              <v-switch
                hide-details
                density="compact"
                :model-value="channelPoint.active"
                :indeterminate="loading"
                @click="toggleChannelPoint(channelPoint)"
              ></v-switch>
            </v-row>
          </v-col>
        </v-row>
      </v-card-item>
    </v-card>
  </v-col>
</template>

<style scoped lang="scss">
</style>
