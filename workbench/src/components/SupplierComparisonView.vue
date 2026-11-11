<script setup lang="ts">
import type { SupplierComparisonEntry } from '../services/dataspace-client';

defineProps<{
  entries: SupplierComparisonEntry[];
  loading: boolean;
}>();

const emit = defineEmits<{
  (e: 'refresh'): void;
  (e: 'inspect-urn', urn: string): void;
}>();
</script>

<template>
  <div class="page-container">
    <section class="panel-card">
      <div class="panel-header-row">
        <div>
          <div class="panel-eyebrow">Actor D — Engineering &amp; Komponentenauswahl</div>
          <h2 class="panel-title">
            Öffentlicher Lieferantenvergleich (Akteure A, B und C via Company Lookup)
          </h2>
        </div>

        <button
          type="button"
          class="btn btn-primary"
          :disabled="loading"
          @click="emit('refresh')"
        >
          {{ loading ? 'Lade Daten...' : 'Frisch von Ursprungs-Repositories laden' }}
        </button>
      </div>
    </section>

    <div v-if="loading" class="panel-card empty-state">
      Löse Akteure A, B und C über Company Lookup auf und lade Nameplate sowie TechnicalData...
    </div>

    <div v-else class="supplier-grid">
      <div v-for="entry in entries" :key="entry.targetUrn" class="panel-card supplier-card">
        <div class="supplier-card-header">
          <strong>{{ entry.supplierLabel }}</strong>
          <span
            class="badge badge-mono"
            :class="entry.fromCache ? 'badge-cache' : 'badge-ok'"
          >
            {{ entry.fromCache ? 'Cache' : `HTTP ${entry.status}` }}
          </span>
        </div>

        <div class="sub-section">
          <div class="sub-title">1. Company Lookup (INPUT -> OUTPUT)</div>
          <div class="kv-row">
            <span class="kv-label">INPUT Asset-URN:</span>
            <span class="kv-value">{{ entry.targetUrn }}</span>
          </div>
          <div class="kv-row">
            <span class="kv-label">OUTPUT Anbieter:</span>
            <span class="kv-value">{{ entry.lookup.company?.name }}</span>
          </div>
          <div class="kv-row">
            <span class="kv-label">OUTPUT AAS-Repo:</span>
            <span class="kv-value">{{ entry.lookup.aasRepositoryUrl }}</span>
          </div>
        </div>

        <div class="sub-section">
          <div class="sub-title">2. Digital Nameplate</div>
          <div v-for="(val, key) in entry.nameplate" :key="key" class="kv-row">
            <span class="kv-label">{{ key }}:</span>
            <span class="kv-value">{{ val }}</span>
          </div>
        </div>

        <div class="sub-section highlight-section">
          <div class="sub-title">3. TechnicalData (Vergleichswerte)</div>
          <div v-for="(val, key) in entry.technicalData" :key="key" class="kv-row">
            <span class="kv-label">{{ key }}:</span>
            <span class="kv-value tech-val">{{ val }}</span>
          </div>
        </div>

        <button
          type="button"
          class="btn btn-primary full-btn"
          @click="emit('inspect-urn', entry.targetUrn)"
        >
          Ablauf &amp; BaSyx Deep-Link öffnen
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.empty-state {
  text-align: center;
  color: var(--text-secondary);
  padding: 2rem;
}

.supplier-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.85rem;
}

@media (max-width: 1100px) {
  .supplier-grid {
    grid-template-columns: 1fr;
  }
}

.supplier-card {
  gap: 0.65rem;
}

.supplier-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 0.88rem;
}

.sub-section {
  background-color: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 0.5rem 0.65rem;
  display: flex;
  flex-direction: column;
  gap: 0.22rem;
}

.highlight-section {
  border-color: var(--status-ok-border);
}

.sub-title {
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-secondary);
  margin-bottom: 0.15rem;
}

.tech-val {
  color: var(--status-ok-text);
  font-weight: 600;
}

.full-btn {
  width: 100%;
  margin-top: auto;
}
</style>

