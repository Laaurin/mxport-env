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
    // Ignore
  }
}
</script>

<template>
  <section class="panel-card">
    <div class="panel-header-row">
      <div class="jwt-summary-left">
        <h2 class="panel-title">JWT Token-Umwandlung</h2>

        <span v-if="sourceRaw" class="jwt-summary-text">
          Keycloak ({{ actor.realm }}) ->
          {{ exchangedBundle ? `STS (${exchangedBundle.payload?.aud})` : 'Kein STS-Tausch' }}
        </span>
        <span v-else class="jwt-summary-text">
          Öffentlicher Aufruf ohne Token
        </span>
      </div>

      <div class="jwt-actions">
        <button
          v-if="sourceRaw"
          type="button"
          class="btn btn-sm"
          @click="copyToken(sourceRaw, 'src')"
        >
          {{ copiedKey === 'src' ? 'Keycloak-Token kopiert' : 'Keycloak-Token kopieren' }}
        </button>

        <button
          v-if="exchangedBundle?.raw"
          type="button"
          class="btn btn-sm"
          @click="copyToken(exchangedBundle.raw, 'sts')"
        >
          {{ copiedKey === 'sts' ? 'STS-Token kopiert' : 'STS-Token kopieren' }}
        </button>

        <button
          type="button"
          class="btn btn-sm"
          @click="expanded = !expanded"
        >
          {{ expanded ? 'Token-Decoder einklappen' : 'Tokens dekodieren & vergleichen' }}
        </button>
      </div>
    </div>

    <div v-if="expanded" class="jwt-grid">
      <!-- Column 1: Source Token -->
      <div class="jwt-col">
        <div class="jwt-col-head">
          <div class="jwt-col-title">1. Input: Ursprungs-Token (Keycloak)</div>
          <button
            v-if="sourceRaw"
            type="button"
            class="btn btn-sm"
            @click="copyToken(sourceRaw, 'col-src')"
          >
            {{ copiedKey === 'col-src' ? 'Kopiert' : 'Kopieren' }}
          </button>
        </div>

        <template v-if="sourcePayload">
          <div class="claims-list">
            <div><strong>Issuer (iss):</strong> {{ sourcePayload.iss }}</div>
            <div><strong>Client (azp):</strong> {{ sourcePayload.azp }}</div>
            <div><strong>Rollen:</strong> {{ activeRoles.join(', ') || 'keine' }}</div>
          </div>

          <input
            type="text"
            readonly
            class="input-field input-mono full-width"
            :value="sourceRaw"
            @focus="($event.target as HTMLInputElement).select()"
          />

          <pre class="code-block jwt-pre">{{ JSON.stringify(sourcePayload, null, 2) }}</pre>
        </template>
        <div v-else class="empty-msg">Kein Token vorhanden.</div>
      </div>

      <!-- Column 2: Exchanged Token -->
      <div class="jwt-col">
        <div class="jwt-col-head">
          <div class="jwt-col-title">2. Output: Getauschtes Ziel-Token (STS)</div>
          <button
            v-if="exchangedBundle?.raw"
            type="button"
            class="btn btn-sm"
            @click="copyToken(exchangedBundle.raw, 'col-sts')"
          >
            {{ copiedKey === 'col-sts' ? 'Kopiert' : 'Kopieren' }}
          </button>
        </div>

        <template v-if="exchangedBundle">
          <div class="claims-list">
            <div><strong>Neuer Issuer (iss):</strong> {{ exchangedBundle.payload?.iss }}</div>
            <div><strong>Ziel-Service (aud):</strong> {{ exchangedBundle.payload?.aud }}</div>
            <div><strong>Umgebung:</strong> {{ exchangedBundle.payload?.environment }}</div>
            <div><strong>Rollen:</strong> {{ exchangedRoles.join(', ') || 'keine' }}</div>
          </div>

          <input
            type="text"
            readonly
            class="input-field input-mono full-width"
            :value="exchangedBundle.raw"
            @focus="($event.target as HTMLInputElement).select()"
          />

          <pre class="code-block jwt-pre">{{ JSON.stringify({ header: exchangedBundle.header, payload: exchangedBundle.payload }, null, 2) }}</pre>
        </template>
        <div v-else class="empty-msg">Kein STS-Tausch für diesen Aufruf.</div>
      </div>

      <!-- Column 3: Custom Decoder -->
      <div class="jwt-col">
        <div class="jwt-col-head">
          <div class="jwt-col-title">Eigenes JWT dekodieren</div>
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
          class="input-field input-mono full-width"
          placeholder="JWT hier einfügen..."
        />

        <pre v-if="customDecodedJwt" class="code-block jwt-pre">{{ JSON.stringify(customDecodedJwt, null, 2) }}</pre>
        <div v-else class="empty-msg">
          Beliebiges JWT einfügen, um Header und Payload zu dekodieren.
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.jwt-summary-left {
  display: flex;
  align-items: baseline;
  gap: 1rem;
  flex-wrap: wrap;
}

.jwt-summary-text {
  font-family: var(--font-mono);
  font-size: 0.92rem;
  color: var(--text-secondary);
}

.jwt-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.jwt-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
  border-top: 1px solid var(--border-default);
  padding-top: 1rem;
}

@media (max-width: 1100px) {
  .jwt-grid {
    grid-template-columns: 1fr;
  }
}

.jwt-col {
  background-color: var(--bg-app);
  border: 1px solid var(--border-default);
  border-radius: var(--radius);
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.jwt-col-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}

.jwt-col-title {
  font-size: 0.95rem;
  font-weight: 700;
}

.claims-list {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  font-size: 0.9rem;
  font-family: var(--font-mono);
  color: var(--text-secondary);
  word-break: break-all;
}

.claims-list strong {
  color: var(--text-primary);
}

.full-width {
  width: 100%;
}

.jwt-pre {
  max-height: 220px;
}

.empty-msg {
  font-size: 0.9rem;
  color: var(--text-secondary);
}
</style>
