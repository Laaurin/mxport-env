<script setup lang="ts">
import { computed } from 'vue';
import type { ActorDefinition } from '../services/dataspace-client';

const props = defineProps<{
  actor: ActorDefinition;
  activeRoles: string[];
}>();

const displayedRoles = computed<string[]>(() => {
  if (props.activeRoles.length > 0) {
    return props.activeRoles;
  }
  return props.actor.configuredRoles || [];
});
</script>

<template>
  <section class="panel-card profile-summary-card">
    <div class="profile-summary-grid">
      <!-- Left: Actor Identity & Description -->
      <div class="summary-main">
        <div class="summary-title-row">
          <span class="actor-short-box" :class="actor.hasAuth ? 'auth' : 'public'">
            {{ actor.shortCode }}
          </span>
          <div>
            <div class="panel-eyebrow">Aktives Akteur-Profil</div>
            <h1 class="actor-heading">{{ actor.name }} — {{ actor.role }}</h1>
          </div>
        </div>
        <p class="actor-description">{{ actor.description }}</p>
      </div>

      <!-- Right: Roles & Technical Endpoints -->
      <div class="summary-meta-grid">
        <div class="meta-box">
          <span class="meta-label">Authentifizierung &amp; IdP</span>
          <div class="meta-val">
            <template v-if="actor.hasAuth">
              <span class="badge badge-primary badge-mono">Keycloak Realm: {{ actor.realm }}</span>
              <span class="code-inline">{{ actor.clientId }}</span>
            </template>
            <template v-else>
              <span class="badge">Öffentlicher Akteur (Kein Token nötig)</span>
            </template>
          </div>
        </div>

        <div class="meta-box">
          <span class="meta-label">Zugewiesene Rollen (Claims)</span>
          <div class="meta-val roles-list">
            <template v-if="displayedRoles.length > 0">
              <span v-for="role in displayedRoles" :key="role" class="badge badge-ok badge-mono">
                {{ role }}
              </span>
            </template>
            <span v-else class="badge badge-mono">keine (public access)</span>
          </div>
        </div>

        <div class="meta-box">
          <span class="meta-label">Eigene Endpunkte im Cluster</span>
          <div class="meta-val">
            <span class="code-inline" title="Eigenes AAS Gateway">http://{{ actor.gatewayHost }}</span>
            <span class="code-inline" title="Eigener BaSyx AAS Viewer">http://{{ actor.viewerHost }}</span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.profile-summary-card {
  padding: 0.8rem 1.1rem;
  background-color: var(--bg-surface);
}

.profile-summary-grid {
  display: grid;
  grid-template-columns: 1.2fr 1.5fr;
  gap: 1.25rem;
  align-items: center;
}

@media (max-width: 1100px) {
  .profile-summary-grid {
    grid-template-columns: 1fr;
  }
}

.summary-main {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.summary-title-row {
  display: flex;
  align-items: center;
  gap: 0.7rem;
}

.actor-short-box {
  width: 34px;
  height: 34px;
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.95rem;
  flex-shrink: 0;
}

.actor-short-box.auth {
  background-color: var(--status-ok-bg);
  color: var(--status-ok-text);
  border: 1px solid var(--status-ok-border);
}

.actor-short-box.public {
  background-color: var(--accent-primary-bg);
  color: var(--accent-primary-text);
  border: 1px solid var(--accent-primary-border);
}

.actor-heading {
  font-size: 0.96rem;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0.1rem 0 0 0;
}

.actor-description {
  font-size: 0.78rem;
  color: var(--text-secondary);
  margin: 0;
}

.summary-meta-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.65rem;
}

@media (max-width: 850px) {
  .summary-meta-grid {
    grid-template-columns: 1fr;
  }
}

.meta-box {
  background-color: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 0.5rem 0.65rem;
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}

.meta-label {
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-secondary);
}

.meta-val {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  flex-wrap: wrap;
}
</style>

