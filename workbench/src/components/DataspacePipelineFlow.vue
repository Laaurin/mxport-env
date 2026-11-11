<script setup lang="ts">
import { ref } from 'vue';
import type { ActorDefinition, ExecutionResult } from '../services/dataspace-client';

defineProps<{
  actor: ActorDefinition;
  result: ExecutionResult | null;
  activeRoles: string[];
  exchangedRoles: string[];
}>();

const expanded = ref(true);
</script>

<template>
  <section class="panel-card">
    <div
      class="panel-header-row panel-header-clickable"
      @click="expanded = !expanded"
    >
      <div class="panel-title-group">
        <span class="badge badge-primary">Ablaufkette</span>
        <h2 class="panel-title">
          Datenraum-Ablauf (1. Referenz/URN -> 2. Company Lookup -> 3. Gateway &amp; STS -> 4. BaSyx RBAC)
        </h2>
      </div>

      <button
        type="button"
        class="btn btn-sm"
        :class="{ 'btn-active': expanded }"
        @click.stop="expanded = !expanded"
      >
        {{ expanded ? 'Ablauf einklappen' : 'Ablauf aufklappen' }}
      </button>
    </div>

    <div v-if="expanded && result" class="pipeline-grid">
      <!-- Schritt 1: Nameplate / Asset-URN -->
      <div class="step-card">
        <div class="step-header">
          <span class="step-number">Schritt 1</span>
          <span class="step-title">Asset-Referenz / Nameplate</span>
        </div>

        <div class="io-box">
          <div class="io-label">INPUT (Auslöser / Kontext)</div>
          <div class="io-text">{{ result.originHint }}</div>
          <div class="kv-row">
            <span class="kv-label">Anfragender Akteur:</span>
            <span class="kv-value">{{ actor.name }} ({{ actor.shortCode }})</span>
          </div>
        </div>

        <div class="io-box output-box">
          <div class="io-label">OUTPUT (Semantische Kennung)</div>
          <div class="kv-row">
            <span class="kv-label">Ziel-URN:</span>
            <span class="kv-value">{{ result.targetUrn }}</span>
          </div>
          <div class="kv-row">
            <span class="kv-label">Base64Url-ID:</span>
            <span class="kv-value">{{ result.lookupStep.encodedQuery }}</span>
          </div>
        </div>
      </div>

      <!-- Schritt 2: Company Lookup -->
      <div class="step-card" :class="result.lookupStep.success ? 'step-ok' : 'step-err'">
        <div class="step-header">
          <span class="step-number">Schritt 2</span>
          <span class="step-title">Company Lookup Service</span>
          <span class="badge badge-mono" :class="result.lookupStep.fromCache ? 'badge-cache' : ''">
            {{ result.lookupStep.fromCache ? 'Cache' : `${result.lookupStep.durationMs} ms` }}
          </span>
        </div>

        <div class="io-box">
          <div class="io-label">INPUT (Discovery-Anfrage)</div>
          <div class="kv-row">
            <span class="kv-label">Service:</span>
            <span class="kv-value">http://lookup.localhost/api/v2/companies</span>
          </div>
          <div class="kv-row">
            <span class="kv-label">Query-Parameter:</span>
            <span class="kv-value">?asset_id={{ result.lookupStep.encodedQuery }}</span>
          </div>
        </div>

        <div class="io-box output-box">
          <div class="io-label">OUTPUT (Aufgelöster Endpunkt)</div>
          <div class="kv-row">
            <span class="kv-label">Gefundener Anbieter:</span>
            <span class="kv-value">{{ result.lookupStep.company?.name || 'Nicht gefunden' }}</span>
          </div>
          <div class="kv-row">
            <span class="kv-label">AAS-Repository:</span>
            <span class="kv-value">{{ result.lookupStep.aasRepositoryUrl || 'N/A' }}</span>
          </div>
          <div class="kv-row">
            <span class="kv-label">Submodel-Repository:</span>
            <span class="kv-value">{{ result.lookupStep.submodelRepositoryUrl || 'N/A' }}</span>
          </div>
        </div>
      </div>

      <!-- Schritt 3: Gateway & STS Token-Exchange -->
      <div class="step-card" :class="result.exchangedJwt ? 'step-sts' : ''">
        <div class="step-header">
          <span class="step-number">Schritt 3</span>
          <span class="step-title">Gateway &amp; STS Token-Exchange</span>
          <span class="badge badge-mono" :class="result.exchangedJwt ? 'badge-sts' : ''">
            {{ result.exchangedJwt ? 'RFC 8693' : 'Direkt' }}
          </span>
        </div>

        <div class="io-box">
          <div class="io-label">INPUT (Eingehendes Caller-Token)</div>
          <div class="kv-row">
            <span class="kv-label">Keycloak Issuer:</span>
            <span class="kv-value">{{ result.sourceJwt?.payload?.iss || 'Kein Token (Public)' }}</span>
          </div>
          <div class="kv-row">
            <span class="kv-label">Client-Rollen:</span>
            <span class="kv-value">{{ activeRoles.join(', ') || 'keine' }}</span>
          </div>
        </div>

        <div class="io-box output-box">
          <div class="io-label">OUTPUT (Transformiertes Ziel-Token)</div>
          <template v-if="result.exchangedJwt">
            <div class="kv-row">
              <span class="kv-label">Neuer STS-Issuer:</span>
              <span class="kv-value">{{ result.exchangedJwt.payload?.iss }}</span>
            </div>
            <div class="kv-row">
              <span class="kv-label">Ziel-Audience (aud):</span>
              <span class="kv-value">{{ result.exchangedJwt.payload?.aud }}</span>
            </div>
            <div class="kv-row">
              <span class="kv-label">Übernommene Rollen:</span>
              <span class="kv-value">{{ exchangedRoles.join(', ') || 'keine' }}</span>
            </div>
          </template>
          <template v-else>
            <div class="io-text">
              Kein STS-Tausch durchgeführt (Ziel-Repository ist öffentlich oder Request unauthentifiziert).
            </div>
          </template>
        </div>
      </div>

      <!-- Schritt 4: Ziel-Repository & BaSyx Dynamic RBAC -->
      <div
        class="step-card"
        :class="result.status >= 200 && result.status < 300 ? 'step-ok' : 'step-err'"
      >
        <div class="step-header">
          <span class="step-number">Schritt 4</span>
          <span class="step-title">BaSyx Dynamic RBAC</span>
          <span
            class="badge badge-mono"
            :class="result.status >= 200 && result.status < 300 ? 'badge-ok' : 'badge-err'"
          >
            HTTP {{ result.status }}
          </span>
        </div>

        <div class="io-box">
          <div class="io-label">INPUT (Autorisierter Repository-Aufruf)</div>
          <div class="kv-row">
            <span class="kv-label">Methode &amp; Ziel:</span>
            <span class="kv-value">GET {{ result.directUrl }}</span>
          </div>
          <div class="kv-row">
            <span class="kv-label">Geprüfte Rolle:</span>
            <span class="kv-value">
              {{ (exchangedRoles.length ? exchangedRoles : activeRoles).join(', ') || 'public' }}
            </span>
          </div>
        </div>

        <div class="io-box output-box">
          <div class="io-label">OUTPUT (Zugriffsergebnis &amp; Quelle)</div>
          <div class="kv-row">
            <span class="kv-label">Entscheidung:</span>
            <span class="kv-value">
              {{
                result.status >= 200 && result.status < 300
                  ? `Zugriff gewährt (HTTP ${result.status})`
                  : `Zugriff verweigert (HTTP ${result.status})`
              }}
            </span>
          </div>
          <div class="kv-row">
            <span class="kv-label">Datenquelle:</span>
            <span class="kv-value">
              {{
                result.fromCache
                  ? 'Zwischenspeicher (0 ms)'
                  : `Ursprungs-Repository (${result.durationMs} ms)`
              }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.pipeline-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.75rem;
  border-top: 1px solid var(--border-subtle);
  padding-top: 0.75rem;
}

@media (max-width: 1200px) {
  .pipeline-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 700px) {
  .pipeline-grid {
    grid-template-columns: 1fr;
  }
}

.step-card {
  background-color: var(--bg-subtle);
  border: 1px solid var(--border-default);
  border-top: 3px solid var(--accent-primary);
  border-radius: var(--radius-sm);
  padding: 0.65rem 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.step-card.step-ok {
  border-top-color: var(--status-ok-text);
}

.step-card.step-err {
  border-top-color: var(--status-err-text);
}

.step-card.step-sts {
  border-top-color: var(--accent-sts-text);
}

.step-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.4rem;
}

.step-number {
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-secondary);
}

.step-title {
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--text-primary);
  margin-right: auto;
}

.io-box {
  background-color: var(--bg-code);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 0.45rem 0.55rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.output-box {
  border-left: 2px solid var(--border-strong);
}

.io-label {
  font-size: 0.65rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-secondary);
  margin-bottom: 0.1rem;
}

.io-text {
  font-size: 0.74rem;
  color: var(--text-primary);
}
</style>

