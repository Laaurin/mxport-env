export interface KnownUrnTarget {
  id: string;
  label: string;
  urn: string;
  resourceMode: 'specific-resource' | 'shells-catalog' | 'submodels-catalog';
  relation: 'own' | 'purchased' | 'supplier-catalog' | 'dataspace-peer';
  originHint: string;
  description: string;
  expectedAuth: 'public' | 'customer-d' | 'customer-e' | 'partner';
}

export interface ActorDefinition {
  id: string;
  shortCode: string;
  name: string;
  role: string;
  description: string;
  hasAuth: boolean;
  gatewayHost: string;
  viewerHost: string;
  configuredRoles: string[];
  realm?: string;
  clientId?: string;
  clientSecret?: string;
  ownAasUrn?: string;
  knownUrns: KnownUrnTarget[];
}

export interface CompanyEndpoint {
  interface: string;
  protocolInformation: {
    href: string;
    endpointProtocol?: string;
    endpointProtocolVersion?: string[];
  };
}

export interface CompanyLookupRecord {
  name: string;
  domain: string;
  endpoints: CompanyEndpoint[];
}

export interface LookupResolution {
  success: boolean;
  queryType: 'asset_id' | 'name';
  queryValue: string;
  encodedQuery: string;
  lookupApiUrl: string;
  directLookupUrl: string;
  status: number;
  durationMs: number;
  fromCache: boolean;
  company: CompanyLookupRecord | null;
  aasRepositoryUrl: string | null;
  submodelRepositoryUrl: string | null;
  resolvedHost: string | null;
  rawResponse: any;
  errorMessage?: string;
}

export interface DecodedJwtBundle {
  raw: string;
  header: Record<string, any> | null;
  payload: Record<string, any> | null;
}

export interface ExecutionResult {
  url: string;
  directUrl: string;
  method: string;
  status: number;
  statusText: string;
  durationMs: number;
  timestamp: string;
  fromCache: boolean;
  headers: Record<string, string>;
  data: any;
  rawText: string;
  isSuccess: boolean;
  activeIdentity: string;
  tokenUsed: boolean;
  targetUrn: string;
  originHint: string;
  lookupStep: LookupResolution;
  resolvedAasUrl: string | null;
  resolvedSubmodelUrl: string | null;
  sourceJwt: DecodedJwtBundle | null;
  exchangedJwt: DecodedJwtBundle | null;
}

export interface SupplierComparisonEntry {
  supplierLabel: string;
  targetUrn: string;
  lookup: LookupResolution;
  shell: any | null;
  nameplate: Record<string, string>;
  technicalData: Record<string, string>;
  status: number;
  fromCache: boolean;
}

/**
 * Actors A–F in the 6-Actor Industrial Dataspace.
 * No partner repository URLs or hostnames are hardcoded here.
 * Target endpoints are resolved dynamically via the Company Lookup Service (lookup.localhost).
 */
export const ACTORS: ActorDefinition[] = [
  {
    id: 'actor-a',
    shortCode: 'A',
    name: 'Actor A',
    role: 'Servo Motor Supplier (Public)',
    description: 'Stellt öffentlich Produktinformationen (Nameplate & TechnicalData) für Servomotoren bereit.',
    hasAuth: false,
    gatewayHost: 'actor-a.localhost',
    viewerHost: 'viewer-a.localhost',
    configuredRoles: [],
    ownAasUrn: 'urn:dataspace:a:aas:servo-motor-001',
    knownUrns: [
      {
        id: 'a-own-aas',
        label: 'Eigene AAS: ServoMotorAAS (15 kW, IE4)',
        urn: 'urn:dataspace:a:aas:servo-motor-001',
        resourceMode: 'specific-resource',
        relation: 'own',
        originHint: 'Eigene Produkt-AAS im lokalen Katalog von Akteur A',
        description: 'Öffentliche ServoMotorAAS inkl. Nameplate und TechnicalData.',
        expectedAuth: 'public',
      },
      {
        id: 'a-own-tech',
        label: 'Eigenes SM: TechnicalData (15 kW, IE4)',
        urn: 'urn:dataspace:a:sm:technical-data',
        resourceMode: 'specific-resource',
        relation: 'own',
        originHint: 'Submodel-Referenz aus ServoMotorAAS',
        description: 'Öffentliches TechnicalData-Teilmodell von Akteur A.',
        expectedAuth: 'public',
      },
      {
        id: 'a-neg-d-sim',
        label: 'Negativtest: Actor D Simulation SM (Ohne Token -> 401)',
        urn: 'urn:dataspace:d:sm:machine-simulation',
        resourceMode: 'specific-resource',
        relation: 'dataspace-peer',
        originHint: 'Unauthentifizierter Zugriffsversuch auf geschütztes SimulationModel von D',
        description: 'Akteur A besitzt kein Kundentoken von D -> Gateway weist Zugriff mit HTTP 401 ab.',
        expectedAuth: 'customer-d',
      },
    ],
  },
  {
    id: 'actor-b',
    shortCode: 'B',
    name: 'Actor B',
    role: 'Gearbox Supplier (Public)',
    description: 'Stellt öffentlich Produktinformationen (Nameplate & TechnicalData) für Industriegetriebe bereit.',
    hasAuth: false,
    gatewayHost: 'actor-b.localhost',
    viewerHost: 'viewer-b.localhost',
    configuredRoles: [],
    ownAasUrn: 'urn:dataspace:b:aas:gearbox-001',
    knownUrns: [
      {
        id: 'b-own-aas',
        label: 'Eigene AAS: IndustrialGearboxAAS (10:1, 450 Nm)',
        urn: 'urn:dataspace:b:aas:gearbox-001',
        resourceMode: 'specific-resource',
        relation: 'own',
        originHint: 'Eigene Produkt-AAS im lokalen Katalog von Akteur B',
        description: 'Öffentliche IndustrialGearboxAAS inkl. Nameplate und TechnicalData.',
        expectedAuth: 'public',
      },
      {
        id: 'b-own-tech',
        label: 'Eigenes SM: TechnicalData (10:1 Ratio)',
        urn: 'urn:dataspace:b:sm:technical-data',
        resourceMode: 'specific-resource',
        relation: 'own',
        originHint: 'Submodel-Referenz aus IndustrialGearboxAAS',
        description: 'Öffentliches TechnicalData-Teilmodell von Akteur B.',
        expectedAuth: 'public',
      },
    ],
  },
  {
    id: 'actor-c',
    shortCode: 'C',
    name: 'Actor C',
    role: 'Sensor Supplier (Public)',
    description: 'Stellt öffentlich Produktinformationen (Nameplate & TechnicalData) für Vibrationssensoren bereit.',
    hasAuth: false,
    gatewayHost: 'actor-c.localhost',
    viewerHost: 'viewer-c.localhost',
    configuredRoles: [],
    ownAasUrn: 'urn:dataspace:c:aas:sensor-001',
    knownUrns: [
      {
        id: 'c-own-aas',
        label: 'Eigene AAS: VibrationSensorAAS (25.6 kHz, IO-Link)',
        urn: 'urn:dataspace:c:aas:sensor-001',
        resourceMode: 'specific-resource',
        relation: 'own',
        originHint: 'Eigene Produkt-AAS im lokalen Katalog von Akteur C',
        description: 'Öffentliche VibrationSensorAAS inkl. Nameplate und TechnicalData.',
        expectedAuth: 'public',
      },
      {
        id: 'c-own-tech',
        label: 'Eigenes SM: TechnicalData (25.6 kHz)',
        urn: 'urn:dataspace:c:sm:technical-data',
        resourceMode: 'specific-resource',
        relation: 'own',
        originHint: 'Submodel-Referenz aus VibrationSensorAAS',
        description: 'Öffentliches TechnicalData-Teilmodell von Akteur C.',
        expectedAuth: 'public',
      },
    ],
  },
  {
    id: 'actor-d',
    shortCode: 'D',
    name: 'Actor D',
    role: 'Machine OEM (Compares A/B/C, Protects Sim)',
    description: 'Vergleicht öffentliche Daten von A, B und C. Stellt CNC-Maschinen her und schützt das SimulationModel über Keycloak + Security SM.',
    hasAuth: true,
    gatewayHost: 'actor-d.localhost',
    viewerHost: 'viewer-d.localhost',
    configuredRoles: ['partner-d'],
    realm: 'actor-d',
    clientId: 'actor-d-client',
    clientSecret: 'actor-d-secret-12345',
    ownAasUrn: 'urn:dataspace:d:aas:machine-type-001',
    knownUrns: [
      {
        id: 'd-own-aas',
        label: 'Eigene AAS: MillingMachineTypeAAS',
        urn: 'urn:dataspace:d:aas:machine-type-001',
        resourceMode: 'specific-resource',
        relation: 'own',
        originHint: 'Eigene Maschinen-Typ-AAS von Akteur D (integriert A, B, C)',
        description: 'Maschinen-Typ-AAS von Akteur D inkl. Nameplate, TechnicalData und SimulationModel.',
        expectedAuth: 'customer-d',
      },
      {
        id: 'd-peer-e-aas',
        label: 'Fremd-AAS von E: TurbineBladeProductAAS (Nur Nameplate sichtbar)',
        urn: 'urn:dataspace:e:aas:produced-part-001',
        resourceMode: 'specific-resource',
        relation: 'dataspace-peer',
        originHint: 'Produkt-URN von Akteur E -> Nicht-Kunde D sieht nur Nameplate, TimeSeries ist gesperrt',
        description: 'Im BaSyx Viewer sieht D das Nameplate von E, während TimeSeries als "Submodel Not Authorized!" markiert ist.',
        expectedAuth: 'partner',
      },
      {
        id: 'd-peer-e-np',
        label: 'Fremd-SM von E: Digital Nameplate (Erlaubt für Partner D -> 200)',
        urn: 'urn:dataspace:e:sm:nameplate',
        resourceMode: 'specific-resource',
        relation: 'dataspace-peer',
        originHint: 'Nameplate-Referenz aus TurbineBladeProductAAS ("andere sehen nur Nameplate")',
        description: 'Nicht-Kunde D darf das Nameplate von Akteur E lesen (HTTP 200 OK).',
        expectedAuth: 'partner',
      },
      {
        id: 'd-peer-e-ts',
        label: 'Fremd-SM von E: TimeSeries (Gesperrt für Nicht-Kunde D -> 403)',
        urn: 'urn:dataspace:e:sm:timeseries',
        resourceMode: 'specific-resource',
        relation: 'dataspace-peer',
        originHint: 'TimeSeries-Referenz aus TurbineBladeProductAAS (Nur für Kunden mit customer-e)',
        description: 'Negativtest: Akteur D ist kein Kunde von E und erhält HTTP 403 Forbidden auf TimeSeries.',
        expectedAuth: 'customer-e',
      },
      {
        id: 'd-ref-a',
        label: 'Zulieferer A: ServoMotorAAS (Öffentlicher Katalog)',
        urn: 'urn:dataspace:a:aas:servo-motor-001',
        resourceMode: 'specific-resource',
        relation: 'supplier-catalog',
        originHint: 'Stücklisten-Referenz (IntegratedMotorRef) in MillingMachineTypeAAS',
        description: 'Löst Zulieferer A dynamisch über Company Lookup auf.',
        expectedAuth: 'public',
      },
      {
        id: 'd-ref-b',
        label: 'Zulieferer B: IndustrialGearboxAAS (Öffentlicher Katalog)',
        urn: 'urn:dataspace:b:aas:gearbox-001',
        resourceMode: 'specific-resource',
        relation: 'supplier-catalog',
        originHint: 'Stücklisten-Referenz (IntegratedGearboxRef) in MillingMachineTypeAAS',
        description: 'Löst Zulieferer B dynamisch über Company Lookup auf.',
        expectedAuth: 'public',
      },
      {
        id: 'd-ref-c',
        label: 'Zulieferer C: VibrationSensorAAS (Öffentlicher Katalog)',
        urn: 'urn:dataspace:c:aas:sensor-001',
        resourceMode: 'specific-resource',
        relation: 'supplier-catalog',
        originHint: 'Stücklisten-Referenz (IntegratedSensorRef) in MillingMachineTypeAAS',
        description: 'Löst Zulieferer C dynamisch über Company Lookup auf.',
        expectedAuth: 'public',
      },
    ],
  },
  {
    id: 'actor-e',
    shortCode: 'E',
    name: 'Actor E',
    role: 'Component Producer (Kunde von D)',
    description: 'Kauft CNC-Maschine bei Akteur D (Zugriff auf Typ-AAS + Simulation SM via Rolle customer-d). Fertigt Turbinenschaufeln mit geschütztem TimeSeries SM.',
    hasAuth: true,
    gatewayHost: 'actor-e.localhost',
    viewerHost: 'viewer-e.localhost',
    configuredRoles: ['customer-d', 'partner-e'],
    realm: 'actor-e',
    clientId: 'actor-e-client',
    clientSecret: 'actor-e-secret-12345',
    ownAasUrn: 'urn:dataspace:e:aas:produced-part-001',
    knownUrns: [
      {
        id: 'e-purchased-d-aas',
        label: 'Gekaufte Maschine (von D): MillingMachineTypeAAS + Simulation',
        urn: 'urn:dataspace:d:aas:machine-type-001',
        resourceMode: 'specific-resource',
        relation: 'purchased',
        originHint: 'Nameplate-Referenz (ProducingMachineRef -> urn:dataspace:d:aas:machine-type-001)',
        description: 'Löst Akteur D über Company Lookup auf und lädt die gekaufte Maschine inkl. SimulationModel im BaSyx Viewer.',
        expectedAuth: 'customer-d',
      },
      {
        id: 'e-purchased-d-sim',
        label: 'Gekaufte Maschine (von D): SimulationModel SM (Direkt -> 200)',
        urn: 'urn:dataspace:d:sm:machine-simulation',
        resourceMode: 'specific-resource',
        relation: 'purchased',
        originHint: 'Submodel-Referenz (urn:dataspace:d:sm:machine-simulation) der gekauften Maschine D',
        description: 'Autorisierter Zugriff auf das Kinematik- & Thermo-FEA SimulationModel von D (Rolle: customer-d).',
        expectedAuth: 'customer-d',
      },
      {
        id: 'e-own-aas',
        label: 'Eigene AAS: TurbineBladeProductAAS (Nameplate + TimeSeries)',
        urn: 'urn:dataspace:e:aas:produced-part-001',
        resourceMode: 'specific-resource',
        relation: 'own',
        originHint: 'Eigene Bauteil-AAS im lokalen Repository von Akteur E',
        description: 'Hergestellte Turbinenschaufel mit Nameplate und aufgezeichneten TimeSeries-Prozessdaten.',
        expectedAuth: 'partner',
      },
    ],
  },
  {
    id: 'actor-f',
    shortCode: 'F',
    name: 'Actor F',
    role: 'End Customer (Kunde von E)',
    description: 'Kauft gefertigtes Bauteil bei Akteur E und erhält über Rolle customer-e Zugriff auf die AAS samt TimeSeries-Produktionsdaten.',
    hasAuth: true,
    gatewayHost: 'actor-f.localhost',
    viewerHost: 'viewer-f.localhost',
    configuredRoles: ['customer-e', 'partner-f'],
    realm: 'actor-f',
    clientId: 'actor-f-client',
    clientSecret: 'actor-f-secret-12345',
    ownAasUrn: 'urn:dataspace:f:aas:customer-profile-001',
    knownUrns: [
      {
        id: 'f-purchased-e-aas',
        label: 'Gekauftes Produkt (von E): TurbineBladeProductAAS (inkl. TimeSeries)',
        urn: 'urn:dataspace:e:aas:produced-part-001',
        resourceMode: 'specific-resource',
        relation: 'purchased',
        originHint: 'Kundenprofil / Lieferschein-Referenz (AuthorizedCustomerFor -> urn:dataspace:e:aas:produced-part-001)',
        description: 'Löst Akteur E über Company Lookup (?asset_id=...) auf und öffnet die fremde Shell inkl. TimeSeries im BaSyx Viewer von F.',
        expectedAuth: 'customer-e',
      },
      {
        id: 'f-purchased-e-ts',
        label: 'Gekauftes Produkt (von E): TimeSeries Produktionsdaten SM (200 OK)',
        urn: 'urn:dataspace:e:sm:timeseries',
        resourceMode: 'specific-resource',
        relation: 'purchased',
        originHint: 'Submodel-Referenz (urn:dataspace:e:sm:timeseries) aus gekaufter TurbineBladeProductAAS',
        description: 'Direkter Abruf & Deep-Link in das geschützte TimeSeries-Teilmodell von Akteur E (Rolle: customer-e).',
        expectedAuth: 'customer-e',
      },
      {
        id: 'f-purchased-e-np',
        label: 'Gekauftes Produkt (von E): Digital Nameplate SM (200 OK)',
        urn: 'urn:dataspace:e:sm:nameplate',
        resourceMode: 'specific-resource',
        relation: 'purchased',
        originHint: 'Nameplate-Teilmodell (enthält ProducingMachineRef -> Maschine von D)',
        description: 'Digitales Typenschild des gekauften Bauteils von Akteur E.',
        expectedAuth: 'customer-e',
      },
      {
        id: 'f-own-aas',
        label: 'Eigene AAS: CustomerAeroEngineOEM (Lokales Repo von F)',
        urn: 'urn:dataspace:f:aas:customer-profile-001',
        resourceMode: 'specific-resource',
        relation: 'own',
        originHint: 'Lokales AAS-Repository von Akteur F (http://actor-f.localhost/shells)',
        description: 'Eigene Shell von Akteur F mit der Kauf-Referenz auf das Bauteil von E.',
        expectedAuth: 'public',
      },
      {
        id: 'f-neg-d-sim',
        label: 'Negativtest: Actor D Simulation SM (Gesperrt für F -> 403)',
        urn: 'urn:dataspace:d:sm:machine-simulation',
        resourceMode: 'specific-resource',
        relation: 'dataspace-peer',
        originHint: 'Weiterverfolgung von ProducingMachineRef -> Akteur F ist jedoch kein Kunde von D',
        description: 'Negativtest: Akteur F hat nur customer-e (nicht customer-d) -> Zugriff auf Simulation von D wird mit HTTP 403 verweigert.',
        expectedAuth: 'customer-d',
      },
    ],
  },
];

export interface DataspaceResourceItem {
  urn: string;
  ownerActorId: string;
  ownerLabel: string;
  label: string;
  kind: 'AAS' | 'Submodel';
  requiredRole: string;
  originHint: string;
}

export const DATASPACE_RESOURCES: DataspaceResourceItem[] = [
  {
    urn: 'urn:dataspace:e:aas:produced-part-001',
    ownerActorId: 'actor-e',
    ownerLabel: 'Actor E (Component Producer)',
    label: 'TurbineBladeProductAAS (Shell)',
    kind: 'AAS',
    requiredRole: 'authentifiziert (Nameplate: alle Partner | TimeSeries: customer-e)',
    originHint: 'Bauteil-AAS von Akteur E (referenziert in Kundenprofil F)',
  },
  {
    urn: 'urn:dataspace:e:sm:timeseries',
    ownerActorId: 'actor-e',
    ownerLabel: 'Actor E (Component Producer)',
    label: 'TimeSeries Produktionsdaten (Submodel)',
    kind: 'Submodel',
    requiredRole: 'customer-e (Nur Kunde F)',
    originHint: 'Submodel-Referenz aus TurbineBladeProductAAS (Prozessdaten der Fertigung)',
  },
  {
    urn: 'urn:dataspace:e:sm:nameplate',
    ownerActorId: 'actor-e',
    ownerLabel: 'Actor E (Component Producer)',
    label: 'Digital Nameplate Bauteil (Submodel)',
    kind: 'Submodel',
    requiredRole: 'customer-e, partner-d, partner-e, partner-f',
    originHint: 'Nameplate-Referenz aus TurbineBladeProductAAS ("andere sehen nur Nameplate")',
  },
  {
    urn: 'urn:dataspace:d:aas:machine-type-001',
    ownerActorId: 'actor-d',
    ownerLabel: 'Actor D (Machine OEM)',
    label: 'MillingMachineTypeAAS (Shell)',
    kind: 'AAS',
    requiredRole: 'customer-d (Kunde E)',
    originHint: 'Maschinen-Typ-AAS von Akteur D (ProducingMachineRef auf Nameplate von E)',
  },
  {
    urn: 'urn:dataspace:d:sm:machine-simulation',
    ownerActorId: 'actor-d',
    ownerLabel: 'Actor D (Machine OEM)',
    label: 'SimulationModel Kinematik/FEA (Submodel)',
    kind: 'Submodel',
    requiredRole: 'customer-d (Nur Kunde E)',
    originHint: 'Geschütztes SimulationModel-Teilmodell der Fräsmaschine von Akteur D',
  },
  {
    urn: 'urn:dataspace:d:sm:technical-data',
    ownerActorId: 'actor-d',
    ownerLabel: 'Actor D (Machine OEM)',
    label: 'TechnicalData Maschine (Submodel, integriert A/B/C)',
    kind: 'Submodel',
    requiredRole: 'customer-d, partner-d',
    originHint: 'Technische Maschinendaten von Akteur D mit Referenzen auf A, B und C',
  },
  {
    urn: 'urn:dataspace:a:aas:servo-motor-001',
    ownerActorId: 'actor-a',
    ownerLabel: 'Actor A (Servo Motor Supplier)',
    label: 'ServoMotorAAS (Öffentliche Shell)',
    kind: 'AAS',
    requiredRole: 'public (Öffentlich)',
    originHint: 'Öffentlicher Produktkatalog von Zulieferer A (IntegratedMotorRef)',
  },
  {
    urn: 'urn:dataspace:a:sm:technical-data',
    ownerActorId: 'actor-a',
    ownerLabel: 'Actor A (Servo Motor Supplier)',
    label: 'TechnicalData Servomotor 15 kW IE4 (Submodel)',
    kind: 'Submodel',
    requiredRole: 'public (Öffentlich)',
    originHint: 'Öffentliches TechnicalData-Teilmodell von Zulieferer A',
  },
  {
    urn: 'urn:dataspace:b:aas:gearbox-001',
    ownerActorId: 'actor-b',
    ownerLabel: 'Actor B (Gearbox Supplier)',
    label: 'IndustrialGearboxAAS (Öffentliche Shell)',
    kind: 'AAS',
    requiredRole: 'public (Öffentlich)',
    originHint: 'Öffentlicher Produktkatalog von Zulieferer B (IntegratedGearboxRef)',
  },
  {
    urn: 'urn:dataspace:b:sm:technical-data',
    ownerActorId: 'actor-b',
    ownerLabel: 'Actor B (Gearbox Supplier)',
    label: 'TechnicalData Getriebe 10:1 (Submodel)',
    kind: 'Submodel',
    requiredRole: 'public (Öffentlich)',
    originHint: 'Öffentliches TechnicalData-Teilmodell von Zulieferer B',
  },
  {
    urn: 'urn:dataspace:c:aas:sensor-001',
    ownerActorId: 'actor-c',
    ownerLabel: 'Actor C (Sensor Supplier)',
    label: 'VibrationSensorAAS (Öffentliche Shell)',
    kind: 'AAS',
    requiredRole: 'public (Öffentlich)',
    originHint: 'Öffentlicher Produktkatalog von Zulieferer C (IntegratedSensorRef)',
  },
  {
    urn: 'urn:dataspace:c:sm:technical-data',
    ownerActorId: 'actor-c',
    ownerLabel: 'Actor C (Sensor Supplier)',
    label: 'TechnicalData Sensor 25.6 kHz (Submodel)',
    kind: 'Submodel',
    requiredRole: 'public (Öffentlich)',
    originHint: 'Öffentliches TechnicalData-Teilmodell von Zulieferer C',
  },
  {
    urn: 'urn:dataspace:f:aas:customer-profile-001',
    ownerActorId: 'actor-f',
    ownerLabel: 'Actor F (End Customer)',
    label: 'CustomerAeroEngineOEM (Shell)',
    kind: 'AAS',
    requiredRole: 'public (Öffentlich)',
    originHint: 'Lokale Kunden-AAS von Akteur F',
  },
];

// Client-side caches so repeated lookups & data fetches don't hit the origin repo every time
const tokenCache: Record<string, { token: string; expiresAt: number; decoded: any }> = {};
const lookupCache: Record<string, { resolution: LookupResolution; expiresAt: number }> = {};
const resourceCache: Record<string, { result: ExecutionResult; expiresAt: number }> = {};
const parentAasCache: Record<string, string> = {};

const CACHE_TTL_MS = 120 * 1000; // 2 minutes

export function clearDataspaceCache(): void {
  for (const k of Object.keys(lookupCache)) delete lookupCache[k];
  for (const k of Object.keys(resourceCache)) delete resourceCache[k];
  for (const k of Object.keys(parentAasCache)) delete parentAasCache[k];
}

export function getCacheStats(): { lookups: number; resources: number } {
  return {
    lookups: Object.keys(lookupCache).length,
    resources: Object.keys(resourceCache).length,
  };
}

export function toBase64(input: string): string {
  return btoa(input);
}

export function toBase64Url(input: string): string {
  return btoa(input).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function decodeBase64Json(seg: string): Record<string, any> | null {
  try {
    const base64 = seg.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    return JSON.parse(jsonPayload);
  } catch {
    return null;
  }
}

export function decodeJwt(token: string): any {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  return decodeBase64Json(parts[1]);
}

export function decodeJwtBundle(token: string | null | undefined): DecodedJwtBundle | null {
  if (!token || typeof token !== 'string') return null;
  const trimmed = token.trim();
  const parts = trimmed.split('.');
  if (parts.length !== 3) return null;
  return {
    raw: trimmed,
    header: decodeBase64Json(parts[0]),
    payload: decodeBase64Json(parts[1]),
  };
}

export async function getAccessToken(actorId: string): Promise<{ token: string; decoded: any } | null> {
  const actor = ACTORS.find((a) => a.id === actorId);
  if (!actor || !actor.hasAuth || !actor.realm || !actor.clientId || !actor.clientSecret) {
    return null;
  }

  const now = Date.now();
  if (tokenCache[actorId] && tokenCache[actorId].expiresAt > now + 10000) {
    return {
      token: tokenCache[actorId].token,
      decoded: tokenCache[actorId].decoded,
    };
  }

  const tokenUrl = `/cluster-api/keycloak/realms/${actor.realm}/protocol/openid-connect/token`;
  const params = new URLSearchParams();
  params.append('grant_type', 'client_credentials');
  params.append('client_id', actor.clientId);
  params.append('client_secret', actor.clientSecret);

  const response = await fetch(tokenUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params.toString(),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Token exchange failed [${response.status}]: ${errText}`);
  }

  const json = await response.json();
  const token = json.access_token;
  const decoded = decodeJwt(token);
  const expiresInSec = json.expires_in || 300;

  tokenCache[actorId] = {
    token,
    expiresAt: now + expiresInSec * 1000,
    decoded,
  };

  return { token, decoded };
}

export async function listRegisteredCompanies(): Promise<CompanyLookupRecord[]> {
  const response = await fetch('/cluster-api/lookup/api/v2/companies?limit=25', {
    headers: { Accept: 'application/json' },
  });
  if (!response.ok) {
    throw new Error(`Company Lookup returned HTTP ${response.status}`);
  }
  const data = await response.json();
  return data.result || [];
}

function parseCompanyEndpoints(company: CompanyLookupRecord | null): {
  aasRepositoryUrl: string | null;
  submodelRepositoryUrl: string | null;
  resolvedHost: string | null;
} {
  if (!company || !Array.isArray(company.endpoints)) {
    return { aasRepositoryUrl: null, submodelRepositoryUrl: null, resolvedHost: null };
  }

  const aasEp = company.endpoints.find((e) => e.interface.startsWith('AAS-REPOSITORY'));
  const smEp = company.endpoints.find((e) => e.interface.startsWith('SUBMODEL-REPOSITORY'));

  const aasRepositoryUrl = aasEp?.protocolInformation?.href || null;
  const submodelRepositoryUrl = smEp?.protocolInformation?.href || null;

  let resolvedHost: string | null = company.domain || null;
  const primaryHref = aasRepositoryUrl || submodelRepositoryUrl;
  if (primaryHref) {
    try {
      resolvedHost = new URL(primaryHref).host;
    } catch {
      // Fallback to domain
    }
  }

  return { aasRepositoryUrl, submodelRepositoryUrl, resolvedHost };
}

/**
 * Resolves a semantic Asset / AAS / Submodel URN via the Company Lookup Service:
 * GET http://lookup.localhost/api/v2/companies?asset_id=<base64url(urn)>
 * Uses in-memory caching unless forceRefresh is true.
 */
export async function lookupCompanyByAssetUrn(
  urn: string,
  forceRefresh: boolean = false
): Promise<LookupResolution> {
  const now = Date.now();
  if (!forceRefresh && lookupCache[urn] && lookupCache[urn].expiresAt > now) {
    return {
      ...lookupCache[urn].resolution,
      durationMs: 0,
      fromCache: true,
    };
  }

  const encodedQuery = toBase64Url(urn);
  const lookupApiUrl = `/cluster-api/lookup/api/v2/companies?asset_id=${encodedQuery}`;
  const directLookupUrl = `http://lookup.localhost/api/v2/companies?asset_id=${encodedQuery}`;
  const start = performance.now();

  try {
    const response = await fetch(lookupApiUrl, {
      method: 'GET',
      headers: { Accept: 'application/json' },
    });
    const durationMs = Math.round(performance.now() - start);
    const rawResponse = await response.json().catch(() => null);
    const company: CompanyLookupRecord | null = rawResponse?.result?.[0] || null;
    const { aasRepositoryUrl, submodelRepositoryUrl, resolvedHost } = parseCompanyEndpoints(company);

    const resolution: LookupResolution = {
      success: response.ok && !!company && !!resolvedHost,
      queryType: 'asset_id',
      queryValue: urn,
      encodedQuery,
      lookupApiUrl,
      directLookupUrl,
      status: response.status,
      durationMs,
      fromCache: false,
      company,
      aasRepositoryUrl,
      submodelRepositoryUrl,
      resolvedHost,
      rawResponse,
      errorMessage: !company ? `No company matched asset_id pattern for '${urn}'` : undefined,
    };

    if (resolution.success) {
      lookupCache[urn] = { resolution, expiresAt: now + CACHE_TTL_MS };
    }

    return resolution;
  } catch (err: any) {
    return {
      success: false,
      queryType: 'asset_id',
      queryValue: urn,
      encodedQuery,
      lookupApiUrl,
      directLookupUrl,
      status: 0,
      durationMs: Math.round(performance.now() - start),
      fromCache: false,
      company: null,
      aasRepositoryUrl: null,
      submodelRepositoryUrl: null,
      resolvedHost: null,
      rawResponse: null,
      errorMessage: err.message || 'Company Lookup Service unreachable',
    };
  }
}

/**
 * Full 3-Step Dataspace Resolution & Request Execution (with Local Caching):
 * 1. Resolves the target Company & Repository Endpoint dynamically via Company Lookup (?asset_id=...)
 * 2. Attaches the active actor's Keycloak token (if authenticated)
 * 3. Calls the dynamically resolved AAS/Submodel Repository endpoint via its Gateway (STS + Dynamic RBAC)
 *    and captures both the Caller JWT and the Exchanged STS JWT!
 */
export async function resolveAndFetchUrn(
  targetUrn: string,
  identityActorId: string,
  resourceMode: 'specific-resource' | 'shells-catalog' | 'submodels-catalog' = 'specific-resource',
  existingLookup?: LookupResolution,
  forceRefresh: boolean = false
): Promise<ExecutionResult> {
  const identityActor = ACTORS.find((a) => a.id === identityActorId);
  const knownTarget = identityActor?.knownUrns.find((u) => u.urn === targetUrn);
  const globalCatalogTarget = DATASPACE_RESOURCES.find((r) => r.urn === targetUrn);
  const originHint =
    knownTarget?.originHint ||
    globalCatalogTarget?.originHint ||
    `Manuelle URN-Abfrage über Company Lookup (?asset_id=${toBase64Url(targetUrn).slice(0, 16)}...)`;

  const cacheKey = `${identityActorId}:${resourceMode}:${targetUrn}`;
  const now = Date.now();
  if (!forceRefresh && resourceCache[cacheKey] && resourceCache[cacheKey].expiresAt > now) {
    const cached = resourceCache[cacheKey].result;
    return {
      ...cached,
      durationMs: 0,
      fromCache: true,
      lookupStep: {
        ...cached.lookupStep,
        durationMs: 0,
        fromCache: true,
      },
    };
  }

  const lookupStep = existingLookup || (await lookupCompanyByAssetUrn(targetUrn, forceRefresh));

  if (!lookupStep.success || !lookupStep.resolvedHost) {
    return {
      url: lookupStep.lookupApiUrl,
      directUrl: lookupStep.directLookupUrl,
      method: 'GET',
      status: lookupStep.status || 404,
      statusText: lookupStep.errorMessage || 'Discovery Lookup Failed',
      durationMs: lookupStep.durationMs,
      timestamp: new Date().toISOString(),
      fromCache: false,
      headers: {},
      data: lookupStep.rawResponse,
      rawText: JSON.stringify(lookupStep.rawResponse, null, 2) || lookupStep.errorMessage || '',
      isSuccess: false,
      activeIdentity: identityActor?.name || 'Guest',
      tokenUsed: false,
      targetUrn,
      originHint,
      lookupStep,
      resolvedAasUrl: null,
      resolvedSubmodelUrl: null,
      sourceJwt: null,
      exchangedJwt: null,
    };
  }

  const isSubmodelUrn = targetUrn.includes(':sm:');
  const baseAasUrl = (lookupStep.aasRepositoryUrl || `http://${lookupStep.resolvedHost}/shells`).replace(/\/$/, '');
  const baseSmUrl = (lookupStep.submodelRepositoryUrl || `http://${lookupStep.resolvedHost}/submodels`).replace(/\/$/, '');
  let targetEndpointUrl: string;
  let resolvedAasUrl: string | null = null;
  let resolvedSubmodelUrl: string | null = null;

  if (resourceMode === 'shells-catalog') {
    targetEndpointUrl = baseAasUrl;
  } else if (resourceMode === 'submodels-catalog') {
    targetEndpointUrl = baseSmUrl;
  } else if (isSubmodelUrn) {
    resolvedSubmodelUrl = `${baseSmUrl}/${toBase64(targetUrn)}`;
    targetEndpointUrl = resolvedSubmodelUrl;
  } else {
    resolvedAasUrl = `${baseAasUrl}/${toBase64(targetUrn)}`;
    targetEndpointUrl = resolvedAasUrl;
  }

  const parsedTarget = new URL(targetEndpointUrl);
  const resolvedHost = parsedTarget.host;
  const resolvedPath = parsedTarget.pathname + parsedTarget.search;

  const proxyUrl = `/cluster-api/host/${resolvedHost}${resolvedPath}`;
  const directUrl = targetEndpointUrl;

  const headers: Record<string, string> = {
    Accept: 'application/json, text/plain, */*',
    'X-Dataspace-Target-Host': resolvedHost,
  };

  let tokenUsed = false;
  let callerTokenRaw: string | null = null;
  if (identityActor && identityActor.hasAuth) {
    try {
      const tokenInfo = await getAccessToken(identityActor.id);
      if (tokenInfo?.token) {
        callerTokenRaw = tokenInfo.token;
        headers['Authorization'] = `Bearer ${tokenInfo.token}`;
        tokenUsed = true;
      }
    } catch (e) {
      console.warn(`Could not obtain token for ${identityActor.id}, sending unauthenticated request.`);
    }
  }

  // Dynamically discover the parent AAS on the Lookup-resolved provider when a Submodel URN was queried
  if (isSubmodelUrn && resourceMode === 'specific-resource') {
    if (!forceRefresh && parentAasCache[targetUrn]) {
      resolvedAasUrl = parentAasCache[targetUrn];
    } else {
      try {
        const shellsRes = await fetch(`/cluster-api/host/${resolvedHost}/shells`, {
          method: 'GET',
          headers,
        });
        if (shellsRes.ok) {
          const shellsJson = await shellsRes.json().catch(() => null);
          const shellsList: any[] = Array.isArray(shellsJson?.result) ? shellsJson.result : [];
          const parentShell =
            shellsList.find(
              (s) =>
                Array.isArray(s.submodels) &&
                s.submodels.some(
                  (ref: any) => Array.isArray(ref.keys) && ref.keys.some((k: any) => k.value === targetUrn)
                )
            ) || shellsList[0];
          if (parentShell?.id) {
            resolvedAasUrl = `${baseAasUrl}/${toBase64(parentShell.id)}`;
            parentAasCache[targetUrn] = resolvedAasUrl;
          }
        }
      } catch {
        // Leave resolvedAasUrl null if unauthenticated / forbidden on /shells
      }
    }
  }

  const startTime = performance.now();
  const resHeaders: Record<string, string> = {};

  try {
    const response = await fetch(proxyUrl, {
      method: 'GET',
      headers,
    });

    const durationMs = Math.round(performance.now() - startTime);
    response.headers.forEach((value, key) => {
      resHeaders[key] = value;
    });

    const rawText = await response.text();
    let parsedData: any = null;
    try {
      parsedData = JSON.parse(rawText);
    } catch {
      parsedData = rawText;
    }

    if (resourceMode === 'shells-catalog' && Array.isArray(parsedData?.result) && parsedData.result[0]?.id) {
      resolvedAasUrl = `${baseAasUrl}/${toBase64(parsedData.result[0].id)}`;
    }

    const headerSourceToken = resHeaders['x-dataspace-source-token'] || callerTokenRaw;
    const headerExchangedToken = resHeaders['x-dataspace-exchanged-token'] || null;

    const result: ExecutionResult = {
      url: proxyUrl,
      directUrl,
      method: 'GET',
      status: response.status,
      statusText: response.statusText,
      durationMs,
      timestamp: new Date().toISOString(),
      fromCache: false,
      headers: resHeaders,
      data: parsedData,
      rawText,
      isSuccess: response.status >= 200 && response.status < 300,
      activeIdentity: identityActor?.name || 'Guest',
      tokenUsed,
      targetUrn,
      originHint,
      lookupStep,
      resolvedAasUrl,
      resolvedSubmodelUrl,
      sourceJwt: decodeJwtBundle(headerSourceToken),
      exchangedJwt: decodeJwtBundle(headerExchangedToken),
    };

    if (result.isSuccess) {
      resourceCache[cacheKey] = { result, expiresAt: Date.now() + CACHE_TTL_MS };
    }

    return result;
  } catch (error: any) {
    const durationMs = Math.round(performance.now() - startTime);
    return {
      url: proxyUrl,
      directUrl,
      method: 'GET',
      status: 0,
      statusText: error.message || 'Connection Refused',
      durationMs,
      timestamp: new Date().toISOString(),
      fromCache: false,
      headers: {},
      data: null,
      rawText: error.stack || error.message || 'Failed to reach resolved cluster endpoint.',
      isSuccess: false,
      activeIdentity: identityActor?.name || 'Guest',
      tokenUsed,
      targetUrn,
      originHint,
      lookupStep,
      resolvedAasUrl,
      resolvedSubmodelUrl,
      sourceJwt: decodeJwtBundle(callerTokenRaw),
      exchangedJwt: null,
    };
  }
}

function extractPropertiesMap(submodel: any): Record<string, string> {
  const map: Record<string, string> = {};
  if (!submodel || !Array.isArray(submodel.submodelElements)) return map;
  for (const elem of submodel.submodelElements) {
    if (elem.idShort && elem.value !== undefined) {
      map[elem.idShort] = String(elem.value);
    }
  }
  return map;
}

export async function compareSuppliersViaLookup(
  identityActorId: string = 'actor-d',
  forceRefresh: boolean = false
): Promise<SupplierComparisonEntry[]> {
  const targets = [
    {
      supplierLabel: 'Supplier A (Servo Motor)',
      aasUrn: 'urn:dataspace:a:aas:servo-motor-001',
      nameplateUrn: 'urn:dataspace:a:sm:nameplate',
      techDataUrn: 'urn:dataspace:a:sm:technical-data',
    },
    {
      supplierLabel: 'Supplier B (Industrial Gearbox)',
      aasUrn: 'urn:dataspace:b:aas:gearbox-001',
      nameplateUrn: 'urn:dataspace:b:sm:nameplate',
      techDataUrn: 'urn:dataspace:b:sm:technical-data',
    },
    {
      supplierLabel: 'Supplier C (Vibration Sensor)',
      aasUrn: 'urn:dataspace:c:aas:sensor-001',
      nameplateUrn: 'urn:dataspace:c:sm:nameplate',
      techDataUrn: 'urn:dataspace:c:sm:technical-data',
    },
  ];

  const results: SupplierComparisonEntry[] = [];

  for (const t of targets) {
    const shellRes = await resolveAndFetchUrn(t.aasUrn, identityActorId, 'specific-resource', undefined, forceRefresh);
    const npRes = await resolveAndFetchUrn(
      t.nameplateUrn,
      identityActorId,
      'specific-resource',
      shellRes.lookupStep,
      forceRefresh
    );
    const tdRes = await resolveAndFetchUrn(
      t.techDataUrn,
      identityActorId,
      'specific-resource',
      shellRes.lookupStep,
      forceRefresh
    );

    results.push({
      supplierLabel: t.supplierLabel,
      targetUrn: t.aasUrn,
      lookup: shellRes.lookupStep,
      shell: shellRes.isSuccess ? shellRes.data : null,
      nameplate: npRes.isSuccess ? extractPropertiesMap(npRes.data) : {},
      technicalData: tdRes.isSuccess ? extractPropertiesMap(tdRes.data) : {},
      status: shellRes.status,
      fromCache: shellRes.fromCache && npRes.fromCache && tdRes.fromCache,
    });
  }

  return results;
}
