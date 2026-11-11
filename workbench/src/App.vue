<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import AppHeader, { type ActiveViewTab } from './components/AppHeader.vue';
import ActorProfileSummary from './components/ActorProfileSummary.vue';
import ResourceControlBar from './components/ResourceControlBar.vue';
import BasyxDeepLinkCard from './components/BasyxDeepLinkCard.vue';
import JwtTransformationPanel from './components/JwtTransformationPanel.vue';
import DataspacePipelineFlow from './components/DataspacePipelineFlow.vue';
import HttpResponsePreview from './components/HttpResponsePreview.vue';
import SupplierComparisonView from './components/SupplierComparisonView.vue';
import CompanyLookupDirectoryView from './components/CompanyLookupDirectoryView.vue';
// Optionales eingebettetes BaSyx-Iframe (ausgelagert in BasyxViewerEmbed.vue):
// import BasyxViewerEmbed from './components/BasyxViewerEmbed.vue';

import {
  ACTORS,
  DATASPACE_RESOURCES,
  getAccessToken,
  resolveAndFetchUrn,
  compareSuppliersViaLookup,
  listRegisteredCompanies,
  clearDataspaceCache,
  getCacheStats,
  type ActorDefinition,
  type ExecutionResult,
  type SupplierComparisonEntry,
  type CompanyLookupRecord,
} from './services/dataspace-client';

const selectedIdentityId = ref<string>('actor-f');
// Die aktuell gewählte Ziel-URN bleibt im State erhalten, auch wenn der Akteur gewechselt wird
const targetUrnInput = ref<string>('urn:dataspace:e:aas:produced-part-001');
const activeView = ref<ActiveViewTab>('overview');

const activeToken = ref<string | null>(null);
const decodedToken = ref<Record<string, any> | null>(null);
const executionLoading = ref<boolean>(false);
const lastResult = ref<ExecutionResult | null>(null);

const comparisonLoading = ref<boolean>(false);
const comparisonEntries = ref<SupplierComparisonEntry[]>([]);
const registeredCompanies = ref<CompanyLookupRecord[]>([]);
const cacheStats = ref<{ lookups: number; resources: number }>({ lookups: 0, resources: 0 });

const currentIdentity = computed<ActorDefinition>(() => {
  return ACTORS.find((a) => a.id === selectedIdentityId.value) || ACTORS[0];
});

const activeRoles = computed<string[]>(() => {
  const payload = lastResult.value?.sourceJwt?.payload || decodedToken.value;
  if (!payload) return currentIdentity.value.configuredRoles || [];
  const realmRoles = payload.realm_access?.roles || [];
  const claimRoles = Array.isArray(payload.roles) ? payload.roles : [];
  const resourceRoles = Object.values(payload.resource_access || {}).flatMap(
    (res: any) => res.roles || []
  );
  return Array.from(new Set([...realmRoles, ...claimRoles, ...resourceRoles])).filter(
    (r) => !['offline_access', 'uma_authorization', 'default-roles-basyx'].includes(r)
  );
});

const exchangedRoles = computed<string[]>(() => {
  const payload = lastResult.value?.exchangedJwt?.payload;
  if (!payload) return [];
  const realmRoles = payload.realm_access?.roles || [];
  const claimRoles = Array.isArray(payload.roles) ? payload.roles : [];
  return Array.from(new Set([...claimRoles, ...realmRoles])).filter(
    (r) => !['offline_access', 'uma_authorization', 'default-roles-basyx'].includes(r)
  );
});

const baseViewerUrl = computed<string>(() => {
  return `http://${currentIdentity.value.viewerHost}/aasviewer`;
});

const basyxGuiUrl = computed<string>(() => {
  if (!lastResult.value || !lastResult.value.lookupStep.success) {
    return baseViewerUrl.value;
  }

  const aasUrl = lastResult.value.resolvedAasUrl;
  const smUrl = lastResult.value.resolvedSubmodelUrl;

  if (aasUrl && smUrl && lastResult.value.isSuccess) {
    return `${baseViewerUrl.value}?aas=${encodeURIComponent(aasUrl)}&path=${encodeURIComponent(smUrl)}`;
  }
  if (aasUrl) {
    return `${baseViewerUrl.value}?aas=${encodeURIComponent(aasUrl)}`;
  }
  if (smUrl && lastResult.value.isSuccess) {
    return `${baseViewerUrl.value}?path=${encodeURIComponent(smUrl)}`;
  }
  return baseViewerUrl.value;
});

function updateCacheBadge() {
  cacheStats.value = getCacheStats();
}

/**
 * Wechselt das aktive Akteur-Profil (A–F).
 * Die aktuell im State gesetzte Ziel-Ressource (targetUrnInput) bleibt erhalten
 * und wird sofort mit der neuen Akteur-Identität (und deren Token/Rollen) erneut abgerufen,
 * sodass Berechtigungsunterschiede (z. B. E -> 200 OK vs. F -> 403 Forbidden auf D's SimulationModel)
 * unmittelbar sichtbar werden.
 */
async function selectIdentity(actorId: string) {
  selectedIdentityId.value = actorId;
  activeToken.value = null;
  decodedToken.value = null;
  // Altes Ergebnis sofort zurücksetzen, damit kein veralteter HTTP-200-Status für den neuen Akteur stehenbleibt
  lastResult.value = null;

  const actor = ACTORS.find((a) => a.id === actorId);
  if (actor && actor.hasAuth) {
    try {
      const res = await getAccessToken(actor.id);
      if (res) {
        activeToken.value = res.token;
        decodedToken.value = res.decoded;
      }
    } catch {
      // Wird bei der Request-Ausführung behandelt
    }
  }

  if (!targetUrnInput.value.trim() && actor && actor.knownUrns.length > 0) {
    targetUrnInput.value = actor.knownUrns[0].urn;
  }

  await runLookupAndFetch(false);
}

async function loadActorDefaultResource() {
  const actor = currentIdentity.value;
  if (actor.knownUrns.length > 0) {
    targetUrnInput.value = actor.knownUrns[0].urn;
    activeView.value = 'overview';
    await runLookupAndFetch(false);
  }
}

async function handleInspectUrn(urn: string) {
  targetUrnInput.value = urn;
  activeView.value = 'overview';
  await runLookupAndFetch(false);
}

async function runLookupAndFetch(forceRefresh: boolean = false) {
  if (!targetUrnInput.value.trim()) return;
  executionLoading.value = true;
  try {
    lastResult.value = await resolveAndFetchUrn(
      targetUrnInput.value.trim(),
      selectedIdentityId.value,
      'specific-resource',
      undefined,
      forceRefresh
    );
    updateCacheBadge();
  } finally {
    executionLoading.value = false;
  }
}

async function handleClearCacheAndReload() {
  clearDataspaceCache();
  updateCacheBadge();
  await runLookupAndFetch(true);
}

async function runSupplierComparison(forceRefresh: boolean = false) {
  comparisonLoading.value = true;
  activeView.value = 'comparison';
  try {
    comparisonEntries.value = await compareSuppliersViaLookup(selectedIdentityId.value, forceRefresh);
    updateCacheBadge();
  } finally {
    comparisonLoading.value = false;
  }
}

async function refreshLookupDirectory() {
  try {
    registeredCompanies.value = await listRegisteredCompanies();
  } catch {
    registeredCompanies.value = [];
  }
}

async function handleChangeView(view: ActiveViewTab) {
  if (view === 'comparison') {
    await runSupplierComparison(false);
  } else if (view === 'lookup') {
    activeView.value = 'lookup';
    await refreshLookupDirectory();
  } else {
    activeView.value = 'overview';
  }
}

onMounted(async () => {
  await refreshLookupDirectory();
  await selectIdentity('actor-f');
});
</script>

<template>
  <div class="workbench-shell">
    <AppHeader
      :actors="ACTORS"
      :current-actor="currentIdentity"
      :active-roles="activeRoles"
      :active-view="activeView"
      :company-count="registeredCompanies.length"
      @select-actor="selectIdentity"
      @change-view="handleChangeView"
    />

    <ResourceControlBar
      v-model:target-urn="targetUrnInput"
      :actor-short-code="currentIdentity.shortCode"
      :resources="DATASPACE_RESOURCES"
      :loading="executionLoading"
      :last-result="lastResult"
      @resolve="runLookupAndFetch(false)"
      @load-actor-default="loadActorDefaultResource"
      @clear-cache="handleClearCacheAndReload"
    />

    <main class="main-stage">
      <!-- Ansicht 1: Einseitige Hauptübersicht (Profil, Ablauf mit Input/Output, Token-Transformation, BaSyx Link) -->
      <div v-if="activeView === 'overview'" class="page-container">
        <ActorProfileSummary
          :actor="currentIdentity"
          :active-roles="activeRoles"
        />

        <DataspacePipelineFlow
          :actor="currentIdentity"
          :result="lastResult"
          :active-roles="activeRoles"
          :exchanged-roles="exchangedRoles"
        />

        <JwtTransformationPanel
          :actor="currentIdentity"
          :result="lastResult"
          :active-token="activeToken"
          :decoded-token="decodedToken"
          :active-roles="activeRoles"
          :exchanged-roles="exchangedRoles"
        />

        <BasyxDeepLinkCard
          :actor="currentIdentity"
          :result="lastResult"
          :basyx-gui-url="basyxGuiUrl"
          :base-viewer-url="baseViewerUrl"
          :active-roles="activeRoles"
        />

        <!--
          Optionales eingebettetes BaSyx-Iframe (ausgelagert in src/components/BasyxViewerEmbed.vue):
          <BasyxViewerEmbed :url="basyxGuiUrl" :viewer-host="currentIdentity.viewerHost" />
        -->

        <HttpResponsePreview
          v-if="lastResult"
          :result="lastResult"
        />
      </div>

      <!-- Ansicht 2: Lieferantenvergleich (A, B, C) -->
      <SupplierComparisonView
        v-if="activeView === 'comparison'"
        :entries="comparisonEntries"
        :loading="comparisonLoading"
        @refresh="runSupplierComparison(true)"
        @inspect-urn="handleInspectUrn"
      />

      <!-- Ansicht 3: Company Lookup Verzeichnis -->
      <CompanyLookupDirectoryView
        v-if="activeView === 'lookup'"
        :companies="registeredCompanies"
        :cache-stats="cacheStats"
      />
    </main>
  </div>
</template>
