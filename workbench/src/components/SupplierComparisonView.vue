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
        <h2 class="panel-title">
          Öffentlicher Lieferantenvergleich (Akteure A, B und C via Company Lookup)
        </h2>

        <button
          type="button"
          class="btn btn-primary"
          :disabled="loading"
          @click="emit('refresh')"
        >
          {{ loading ? 'Lädt...' : 'Frisch von Ursprungs-Repositories laden' }}
        </button>
      </div>
    </section>

    <div v-if="loading" class="panel-card empty-state">
      Löse Akteure A, B und C über Company Lookup auf...
    </div>

    <div v-else class="supplier-grid">
      <div v-for="entry in entries" :key="entry.targetUrn" class="panel-card supplier-card">
        <h3 class="supplier-title">{{ entry.supplierLabel }}</h3>

        <div class="sub-section">
          <div class="sub-title">Company Lookup</div>
          <div class="item-line">
            <span>Asset-URN:</span>
            <code>{{ entry.targetUrn }}</code>
          </div>
          <div class="item-line">
            <span>AAS-Repository:</span>
            <a
              v-if="entry.lookup.aasRepositoryUrl"
              :href="entry.lookup.aasRepositoryUrl"
              target="_blank"
              rel="noopener noreferrer"
              class="ext-link"
            >
              {{ entry.lookup.aasRepositoryUrl }}
            </a>
          </div>
        </div>

        <div class="sub-section">
          <div class="sub-title">Digital Nameplate</div>
          <div v-for="(val, key) in entry.nameplate" :key="key" class="item-line">
            <span>{{ key }}:</span>
            <strong>{{ val }}</strong>
          </div>
        </div>

        <div class="sub-section">
          <div class="sub-title">TechnicalData</div>
          <div v-for="(val, key) in entry.technicalData" :key="key" class="item-line">
            <span>{{ key }}:</span>
            <strong>{{ val }}</strong>
          </div>
        </div>

        <button
          type="button"
          class="btn btn-primary full-btn"
          @click="emit('inspect-urn', entry.targetUrn)"
        >
          In Übersicht auswählen
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
  gap: 1.25rem;
}

@media (max-width: 1100px) {
  .supplier-grid {
    grid-template-columns: 1fr;
  }
}

.supplier-card {
  gap: 1rem;
}

.supplier-title {
  font-size: 1.15rem;
  font-weight: 700;
  margin: 0;
}

.sub-section {
  background-color: var(--bg-app);
  border: 1px solid var(--border-default);
  border-radius: var(--radius);
  padding: 0.85rem;
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.sub-title {
  font-size: 0.82rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-secondary);
  margin-bottom: 0.2rem;
}

.item-line {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  font-size: 0.92rem;
  color: var(--text-secondary);
}

.item-line strong,
.item-line code {
  color: var(--text-primary);
  font-family: var(--font-mono);
  text-align: right;
  word-break: break-all;
}

.full-btn {
  width: 100%;
  margin-top: auto;
}
</style>
