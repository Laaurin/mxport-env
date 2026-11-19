<script setup lang="ts">
import { ref } from 'vue';
import type { ActorDefinition, ExecutionResult } from '../services/dataspace-client';

defineProps<{
  actor: ActorDefinition;
  result: ExecutionResult | null;
  basyxGuiUrl: string;
  baseViewerUrl: string;
  activeRoles: string[];
}>();

const copied = ref(false);

async function copyUrl(url: string) {
  try {
    await navigator.clipboard.writeText(url);
    copied.value = true;
    setTimeout(() => {
      copied.value = false;
    }, 1800);
  } catch {
    // Ignore
  }
}
</script>

<template>
  <section class="panel-card">
    <div class="viewer-row">
      <div class="viewer-main">
        <h2 class="panel-title">BaSyx AAS Viewer Deep-Link ({{ actor.viewerHost }})</h2>
        <div class="deeplink-line">
          <a
            :href="basyxGuiUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="ext-link"
          >
            {{ basyxGuiUrl }}
          </a>
        </div>
      </div>

      <div class="viewer-buttons">
        <button type="button" class="btn btn-sm" @click="copyUrl(basyxGuiUrl)">
          {{ copied ? 'Link kopiert' : 'Link kopieren' }}
        </button>
        <a
          :href="basyxGuiUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-primary"
        >
          Im BaSyx Viewer öffnen (Neuer Tab)
        </a>
      </div>
    </div>

    <div
      v-if="result && (result.status === 401 || result.status === 403)"
      class="denial-note"
    >
      Hinweis: Der direkte Abruf von <code>{{ result.targetUrn }}</code> wurde für
      <strong>{{ actor.name }}</strong> mit <strong>HTTP {{ result.status }}</strong> abgewiesen.
      Im BaSyx Viewer sind daher nur öffentlich freigegebene Teilmodelle (wie <code>Nameplate</code>)
      sichtbar, während geschützte Teilmodelle gesperrt bleiben.
    </div>
  </section>
</template>

<style scoped>
.viewer-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1.5rem;
  flex-wrap: wrap;
}

.viewer-main {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  min-width: 0;
  flex: 1;
}

.deeplink-line {
  word-break: break-all;
}

.viewer-buttons {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  flex-wrap: wrap;
}

.denial-note {
  border-top: 1px solid var(--border-default);
  padding-top: 0.85rem;
  font-size: 0.92rem;
  color: var(--text-secondary);
}

.denial-note strong {
  color: var(--text-primary);
}
</style>
