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
      <span class="brand-tag">Factory-X</span>
      <span class="header-title">Dataspace Inspector</span>

      <nav class="header-nav">
        <button
          type="button"
          class="nav-tab"
          :class="{ active: activeView === 'overview' }"
          @click="emit('change-view', 'overview')"
        >
          Ablauf, Token &amp; Viewer-Link
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

    <!-- Top-Right Account Switcher (Actors A-F) -->
    <div ref="menuRef" class="profile-switcher">
      <button
        type="button"
        class="profile-trigger"
        :class="{ open: showMenu }"
        @click="showMenu = !showMenu"
      >
        <span class="actor-badge" :class="currentActor.hasAuth ? 'auth' : 'public'">
          {{ currentActor.shortCode }}
        </span>
        <div class="profile-text">
          <span class="profile-name">{{ currentActor.name }}</span>
          <span class="profile-role">{{ currentActor.role }}</span>
        </div>
        <span v-if="activeRoles.length > 0" class="badge badge-ok badge-mono">
          {{ activeRoles.join(', ') }}
        </span>
        <span v-else class="badge badge-mono">public</span>
        <span class="caret-label">Wechseln</span>
      </button>

      <div v-if="showMenu" class="profile-dropdown">
        <div class="dropdown-header">Akteur / Account wechseln (A–F)</div>
        <button
          v-for="actor in actors"
          :key="actor.id"
          type="button"
          class="dropdown-item"
          :class="{ selected: actor.id === currentActor.id }"
          @click="handleSelectActor(actor.id)"
        >
          <span class="actor-badge" :class="actor.hasAuth ? 'auth' : 'public'">
            {{ actor.shortCode }}
          </span>
          <div class="dropdown-item-body">
            <div class="dropdown-item-top">
              <span class="dropdown-item-name">{{ actor.name }}</span>
              <span class="badge badge-mono" :class="actor.hasAuth ? 'badge-ok' : ''">
                {{ actor.hasAuth ? `Keycloak (${actor.realm})` : 'Public' }}
              </span>
            </div>
            <div class="dropdown-item-role">{{ actor.role }}</div>
            <div v-if="actor.configuredRoles.length > 0" class="dropdown-item-roles">
              Rollen: {{ actor.configuredRoles.join(', ') }}
            </div>
          </div>
        </button>
      </div>
    </div>
  </header>
</template>

<style scoped>
.app-header {
  height: 52px;
  flex-shrink: 0;
  background-color: var(--bg-surface);
  border-bottom: 1px solid var(--border-default);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 1.25rem;
  gap: 1rem;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  min-width: 0;
}

.brand-tag {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--accent-primary-text);
  background-color: var(--accent-primary-bg);
  border: 1px solid var(--accent-primary-border);
  padding: 0.16rem 0.5rem;
  border-radius: var(--radius-sm);
}

.header-title {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
}

.header-nav {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  margin-left: 0.5rem;
}

.nav-tab {
  background: transparent;
  border: 1px solid transparent;
  color: var(--text-secondary);
  font-family: var(--font-sans);
  font-size: 0.78rem;
  font-weight: 500;
  padding: 0.32rem 0.7rem;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: background-color 0.12s ease, color 0.12s ease;
}

.nav-tab:hover {
  color: var(--text-primary);
  background-color: var(--bg-elevated);
}

.nav-tab.active {
  color: var(--accent-primary-text);
  background-color: var(--accent-primary-bg);
  border-color: var(--accent-primary-border);
}

.profile-switcher {
  position: relative;
}

.profile-trigger {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  background-color: var(--bg-elevated);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-sm);
  padding: 0.28rem 0.65rem 0.28rem 0.4rem;
  color: var(--text-primary);
  cursor: pointer;
}

.profile-trigger:hover,
.profile-trigger.open {
  border-color: var(--accent-primary);
}

.actor-badge {
  width: 26px;
  height: 26px;
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.78rem;
  flex-shrink: 0;
}

.actor-badge.auth {
  background-color: var(--status-ok-bg);
  color: var(--status-ok-text);
  border: 1px solid var(--status-ok-border);
}

.actor-badge.public {
  background-color: var(--accent-primary-bg);
  color: var(--accent-primary-text);
  border: 1px solid var(--accent-primary-border);
}

.profile-text {
  display: flex;
  flex-direction: column;
  text-align: left;
  line-height: 1.15;
}

.profile-name {
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--text-primary);
}

.profile-role {
  font-size: 0.68rem;
  color: var(--text-secondary);
}

.caret-label {
  font-size: 0.7rem;
  color: var(--text-secondary);
  padding-left: 0.2rem;
  border-left: 1px solid var(--border-default);
}

.profile-dropdown {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  width: 360px;
  background-color: var(--bg-surface);
  border: 1px solid var(--border-strong);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-popover);
  z-index: 1000;
  padding: 0.45rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.dropdown-header {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-secondary);
  padding: 0.35rem 0.5rem;
  border-bottom: 1px solid var(--border-subtle);
  margin-bottom: 0.15rem;
}

.dropdown-item {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
  padding: 0.5rem 0.55rem;
  background: transparent;
  border: 1px solid transparent;
  border-radius: var(--radius-sm);
  text-align: left;
  cursor: pointer;
  color: var(--text-primary);
}

.dropdown-item:hover {
  background-color: var(--bg-elevated);
}

.dropdown-item.selected {
  background-color: var(--accent-primary-bg);
  border-color: var(--accent-primary-border);
}

.dropdown-item-body {
  flex: 1;
  min-width: 0;
}

.dropdown-item-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.4rem;
}

.dropdown-item-name {
  font-size: 0.8rem;
  font-weight: 600;
}

.dropdown-item-role {
  font-size: 0.72rem;
  color: var(--text-secondary);
  margin-top: 0.12rem;
}

.dropdown-item-roles {
  font-size: 0.68rem;
  font-family: var(--font-mono);
  color: var(--status-ok-text);
  margin-top: 0.2rem;
}
</style>

