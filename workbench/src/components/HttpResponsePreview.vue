<script setup lang="ts">
import { ref } from 'vue';
import type { ExecutionResult } from '../services/dataspace-client';

defineProps<{
  result: ExecutionResult;
}>();

const expanded = ref(false);
</script>

<template>
  <section class="panel-card">
    <div
      class="panel-header-row panel-header-clickable"
      @click="expanded = !expanded"
    >
      <div class="panel-title-group">
        <span class="badge">HTTP Antwort</span>
        <h2 class="panel-title">Abgerufene AAS / Submodel JSON-Payload &amp; Response-Header</h2>
        <span class="code-inline">{{ result.directUrl }}</span>
      </div>

      <button
        type="button"
        class="btn btn-sm"
        :class="{ 'btn-active': expanded }"
        @click.stop="expanded = !expanded"
      >
        {{ expanded ? 'Payload einklappen' : 'Payload & Header anzeigen' }}
      </button>
    </div>

    <div v-if="expanded" class="response-grid">
      <div class="response-col">
        <div class="col-title">HTTP Response Body (Status {{ result.status }})</div>
        <pre class="code-block body-pre">{{ typeof result.data === 'object' ? JSON.stringify(result.data, null, 2) : result.rawText }}</pre>
      </div>

      <div class="response-col">
        <div class="col-title">HTTP Response Headers (inkl. STS Token-Header)</div>
        <div class="header-list">
          <div v-for="(val, key) in result.headers" :key="key" class="header-row">
            <span class="header-key">{{ key }}</span>
            <code class="header-val">{{ val }}</code>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.response-grid {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 0.85rem;
  border-top: 1px solid var(--border-subtle);
  padding-top: 0.75rem;
}

@media (max-width: 1000px) {
  .response-grid {
    grid-template-columns: 1fr;
  }
}

.response-col {
  background-color: var(--bg-subtle);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-sm);
  padding: 0.65rem 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
}

.col-title {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-secondary);
}

.body-pre {
  max-height: 360px;
}

.header-list {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  max-height: 360px;
  overflow: auto;
}

.header-row {
  background-color: var(--bg-code);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 0.35rem 0.55rem;
  display: flex;
  flex-direction: column;
  gap: 0.12rem;
}

.header-key {
  font-family: var(--font-mono);
  font-size: 0.7rem;
  font-weight: 600;
  color: var(--accent-primary-text);
}

.header-val {
  font-family: var(--font-mono);
  font-size: 0.7rem;
  color: var(--text-primary);
  word-break: break-all;
}
</style>

