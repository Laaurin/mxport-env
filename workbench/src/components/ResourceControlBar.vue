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

const activeResourceMeta = computed(() => {
  return props.resources.find((r) => r.urn === props.targetUrn) || null;
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
      <label class="control-label">Ziel-Ressource im Datenraum:</label>

      <select
        :value="selectedDropdownUrn"
        class="select-field preset-select"
        @change="onDropdownSelect"
      >
        <option value="" disabled>-- Benutzerdefinierte URN --</option>
        <optgroup
          v-for="(items, ownerLabel) in groupedResources"
          :key="ownerLabel"
          :label="ownerLabel"
        >
          <option v-for="item in items" :key="item.urn" :value="item.urn">
            [{{ item.kind }}] {{ item.label }} — Benötigt: {{ item.requiredRole }}
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
        {{ loading ? 'Prüfe Zugriff...' : 'URN auflösen & abrufen' }}
      </button>

      <button
        type="button"
        class="btn btn-sm"
        :disabled="loading"
        :title="`Lädt die primäre Standard-Ressource für Actor ${actorShortCode}`"
        @click="emit('load-actor-default')"
      >
        Standardziel Actor {{ actorShortCode }}
      </button>

      <span v-if="activeResourceMeta" class="badge badge-mono" title="Erforderliche Berechtigung am Ziel-Repository">
        Policy: {{ activeResourceMeta.requiredRole }}
      </span>

      <template v-if="lastResult">
        <span
          class="badge badge-mono"
          :class="lastResult.fromCache ? 'badge-cache' : 'badge-primary'"
          :title="
            lastResult.fromCache
              ? 'Aus lokalem Zwischenspeicher für diesen Akteur geladen'
              : 'Live über Company Lookup und Ursprungs-Repository geprüft'
          "
        >
          {{ lastResult.fromCache ? 'Quelle: Cache (0 ms)' : `Quelle: Live (${lastResult.durationMs} ms)` }}
        </span>

        <button
          type="button"
          class="btn btn-sm"
          title="Zwischenspeicher leeren und frisch vom Ursprungs-Repository abrufen"
          @click="emit('clear-cache')"
        >
          Cache leeren &amp; neu laden
        </button>
      </template>
    </div>
  </section>
</template>

<style scoped>
.control-bar {
  background-color: var(--bg-subtle);
  border-bottom: 1px solid var(--border-default);
  padding: 0.55rem 1.25rem;
}

.control-row {
  max-width: 1440px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.control-label {
  font-size: 0.76rem;
  font-weight: 600;
  color: var(--text-secondary);
  white-space: nowrap;
}

.preset-select {
  max-width: 410px;
}

.urn-input {
  width: 265px;
}
</style>
