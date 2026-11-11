<script setup lang="ts">
import { ref, computed } from 'vue';
import {
  decodeJwtBundle,
  type ActorDefinition,
  type ExecutionResult,
} from '../services/dataspace-client';

const props = defineProps<{
  actor: ActorDefinition;
  result: ExecutionResult | null;
  activeToken: string | null;
  decodedToken: Record<string, any> | null;
  activeRoles: string[];
  exchangedRoles: string[];
}>();

const expanded = ref(false);
const copiedKey = ref<string | null>(null);
const customJwtInput = ref('');

const sourcePayload = computed(() => {
  return props.result?.sourceJwt?.payload || props.decodedToken;
});

const sourceRaw = computed(() => {
  return props.result?.sourceJwt?.raw || props.activeToken || '';
});

const exchangedBundle = computed(() => {
  return props.result?.exchangedJwt || null;
});

const customDecodedJwt = computed(() => {
  if (!customJwtInput.value.trim()) return null;
  return decodeJwtBundle(customJwtInput.value.trim());
});

async function copyToken(text: string | null | undefined, key: string) {
  if (!text) return;
  try {
    await navigator.clipboard.writeText(text);
    copiedKey.value = key;
    setTimeout(() => {
      if (copiedKey.value === key) copiedKey.value = null;
    }, 1800);
  } catch {
    // Ignore clipboard error
  }
}
</script>

<template>
  <section class="panel-card">
    <!-- Compact 1-Line Summary Bar (Always Visible) -->
    <div class="panel-header-row">
      <div class="panel-title-group">
        <span class="badge badge-sts">JWT Transformation</span>

        <template v-if="sourceRaw">
          <div class="token-summary-chain">
            <span class="token-node">
              <strong>INPUT:</strong> Keycloak (<code>{{ actor.realm }}</code>)
              <span v-if="activeRoles.length" class="badge badge-ok badge-mono">
                {{ activeRoles.join(', ') }}
              </span>
            </span>

            <span class="chain-arrow">-></span>

            <span v-if="exchangedBundle" class="token-node">
              <strong>OUTPUT:</strong> MX-Port Leo STS (<code>{{ exchangedBundle.payload?.iss }}</code>)
              <span class="badge badge-sts badge-mono">aud={{ exchangedBundle.payload?.aud }}</span>
            </span>
            <span v-else class="token-node muted">
              <strong>OUTPUT:</strong> Kein STS-Tausch (Ziel-Endpunkt öffentlich)
            </span>
          </div>
        </template>

        <span v-else class="token-node muted">
          Öffentlicher Akteur ({{ actor.name }}) — kein Keycloak-Token im Einsatz
        </span>
      </div>

      <div class="token-action-group">
        <button
          v-if="sourceRaw"
          type="button"
          class="btn btn-sm"
          @click="copyToken(sourceRaw, 'src')"
        >
          {{ copiedKey === 'src' ? 'Keycloak JWT kopiert' : 'Keycloak JWT kopieren' }}
        </button>

        <button
          v-if="exchangedBundle?.raw"
          type="button"
          class="btn btn-sm btn-sts"
          @click="copyToken(exchangedBundle.raw, 'sts')"
        >
          {{ copiedKey === 'sts' ? 'STS JWT kopiert' : 'STS JWT kopieren' }}
        </button>

        <button
          type="button"
          class="btn btn-sm"
          :class="{ 'btn-active': expanded }"
          @click="expanded = !expanded"
        >
          {{ expanded ? 'Token-Details einklappen' : 'Dekodieren & Vergleichen' }}
        </button>
      </div>
    </div>

    <!-- Collapsible Side-by-Side Comparison & Decoder -->
    <div v-if="expanded" class="jwt-details-grid">
      <!-- Column 1: Source Token (Keycloak) -->
      <div class="jwt-column">
        <div class="jwt-col-header">
          <div>
            <span class="badge badge-primary">1. INPUT: Ursprungs-Token (Keycloak IdP)</span>
            <div class="jwt-col-sub">
              Ausgestellt für <code>{{ actor.clientId || 'public' }}</code>
            </div>
          </div>
          <button
            v-if="sourceRaw"
            type="button"
            class="btn btn-sm"
            @click="copyToken(sourceRaw, 'col-src')"
          >
            {{ copiedKey === 'col-src' ? 'Kopiert' : 'Raw JWT kopieren' }}
          </button>
        </div>

        <template v-if="sourcePayload">
          <div class="claims-box">
            <div class="kv-row">
              <span class="kv-label">iss (Issuer):</span>
              <span class="kv-value">{{ sourcePayload.iss }}</span>
            </div>
            <div class="kv-row">
              <span class="kv-label">azp (Client):</span>
              <span class="kv-value">{{ sourcePayload.azp }}</span>
            </div>
            <div class="kv-row">
              <span class="kv-label">aud (Audience):</span>
              <span class="kv-value">{{ JSON.stringify(sourcePayload.aud) }}</span>
            </div>
            <div class="kv-row">
              <span class="kv-label">Rollen:</span>
              <span class="kv-value role-text">{{ activeRoles.join(', ') || 'keine' }}</span>
            </div>
          </div>

          <input
            type="text"
            readonly
            class="input-field input-mono raw-token-field"
            :value="sourceRaw"
            title="Klicken zum Markieren"
            @focus="($event.target as HTMLInputElement).select()"
          />

          <pre class="code-block jwt-pre">{{ JSON.stringify(sourcePayload, null, 2) }}</pre>
        </template>
        <div v-else class="empty-note">
          Kein Keycloak-Token für diesen Akteur vorhanden.
        </div>
      </div>

      <!-- Column 2: Exchanged Token (MX-Port Leo STS) -->
      <div class="jwt-column sts-column">
        <div class="jwt-col-header">
          <div>
            <span class="badge badge-sts">2. OUTPUT: Getauschtes Ziel-Token (Leo STS)</span>
            <div class="jwt-col-sub">Transformiert am Ziel-Gateway nach RFC 8693</div>
          </div>
          <button
            v-if="exchangedBundle?.raw"
            type="button"
            class="btn btn-sm btn-sts"
            @click="copyToken(exchangedBundle.raw, 'col-sts')"
          >
            {{ copiedKey === 'col-sts' ? 'Kopiert' : 'Raw STS-JWT kopieren' }}
          </button>
        </div>

        <template v-if="exchangedBundle">
          <div class="claims-box">
            <div class="kv-row">
              <span class="kv-label">iss (Neuer Issuer):</span>
              <span class="kv-value changed-claim">{{ exchangedBundle.payload?.iss }}</span>
            </div>
            <div class="kv-row">
              <span class="kv-label">aud (Ziel-Service):</span>
              <span class="kv-value changed-claim">{{ exchangedBundle.payload?.aud }}</span>
            </div>
            <div class="kv-row">
              <span class="kv-label">environment:</span>
              <span class="kv-value changed-claim">{{ exchangedBundle.payload?.environment }}</span>
            </div>
            <div class="kv-row">
              <span class="kv-label">kid (Signing Key):</span>
              <span class="kv-value changed-claim">{{ exchangedBundle.header?.kid }}</span>
            </div>
            <div class="kv-row">
              <span class="kv-label">Übernommene Rollen:</span>
              <span class="kv-value role-text">{{ exchangedRoles.join(', ') || 'keine' }}</span>
            </div>
          </div>

          <input
            type="text"
            readonly
            class="input-field input-mono raw-token-field"
            :value="exchangedBundle.raw"
            title="Klicken zum Markieren"
            @focus="($event.target as HTMLInputElement).select()"
          />

          <pre class="code-block jwt-pre">{{ JSON.stringify({ header: exchangedBundle.header, payload: exchangedBundle.payload }, null, 2) }}</pre>
        </template>
        <div v-else class="empty-note">
          Für diesen Aufruf fand kein STS-Token-Tausch statt (öffentlicher Endpunkt A/B/C oder unauthentifizierter Aufruf).
        </div>
      </div>

      <!-- Column 3: Manual JWT Decoder -->
      <div class="jwt-column">
        <div class="jwt-col-header">
          <div>
            <span class="badge">Manueller JWT-Decoder</span>
            <div class="jwt-col-sub">Beliebiges JWT einfügen, um Header &amp; Payload zu prüfen</div>
          </div>
          <button
            v-if="customJwtInput"
            type="button"
            class="btn btn-sm"
            @click="customJwtInput = ''"
          >
            Leeren
          </button>
        </div>

        <input
          v-model="customJwtInput"
          type="text"
          class="input-field input-mono raw-token-field"
          placeholder="eyJhbGciOiJSUzI1NiIs... hier einfügen"
        />

        <pre v-if="customDecodedJwt" class="code-block jwt-pre">{{ JSON.stringify(customDecodedJwt, null, 2) }}</pre>
        <div v-else class="empty-note">
          Füge hier ein kopiertes Keycloak- oder STS-Token (z. B. aus Postman) ein, um es direkt zu dekodieren.
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.token-summary-chain {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.token-node {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.76rem;
  color: var(--text-primary);
}

.token-node.muted {
  color: var(--text-secondary);
}

.token-node code {
  font-family: var(--font-mono);
  color: var(--accent-primary-text);
}

.chain-arrow {
  font-family: var(--font-mono);
  color: var(--text-secondary);
  font-weight: 600;
}

.token-action-group {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  flex-wrap: wrap;
}

.jwt-details-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.75rem;
  border-top: 1px solid var(--border-subtle);
  padding-top: 0.75rem;
}

@media (max-width: 1150px) {
  .jwt-details-grid {
    grid-template-columns: 1fr;
  }
}

.jwt-column {
  background-color: var(--bg-subtle);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-sm);
  padding: 0.65rem 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.jwt-column.sts-column {
  border-color: var(--accent-sts-border);
}

.jwt-col-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.5rem;
}

.jwt-col-sub {
  font-size: 0.69rem;
  color: var(--text-secondary);
  margin-top: 0.2rem;
}

.claims-box {
  background-color: var(--bg-code);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 0.45rem 0.55rem;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.changed-claim {
  color: var(--accent-sts-text);
  font-weight: 600;
}

.role-text {
  color: var(--status-ok-text);
  font-weight: 600;
}

.raw-token-field {
  width: 100%;
  font-size: 0.7rem;
}

.jwt-pre {
  max-height: 170px;
}

.empty-note {
  font-size: 0.74rem;
  color: var(--text-secondary);
  padding: 0.5rem 0;
}
</style>

