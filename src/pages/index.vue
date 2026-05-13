<script setup lang="ts">
const targetAddress = ref("http://localhost:8105");
</script>

<template>
  <div class="iframe-container">
    <iframe :src="`${targetAddress}/commander`"></iframe>
  </div>
</template>

<style scoped lang="scss">
.iframe-container {
  height: 100%;
  width: 100%;
}

iframe {
  display: block;
  width: 100%;
  height: 100%;
  border: none;
}
</style>