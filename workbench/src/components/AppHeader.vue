<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue';
import type { ActorDefinition } from '../services/dataspace-client';

export type ActiveViewTab = 'overview' | 'comparison' | 'lookup';

defineProps<{
  actors: ActorDefinition[];
  currentActor: ActorDefinition;
  activeRoles: string[];
  activeView: ActiveViewTab;
  companyCount: number;
}>();

const emit = defineEmits<{
  (e: 'select-actor', actorId: string): void;
  (e: 'change-view', view: ActiveViewTab): void;
}>();

const showMenu = ref(false);
const menuRef = ref<HTMLElement | null>(null);

function handleSelectActor(actorId: string) {
  showMenu.value = false;
  emit('select-actor', actorId);
}

function handleDocumentClick(event: MouseEvent) {
  if (showMenu.value && menuRef.value && !menuRef.value.contains(event.target as Node)) {
    showMenu.value = false;
  }
}

onMounted(() => {
  document.addEventListener('click', handleDocumentClick);
});

onBeforeUnmount(() => {
  document.removeEventListener('click', handleDocumentClick);
});
</script>

<template>
  <header class="app-header">
    <div class="header-left">
      <span class="header-title">Dataspace Workbench</span>

      <nav class="header-nav">
        <button
          type="button"
          class="nav-tab"
          :class="{ active: activeView === 'overview' }"
          @click="emit('change-view', 'overview')"
        >
          Übersicht
        </button>
        <button
          type="button"
          class="nav-tab"
          :class="{ active: activeView === 'comparison' }"
          @click="emit('change-view', 'comparison')"
        >
          Lieferantenvergleich (A, B, C)
        </button>
        <button
          type="button"
          class="nav-tab"
          :class="{ active: activeView === 'lookup' }"
          @click="emit('change-view', 'lookup')"
        >
          Company Lookup ({{ companyCount }})
        </button>
      </nav>
    </div>

    <div ref="menuRef" class="profile-switcher">
      <button
        type="button"
        class="profile-trigger"
        @click="showMenu = !showMenu"
      >
        <span class="profile-name">{{ currentActor.name }}</span>
        <span class="profile-sep">—</span>
        <span class="profile-role">{{ currentActor.role }}</span>
        <span class="profile-action">Account wechseln</span>
      </button>

      <div v-if="showMenu" class="profile-dropdown">
        <button
          v-for="actor in actors"
          :key="actor.id"
          type="button"
          class="dropdown-item"
          :class="{ selected: actor.id === currentActor.id }"
          @click="handleSelectActor(actor.id)"
        >
          <div class="dropdown-item-name">{{ actor.name }} — {{ actor.role }}</div>
          <div class="dropdown-item-roles">
            Rollen: {{ actor.configuredRoles.length ? actor.configuredRoles.join(', ') : 'Öffentlich (keine Rollen)' }}
          </div>
        </button>
      </div>
    </div>
  </header>
</template>

<style scoped>
.app-header {
  height: 60px;
  flex-shrink: 0;
  background-color: var(--bg-surface);
  border-bottom: 1px solid var(--border-default);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 2rem;
  gap: 1.5rem;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 1.5rem;
}

.header-title {
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--text-primary);
  white-space: nowrap;
}

.header-nav {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.nav-tab {
  background: transparent;
  border: 1px solid transparent;
  color: var(--text-secondary);
  font-family: var(--font-sans);
  font-size: 0.92rem;
  font-weight: 500;
  padding: 0.42rem 0.85rem;
  border-radius: var(--radius);
  cursor: pointer;
}

.nav-tab:hover {
  color: var(--text-primary);
  background-color: var(--bg-elevated);
}

.nav-tab.active {
  color: var(--text-primary);
  background-color: var(--bg-elevated);
  border-color: var(--border-strong);
}

.profile-switcher {
  position: relative;
}

.profile-trigger {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  background-color: var(--bg-elevated);
  border: 1px solid var(--border-default);
  border-radius: var(--radius);
  padding: 0.48rem 0.9rem;
  color: var(--text-primary);
  font-family: var(--font-sans);
  font-size: 0.92rem;
  cursor: pointer;
}

.profile-trigger:hover {
  border-color: var(--border-strong);
}

.profile-name {
  font-weight: 600;
}

.profile-sep {
  color: var(--text-muted);
}

.profile-role {
  color: var(--text-secondary);
}

.profile-action {
  margin-left: 0.5rem;
  padding-left: 0.65rem;
  border-left: 1px solid var(--border-default);
  font-size: 0.84rem;
  color: var(--text-secondary);
}

.profile-dropdown {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  width: 380px;
  background-color: var(--bg-surface);
  border: 1px solid var(--border-strong);
  border-radius: var(--radius);
  box-shadow: 0 12px 28px rgba(0, 0, 0, 0.5);
  z-index: 1000;
  padding: 0.4rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.dropdown-item {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.65rem 0.8rem;
  background: transparent;
  border: 1px solid transparent;
  border-radius: var(--radius);
  text-align: left;
  cursor: pointer;
  color: var(--text-primary);
  font-family: var(--font-sans);
}

.dropdown-item:hover {
  background-color: var(--bg-elevated);
}

.dropdown-item.selected {
  background-color: var(--bg-elevated);
  border-color: var(--border-strong);
}

.dropdown-item-name {
  font-size: 0.92rem;
  font-weight: 600;
}

.dropdown-item-roles {
  font-size: 0.82rem;
  color: var(--text-secondary);
  font-family: var(--font-mono);
}
</style>
