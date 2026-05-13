<script setup lang="ts">


import {useI18n} from "vue-i18n";

const { t } = useI18n()
</script>

<template>
  <v-bottom-navigation density="compact">
    <v-btn to="/">
      <v-icon>mdi-home-variant</v-icon>
      <span>{{ t('navigation.home') }}</span>
    </v-btn>
    <v-btn to="/admin">
      <v-icon>mdi-view-dashboard</v-icon>
      <span>{{ t('navigation.admin') }}</span>
    </v-btn>
  </v-bottom-navigation>
</template>

<style scoped lang="scss">

</style>