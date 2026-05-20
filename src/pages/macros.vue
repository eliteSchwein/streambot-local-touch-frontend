<script lang="ts">
import {mapState} from "pinia";
import {useAppStore} from "@/stores/app";
export default {
  computed: {
    ...mapState(useAppStore, ['getMacros']),
  }
}
</script>

<template>
  <v-card
    class="overflow-auto mx-auto"
    max-height="100%"
    elevation="0"
    color="transparent"
    max-width="100%"
  >
    <v-row class="mx-3 my-2">
      <v-expansion-panels>
        <template v-for="(macro, index) in getMacros">
          <Macro :macro="macro" :name="index"></Macro>
        </template>
      </v-expansion-panels>
    </v-row>
  </v-card>
</template>

<style scoped lang="scss">

</style>
