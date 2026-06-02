<script lang="ts">
import eventBus from "@/eventBus";
import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";

export default {
  mounted(): any {
    // Keep this exactly like before so the touch UI power button still works.
    eventBus.$on('dialog:show', (target: string) => {
      if(target === 'power') {
        this.error = null
        this.show = true
      }
    })

    // Physical power button from the Tauri backend uses the same dialog path.
    listen('notify_power_button', () => {
      eventBus.$emit('dialog:show', 'power')
    }).then((unlisten) => {
      this.powerButtonUnlisten = unlisten
    })
  },

  beforeUnmount(): void {
    if (this.powerButtonUnlisten) {
      this.powerButtonUnlisten()
      this.powerButtonUnlisten = null
    }
  },

  data () {
    return {
      show: false,
      busy: false,
      loadingAction: null as 'reboot_system' | 'shutdown_system' | 'restart_streambot_service' | null,
      error: null as string | null,
      powerButtonUnlisten: null as UnlistenFn | null,
    }
  },

  methods: {
    async rebootSystem() {
      await this.runPowerCommand('reboot_system')
    },

    async shutdownSystem() {
      await this.runPowerCommand('shutdown_system')
    },

    async restartStreambotService() {
      await this.runPowerCommand('restart_streambot_service')
    },

    async runPowerCommand(command: 'reboot_system' | 'shutdown_system' | 'restart_streambot_service') {
      if (this.busy) return

      this.busy = true
      this.loadingAction = command
      this.error = null

      try {
        await invoke(command)
        this.show = false
      } catch (error) {
        this.error = String(error)
      } finally {
        this.busy = false
        this.loadingAction = null
      }
    },
  }
}
</script>

<template>
  <v-dialog
      width="760"
      :model-value="show"
      persistent
  >
    <v-card
        v-if="show"
        rounded="lg"
    >
      <v-card-title class="power-dialog__title">
        {{ $t('power.shutdown_question') }}
      </v-card-title>

      <v-card-text class="power-dialog__content">
        <v-alert
            v-if="error"
            type="error"
            variant="tonal"
            density="compact"
            class="mb-4"
        >
          {{ error }}
        </v-alert>

        <div class="power-dialog__grid">
          <div class="power-dialog__tile">
            <v-btn
                class="power-dialog__btn"
                color="error"
                variant="tonal"
                :loading="loadingAction === 'shutdown_system'"
                :disabled="busy"
                @click="shutdownSystem()"
            >
              <div class="power-dialog__btn-content">
                <v-icon size="18">mdi-power</v-icon>
                <span>{{ $t('power.shutdown') }}</span>
              </div>
            </v-btn>
          </div>

          <div class="power-dialog__tile">
            <v-btn
                class="power-dialog__btn"
                color="warning"
                variant="tonal"
                :loading="loadingAction === 'reboot_system'"
                :disabled="busy"
                @click="rebootSystem()"
            >
              <div class="power-dialog__btn-content">
                <v-icon size="18">mdi-restart</v-icon>
                <span>{{ $t('power.restart') }}</span>
              </div>
            </v-btn>
          </div>

          <div class="power-dialog__tile">
            <v-btn
                class="power-dialog__btn"
                variant="tonal"
                :loading="loadingAction === 'restart_streambot_service'"
                :disabled="busy"
                @click="restartStreambotService()"
            >
              <div class="power-dialog__btn-content">
                <v-icon size="18">mdi-server</v-icon>
                <span>Restart Streambot</span>
              </div>
            </v-btn>
          </div>
        </div>
      </v-card-text>

      <v-card-actions>
        <v-spacer />
        <v-btn
            variant="text"
            :disabled="busy"
            @click="show = false"
        >
          {{ $t('dialog.close') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<style scoped>
.power-dialog__title {
  padding-bottom: 0;
}

.power-dialog__content {
  padding-top: 12px;
}

.power-dialog__grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
}

.power-dialog__tile {
  position: relative;
  width: 100%;
  aspect-ratio: 1 / 1;
}

.power-dialog__btn {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  min-width: 0;
  padding: 0;
}

.power-dialog__btn-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  width: 100%;
  height: 100%;
  text-align: center;
}

.power-dialog__btn-content span {
  font-size: 0.75rem;
  line-height: 1.1;
  max-width: 100%;
  letter-spacing: 0.04em;
}

.power-dialog__btn :deep(.v-btn__content) {
  width: 100%;
  height: 100%;
}

@media (max-width: 620px) {
  .power-dialog__grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>
