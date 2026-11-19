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
        <h2 class="panel-title">Registrierte Akteure im Company Lookup Service</h2>
        <a
          href="http://lookup.localhost/api/v2/companies"
          target="_blank"
          rel="noopener noreferrer"
          class="ext-link"
        >
          http://lookup.localhost/api/v2/companies
        </a>
      </div>
    </section>

    <div class="directory-grid">
      <div v-for="comp in companies" :key="comp.domain" class="panel-card company-card">
        <div class="company-header">
          <span class="company-name">{{ comp.name }}</span>
          <a
            :href="`http://${comp.domain}/shells`"
            target="_blank"
            rel="noopener noreferrer"
            class="ext-link"
          >
            {{ comp.domain }}
          </a>
        </div>

        <div class="endpoints-list">
          <div v-for="(ep, idx) in comp.endpoints" :key="idx" class="endpoint-item">
            <span class="endpoint-iface">{{ ep.interface }}</span>
            <a
              :href="ep.protocolInformation.href"
              target="_blank"
              rel="noopener noreferrer"
              class="ext-link"
            >
              {{ ep.protocolInformation.href }}
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.directory-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
}

@media (max-width: 950px) {
  .directory-grid {
    grid-template-columns: 1fr;
  }
}

.company-card {
  gap: 0.85rem;
}

.company-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.75rem;
}

.company-name {
  font-size: 1.05rem;
  font-weight: 700;
}

.endpoints-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.endpoint-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  background-color: var(--bg-app);
  border: 1px solid var(--border-default);
  border-radius: var(--radius);
  padding: 0.6rem 0.8rem;
}

.endpoint-iface {
  font-family: var(--font-mono);
  font-size: 0.84rem;
  color: var(--text-secondary);
}
</style>
