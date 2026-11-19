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
      <h2 class="panel-title">Datenraum-Ablauf (Input / Output je Schritt)</h2>

      <button
        type="button"
        class="btn btn-sm"
        @click.stop="expanded = !expanded"
      >
        {{ expanded ? 'Ablauf einklappen' : 'Ablauf anzeigen' }}
      </button>
    </div>

    <div v-if="expanded && result" class="steps-grid">
      <!-- Schritt 1: Asset-Referenz -->
      <div class="step-card">
        <div class="step-title">1. Referenz / URN</div>

        <div class="io-section">
          <div class="io-heading">Input</div>
          <div class="io-value">{{ result.originHint }}</div>
        </div>

        <div class="io-section">
          <div class="io-heading">Output</div>
          <div class="io-mono">{{ result.targetUrn }}</div>
          <div class="io-sub">Base64Url: {{ result.lookupStep.encodedQuery }}</div>
        </div>
      </div>

      <!-- Schritt 2: Company Lookup -->
      <div class="step-card">
        <div class="step-title">2. Company Lookup</div>

        <div class="io-section">
          <div class="io-heading">Input</div>
          <a
            :href="result.lookupStep.directLookupUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="ext-link break-all"
          >
            {{ result.lookupStep.directLookupUrl }}
          </a>
        </div>

        <div class="io-section">
          <div class="io-heading">Output</div>
          <div class="io-value">{{ result.lookupStep.company?.name || 'Nicht gefunden' }}</div>
          <a
            v-if="result.lookupStep.aasRepositoryUrl"
            :href="result.lookupStep.aasRepositoryUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="ext-link break-all"
          >
            {{ result.lookupStep.aasRepositoryUrl }}
          </a>
        </div>
      </div>

      <!-- Schritt 3: Gateway & STS -->
      <div class="step-card">
        <div class="step-title">3. Gateway &amp; Token-Exchange</div>

        <div class="io-section">
          <div class="io-heading">Input (Keycloak-Token)</div>
          <div class="io-mono">{{ result.sourceJwt?.payload?.iss || 'Kein Token (Öffentlich)' }}</div>
          <div class="io-sub">Rollen: {{ activeRoles.join(', ') || 'keine' }}</div>
        </div>

        <div class="io-section">
          <div class="io-heading">Output (STS-Ziel-Token)</div>
          <template v-if="result.exchangedJwt">
            <div class="io-mono">{{ result.exchangedJwt.payload?.iss }}</div>
            <div class="io-sub">
              Ziel: {{ result.exchangedJwt.payload?.aud }} | Rollen: {{ exchangedRoles.join(', ') }}
            </div>
          </template>
          <div v-else class="io-sub">
            Kein Token-Tausch erforderlich
          </div>
        </div>
      </div>

      <!-- Schritt 4: Ziel-Repository & RBAC -->
      <div class="step-card">
        <div class="step-title">4. Repository &amp; Zugriffsprüfung</div>

        <div class="io-section">
          <div class="io-heading">Input (Aufruf)</div>
          <a
            :href="result.directUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="ext-link break-all"
          >
            {{ result.directUrl }}
          </a>
        </div>

        <div class="io-section">
          <div class="io-heading">Output (Ergebnis)</div>
          <div class="io-status">
            HTTP {{ result.status }} —
            {{ result.status >= 200 && result.status < 300 ? 'Zugriff erlaubt' : 'Zugriff verweigert' }}
          </div>
          <div class="io-sub">
            {{ result.fromCache ? 'Aus Zwischenspeicher geladen' : `Vom Ursprungs-Repository geladen (${result.durationMs} ms)` }}
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.steps-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
  border-top: 1px solid var(--border-default);
  padding-top: 1rem;
}

@media (max-width: 1150px) {
  .steps-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 680px) {
  .steps-grid {
    grid-template-columns: 1fr;
  }
}

.step-card {
  background-color: var(--bg-app);
  border: 1px solid var(--border-default);
  border-radius: var(--radius);
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.9rem;
}

.step-title {
  font-size: 1rem;
  font-weight: 700;
  color: var(--text-primary);
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--border-default);
}

.io-section {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.io-heading {
  font-size: 0.78rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-secondary);
}

.io-value {
  font-size: 0.95rem;
  font-weight: 500;
  color: var(--text-primary);
}

.io-status {
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--text-primary);
}

.io-mono {
  font-family: var(--font-mono);
  font-size: 0.88rem;
  color: var(--text-primary);
  word-break: break-all;
}

.io-sub {
  font-size: 0.84rem;
  color: var(--text-secondary);
  word-break: break-all;
}

.break-all {
  word-break: break-all;
}
</style>
