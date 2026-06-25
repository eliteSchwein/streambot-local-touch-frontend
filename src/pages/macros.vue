<script lang="ts">
import { mapState } from "pinia";
import { useAppStore } from "@/stores/app";

export default {
  data() {
    return {
      search: "",
    };
  },

  computed: {
    ...mapState(useAppStore, ["getMacros"]),

    filteredMacros() {
      const search = this.search.toLowerCase().trim();

      return Object.entries(this.getMacros).filter(([name]) => {
        return name.toLowerCase().includes(search);
      });
    },
  },
};
</script>

<template>
  <v-card
      class="macro-card"
      color="transparent"
      elevation="0"
  >
    <div class="macro-search">
      <v-text-field
          v-model="search"
          :label="$t('macro.search')"
          prepend-inner-icon="mdi-magnify"
          clearable
          hide-details
          density="comfortable"
          variant="outlined"
      />
    </div>

    <div class="macro-list-wrapper">
      <v-list density="compact" bg-color="transparent">
        <Macro
            v-for="[name, macro] in filteredMacros"
            :key="name"
            :macro="macro"
            :name="name"
        />
      </v-list>
    </div>
  </v-card>
</template>

<style scoped lang="scss">
.macro-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.macro-search {
  flex: 0 0 auto;
  padding: 16px 12px 8px;
  background: rgb(var(--v-theme-background));
  z-index: 2;
}

.macro-list-wrapper {
  flex: 1 1 auto;
  overflow-y: auto;
  padding: 0 0 12px;
}
</style>