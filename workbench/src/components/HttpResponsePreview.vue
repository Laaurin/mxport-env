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
      <div class="header-left">
        <h2 class="panel-title">HTTP-Antwort &amp; JSON-Payload</h2>
        <a
          :href="result.directUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="ext-link"
          @click.stop
        >
          {{ result.directUrl }}
        </a>
      </div>

      <button
        type="button"
        class="btn btn-sm"
        @click.stop="expanded = !expanded"
      >
        {{ expanded ? 'JSON-Payload einklappen' : 'JSON-Payload & Header anzeigen' }}
      </button>
    </div>

    <div v-if="expanded" class="response-grid">
      <div class="response-col">
        <div class="col-title">Response Body (HTTP {{ result.status }})</div>
        <pre class="code-block body-pre">{{ typeof result.data === 'object' ? JSON.stringify(result.data, null, 2) : result.rawText }}</pre>
      </div>

      <div class="response-col">
        <div class="col-title">Response Headers</div>
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
.header-left {
  display: flex;
  align-items: baseline;
  gap: 1rem;
  flex-wrap: wrap;
}

.response-grid {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 1rem;
  border-top: 1px solid var(--border-default);
  padding-top: 1rem;
}

@media (max-width: 1000px) {
  .response-grid {
    grid-template-columns: 1fr;
  }
}

.response-col {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.col-title {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.body-pre {
  max-height: 400px;
}

.header-list {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  max-height: 400px;
  overflow: auto;
}

.header-row {
  background-color: var(--bg-code);
  border: 1px solid var(--border-default);
  border-radius: var(--radius);
  padding: 0.5rem 0.7rem;
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.header-key {
  font-family: var(--font-mono);
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.header-val {
  font-family: var(--font-mono);
  font-size: 0.82rem;
  color: var(--text-primary);
  word-break: break-all;
}
</style>
