# MX-Port Leo & BaSyx Dynamic RBAC – End-to-End Dataspace Architecture

Dieses Repository stellt eine produktionsnahe, containerisierte Referenzarchitektur für den **Factory-X Dataspace** bereit. Es kombiniert den **MX-Port Leo Security Token Service (STS)**, **API-Gateways (OpenResty)**, den **Company Lookup Service** sowie eine **BaSyx Asset Administration Shell (AAS) Umgebung mit Dynamic Role-Based Access Control (RBAC)** und **BaSyx Web UI**.

---

## Inhaltsverzeichnis

- [Architektur-Überblick](#architektur-überblick)
- [Service- & Port-Matrix](#service---port-matrix)
- [Demo-Accounts, Credentials & API-Keys](#demo-accounts-credentials--api-keys)
- [Company Lookup & Pre-seeded Companies](#company-lookup--pre-seeded-companies)
- [BaSyx AAS Web UI](#basyx-aas-web-ui)
- [Quick-Start](#quick-start)
- [Automatisierte Verifikation (Test-Suite)](#automatisierte-verifikation-test-suite)
- [Postman End-to-End Walkthrough](#postman-end-to-end-walkthrough)
- [Repository- & Verzeichnisstruktur](#repository---verzeichnisstruktur)

---

## Architektur-Überblick

Das Gesamtszenario deckt den vollständigen Lebenszyklus von Service Discovery, Multi-Hop-Authentifizierung, Token-Transformationen bis hin zur dynamischen Autorisierung auf AAS-Ebene ab:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 0. Service Discovery                                                                   │
│ Client / Consumer Gateway ──[GET /companies?name=...]──▶ Company Lookup Service (50102)│
└────────────────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 1-4. Token Pipeline & Multi-Hop Gateway                                                │
│                                                                                        │
│ [Client / Consumer]                                                                    │
│         │                                                                              │
│         ▼ 1. Hole Consumer Token (🟠)                                                   │
│   Keycloak IdP (8080)                                                                  │
│         │                                                                              │
│         ▼ 2. Proxy-Aufruf mit Consumer Token (🟠)                                      │
│   Consumer Gateway (8081)                                                              │
│         │                                                                              │
│         ▼ 3. Token-Exchange (RFC 8693)                                                 │
│   Consumer STS (9050) ───▶ Erzeugt Factory-X Token (🔵)                                │
│         │                                                                              │
│         ▼ 4. Weiterleitung über fx-net (🔵)                                            │
│   Provider Gateway (8082)                                                              │
│         │                                                                              │
│         ▼ 5. Token-Exchange (RFC 8693)                                                 │
│   Provider STS (9051) ───▶ Erzeugt Provider Token mit Rollen (🟣)                      │
│         │                                                                              │
│         ▼ 6. Autorisierter Zugriff mit Provider Token (🟣)                             │
│   Provider AAS Environment (8083) ◀──[BaSyx Web UI (3000)]                             │
│         ▲                                                                              │
│         │ 7. Dynamic RBAC Policy Enforcement                                           │
│   Security Submodel Repo (8086) ◀──[Keycloak RBAC (8085)]                              │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Token-Hierarchie

| Token | Farbe | Aussteller (Issuer) | Audience | Enthaltene Claims |
|-------|-------|--------------------|----------|-------------------|
| **Consumer Token** | 🟠 Orange | `http://localhost:8080/realms/mxport` | `account`, `mxport-client` | `scope: data-consumer`, `preferred_username: testuser` |
| **Factory-X Token** | 🔵 Blau | `http://consumer-sts:9050/sts` | Factory-X Dataspace Partners | `environment: consumer`, `token-format: JWT` |
| **Provider Token** | 🟣 Violett | `http://provider-sts:9050/sts` | `provider-aas` | `realm_access.roles: ["admin"]`, `sub: testuser` |

---

## Service- & Port-Matrix

Alle 12 Microservices laufen isoliert in Docker-Containern und sind über Compose v2 (`compose/*.yml`) modular organisiert:

| Service | Host-Port | Interner Port | Protokoll | Docker-Netzwerk | Funktion |
|---------|-----------|---------------|-----------|-----------------|----------|
| `keycloak` | **8080** | 8080 | HTTP | `consumer-net` | Consumer Identity Provider (User Login & Token Minting) |
| `consumer-gateway` | **8081** | 80 | HTTP | `consumer-net`, `fx-net` | OpenResty Reverse-Proxy (tauscht Token 🟠 ➔ 🔵) |
| `provider-gateway` | **8082** | 80 | HTTP | `provider-net`, `fx-net` | OpenResty Reverse-Proxy (tauscht Token 🔵 ➔ 🟣) |
| `provider-aas` | **8083** | 8081 | HTTP | `provider-net` | BaSyx AAS Environment (mit Dynamic RBAC Feature) |
| `keycloak-rbac` | **8085** | 8080 | HTTP | `provider-net` | BaSyx RBAC IdP (Verwaltung von AAS-Rollen & Rechten) |
| `security-submodel`| **8086** | 8081 | HTTP | `provider-net` | BaSyx Submodel Repository für dynamische Zugriffspolicies |
| `consumer-sts` | **9050** | 9050 | HTTP | `consumer-net` | Security Token Service für Consumer (RFC 8693) |
| `provider-sts` | **9051** | 9050 | HTTP | `provider-net` | Security Token Service für Provider (RFC 8693) |
| `company-lookup` | **50102** | 50102 | HTTP | `consumer-net` | AAS Discovery Service (FastAPI / OpenAPI v2) |
| `company-lookup-db`| **5432** | 5432 | TCP | `consumer-net` | PostgreSQL 16 Datenbank für Company Lookup |
| `basyx-mongo` | **27017** | 27017 | TCP | `provider-net` | MongoDB Backend für AAS & Submodel Speicherung |
| `aas-web-ui` | **3000** | 3000 | HTTP | `provider-net` | BaSyx AAS Web GUI zur interaktiven Verwaltung |

---

## Demo-Accounts, Credentials & API-Keys

### 1. Consumer Keycloak (Port 8080)
- **Admin-Konsole:** [http://localhost:8080/admin](http://localhost:8080/admin)
- **Admin-Zugangsdaten:** `admin` / `password`
- **Realm:** `mxport`
- **Client ID:** `mxport-client` (Public Client, Direct Access Grants enabled)
- **Benutzer-Account:**
  - Benutzername: `testuser`
  - Passwort: `testpass`
  - Zugewiesene Rollen / Scopes: `data-consumer`

### 2. Provider Keycloak RBAC (Port 8085)
- **Admin-Konsole:** [http://localhost:8085/admin](http://localhost:8085/admin)
- **Admin-Zugangsdaten:** `admin` / `admin`
- **Realm:** `BaSyx`
- **Clients:**
  - `workstation-1` (Confidential Client für M2M-Token-Erstellung)
    - Client Secret: `nY0mjyECF60DGzNmQUjL81XurSl8etom`
    - Grant Type: `client_credentials`
  - `basyx-web-ui` (Public Client für AAS-Web-Oberfläche)
- **Vorkonfigurierte Benutzer:**
  | Benutzername | Passwort | Zugewiesene Realm-Rollen | Beschreibung |
  |--------------|----------|--------------------------|--------------|
  | `john.doe` | `johndoe` | `admin`, `maintainer` | Vollzugriff auf alle AAS und Security Submodels |
  | `alice` | `alice` | `analyst` | Lesezugriff auf Analytics-Submodels |
  | `bob` | `bob` | `operator` | Operative Steuerung & Statusabfragen |
  | `dave` | `dave` | `guest` | Eingeschränkter Gastzugriff |

### 3. Security Token Services (STS)
- **Consumer STS (Port 9050):**
  - Token-Exchange-Endpunkt: `http://localhost:9050/sts/token`
  - Private Signing Key: `consumer/sts/signingkey/private_key.pem`
  - API Key: `consumer-sts-key`
- **Provider STS (Port 9051):**
  - Token-Exchange-Endpunkt: `http://localhost:9051/sts/token`
  - Private Signing Key: `provider/sts/signingkey/private_key.pem`
  - API Key: `provider-sts-key`

### 4. Company Lookup Service (Port 50102)
- **Basis-URL:** `http://localhost:50102/api/v2`
- **OpenAPI Dokumentation:** [http://localhost:50102/api/v2/openapi.json](http://localhost:50102/api/v2/openapi.json)
- **Admin API Key:** `admin-secret-key` (Authorization: `Bearer admin-secret-key`)
- **PostgreSQL Datenbank:**
  - Host: `company-lookup-db` (Port `5432`)
  - DB Name: `company_lookup`
  - Benutzer: `lookup_user` / Passwort: `lookup_pass`

---

## Company Lookup & Pre-seeded Companies

Beim Start des `company-lookup`-Containers werden automatisch Datenbankmigrationen (`alembic upgrade head`) und Initial-Daten (`scripts/import_descriptors`) ausgeführt. Folgende Unternehmen sind unter anderem vorinstalliert:

| Unternehmensname | Domäne | Base64URL Domänen-ID (Key) | Registrierte Schnittstellen |
|------------------|--------|----------------------------|-----------------------------|
| **Factory-X** | `factory-x.org` | `ZmFjdG9yeS14Lm9yZw` | `AAS-REPOSITORY-3.1`, `SUBMODEL-REPOSITORY-3.1` |
| **Siemens AG** | `siemens.com` | `c2llbWVucy5jb20` | `AAS-REGISTRY-3.1` |
| **Festo SE & Co. KG** | `festo.com` | `ZmVzdG8uY29t` | `AAS-REGISTRY-3.1` |
| **IDTA** | `admin-shell-io.com` | `YWRtaW4tc2hlbGwtaW8uY29t` | `AAS-REPOSITORY-3.1` |
| **Balluff** | `balluff.com` | `YmFsbHVmZi5jb20` | `AAS-REGISTRY-3.1` |
| **Bosch Rexroth** | `boschrexroth.com` | `Ym9zY2hyZXhyb3RoLmNvbQ` | `AAS-REPOSITORY-3.1` |
| **Phoenix Contact** | `phoenixcontact.com` | `cGhvZW5peGNvbnRhY3QuY29t` | `AAS-REGISTRY-3.1` |
| **SAP** | `sap.com` | `c2FwLmNvbQ` | `AAS-REGISTRY-3.1` |
| **Trumpf** | `trumpf.com` | `dHJ1bXBmLmNvbQ` | `AAS-REPOSITORY-3.1` |
| **Schneider Electric** | `se.com` | `c2UuY29t` | `AAS-REGISTRY-3.1` |
| **WAGO** | `wago.com` | `d2Fnby5jb20` | `AAS-REGISTRY-3.1` |

> **Hinweis zur Kodierung:** 
> Bei REST-Abfragen verlangt der Company Lookup Service **Base64URL ohne Padding (`=`)**.
> - Suchabfrage nach Name: `GET /api/v2/companies?name=RmFjdG9yeS1Y` (`RmFjdG9yeS1Y` = Factory-X)
> - Abfrage per Domäne: `GET /api/v2/companies/ZmFjdG9yeS14Lm9yZw` (`ZmFjdG9yeS14Lm9yZw` = factory-x.org)

---

## BaSyx AAS Web UI

Die offizielle BaSyx Web UI steht unter **[http://localhost:3000](http://localhost:3000)** zur Verfügung.

### Vorkonfigurierte Endpunkte in der UI
- **AAS Repository:** `http://localhost:8083/shells`
- **Submodel Repository:** `http://localhost:8083/submodels`
- **Concept Description Repository:** `http://localhost:8083/concept-descriptions`
- **Security Submodel Repository:** `http://localhost:8086/submodels`

### Funktionen in der Oberfläche
1. **Shell-Inspektion:** Visualisierung der AAS-Struktur (inkl. `FrameAAS` mit ID `https://example.com/ids/sm/5255_5191_9042_8127`).
2. **Submodel-Browser:** Durchsuchen aller Submodels, Eigenschaften (Properties) und Collections.
3. **Endpoint-Umschaltung:** In den UI-Einstellungen können Repositories beliebig hinzugefügt oder auf das `security-submodel` umgestellt werden, um Zugriffskontrollregeln grafisch einzusehen.

---

## Quick-Start

### 1. Umgebung initialisieren (Setup-Skript)
Führe das zentrale Setup-Skript aus. Es klont automatisch alle benötigten Upstream-Repositories in den Ordner `repos/` (ohne dass diese in deinem eigenen Git-Repository versioniert werden), generiert bei Bedarf die RSA-Signing-Keys für Consumer- und Provider-STS und legt die `.env` aus `.env.example` an:

**Unter macOS, Linux, WSL2 oder Git Bash:**
```bash
./setup.sh
```

**Unter Windows (native PowerShell):**
```powershell
.\setup.ps1
```

### 2. Docker Compose starten
```bash
docker compose up -d
```
Überprüfe mit `docker compose ps`, dass alle 12 Container aktiv und gesund (`healthy`) sind.

### 3. Gesamte Pipeline verifizieren
- **In Bash (macOS, Linux, WSL2, Git Bash):**
  ```bash
  ./tests/verify_token_pipeline.sh
  ```
- **Plattformunabhängig mit Postman:**
  Importiere die Collection `postman/MXPort_BaSyx_E2E.postman_collection.json` und das Environment `postman/MXPort_BaSyx_Environment.postman_environment.json` und führe den Collection Runner aus.

---

## Automatisierte Verifikation (Test-Suite)

Das Repository enthält eine automatisierte Laufzeit-Testsuite, die **alle 26 Schritte** der Pipeline (Token Minting, RFC 8693 STS Token Exchange, Negativtests, Gateway-Hops und Dynamic RBAC Lifecycle) eigenständig validiert:

```bash
./tests/verify_token_pipeline.sh
```

### Ausgeführte Validierungsschritte:
- **Consumer Token Minting:** Validierung von HTTP 200, Issuer-Claim, Scope `data-consumer` und Subject-Claim.
- **Negativtest IdP:** Falsche Credentials werden mit HTTP 401 abgewiesen.
- **Consumer STS Exchange:** Erhalt des Factory-X-Tokens mit korrekten Claims.
- **Negativtest STS:** Gefälschte Tokens werden mit HTTP 400 abgelehnt.
- **Provider STS Exchange:** Erhalt des Provider-Tokens mit Audience `provider-aas` und Rolle `admin`.
- **Negativtests AAS & Gateways:** Unauthentifizierte Anfragen oder unvertauschte Tokens werden mit HTTP 401/403 blockiert.
- **Gateway Multi-Hop:** Weiterleitung von Consumer Gateway an Provider Gateway.
- **BaSyx Dynamic RBAC:**
  1. Anfrage vor Regelinjektion: **HTTP 403 Forbidden**
  2. Injektion der dynamic Access Rule für Rolle `admin` in das Security Submodel: **HTTP 201 Created**
  3. Anfrage nach Regelinjektion: **HTTP 200 OK** mit AAS-Payload
  4. Löschen der Regel im Security Submodel: **HTTP 204 No Content**
  5. Anfrage nach Löschung: Sofortige Sperre (**HTTP 403 Forbidden**)

---

## Postman End-to-End Walkthrough

Im Ordner `postman/` befinden sich die exportierte Collection und das dazugehörige Environment:
- **Collection:** `postman/MXPort_BaSyx_E2E.postman_collection.json`
- **Environment:** `postman/MXPort_BaSyx_Environment.postman_environment.json`

### Import in Postman
1. Öffne Postman und wähle **Import**.
2. Wähle beide Dateien aus `postman/` aus.
3. Wähle rechts oben das Environment **MXPort BaSyx Environment** aus.

### Struktur der Test-Pipeline in Postman

#### Ordner `01 - Company Lookup & Service Discovery`
1. **1.1 List All Seeded Companies:** `GET {{company_lookup_url}}/companies?limit=10`
2. **1.2 Search Company by Name:** `GET {{company_lookup_url}}/companies?name={{sample_company_name_b64}}`
3. **1.3 Get Company by Domain:** `GET {{company_lookup_url}}/companies/{{sample_company_domain_b64}}`
4. **1.4 Register Demo Company Endpoint:** `POST {{company_lookup_url}}/companies` mit Bearer API-Key
5. **1.5 Verify Registered Demo Company:** `GET {{company_lookup_url}}/companies/{{demo_company_domain_b64}}`
6. **1.6 Cleanup / Delete Demo Company:** `DELETE {{company_lookup_url}}/companies/{{demo_company_domain_b64}}`

#### Ordner `02 - Consumer Identity & STS Token Exchange`
1. **2.1 Consumer IdP - Mint Consumer Token:** Mintet Token 🟠 mit `testuser` / `testpass`
2. **2.2 Negative Test - Invalid Credentials:** Erwartet HTTP 401 bei falschem Passwort
3. **2.3 Consumer STS - Exchange to Factory-X Token:** Tauscht 🟠 gegen 🔵
4. **2.4 Negative Test - Forged Token:** Erwartet HTTP 400 bei unautorisiertem Token

#### Ordner `03 - Provider STS Token Exchange & Security Validation`
1. **3.1 Provider STS - Exchange to Provider Token:** Tauscht 🔵 gegen 🟣 (Rolle `admin`)
2. **3.2 - 3.5 Security Validations:** Prüft Abweisung bei fehlendem oder falschem Token

#### Ordner `04 - Gateway Hop & Dynamic RBAC`
1. **4.1 Gateway End-to-End Hop:** Consumer Gateway ➔ Provider Gateway Healthcheck
2. **4.2 Dynamic RBAC - Call AAS (Pre-Rule):** Erwartet HTTP 403 Forbidden
3. **4.3 Keycloak RBAC - Get Admin Token:** Holt M2M Token für Policy Management
4. **4.4 Security Submodel - Inject Dynamic Rule:** Legt Zugriffsregel für Rolle `admin` an
5. **4.5 Dynamic RBAC - Call AAS (Post-Rule):** Erwartet HTTP 200 OK mit `FrameAAS`
6. **4.6 Security Submodel - Revoke Rule:** Entfernt Zugriffsregel
7. **4.7 Dynamic RBAC - Call AAS (Post-Revocation):** Erwartet wieder HTTP 403 Forbidden

> **Tipp:** Der Collection Runner in Postman kann den gesamten Durchlauf mit einem Klick ausführen ("Run Collection"). Alle Token und IDs werden automatisch zwischen den Schritten übergeben.

---

## Repository- & Verzeichnisstruktur

Das Repository hält strikt das Prinzip der **Immutable Repositories** ein (Quellcode in `repos/` bleibt unberührt):

```
mxport-env/
├── docker-compose.yml              ← Haupt-Compose-Datei (nutzt Compose include)
├── setup.sh                        ← Setup-Skript für macOS, Linux, WSL2 & Git Bash
├── setup.ps1                       ← Setup-Skript für Windows PowerShell (nativ)
├── .gitattributes                  ← LF-Zeilenenden-Erzwingung für Linux/Container
├── .env.example                    ← Vorlage aller Umgebungsvariablen
├── .env                            ← Aktive lokale Konfiguration
│
├── compose/                        ← Modularisierte Docker Compose Definitionen
│   ├── infrastructure.yml          ← Keycloak, Postgres, Company Lookup, Mongo
│   ├── consumer.yml                ← Consumer STS & Consumer Gateway
│   └── provider.yml                ← Provider STS, Gateway, BaSyx AAS, RBAC, Web UI
│
├── repos/                          ← Unveränderte Sub-Repositories (Immutable)
│   ├── mxport-leo-token-exchange   ← STS Core Library
│   ├── mxport-leo-gateway          ← OpenResty Gateways & STS-Lua-Plugins
│   ├── mxport-leo-company-lookup   ← AAS Discovery Service
│   └── basyx-java-server-sdk       ← BaSyx Java Server SDK & RBAC Examples
│
├── consumer/                       ← Consumer-spezifische Konfigurationen
│   ├── sts/                        ← Server- & Filter-Konfigurationen
│   └── gateway/                    ← OpenResty Nginx-Routing
│
├── provider/                       ← Provider-spezifische Konfigurationen
│   ├── sts/                        ← Server- & Filter-Konfigurationen
│   ├── gateway/                    ← OpenResty Nginx-Routing
│   └── basyx/                      ← MongoDB Context & RBAC Initialisierungsdaten
│
├── postman/                        ← Postman E2E Test-Sammlung & Environment
│   ├── MXPort_BaSyx_E2E.postman_collection.json
│   └── MXPort_BaSyx_Environment.postman_environment.json
│
└── tests/                          ← Automatisierte Test-Skripte
    └── verify_token_pipeline.sh    ← 26-Punkte Verifikationsskript
```
