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
  <section class="panel-card">
    <div class="profile-grid">
      <div class="profile-main">
        <h1 class="actor-title">{{ actor.name }} — {{ actor.role }}</h1>
        <p class="actor-desc">{{ actor.description }}</p>
      </div>

      <div class="profile-details">
        <div class="detail-block">
          <div class="detail-label">Rollen im Datenraum</div>
          <div class="detail-value mono">
            {{ displayedRoles.length > 0 ? displayedRoles.join(', ') : 'Öffentlich (keine Rollen)' }}
          </div>
        </div>

        <div class="detail-block">
          <div class="detail-label">Eigene Cluster-Endpunkte</div>
          <div class="endpoint-links">
            <a
              :href="`http://${actor.gatewayHost}/shells`"
              target="_blank"
              rel="noopener noreferrer"
              class="ext-link"
            >
              http://{{ actor.gatewayHost }}/shells
            </a>
            <a
              :href="`http://${actor.viewerHost}/aasviewer`"
              target="_blank"
              rel="noopener noreferrer"
              class="ext-link"
            >
              http://{{ actor.viewerHost }}
            </a>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.profile-grid {
  display: grid;
  grid-template-columns: 1.3fr 1fr;
  gap: 2rem;
  align-items: start;
}

@media (max-width: 1000px) {
  .profile-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
}

.actor-title {
  font-size: 1.35rem;
  font-weight: 700;
  color: var(--text-primary);
  margin: 0 0 0.35rem 0;
}

.actor-desc {
  font-size: 0.96rem;
  color: var(--text-secondary);
  margin: 0;
}

.profile-details {
  display: grid;
  grid-template-columns: 1fr 1.2fr;
  gap: 1.25rem;
  border-left: 1px solid var(--border-default);
  padding-left: 1.5rem;
}

@media (max-width: 1000px) {
  .profile-details {
    border-left: none;
    padding-left: 0;
    border-top: 1px solid var(--border-default);
    padding-top: 1rem;
  }
}

.detail-block {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.detail-label {
  font-size: 0.82rem;
  color: var(--text-secondary);
}

.detail-value {
  font-size: 1rem;
  font-weight: 600;
  color: var(--text-primary);
}

.detail-value.mono {
  font-family: var(--font-mono);
}

.endpoint-links {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}
</style>
