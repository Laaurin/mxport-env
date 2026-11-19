<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import {
  ACTORS,
  isBuiltinActor,
  fetchActorRepositoryOverview,
  setRoleSubmodelAccess,
  resetActorSecurityRulesToDefault,
  importCustomModelsToActorRepo,
  deleteResourceFromActorRepo,
  registerNewDataspaceActor,
  deleteDataspaceActor,
  listRegisteredCompanies,
  deleteCompanyLookupRecordByDomain,
  type ActorDefinition,
  type ActorRepositoryOverview,
  type CompanyLookupRecord,
} from '../services/dataspace-client';

const props = defineProps<{
  actor: ActorDefinition;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'updated'): void;
  (e: 'actor-deleted', fallbackActorId: string): void;
}>();

const activeTab = ref<'rbac' | 'models' | 'actors'>('rbac');

// Tab 1: RBAC Matrix State
const rbacLoading = ref(false);
const rbacSavingKey = ref<string | null>(null);
const rbacError = ref<string | null>(null);
const repoOverview = ref<ActorRepositoryOverview | null>(null);
const customRoleInput = ref('');
const managedRoles = ref<Array<{ role: string; label: string }>>([
  { role: 'customer-e', label: 'customer-e (Kunde F)' },
  { role: 'partner-d', label: 'partner-d (Partner D)' },
  { role: 'customer-d', label: 'customer-d (Kunde E)' },
  { role: 'partner-f', label: 'partner-f (Partner F)' },
]);

// Tab 2: Custom Models Upload & Delete State
const modelJsonInput = ref('');
const modelImportLoading = ref(false);
const modelImportStatus = ref<string | null>(null);
const modelImportError = ref<string | null>(null);
const deletingResourceUrn = ref<string | null>(null);

// Tab 3: New Actor Registration & Delete State
const newActorCode = ref('G');
const newActorName = ref('Actor G');
const newActorRole = ref('Logistics Partner');
const newActorDesc = ref('Zusätzlicher Datenraum-Teilnehmer mit dynamischer Lookup-Registrierung.');
const newActorGateway = ref('actor-g.localhost');
const newActorViewer = ref('viewer-g.localhost');
const newActorPrefix = ref('^urn:dataspace:g:');
const newActorRolesInput = ref('partner-g');
const newActorRealm = ref('');
const newActorClientId = ref('');
const newActorClientSecret = ref('');
const actorCreateStatus = ref<string | null>(null);
const actorCreateError = ref<string | null>(null);
const lookupCompanies = ref<CompanyLookupRecord[]>([]);

const BUILTIN_DOMAINS = new Set([
  'actor-a.localhost',
  'actor-b.localhost',
  'actor-c.localhost',
  'actor-d.localhost',
  'actor-e.localhost',
  'actor-f.localhost',
]);

const customActorsList = computed(() => {
  return ACTORS.filter((a) => !isBuiltinActor(a.id));
});

const customLookupRecords = computed(() => {
  return lookupCompanies.value.filter((c) => !BUILTIN_DOMAINS.has(c.domain));
});

watch(newActorCode, (code) => {
  const clean = (code || 'g').trim().toLowerCase();
  if (clean) {
    newActorName.value = `Actor ${clean.toUpperCase()}`;
    newActorGateway.value = `actor-${clean}.localhost`;
    newActorViewer.value = `viewer-${clean}.localhost`;
    newActorPrefix.value = `^urn:dataspace:${clean}:`;
    newActorRolesInput.value = `partner-${clean}`;
  }
});

async function loadRbacOverview() {
  rbacLoading.value = true;
  rbacError.value = null;
  try {
    const [overview, companies] = await Promise.all([
      fetchActorRepositoryOverview(props.actor),
      listRegisteredCompanies().catch(() => []),
    ]);
    repoOverview.value = overview;
    lookupCompanies.value = companies;
    for (const r of overview.rules) {
      if (r.role !== 'admin' && !managedRoles.value.some((m) => m.role === r.role)) {
        managedRoles.value.push({ role: r.role, label: r.role });
      }
    }
  } catch (err: any) {
    rbacError.value = err.message || 'Repository-Daten konnten nicht geladen werden.';
  } finally {
    rbacLoading.value = false;
  }
}

function hasSubmodelReadAccess(role: string, submodelId: string): boolean {
  if (!repoOverview.value) return false;
  return repoOverview.value.rules.some(
    (r) =>
      r.role === role &&
      (r.targetType === 'submodel' || r.targetType === 'aas-environment') &&
      r.actions.includes('READ') &&
      (r.targetIds.includes('*') || r.targetIds.includes(submodelId))
  );
}

async function togglePermission(role: string, submodelId: string) {
  const currentlyAllowed = hasSubmodelReadAccess(role, submodelId);
  const key = `${role}:${submodelId}`;
  rbacSavingKey.value = key;
  rbacError.value = null;
  try {
    repoOverview.value = await setRoleSubmodelAccess(
      props.actor,
      role,
      submodelId,
      !currentlyAllowed
    );
    emit('updated');
  } catch (err: any) {
    rbacError.value = err.message || 'Änderung der Berechtigung fehlgeschlagen.';
  } finally {
    rbacSavingKey.value = null;
  }
}

async function handleResetDefaultPermissions() {
  rbacLoading.value = true;
  rbacError.value = null;
  try {
    repoOverview.value = await resetActorSecurityRulesToDefault(props.actor);
    emit('updated');
  } catch (err: any) {
    rbacError.value = err.message || 'Zurücksetzen fehlgeschlagen.';
  } finally {
    rbacLoading.value = false;
  }
}

function addCustomRoleColumn() {
  const r = customRoleInput.value.trim();
  if (!r) return;
  if (!managedRoles.value.some((m) => m.role === r)) {
    managedRoles.value.push({ role: r, label: r });
  }
  customRoleInput.value = '';
}

function insertExampleModelTemplate() {
  const code = props.actor.shortCode.toLowerCase();
  modelJsonInput.value = JSON.stringify(
    {
      assetAdministrationShells: [
        {
          modelType: 'AssetAdministrationShell',
          idShort: `CustomProductAAS_${props.actor.shortCode}`,
          id: `urn:dataspace:${code}:aas:custom-001`,
          assetInformation: {
            assetKind: 'Instance',
            globalAssetId: `urn:dataspace:${code}:asset:custom-001`,
          },
          submodels: [
            {
              type: 'ModelReference',
              keys: [
                {
                  type: 'Submodel',
                  value: `urn:dataspace:${code}:sm:custom-data-001`,
                },
              ],
            },
          ],
        },
      ],
      submodels: [
        {
          modelType: 'Submodel',
          idShort: 'CustomData',
          id: `urn:dataspace:${code}:sm:custom-data-001`,
          submodelElements: [
            {
              modelType: 'Property',
              idShort: 'CustomParameter',
              valueType: 'xs:string',
              value: `Eigener Wert von ${props.actor.name}`,
            },
          ],
        },
      ],
    },
    null,
    2
  );
}

function onFileUpload(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    modelJsonInput.value = String(reader.result || '');
  };
  reader.readAsText(file);
}

async function handleImportModels() {
  if (!modelJsonInput.value.trim()) return;
  modelImportLoading.value = true;
  modelImportError.value = null;
  modelImportStatus.value = null;
  try {
    const res = await importCustomModelsToActorRepo(props.actor, modelJsonInput.value);
    modelImportStatus.value = `Importiert in ${props.actor.name}: ${res.importedShells.length} AAS, ${res.importedSubmodels.length} Submodels.`;
    await loadRbacOverview();
    emit('updated');
  } catch (err: any) {
    modelImportError.value = err.message || 'JSON-Import fehlgeschlagen.';
  } finally {
    modelImportLoading.value = false;
  }
}

async function handleDeleteResource(kind: 'AAS' | 'Submodel', urn: string) {
  deletingResourceUrn.value = urn;
  modelImportError.value = null;
  modelImportStatus.value = null;
  try {
    repoOverview.value = await deleteResourceFromActorRepo(props.actor, kind, urn);
    modelImportStatus.value = `${kind} '${urn}' wurde aus dem Repository von ${props.actor.name} gelöscht.`;
    emit('updated');
  } catch (err: any) {
    modelImportError.value = err.message || 'Löschen fehlgeschlagen.';
  } finally {
    deletingResourceUrn.value = null;
  }
}

async function handleCreateActor() {
  actorCreateStatus.value = null;
  actorCreateError.value = null;
  try {
    const roles = newActorRolesInput.value
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);

    const created = await registerNewDataspaceActor({
      shortCode: newActorCode.value.trim() || 'G',
      name: newActorName.value.trim() || 'Actor G',
      role: newActorRole.value.trim() || 'Dataspace Participant',
      description: newActorDesc.value.trim(),
      gatewayHost: newActorGateway.value.trim(),
      viewerHost: newActorViewer.value.trim(),
      assetIdPrefix: newActorPrefix.value.trim(),
      configuredRoles: roles,
      realm: newActorRealm.value.trim() || undefined,
      clientId: newActorClientId.value.trim() || undefined,
      clientSecret: newActorClientSecret.value.trim() || undefined,
    });

    lookupCompanies.value = await listRegisteredCompanies().catch(() => []);
    actorCreateStatus.value = `${created.name} (${created.gatewayHost}) wurde persistent in der Company-Lookup-DB und in der Workbench gespeichert.`;
    emit('updated');
  } catch (err: any) {
    actorCreateError.value = err.message || 'Registrierung fehlgeschlagen.';
  }
}

async function handleRemoveActor(actorToRemove: ActorDefinition) {
  actorCreateStatus.value = null;
  actorCreateError.value = null;
  try {
    await deleteDataspaceActor(actorToRemove.id, actorToRemove.gatewayHost);
    lookupCompanies.value = await listRegisteredCompanies().catch(() => []);
    actorCreateStatus.value = `${actorToRemove.name} wurde aus dem Company Lookup (PostgreSQL) und aus der Workbench gelöscht.`;
    if (props.actor.id === actorToRemove.id) {
      emit('actor-deleted', 'actor-f');
    } else {
      emit('updated');
    }
  } catch (err: any) {
    actorCreateError.value = err.message || 'Löschen des Akteurs fehlgeschlagen.';
  }
}

async function handleRemoveLookupDomain(domain: string) {
  actorCreateStatus.value = null;
  actorCreateError.value = null;
  try {
    await deleteCompanyLookupRecordByDomain(domain);
    lookupCompanies.value = await listRegisteredCompanies().catch(() => []);
    actorCreateStatus.value = `Lookup-Eintrag '${domain}' wurde aus der PostgreSQL-Datenbank gelöscht.`;
    emit('updated');
  } catch (err: any) {
    actorCreateError.value = err.message || 'Löschen im Company Lookup fehlgeschlagen.';
  }
}

watch(
  () => props.actor.id,
  () => {
    loadRbacOverview();
    insertExampleModelTemplate();
  }
);

onMounted(() => {
  loadRbacOverview();
  insertExampleModelTemplate();
});
</script>

<template>
  <div class="admin-backdrop" @click.self="emit('close')">
    <section class="admin-drawer">
      <div class="admin-header">
        <div>
          <h2 class="admin-title">Datenraum-Verwaltung ({{ actor.name }})</h2>
          <p class="admin-subtitle">
            Zugriffsrechte steuern, Shells &amp; Submodels verwalten oder Akteure anlegen und löschen
          </p>
        </div>
        <button type="button" class="btn btn-sm" @click="emit('close')">
          Schließen
        </button>
      </div>

      <div class="admin-tabs">
        <button
          type="button"
          class="tab-btn"
          :class="{ active: activeTab === 'rbac' }"
          @click="activeTab = 'rbac'"
        >
          1. Zugriffsrechte ({{ actor.name }})
        </button>
        <button
          type="button"
          class="tab-btn"
          :class="{ active: activeTab === 'models' }"
          @click="activeTab = 'models'"
        >
          2. Shells &amp; Submodels ({{ actor.name }})
        </button>
        <button
          type="button"
          class="tab-btn"
          :class="{ active: activeTab === 'actors' }"
          @click="activeTab = 'actors'"
        >
          3. Akteure verwalten
        </button>
      </div>

      <!-- TAB 1: Live Dynamic RBAC Matrix via BaSyx Security Submodel -->
      <div v-if="activeTab === 'rbac'" class="admin-body">
        <div v-if="rbacLoading" class="info-box">
          Lade Teilmodelle und Security-Submodel-Regeln von {{ actor.name }}...
        </div>

        <template v-else-if="repoOverview && repoOverview.hasSecuritySubmodel">
          <div class="info-box">
            <strong>Persistenz (MongoDB):</strong>
            Änderungen in dieser Matrix werden direkt im <strong>BaSyx Security Submodel</strong>
            (<code>{{ actor.id }}-secsm</code>) in der MongoDB gespeichert und bleiben auch nach einem
            Browser-Reload oder Pod-Neustart erhalten.
          </div>

          <div v-if="rbacError" class="error-box">{{ rbacError }}</div>

          <div class="matrix-scroll">
            <table class="rbac-table">
              <thead>
                <tr>
                  <th>Teilmodell in {{ actor.name }}</th>
                  <th v-for="col in managedRoles" :key="col.role">
                    {{ col.label }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="sm in repoOverview.submodels" :key="sm.id">
                  <td>
                    <div class="sm-name">{{ sm.idShort }}</div>
                    <code class="sm-urn">{{ sm.id }}</code>
                  </td>
                  <td v-for="col in managedRoles" :key="col.role" class="check-cell">
                    <label class="check-label">
                      <input
                        type="checkbox"
                        :checked="hasSubmodelReadAccess(col.role, sm.id)"
                        :disabled="rbacSavingKey === `${col.role}:${sm.id}`"
                        @change="togglePermission(col.role, sm.id)"
                      />
                      <span>{{ hasSubmodelReadAccess(col.role, sm.id) ? 'Erlaubt' : 'Gesperrt' }}</span>
                    </label>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="rbac-footer-row">
            <div class="add-role-row">
              <input
                v-model="customRoleInput"
                type="text"
                class="input-field input-mono"
                placeholder="Weitere Rolle hinzufügen (z. B. partner-g)"
                @keyup.enter="addCustomRoleColumn"
              />
              <button type="button" class="btn btn-sm" @click="addCustomRoleColumn">
                Rolle als Spalte ergänzen
              </button>
            </div>

            <button
              v-if="actor.id === 'actor-d' || actor.id === 'actor-e'"
              type="button"
              class="btn btn-sm"
              @click="handleResetDefaultPermissions"
            >
              Standard-Berechtigungen für {{ actor.name }} wiederherstellen
            </button>
          </div>
        </template>

        <div v-else-if="actor.hasAuth" class="info-box">
          <strong>Security-Submodel-Endpunkt (/secsm) auf {{ actor.gatewayHost }} noch nicht ausgerollt:</strong>
          <div class="help-line">
            Bitte aktualisiere einmal die Helm-Charts für Actor D und Actor E im Cluster, damit die neue
            <code>/secsm</code>-Gateway-Route aktiv wird:
          </div>
          <pre class="code-block" style="margin-top: 0.6rem;">helm upgrade --install actor-d k8s/helm/dataspace-actor -f k8s/values/actor-d.yaml -n dataspace
helm upgrade --install actor-e k8s/helm/dataspace-actor -f k8s/values/actor-e.yaml -n dataspace</pre>
        </div>

        <div v-else class="info-box">
          <strong>{{ actor.name }}</strong> ist als öffentliches Repository ohne BaSyx Security Submodel
          konfiguriert (alle Shells und Teilmodelle sind öffentlich lesbar). Wechsle oben rechts auf
          <strong>Actor D</strong> oder <strong>Actor E</strong>, um deren dynamische Zugriffsregeln im
          Security Submodel live zu steuern.
        </div>
      </div>

      <!-- TAB 2: Custom Shells & Submodels (Persistent File vs Runtime InMemory + Clean Delete) -->
      <div v-if="activeTab === 'models'" class="admin-body">
        <div class="info-box">
          <div>
            <strong>1. Dauerhaft persistent im Dateisystem (Git-ignoriert, mit Fallback):</strong>
            Lege deine Datei unter
            <code>k8s/helm/dataspace-actor/files/custom-models/{{ actor.id }}.json</code> ab und führe
            <code>deploy-all</code> aus. Wenn du die Datei wieder löschst, greift automatisch der Fallback auf
            <code>files/models/{{ actor.id }}.json</code>.
          </div>
          <div class="help-line">
            <strong>2. Zur Laufzeit über dieses Formular (In-Memory im BaSyx-Pod):</strong>
            Hier importierte Shells und Submodels sind sofort im laufenden Container von
            <strong>{{ actor.name }}</strong> aktiv (überstehen Browser-Reloads) und können unten jederzeit
            einzeln wieder gelöscht werden. Beim Neustart des Pods wird wieder der Stand der
            <code>model.json</code> geladen.
          </div>
        </div>

        <!-- Aktuell im Repository von Actor X vorhandene Shells & Submodels (mit Löschen-Button) -->
        <div v-if="repoOverview" class="existing-models-section">
          <div class="subsection-title">
            Aktuell im Repository von {{ actor.name }} ({{ actor.gatewayHost }}) vorhandene Ressourcen
          </div>

          <div class="existing-models-grid">
            <div class="existing-col">
              <div class="col-label">Shells ({{ repoOverview.shells.length }})</div>
              <div v-for="sh in repoOverview.shells" :key="sh.id" class="resource-item-row">
                <div class="res-meta">
                  <div class="sm-name">{{ sh.idShort }}</div>
                  <code class="sm-urn">{{ sh.id }}</code>
                </div>
                <button
                  type="button"
                  class="btn btn-sm"
                  :disabled="deletingResourceUrn === sh.id"
                  @click="handleDeleteResource('AAS', sh.id)"
                >
                  {{ deletingResourceUrn === sh.id ? 'Lösche...' : 'Löschen' }}
                </button>
              </div>
            </div>

            <div class="existing-col">
              <div class="col-label">Submodels ({{ repoOverview.submodels.length }})</div>
              <div v-for="sm in repoOverview.submodels" :key="sm.id" class="resource-item-row">
                <div class="res-meta">
                  <div class="sm-name">{{ sm.idShort }}</div>
                  <code class="sm-urn">{{ sm.id }}</code>
                </div>
                <button
                  type="button"
                  class="btn btn-sm"
                  :disabled="deletingResourceUrn === sm.id"
                  @click="handleDeleteResource('Submodel', sm.id)"
                >
                  {{ deletingResourceUrn === sm.id ? 'Lösche...' : 'Löschen' }}
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="upload-header">
          <strong>Neue Shell / Submodel JSON in {{ actor.name }} importieren:</strong>
          <div class="upload-actions">
            <label class="btn btn-sm file-btn">
              JSON-Datei wählen
              <input type="file" accept=".json" hidden @change="onFileUpload" />
            </label>
            <button type="button" class="btn btn-sm" @click="insertExampleModelTemplate">
              Beispiel-Template einfügen
            </button>
          </div>
        </div>

        <textarea
          v-model="modelJsonInput"
          class="input-field input-mono json-textarea"
          rows="9"
          placeholder='{ "assetAdministrationShells": [...], "submodels": [...] }'
        ></textarea>

        <div class="action-footer">
          <button
            type="button"
            class="btn btn-primary"
            :disabled="modelImportLoading"
            @click="handleImportModels"
          >
            {{ modelImportLoading ? 'Importiere...' : `In Repository von ${actor.name} importieren` }}
          </button>
          <span v-if="modelImportStatus" class="status-msg">{{ modelImportStatus }}</span>
          <span v-if="modelImportError" class="error-msg">{{ modelImportError }}</span>
        </div>
      </div>

      <!-- TAB 3: Add & Delete Custom Actors -->
      <div v-if="activeTab === 'actors'" class="admin-body">
        <div class="info-box">
          <strong>Persistenz (PostgreSQL + Browser):</strong>
          Neu angelegte Akteure werden persistent in der PostgreSQL-Datenbank des
          <strong>Company Lookup Service</strong> (<code>company-lookup-db</code>) und im
          <code>localStorage</code> der Workbench gespeichert. Du kannst jeden hinzugefügten Akteur unten
          vollständig wieder löschen.
        </div>

        <!-- Liste der hinzugefügten Akteure mit Löschen-Button -->
        <div v-if="customActorsList.length > 0 || customLookupRecords.length > 0" class="existing-models-section">
          <div class="subsection-title">Hinzugefügte benutzerdefinierte Akteure</div>

          <div class="custom-actors-list">
            <div v-for="ca in customActorsList" :key="ca.id" class="resource-item-row">
              <div class="res-meta">
                <div class="sm-name">{{ ca.name }} — {{ ca.role }}</div>
                <code class="sm-urn">
                  Domain: {{ ca.gatewayHost }} | Rollen: {{ ca.configuredRoles.join(', ') || 'keine' }}
                </code>
              </div>
              <button
                type="button"
                class="btn btn-sm"
                @click="handleRemoveActor(ca)"
              >
                Akteur löschen (Lookup-DB &amp; Workbench)
              </button>
            </div>

            <template v-for="rec in customLookupRecords" :key="rec.domain">
              <div
                v-if="!customActorsList.some((a) => a.gatewayHost === rec.domain)"
                class="resource-item-row"
              >
                <div class="res-meta">
                  <div class="sm-name">{{ rec.name }}</div>
                  <code class="sm-urn">Domain in Lookup-DB: {{ rec.domain }}</code>
                </div>
                <button
                  type="button"
                  class="btn btn-sm"
                  @click="handleRemoveLookupDomain(rec.domain)"
                >
                  Aus Lookup-DB löschen
                </button>
              </div>
            </template>
          </div>
        </div>

        <div class="subsection-title">Neuen Akteur anlegen</div>

        <div class="form-grid">
          <div class="form-field">
            <label>Kürzel (z. B. G)</label>
            <input v-model="newActorCode" type="text" class="input-field" />
          </div>
          <div class="form-field">
            <label>Name</label>
            <input v-model="newActorName" type="text" class="input-field" />
          </div>
          <div class="form-field">
            <label>Rolle / Funktion</label>
            <input v-model="newActorRole" type="text" class="input-field" />
          </div>
          <div class="form-field">
            <label>Zugewiesene Rollen (Komma-getrennt)</label>
            <input v-model="newActorRolesInput" type="text" class="input-field input-mono" />
          </div>
          <div class="form-field">
            <label>Eindeutige Gateway-Domain im Lookup</label>
            <input v-model="newActorGateway" type="text" class="input-field input-mono" />
          </div>
          <div class="form-field">
            <label>BaSyx Viewer-Host</label>
            <input v-model="newActorViewer" type="text" class="input-field input-mono" />
          </div>
          <div class="form-field">
            <label>Asset-URN Regex für Company Lookup</label>
            <input v-model="newActorPrefix" type="text" class="input-field input-mono" />
          </div>
          <div class="form-field">
            <label>Keycloak Realm (optional)</label>
            <input v-model="newActorRealm" type="text" class="input-field input-mono" placeholder="z. B. actor-f" />
          </div>
          <div class="form-field">
            <label>Keycloak Client-ID (optional)</label>
            <input v-model="newActorClientId" type="text" class="input-field input-mono" placeholder="z. B. actor-f-client" />
          </div>
          <div class="form-field">
            <label>Keycloak Client-Secret (optional)</label>
            <input v-model="newActorClientSecret" type="password" class="input-field input-mono" />
          </div>
        </div>

        <div class="action-footer">
          <button type="button" class="btn btn-primary" @click="handleCreateActor">
            Akteur im Datenraum registrieren
          </button>
          <span v-if="actorCreateStatus" class="status-msg">{{ actorCreateStatus }}</span>
          <span v-if="actorCreateError" class="error-msg">{{ actorCreateError }}</span>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.admin-backdrop {
  position: fixed;
  inset: 0;
  background-color: rgba(0, 0, 0, 0.65);
  z-index: 2000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
}

.admin-drawer {
  background-color: var(--bg-surface);
  border: 1px solid var(--border-strong);
  border-radius: var(--radius);
  width: 100%;
  max-width: 1060px;
  max-height: 88vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  box-shadow: 0 20px 45px rgba(0, 0, 0, 0.6);
}

.admin-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border-default);
}

.admin-title {
  font-size: 1.15rem;
  font-weight: 700;
  margin: 0;
}

.admin-subtitle {
  font-size: 0.9rem;
  color: var(--text-secondary);
  margin: 0.25rem 0 0 0;
}

.admin-tabs {
  display: flex;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  background-color: var(--bg-app);
  border-bottom: 1px solid var(--border-default);
}

.tab-btn {
  background: transparent;
  border: 1px solid transparent;
  color: var(--text-secondary);
  font-family: var(--font-sans);
  font-size: 0.92rem;
  font-weight: 500;
  padding: 0.45rem 0.9rem;
  border-radius: var(--radius);
  cursor: pointer;
}

.tab-btn:hover {
  color: var(--text-primary);
  background-color: var(--bg-elevated);
}

.tab-btn.active {
  color: var(--text-primary);
  background-color: var(--bg-elevated);
  border-color: var(--border-strong);
}

.admin-body {
  padding: 1.5rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1.15rem;
}

.info-box {
  background-color: var(--bg-app);
  border: 1px solid var(--border-default);
  border-radius: var(--radius);
  padding: 1rem;
  font-size: 0.92rem;
  color: var(--text-secondary);
}

.help-line {
  margin-top: 0.55rem;
}

.error-box {
  background-color: var(--bg-app);
  border: 1px solid var(--border-strong);
  padding: 0.75rem 1rem;
  border-radius: var(--radius);
  color: var(--text-primary);
}

.matrix-scroll {
  overflow-x: auto;
}

.rbac-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.92rem;
}

.rbac-table th,
.rbac-table td {
  border: 1px solid var(--border-default);
  padding: 0.75rem 0.9rem;
  text-align: left;
}

.rbac-table th {
  background-color: var(--bg-app);
  font-weight: 600;
  color: var(--text-primary);
}

.sm-name {
  font-weight: 600;
  color: var(--text-primary);
}

.sm-urn {
  font-family: var(--font-mono);
  font-size: 0.82rem;
  color: var(--text-secondary);
  word-break: break-all;
}

.check-cell {
  white-space: nowrap;
}

.check-label {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  user-select: none;
}

.rbac-footer-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
}

.add-role-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.existing-models-section {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}

.subsection-title {
  font-size: 0.95rem;
  font-weight: 600;
  color: var(--text-primary);
}

.existing-models-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
}

@media (max-width: 800px) {
  .existing-models-grid {
    grid-template-columns: 1fr;
  }
}

.existing-col,
.custom-actors-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.col-label {
  font-size: 0.84rem;
  color: var(--text-secondary);
  font-weight: 600;
}

.resource-item-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  background-color: var(--bg-app);
  border: 1px solid var(--border-default);
  border-radius: var(--radius);
  padding: 0.6rem 0.85rem;
}

.res-meta {
  min-width: 0;
  flex: 1;
}

.upload-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
  padding-top: 0.5rem;
  border-top: 1px solid var(--border-default);
}

.upload-actions {
  display: flex;
  gap: 0.5rem;
}

.file-btn {
  cursor: pointer;
}

.json-textarea {
  width: 100%;
  resize: vertical;
  line-height: 1.45;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
}

@media (max-width: 750px) {
  .form-grid {
    grid-template-columns: 1fr;
  }
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.form-field label {
  font-size: 0.85rem;
  color: var(--text-secondary);
}

.action-footer {
  display: flex;
  align-items: center;
  gap: 1rem;
  flex-wrap: wrap;
}

.status-msg {
  font-size: 0.9rem;
  color: var(--text-primary);
}

.error-msg {
  font-size: 0.9rem;
  color: var(--text-secondary);
}
</style>
