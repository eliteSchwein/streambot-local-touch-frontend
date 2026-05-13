<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from "vue";
import Header from "./components/Header.vue";
import Navigation from "@/components/Navigation.vue";
import { getCurrentWindow } from '@tauri-apps/api/window'
import {invoke} from "@tauri-apps/api/core";

const targetAddress = ref("http://localhost:8105");

const ready = ref(false);
const updating = ref(false);
const stage = ref("Unknown");

let watchdogId: number | null = null;

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchStatus() {
  let status = {
    bootup_stage: "Unknown",
    ready: false,
    updating: false,
  };

  try {
    const response = await fetch(`${targetAddress.value}/api/status`, {
      cache: "no-store",
    });

    const json = await response.json();
    status = {
      bootup_stage: json?.data?.bootup_stage ?? "Unknown",
      ready: json?.data?.ready ?? false,
      updating: json?.data?.updating ?? false,
    };
  } catch (e) {
    console.warn(e);
  }

  return status;
}

function startTwitchAuth() {
  const returnTo = encodeURIComponent(window.location.href);
  window.location.href = `${targetAddress.value}/commander?returnTo=${returnTo}`;
}

async function bootupSequence() {
  stage.value = "Unknown";
  ready.value = false;

  let status = await fetchStatus();
  updating.value = status.updating ?? false;

  while (!status.ready) {
    stage.value = status.bootup_stage ?? "Unknown";
    updating.value = status.updating ?? false;

    await sleep(250);
    status = await fetchStatus();
  }

  updating.value = status.updating ?? false;
  ready.value = true;
}

async function init() {
  await bootupSequence();

  watchdogId = window.setInterval(async () => {
    if (!ready.value) return;

    const status = await fetchStatus();

    if (status.ready) return;

    ready.value = false;
    updating.value = status.updating ?? false;
    await bootupSequence();
  }, 1000);
}

async function wakeMainWindow() {
  try {
    await invoke("wake_main_window");
  } catch (error) {
    console.warn("Failed to wake main window:", error);
  }
}

onMounted(async () => {
  await wakeMainWindow()
  await init();
});

onBeforeUnmount(() => {
  if (watchdogId !== null) {
    clearInterval(watchdogId);
  }
});
</script>

<template>
  <v-app style="overflow: hidden">
    <div class="app-shell">
      <Header />

      <div class="app-content">
        <template v-if="updating">
          <v-card color="transparent" rounded="0" flat class="boot-root">
            <v-layout class="boot-layout">
              <div class="boot-bg" aria-hidden="true" />

              <v-card class="boot-card" rounded="xl" elevation="12">
                <v-card-text class="pa-8 pa-md-10">
                  <div class="d-flex align-center justify-space-between">
                    <div class="d-flex align-center ga-4">
                      <div>
                        <div class="text-h5 font-weight-bold">Bot Updating</div>
                        <div class="text-body-2 text-medium-emphasis">
                          Please wait while the system is updating…
                        </div>
                      </div>
                    </div>
                  </div>
                </v-card-text>
              </v-card>
            </v-layout>
          </v-card>
        </template>

        <template v-else-if="ready">
          <router-view />
        </template>

        <template v-else-if="stage === 'auth'">
          <v-card color="transparent" rounded="0" flat class="boot-root">
            <v-layout class="boot-layout">
              <div class="boot-bg" aria-hidden="true" />

              <v-card class="boot-card" rounded="xl" elevation="12">
                <v-card-text class="pa-8 pa-md-10">
                  <div class="text-h5 font-weight-bold mb-2">Twitch Login Required</div>
                  <div class="text-body-2 text-medium-emphasis mb-6">
                    Continue the login flow in this window.
                  </div>

                  <v-btn color="primary" @click="startTwitchAuth">
                    Continue to Twitch Login
                  </v-btn>

                  <div class="mt-6 text-body-2">
                    <span class="text-medium-emphasis">Stage:</span>
                    <span class="font-weight-medium ms-2">
                      {{ stage || "Unknown" }}
                    </span>
                  </div>
                </v-card-text>
              </v-card>
            </v-layout>
          </v-card>
        </template>

        <template v-else>
          <v-card color="transparent" rounded="0" flat class="boot-root">
            <v-layout class="boot-layout">
              <div class="boot-bg" aria-hidden="true" />

              <v-card class="boot-card" rounded="xl" elevation="12">
                <v-card-text class="pa-8 pa-md-10">
                  <div class="d-flex align-center justify-space-between mb-6">
                    <div class="d-flex align-center ga-4">
                      <div>
                        <div class="text-h5 font-weight-bold">Bot starting</div>
                        <div class="text-body-2 text-medium-emphasis">
                          Please wait while services initialize…
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="d-flex align-center ga-4">
                    <div class="text-body-2">
                      <span class="text-medium-emphasis">Stage:</span>
                      <span class="font-weight-medium ms-2">
                        {{ stage || "Unknown" }}
                      </span>
                    </div>
                  </div>
                </v-card-text>
              </v-card>
            </v-layout>
          </v-card>
        </template>
      </div>

      <Navigation />
    </div>
  </v-app>
</template>

<style scoped>
.app-shell {
  height: 100dvh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.app-content {
  flex: 1;
  min-height: 0;
  width: 100%;
}

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

.boot-root {
  height: 100%;
}

.boot-layout {
  height: 100%;
  min-height: 100%;
  position: relative;
  overflow: hidden;
  display: grid;
  place-items: center;
  padding: 24px;
}

.boot-bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background:
      radial-gradient(circle at top left, transparent 9%, #3A0045 10%, #3A0045 15%, transparent 16%),
      radial-gradient(circle at bottom left, transparent 9%, #3A0045 10%, #3A0045 15%, transparent 16%),
      radial-gradient(circle at top right, transparent 9%, #3A0045 10%, #3A0045 15%, transparent 16%),
      radial-gradient(circle at bottom right, transparent 9%, #3A0045 10%, #3A0045 15%, transparent 16%),
      radial-gradient(circle, transparent 25%, #000000 26%),
      linear-gradient(45deg, transparent 46%, #3A0045 47%, #3A0045 52%, transparent 53%),
      linear-gradient(135deg, transparent 46%, #3A0045 47%, #3A0045 52%, transparent 53%);
  background-size: 3em 3em;
  background-color: #000000;
  animation: rainbow-cycle 12s linear infinite;
}

@keyframes rainbow-cycle {
  from {
    filter: hue-rotate(0deg);
  }
  to {
    filter: hue-rotate(360deg);
  }
}

.boot-card {
  width: min(620px, 92vw);
  border: 1px solid rgba(255, 255, 255, 0.1);
  background: rgba(18, 18, 22, 0.8);
  backdrop-filter: blur(14px);
}
</style>