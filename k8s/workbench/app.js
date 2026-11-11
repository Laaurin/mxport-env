/**
 * Dataspace Test Workbench - Frontend Application Logic
 * Supports both Live Cluster execution (via proxy/direct fetch) and Demo Simulation mode.
 */

// Global Configuration
const CONFIG = {
  keycloakBase: 'http://keycloak.localhost',
  actors: {
    'a': { name: 'Akteur A', gw: 'http://actor-a.localhost' },
    'b': { name: 'Akteur B', gw: 'http://actor-b.localhost' },
    'c': { name: 'Akteur C', gw: 'http://actor-c.localhost' },
    'd': { name: 'Akteur D', gw: 'http://actor-d.localhost', realm: 'actor-d', client: 'actor-d-client', secret: 'actor-d-secret-12345' },
    'e': { name: 'Akteur E', gw: 'http://actor-e.localhost', realm: 'actor-e', client: 'actor-e-client', secret: 'actor-e-secret-12345' },
    'f': { name: 'Akteur F', gw: 'http://actor-f.localhost', realm: 'actor-f', client: 'actor-f-client', secret: 'actor-f-secret-12345' }
  },
  submodels: {
    aTech: 'dXJuOmRhdGFzcGFjZTphOnNtOnRlY2huaWNhbC1kYXRh',
    bTech: 'dXJuOmRhdGFzcGFjZTpiOnNtOnRlY2huaWNhbC1kYXRh',
    cTech: 'dXJuOmRhdGFzcGFjZTpjOnNtOnRlY2huaWNhbC1kYXRh',
    dTech: 'dXJuOmRhdGFzcGFjZTpkOnNtOnRlY2huaWNhbC1kYXRh',
    dSim:  'dXJuOmRhdGFzcGFjZTpkOnNtOm1hY2hpbmUtc2ltdWxhdGlvbg==',
    eNp:   'dXJuOmRhdGFzcGFjZTplOnNtOm5hbWVwbGF0ZQ==',
    eTs:   'dXJuOmRhdGFzcGFjZTplOnNtOnRpbWVzZXJpZXM='
  }
};

let currentMode = 'live'; // 'live' or 'demo'
let tokenCache = {};

// Demo Mock Data
const MOCK_DATA = {
  'test_a_shells': { status: 200, body: { result: [{ id: 'urn:dataspace:a:aas:servo-motor-001', idShort: 'ServoMotorAAS', modelType: 'AssetAdministrationShell' }] } },
  'test_a_tech': { status: 200, body: { id: 'urn:dataspace:a:sm:technical-data', idShort: 'TechnicalData', submodelElements: [{ idShort: 'NominalPowerKW', value: 15.0 }, { idShort: 'EfficiencyClass', value: 'IE4' }] } },
  'test_b_shells': { status: 200, body: { result: [{ id: 'urn:dataspace:b:aas:gearbox-001', idShort: 'IndustrialGearboxAAS' }] } },
  'test_b_tech': { status: 200, body: { id: 'urn:dataspace:b:sm:technical-data', idShort: 'TechnicalData', submodelElements: [{ idShort: 'GearRatio', value: '10:1' }, { idShort: 'MaxOutputTorqueNm', value: 450.0 }] } },
  'test_c_shells': { status: 200, body: { result: [{ id: 'urn:dataspace:c:aas:sensor-001', idShort: 'VibrationSensorAAS' }] } },
  'test_c_tech': { status: 200, body: { id: 'urn:dataspace:c:sm:technical-data', idShort: 'TechnicalData', submodelElements: [{ idShort: 'SamplingRateKHz', value: 25.6 }, { idShort: 'Interface', value: 'IO-Link' }] } },
  'test_d_unauth': { status: 401, body: { error: 'Unauthorized', message: 'Full authentication required to access this resource' } },
  'test_d_unauthorized_f': { status: 403, body: { error: 'Forbidden', message: 'Access denied: caller does not possess required role customer-d' } },
  'test_d_shells': { status: 200, body: { result: [{ id: 'urn:dataspace:d:aas:machine-type-001', idShort: 'MillingMachineTypeAAS' }] } },
  'test_d_tech': { status: 200, body: { id: 'urn:dataspace:d:sm:technical-data', submodelElements: [{ idShort: 'IntegratedMotorRef', value: 'urn:dataspace:a:aas:servo-motor-001' }, { idShort: 'IntegratedGearboxRef', value: 'urn:dataspace:b:aas:gearbox-001' }, { idShort: 'IntegratedSensorRef', value: 'urn:dataspace:c:aas:sensor-001' }] } },
  'test_d_auth_e': { status: 200, body: { id: 'urn:dataspace:d:sm:machine-simulation', idShort: 'SimulationModel', submodelElements: [{ idShort: 'SimulationType', value: 'KinematicAndThermalFEA' }, { idShort: 'ModelVersion', value: 'v3.2.1' }, { idShort: 'ToolCenterPointPrecisionMicron', value: 2.5 }, { idShort: 'SimulationPackageUrl', value: 's3://apex-simulation-vault/packages/v5-thermal-fea.fmu' }] } },
  'test_e_nameplate_d': { status: 200, body: { id: 'urn:dataspace:e:sm:nameplate', idShort: 'Nameplate', submodelElements: [{ idShort: 'ManufacturerName', value: 'PrecisionAero Components GmbH' }, { idShort: 'ManufacturerProductDesignation', value: 'HighPressure Turbine Blade Ti-6Al-4V' }, { idShort: 'ProducingMachineRef', value: 'urn:dataspace:d:aas:machine-type-001' }] } },
  'test_e_timeseries_d': { status: 403, body: { error: 'Forbidden', message: 'Policy enforcement: role partner-d is restricted to Nameplate; TimeSeries requires customer-e' } },
  'test_e_timeseries_f': { status: 200, body: { id: 'urn:dataspace:e:sm:timeseries', idShort: 'TimeSeries', submodelElements: [{ idShort: 'ProcessRecordCount', value: 3600 }, { idShort: 'AverageMillingTemperatureCelsius', value: 142.8 }, { idShort: 'PeakVibrationRMS', value: 0.45 }, { idShort: 'SurfaceRoughnessRaMicron', value: 0.38 }] } },
  'test_f_full_verify': { status: 200, body: { certificate: 'Aviation Quality Inspection Passed', workpieceId: 'HPTB-2026-0042', verifiedMetrics: { maxTemp: 142.8, rmsVibration: 0.45, surfaceRoughnessRa: 0.38 } } }
};

// -----------------------------------------------------------------------------
// Network Dispatcher (Direct / Proxy / Demo)
// -----------------------------------------------------------------------------
async function dispatchRequest(opts) {
  if (currentMode === 'demo') {
    await new Promise(r => setTimeout(r, 200));
    const mock = MOCK_DATA[opts.testId] || { status: 200, body: { demo: true } };
    return {
      status: mock.status,
      statusText: mock.status === 200 ? 'OK' : (mock.status === 401 ? 'Unauthorized' : 'Forbidden'),
      body: JSON.stringify(mock.body, null, 2),
      url: opts.url
    };
  }

  // Live Mode: Dispatch via /api/proxy
  try {
    const res = await fetch('/api/proxy', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        url: opts.url,
        method: opts.method || 'GET',
        headers: opts.headers || {},
        body: opts.body || null
      })
    });

    if (res.ok) {
      const data = await res.json();
      return {
        status: data.status,
        statusText: data.statusText,
        body: data.body,
        url: opts.url
      };
    }
  } catch (err) {
    console.warn('Proxy request failed, trying direct fetch:', err);
  }

  // Fallback direct browser fetch
  try {
    const res = await fetch(opts.url, {
      method: opts.method || 'GET',
      headers: opts.headers || {}
    });
    const text = await res.text();
    return {
      status: res.status,
      statusText: res.statusText,
      body: text,
      url: opts.url
    };
  } catch (e) {
    return {
      status: 0,
      statusText: 'Network Error',
      body: JSON.stringify({ error: 'Connection failed', detail: e.message }),
      url: opts.url
    };
  }
}

// -----------------------------------------------------------------------------
// Token Acquisition & Cache
// -----------------------------------------------------------------------------
async function getToken(actorKey) {
  if (tokenCache[actorKey]) return tokenCache[actorKey];
  const conf = CONFIG.actors[actorKey];
  if (!conf || !conf.realm) return null;

  if (currentMode === 'demo') {
    const mockJwt = generateMockJwt(actorKey);
    tokenCache[actorKey] = mockJwt;
    return mockJwt;
  }

  const tokenUrl = `${CONFIG.keycloakBase}/realms/${conf.realm}/protocol/openid-connect/token`;
  const bodyData = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: conf.client,
    client_secret: conf.secret
  });

  const res = await dispatchRequest({
    url: tokenUrl,
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: bodyData.toString()
  });

  try {
    const json = JSON.parse(res.body);
    if (json.access_token) {
      tokenCache[actorKey] = json.access_token;
      return json.access_token;
    }
  } catch (e) {}

  // Fallback demo mock if keycloak not reachable
  const fallback = generateMockJwt(actorKey);
  tokenCache[actorKey] = fallback;
  return fallback;
}

function generateMockJwt(actorKey) {
  const rolesMap = {
    'd': ['partner-d', 'admin'],
    'e': ['partner-e', 'customer-d', 'admin'],
    'f': ['partner-f', 'customer-e', 'admin']
  };
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT', kid: `${actorKey}-key-1` }));
  const payload = btoa(JSON.stringify({
    iss: `http://keycloak.localhost/realms/actor-${actorKey}`,
    sub: `service-account-actor-${actorKey}-client`,
    roles: rolesMap[actorKey] || ['user'],
    exp: Math.floor(Date.now() / 1000) + 3600,
    iat: Math.floor(Date.now() / 1000)
  }));
  return `${header}.${payload}.DEMO_SIGNATURE_MOCK`;
}

// -----------------------------------------------------------------------------
// Test Execution Engine
// -----------------------------------------------------------------------------
const TEST_DEFINITIONS = {
  'test_a_shells': {
    name: 'Akteur A Shells',
    url: `${CONFIG.actors.a.gw}/shells`,
    expected: 200,
    actor: 'a',
    target: 'result-test-a'
  },
  'test_a_tech': {
    name: 'Akteur A TechnicalData',
    url: `${CONFIG.actors.a.gw}/submodels/${CONFIG.submodels.aTech}`,
    expected: 200,
    actor: 'a',
    target: 'result-test-a'
  },
  'test_b_shells': {
    name: 'Akteur B Shells',
    url: `${CONFIG.actors.b.gw}/shells`,
    expected: 200,
    actor: 'b',
    target: 'result-test-b'
  },
  'test_b_tech': {
    name: 'Akteur B TechnicalData',
    url: `${CONFIG.actors.b.gw}/submodels/${CONFIG.submodels.bTech}`,
    expected: 200,
    actor: 'b',
    target: 'result-test-b'
  },
  'test_c_shells': {
    name: 'Akteur C Shells',
    url: `${CONFIG.actors.c.gw}/shells`,
    expected: 200,
    actor: 'c',
    target: 'result-test-c'
  },
  'test_c_tech': {
    name: 'Akteur C TechnicalData',
    url: `${CONFIG.actors.c.gw}/submodels/${CONFIG.submodels.cTech}`,
    expected: 200,
    actor: 'c',
    target: 'result-test-c'
  },
  'test_d_unauth': {
    name: 'Akteur D Simulation (Ohne Token)',
    url: `${CONFIG.actors.d.gw}/submodels/${CONFIG.submodels.dSim}`,
    expected: 401,
    actor: 'd',
    target: 'result-test-d-unauth'
  },
  'test_d_unauthorized_f': {
    name: 'Akteur D Simulation (Nicht-Kunde F)',
    url: `${CONFIG.actors.d.gw}/submodels/${CONFIG.submodels.dSim}`,
    expected: [401, 403],
    useToken: 'f',
    actor: 'd',
    target: 'result-test-d-unauthorized-f'
  },
  'test_d_auth_e': {
    name: 'Akteur D Simulation (Kunde E)',
    url: `${CONFIG.actors.d.gw}/submodels/${CONFIG.submodels.dSim}`,
    expected: 200,
    useToken: 'e',
    actor: 'd',
    target: 'result-test-d-auth-e'
  },
  'test_d_tech': {
    name: 'Akteur D Integrierte Daten (A, B, C)',
    url: `${CONFIG.actors.d.gw}/submodels/${CONFIG.submodels.dTech}`,
    expected: 200,
    useToken: 'e',
    actor: 'd',
    target: 'result-test-d-auth-e'
  },
  'test_e_nameplate_d': {
    name: 'Akteur E Nameplate (Partner D)',
    url: `${CONFIG.actors.e.gw}/submodels/${CONFIG.submodels.eNp}`,
    expected: 200,
    useToken: 'd',
    actor: 'd',
    target: 'result-test-e-nameplate-d'
  },
  'test_e_timeseries_d': {
    name: 'Akteur E TimeSeries (Partner D -> Blockiert)',
    url: `${CONFIG.actors.e.gw}/submodels/${CONFIG.submodels.eTs}`,
    expected: [401, 403],
    useToken: 'd',
    actor: 'd',
    target: 'result-test-e-timeseries-d'
  },
  'test_e_timeseries_f': {
    name: 'Akteur E TimeSeries (Kunde F -> Erlaubt)',
    url: `${CONFIG.actors.e.gw}/submodels/${CONFIG.submodels.eTs}`,
    expected: 200,
    useToken: 'f',
    actor: 'f',
    target: 'result-test-e-timeseries-f'
  },
  'test_f_full_verify': {
    name: 'Akteur F Qualitätsprüfung',
    url: `${CONFIG.actors.e.gw}/submodels/${CONFIG.submodels.eTs}`,
    expected: 200,
    useToken: 'f',
    actor: 'f',
    target: 'result-test-f-verify'
  }
};

async function runSingleTest(testId) {
  const def = TEST_DEFINITIONS[testId];
  if (!def) return;

  const targetEl = document.getElementById(def.target);
  if (targetEl) {
    targetEl.innerHTML = `<span class="status-badge running">⏳ Sende Anfrage...</span>`;
  }

  const headers = {};
  if (def.useToken) {
    const token = await getToken(def.useToken);
    if (token) headers['Authorization'] = `Bearer ${token}`;
  }

  const startTime = performance.now();
  const res = await dispatchRequest({
    testId: testId,
    url: def.url,
    method: 'GET',
    headers: headers
  });
  const duration = Math.round(performance.now() - startTime);

  let passed = false;
  if (Array.isArray(def.expected)) {
    passed = def.expected.includes(res.status);
  } else {
    passed = res.status === def.expected;
  }

  if (targetEl) {
    const badgeClass = passed ? 'badge-success' : 'badge-danger';
    const statusText = passed ? 'PASS' : 'FAIL';
    targetEl.innerHTML = `
      <div style="display:flex; align-items:center; gap:0.5rem;">
        <span class="badge ${badgeClass}">${statusText}: HTTP ${res.status}</span>
        <span style="color:var(--text-dim); font-size:0.75rem;">${duration}ms</span>
      </div>
      <button class="btn btn-sm btn-secondary" onclick="openModal('${def.name}', ${res.status}, '${def.url}', ${escapeHtml(JSON.stringify(res.body))})">Inspect JSON</button>
    `;
  }

  return { testId, passed, status: res.status, duration, body: res.body };
}

function escapeHtml(str) {
  return str.replace(/"/g, '&quot;');
}

// -----------------------------------------------------------------------------
// Automated Test Suite Runner (Tab 5)
// -----------------------------------------------------------------------------
const SUITE_TESTS = [
  { id: 'test_a_shells', label: 'Akteur A: /shells (Public)', target: 'http://actor-a.localhost/shells', expected: '200' },
  { id: 'test_a_tech',   label: 'Akteur A: TechnicalData (Public)', target: 'http://actor-a.localhost/submodels/...', expected: '200' },
  { id: 'test_b_shells', label: 'Akteur B: /shells (Public)', target: 'http://actor-b.localhost/shells', expected: '200' },
  { id: 'test_b_tech',   label: 'Akteur B: TechnicalData (Public)', target: 'http://actor-b.localhost/submodels/...', expected: '200' },
  { id: 'test_c_shells', label: 'Akteur C: /shells (Public)', target: 'http://actor-c.localhost/shells', expected: '200' },
  { id: 'test_c_tech',   label: 'Akteur C: TechnicalData (Public)', target: 'http://actor-c.localhost/submodels/...', expected: '200' },
  { id: 'test_d_unauth', label: 'Akteur D: Simulation ohne Token', target: 'http://actor-d.localhost/submodels/...', expected: '401' },
  { id: 'test_d_unauthorized_f', label: 'Akteur D: Simulation von Nicht-Kunde F', target: 'http://actor-d.localhost/submodels/...', expected: '401/403' },
  { id: 'test_d_auth_e', label: 'Akteur D: Simulation für Kunde E', target: 'http://actor-d.localhost/submodels/...', expected: '200' },
  { id: 'test_d_tech',   label: 'Akteur D: Integrierte Technische Daten', target: 'http://actor-d.localhost/submodels/...', expected: '200' },
  { id: 'test_e_nameplate_d', label: 'Akteur E: Nameplate für Partner D', target: 'http://actor-e.localhost/submodels/nameplate', expected: '200' },
  { id: 'test_e_timeseries_d', label: 'Akteur E: TimeSeries für Nicht-Kunde D', target: 'http://actor-e.localhost/submodels/timeseries', expected: '401/403' },
  { id: 'test_e_timeseries_f', label: 'Akteur E: TimeSeries für Kunde F', target: 'http://actor-e.localhost/submodels/timeseries', expected: '200' },
  { id: 'test_f_full_verify', label: 'Akteur F: Endkunden-Qualitätsabnahme', target: 'http://actor-e.localhost/submodels/timeseries', expected: '200' }
];

function initSuiteTable() {
  const tbody = document.getElementById('suite-table-body');
  if (!tbody) return;

  tbody.innerHTML = SUITE_TESTS.map((t, idx) => `
    <tr id="suite-row-${t.id}">
      <td>${idx + 1}</td>
      <td><strong>${t.label}</strong></td>
      <td><code>${t.target}</code></td>
      <td><span class="badge badge-info">${t.expected}</span></td>
      <td id="suite-status-${t.id}"><span class="status-badge pending">Bereit</span></td>
      <td id="suite-time-${t.id}">---</td>
      <td><button class="btn btn-sm btn-secondary" onclick="runSingleTest('${t.id}')">Testen</button></td>
    </tr>
  `).join('');
}

async function runAllTestSuite() {
  const progressBar = document.getElementById('suite-progress-bar');
  const progressText = document.getElementById('suite-progress-text');
  const progressCount = document.getElementById('suite-progress-count');
  const startBtn = document.getElementById('btn-suite-start');

  if (startBtn) startBtn.disabled = true;
  let passedCount = 0;

  for (let i = 0; i < SUITE_TESTS.length; i++) {
    const t = SUITE_TESTS[i];
    const statusCell = document.getElementById(`suite-status-${t.id}`);
    const timeCell = document.getElementById(`suite-time-${t.id}`);

    if (statusCell) statusCell.innerHTML = `<span class="status-badge running">Läuft...</span>`;
    if (progressText) progressText.innerText = `Führe aus: ${t.label}`;

    const res = await runSingleTest(t.id);
    if (res && res.passed) passedCount++;

    if (statusCell) {
      statusCell.innerHTML = res.passed 
        ? `<span class="status-badge pass">PASS (HTTP ${res.status})</span>`
        : `<span class="status-badge fail">FAIL (HTTP ${res.status})</span>`;
    }
    if (timeCell) timeCell.innerText = `${res.duration}ms`;

    const percent = Math.round(((i + 1) / SUITE_TESTS.length) * 100);
    if (progressBar) progressBar.style.width = `${percent}%`;
    if (progressCount) progressCount.innerText = `${i + 1} / ${SUITE_TESTS.length} Tests`;

    await new Promise(r => setTimeout(r, 100));
  }

  if (progressText) {
    progressText.innerText = `Fertig! ${passedCount} von ${SUITE_TESTS.length} Tests erfolgreich bestanden.`;
  }
  if (startBtn) startBtn.disabled = false;
}

// -----------------------------------------------------------------------------
// Token Inspection (Tab 6)
// -----------------------------------------------------------------------------
async function fetchTokenManual(actorKey) {
  const token = await getToken(actorKey.replace('actor-', ''));
  const rawEl = document.getElementById(`raw-jwt-${actorKey.replace('actor-', '')}`);
  const decodedEl = document.getElementById(`decoded-jwt-${actorKey.replace('actor-', '')}`);

  if (rawEl) rawEl.value = token;
  if (decodedEl) {
    try {
      const parts = token.split('.');
      const header = JSON.parse(atob(parts[0]));
      const payload = JSON.parse(atob(parts[1]));
      decodedEl.innerHTML = `<code>// Header\n${JSON.stringify(header, null, 2)}\n\n// Payload\n${JSON.stringify(payload, null, 2)}</code>`;
    } catch (e) {
      decodedEl.innerHTML = `<code>Fehler beim Dekodieren: ${e.message}</code>`;
    }
  }
}

function showTokenView(viewId) {
  document.querySelectorAll('.token-view-panel').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.token-subtab').forEach(b => b.classList.remove('active'));
  const el = document.getElementById(viewId);
  if (el) el.classList.add('active');
  event.target.classList.add('active');
}

// -----------------------------------------------------------------------------
// Health Check Pinger
// -----------------------------------------------------------------------------
async function checkAllHealth() {
  const nodes = [
    { id: 'node-keycloak', url: `${CONFIG.keycloakBase}/realms/BaSyx/.well-known/openid-configuration` },
    { id: 'node-actor-a',  url: `${CONFIG.actors.a.gw}/healthz` },
    { id: 'node-actor-b',  url: `${CONFIG.actors.b.gw}/healthz` },
    { id: 'node-actor-c',  url: `${CONFIG.actors.c.gw}/healthz` },
    { id: 'node-actor-d',  url: `${CONFIG.actors.d.gw}/healthz` },
    { id: 'node-actor-e',  url: `${CONFIG.actors.e.gw}/healthz` },
    { id: 'node-actor-f',  url: `${CONFIG.actors.f.gw}/healthz` }
  ];

  for (const n of nodes) {
    const el = document.getElementById(n.id);
    if (!el) continue;
    const dot = el.querySelector('.node-dot');

    if (currentMode === 'demo') {
      if (dot) { dot.className = 'node-dot up'; }
      continue;
    }

    try {
      const res = await dispatchRequest({ url: n.url, method: 'GET' });
      if (dot) {
        dot.className = (res.status === 200) ? 'node-dot up' : 'node-dot down';
      }
    } catch (e) {
      if (dot) dot.className = 'node-dot down';
    }
  }
}

// -----------------------------------------------------------------------------
// Tab Switching & Modal
// -----------------------------------------------------------------------------
function switchTab(tabId) {
  document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));

  const content = document.getElementById(tabId);
  if (content) content.classList.add('active');

  const btn = document.querySelector(`.tab-btn[data-tab="${tabId}"]`);
  if (btn) btn.classList.add('active');
}

function openModal(title, status, url, body) {
  const modal = document.getElementById('json-modal');
  document.getElementById('modal-title').innerText = title;
  document.getElementById('modal-status').innerText = `HTTP ${status}`;
  document.getElementById('modal-status').className = `badge ${status === 200 ? 'badge-success' : 'badge-danger'}`;
  document.getElementById('modal-url').innerText = url;

  let formatted = body;
  try {
    const parsed = typeof body === 'string' ? JSON.parse(body) : body;
    formatted = JSON.stringify(parsed, null, 2);
  } catch (e) {}

  document.getElementById('modal-body').innerHTML = `<code>${formatted}</code>`;
  modal.classList.add('active');
}

function closeModal() {
  document.getElementById('json-modal').classList.remove('active');
}

// -----------------------------------------------------------------------------
// Initial Setup
// -----------------------------------------------------------------------------
document.addEventListener('DOMContentLoaded', () => {
  // Tabs
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.getAttribute('data-tab')));
  });

  // Mode toggles
  document.getElementById('btn-mode-live').addEventListener('click', () => {
    currentMode = 'live';
    document.getElementById('btn-mode-live').classList.add('active');
    document.getElementById('btn-mode-demo').classList.remove('active');
    checkAllHealth();
  });

  document.getElementById('btn-mode-demo').addEventListener('click', () => {
    currentMode = 'demo';
    document.getElementById('btn-mode-demo').classList.add('active');
    document.getElementById('btn-mode-live').classList.remove('active');
    checkAllHealth();
  });

  // Action buttons
  document.getElementById('btn-run-all').addEventListener('click', () => {
    switchTab('tab-runner');
    runAllTestSuite();
  });

  document.getElementById('btn-ping-health').addEventListener('click', checkAllHealth);

  // Close modal on click outside
  document.getElementById('json-modal').addEventListener('click', (e) => {
    if (e.target.id === 'json-modal') closeModal();
  });

  // Pre-fetch tokens for inspector
  fetchTokenManual('actor-e');
  fetchTokenManual('actor-f');
  fetchTokenManual('actor-d');

  initSuiteTable();
  checkAllHealth();
});
