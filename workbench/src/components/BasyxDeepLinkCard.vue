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
    // Ignore clipboard error
  }
}
</script>

<template>
  <section class="panel-card viewer-card">
    <div class="viewer-card-top">
      <div class="viewer-info">
        <div class="panel-eyebrow">
          Offizielle Eclipse BaSyx AAS Web UI — Instanz: {{ actor.viewerHost }}
        </div>
        <div class="viewer-title-line">
          <h2 class="panel-title">
            <template v-if="result?.lookupStep.success">
              Aufgelöste Ziel-Shell bei {{ result.lookupStep.company?.name }} im BaSyx Viewer öffnen
            </template>
            <template v-else>
              BaSyx AAS Viewer ({{ actor.viewerHost }})
            </template>
          </h2>
          <span
            v-if="result"
            class="badge badge-mono"
            :class="result.status >= 200 && result.status < 300 ? 'badge-ok' : 'badge-err'"
          >
            HTTP {{ result.status }} {{ result.statusText }}
          </span>
        </div>
        <p class="viewer-note">
          Die Authentifizierung erfolgt beim Öffnen des Links im neuen Tab automatisch über das
          OpenResty-Gateway anhand von <span class="code-inline">Origin: http://{{ actor.viewerHost }}</span>
          (Keycloak Token-Bezug + RFC 8693 STS Token-Exchange).
        </p>
      </div>

      <div class="viewer-actions">
        <a
          :href="basyxGuiUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-primary"
        >
          Im BaSyx Viewer öffnen (Neuer Tab)
        </a>
        <a
          :href="baseViewerUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="btn"
          title="Öffnet den BaSyx Viewer auf dem eigenen lokalen Repository ohne ?aas= Parameter"
        >
          Eigenes Repo ({{ actor.viewerHost }})
        </a>
      </div>
    </div>

    <div class="deeplink-row">
      <span class="deeplink-label">Deep-Link URL:</span>
      <code class="deeplink-url">{{ basyxGuiUrl }}</code>
      <button type="button" class="btn btn-sm" @click="copyUrl(basyxGuiUrl)">
        {{ copied ? 'Link kopiert' : 'Link kopieren' }}
      </button>
    </div>

    <div
      v-if="result && (result.status === 401 || result.status === 403)"
      class="rbac-alert"
    >
      <strong>Zugriff durch Gateway / BaSyx Security Submodel abgewiesen (HTTP {{ result.status }}):</strong>
      Die Ressource <span class="code-inline">{{ result.targetUrn }}</span> auf
      <span class="code-inline">{{ result.lookupStep.resolvedHost }}</span> ist für
      <strong>{{ actor.name }}</strong> (Rollen:
      <span class="code-inline">{{ activeRoles.join(', ') || 'keine' }}</span>) gesperrt.
      Beim Öffnen des Deep-Links wird die übergeordnete Shell geladen; öffentliche Teilmodelle
      (z. B. <span class="code-inline">Nameplate</span>) sind einsehbar, während geschützte Teilmodelle als
      <em>"Submodel Not Authorized!"</em> abgewiesen werden.
    </div>
  </section>
</template>

<style scoped>
.viewer-card {
  border-left: 3px solid var(--accent-primary);
}

.viewer-card-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
}

.viewer-info {
  flex: 1;
  min-width: 280px;
}

.viewer-title-line {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin-top: 0.2rem;
  flex-wrap: wrap;
}

.viewer-note {
  font-size: 0.76rem;
  color: var(--text-secondary);
  margin: 0.35rem 0 0 0;
}

.viewer-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.deeplink-row {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  background-color: var(--bg-code);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 0.42rem 0.65rem;
}

.deeplink-label {
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--text-secondary);
  white-space: nowrap;
}

.deeplink-url {
  flex: 1;
  font-family: var(--font-mono);
  font-size: 0.73rem;
  color: var(--accent-primary-text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rbac-alert {
  background-color: var(--status-err-bg);
  border: 1px solid var(--status-err-border);
  color: var(--status-err-text);
  border-radius: var(--radius-sm);
  padding: 0.55rem 0.75rem;
  font-size: 0.75rem;
}
</style>

