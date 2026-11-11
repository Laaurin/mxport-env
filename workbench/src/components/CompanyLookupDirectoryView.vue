<script setup lang="ts">
import type { CompanyLookupRecord } from '../services/dataspace-client';

defineProps<{
  companies: CompanyLookupRecord[];
  cacheStats: { lookups: number; resources: number };
}>();
</script>

<template>
  <div class="page-container">
    <section class="panel-card">
      <div class="panel-header-row">
        <div>
          <div class="panel-eyebrow">
            Factory-X Discovery Service (http://lookup.localhost/api/v2/companies)
          </div>
          <h2 class="panel-title">
            Registrierte Akteure &amp; Endpunkte im Company Lookup Verzeichnis
          </h2>
        </div>

        <div class="cache-stats-row">
          <span class="badge badge-mono">Lookups im Cache: {{ cacheStats.lookups }}</span>
          <span class="badge badge-mono">Ressourcen im Cache: {{ cacheStats.resources }}</span>
        </div>
      </div>
    </section>

    <div class="directory-grid">
      <div v-for="comp in companies" :key="comp.domain" class="panel-card company-card">
        <div class="company-header">
          <span class="company-name">{{ comp.name }}</span>
          <span class="code-inline">{{ comp.domain }}</span>
        </div>

        <div class="endpoints-list">
          <div v-for="(ep, idx) in comp.endpoints" :key="idx" class="endpoint-item">
            <span class="badge badge-primary badge-mono">{{ ep.interface }}</span>
            <code class="endpoint-href">{{ ep.protocolInformation.href }}</code>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.cache-stats-row {
  display: flex;
  align-items: center;
  gap: 0.45rem;
}

.directory-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 0.85rem;
}

@media (max-width: 950px) {
  .directory-grid {
    grid-template-columns: 1fr;
  }
}

.company-card {
  gap: 0.55rem;
}

.company-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}

.company-name {
  font-size: 0.88rem;
  font-weight: 600;
}

.endpoints-list {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.endpoint-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  background-color: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 0.4rem 0.6rem;
}

.endpoint-href {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  color: var(--text-primary);
}
</style>

