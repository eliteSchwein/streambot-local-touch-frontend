<script setup lang="ts">
import { computed, ref } from 'vue'
import WifiSettingsCard from '../cards/WifiSettingsCard.vue'
import WiredSettingsCard from '../cards/WiredSettingsCard.vue'

const isOpen = ref(false)

const panelStyle = computed(() => ({
  transform: isOpen.value ? 'translateY(0)' : 'translateY(-100%)',
  transition: 'transform 220ms ease',
}))

function open() {
  isOpen.value = true
}

function close() {
  isOpen.value = false
}

function toggle() {
  isOpen.value = !isOpen.value
}

defineExpose({
  open,
  close,
  toggle,
})
</script>

<template>
  <teleport to="body">
    <div class="settings-panel" :style="panelStyle">
      <div class="settings-panel__content">
        <v-container fluid class="pa-0">
          <v-row no-gutters class="settings-panel__row">
            <v-col cols="12" sm="6" class="settings-panel__col">
              <WifiSettingsCard :panel-open="isOpen" />
            </v-col>

            <v-col cols="12" sm="6" class="settings-panel__col">
              <WiredSettingsCard :panel-open="isOpen" />
            </v-col>
          </v-row>
        </v-container>
      </div>

      <div class="settings-panel__footer">
        <v-btn
            block
            variant="tonal"
            class="settings-panel__footer-btn"
            @click="close"
        >
          <v-icon icon="mdi-chevron-up" size="24" />
        </v-btn>
      </div>
    </div>
  </teleport>
</template>

<style scoped lang="scss">
.settings-panel {
  position: fixed;
  inset: 0;
  z-index: 2000;
  background: rgb(var(--v-theme-surface));
  overflow: hidden;
  user-select: none;
  will-change: transform;
}

.settings-panel__content {
  height: calc(100vh - 92px);
  overflow: auto;
  padding: 8px 12px 12px;
}

.settings-panel__row {
  margin: 0;
}

.settings-panel__col {
  padding: 0;
}

@media (max-width: 599px) {
  .settings-panel__col + .settings-panel__col {
    margin-top: 12px;
  }
}

@media (min-width: 600px) {
  .settings-panel__col:first-child {
    padding-right: 6px;
  }

  .settings-panel__col:last-child {
    padding-left: 6px;
  }
}

.settings-panel__footer {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 56px;
  background: rgb(var(--v-theme-surface));
}

.settings-panel__footer-btn {
  width: 100%;
  height: 56px;
  border-radius: 0;
  color: rgb(var(--v-theme-on-surface));
}
</style>