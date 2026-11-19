<script setup lang="ts">
import { computed } from 'vue';
import type { DataspaceResourceItem, ExecutionResult } from '../services/dataspace-client';

const props = defineProps<{
  actorShortCode: string;
  resources: DataspaceResourceItem[];
  targetUrn: string;
  loading: boolean;
  lastResult: ExecutionResult | null;
}>();

const emit = defineEmits<{
  (e: 'update:targetUrn', urn: string): void;
  (e: 'resolve'): void;
  (e: 'load-actor-default'): void;
  (e: 'clear-cache'): void;
}>();

const groupedResources = computed(() => {
  const groups: Record<string, DataspaceResourceItem[]> = {};
  for (const item of props.resources) {
    if (!groups[item.ownerLabel]) {
      groups[item.ownerLabel] = [];
    }
    groups[item.ownerLabel].push(item);
  }
  return groups;
});

const selectedDropdownUrn = computed(() => {
  const exists = props.resources.some((r) => r.urn === props.targetUrn);
  return exists ? props.targetUrn : '';
});

function onDropdownSelect(event: Event) {
  const val = (event.target as HTMLSelectElement).value;
  if (!val) return;
  emit('update:targetUrn', val);
  emit('resolve');
}

function onUrnInput(event: Event) {
  const val = (event.target as HTMLInputElement).value;
  emit('update:targetUrn', val);
}
</script>

<template>
  <section class="control-bar">
    <div class="control-row">
      <label class="control-label">Ziel-Ressource:</label>

      <select
        :value="selectedDropdownUrn"
        class="select-field preset-select"
        @change="onDropdownSelect"
      >
        <option value="" disabled>-- Eigene URN --</option>
        <optgroup
          v-for="(items, ownerLabel) in groupedResources"
          :key="ownerLabel"
          :label="ownerLabel"
        >
          <option v-for="item in items" :key="item.urn" :value="item.urn">
            {{ item.label }}
          </option>
        </optgroup>
      </select>

      <input
        :value="targetUrn"
        type="text"
        class="input-field input-mono urn-input"
        placeholder="urn:dataspace:e:aas:produced-part-001"
        @input="onUrnInput"
        @keyup.enter="emit('resolve')"
      />

      <button
        type="button"
        class="btn btn-primary"
        :disabled="loading"
        @click="emit('resolve')"
      >
        {{ loading ? 'Lädt...' : 'Abrufen' }}
      </button>

      <button
        v-if="lastResult?.fromCache"
        type="button"
        class="btn btn-sm"
        @click="emit('clear-cache')"
      >
        Aus Zwischenspeicher geladen — Neu vom Ursprungs-Repo laden
      </button>
    </div>
  </section>
</template>

<style scoped>
.control-bar {
  background-color: var(--bg-surface);
  border-bottom: 1px solid var(--border-default);
  padding: 0.75rem 2rem;
}

.control-row {
  max-width: 1360px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.control-label {
  font-size: 0.92rem;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
}

.preset-select {
  min-width: 320px;
}

.urn-input {
  width: 310px;
}
</style>
