<script lang="ts">
import { mapState } from "pinia";
import { useAppStore } from "@/stores/app.ts";
import { sleep } from "@/helper/GeneralHelper.ts";

export default {
  props: ["macro", "name"],
  data() {
    return {
      loading: false,
      icon: "mdi-play",
      color: "",
    };
  },
  computed: {
    ...mapState(useAppStore, ["getRestApi"]),
  },
  methods: {
    async triggerMacro() {
      if (this.loading || this.color !== "") return;

      this.loading = true;

      await fetch(`${this.getRestApi}/api/macro`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ macro: this.name }),
      });

      this.loading = false;
      this.color = "success";
      this.icon = "mdi-check";

      await sleep(2500);

      this.color = "";
      this.icon = "mdi-play";
    },
  },
};
</script>

<template>
  <v-list-item
      class="macro-list-item mb-2"
      rounded="lg"
  >
    <template #prepend>
      <v-btn
          :loading="loading"
          :icon="icon"
          :color="color || 'primary'"
          size="x-large"
          density="comfortable"
          variant="tonal"
          class="macro-play-button"
          @click.stop="triggerMacro"
      />
    </template>

    <v-list-item-title class="macro-title">
      {{ name }}
    </v-list-item-title>
  </v-list-item>
</template>

<style scoped lang="scss">
.macro-list-item {
  min-height: 32px;
  padding: 10px 16px;
}

.macro-play-button {
  margin-right: 18px;
}

.macro-title {
  font-size: 1.15rem;
  font-weight: 600;
}
</style>