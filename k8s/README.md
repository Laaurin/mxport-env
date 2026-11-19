# 6-Akteure Datenraum in k3d (Kubernetes) — Dokumentation & Betriebshandbuch

Dieses Verzeichnis enthält die Kubernetes-Implementierung (`k3d` + `Helm`) des **6-Akteure Datenraums** mit dynamischem Discovery über den **Factory-X Company Lookup Service**, **RFC 8693 Token-Exchange (MX-Port Leo STS)**, **Eclipse BaSyx AAS V3.0 Repositories & Security Submodels** sowie den offiziellen **BaSyx AAS Web UIs**.

---

## 1. Schnellhilfe: Cluster starten, stoppen & neu aufbauen

### Fall A: Docker / PC wurde neu gestartet (alle Container sind gestoppt)
Wenn der `k3d`-Cluster `dataspace` bereits angelegt wurde, nach einem Neustart von Docker Desktop oder des PCs aber alle Container heruntergefahren sind (oder `Error: Kubernetes cluster unreachable` erscheint):

```powershell
# 1. Gestoppte k3d-Container wieder starten
k3d cluster start dataspace

# 2. Kubeconfig-Port und Context aktualisieren
k3d kubeconfig merge dataspace --kubeconfig-switch-context

# 3. Prüfen, ob die Pods wieder anlaufen (dauert nach dem Start ca. 30-60 Sekunden)
kubectl get pods -n dataspace
```

---

### Fall B: Cluster existiert nicht (oder soll komplett frisch aufgebaut werden)

#### Variante 1: Über die Start-Skripte
* **Windows (PowerShell)**:
  ```powershell
  # Optional, falls bestehenden Cluster vorher löschen:
  .\k8s\scripts\cluster-down.ps1

  # Cluster erstellen, Images bauen/importieren & alle Charts ausrollen:
  .\k8s\scripts\cluster-up.ps1
  ```
* **macOS / Linux (Bash)**:
  ```bash
  # Optional, falls bestehenden Cluster vorher löschen:
  ./k8s/scripts/cluster-down.sh

  # Cluster erstellen, Images bauen/importieren & alle Charts ausrollen:
  ./k8s/scripts/cluster-up.sh
  ```

#### Variante 2: Manuell Schritt für Schritt (ohne `.ps1` / `.sh` Skripte)
Falls unter Windows die PowerShell `ExecutionPolicy` das Ausführen von `.ps1`-Skripten verhindert, können die Befehle direkt im Projekt-Hauptverzeichnis `mxport-env` ausgeführt werden:

```powershell
# 1. Optional: Altes Cluster löschen (falls vorhanden)
k3d cluster delete dataspace

# 2. Neues k3d-Cluster erstellen
k3d cluster create --config k8s/cluster/k3d-config.yaml

# 3. Lokale Docker-Images bauen (nur nötig, falls noch nicht lokal im Docker-Cache vorhanden)
docker build -t mxport-leo-gateway:local -f provider/gateway/Dockerfile provider/gateway
docker build -t mxport-leo-sts:local repos/mxport-leo-token-exchange
docker build -t mxport-leo-company-lookup:local repos/mxport-leo-company-lookup
docker pull postgres:16-alpine

# 4. Lokale Images in das k3d-Cluster importieren
k3d image import mxport-leo-gateway:local -c dataspace
k3d image import mxport-leo-sts:local -c dataspace
k3d image import mxport-leo-company-lookup:local -c dataspace
k3d image import postgres:16-alpine -c dataspace

# 5. Namespace, Keycloak-Realms & zentrale Infrastruktur (Keycloak, MongoDB, Company Lookup) installieren
kubectl create namespace dataspace
kubectl create configmap keycloak-realms --from-file=k8s/infra/keycloak/realms -n dataspace
helm upgrade --install infra k8s/helm/dataspace-infra -n dataspace

# 6. Alle 6 Akteure (A bis F) per Helm installieren
helm upgrade --install actor-a k8s/helm/dataspace-actor -f k8s/values/actor-a.yaml -n dataspace
helm upgrade --install actor-b k8s/helm/dataspace-actor -f k8s/values/actor-b.yaml -n dataspace
helm upgrade --install actor-c k8s/helm/dataspace-actor -f k8s/values/actor-c.yaml -n dataspace
helm upgrade --install actor-d k8s/helm/dataspace-actor -f k8s/values/actor-d.yaml -n dataspace
helm upgrade --install actor-e k8s/helm/dataspace-actor -f k8s/values/actor-e.yaml -n dataspace
helm upgrade --install actor-f k8s/helm/dataspace-actor -f k8s/values/actor-f.yaml -n dataspace

# 7. Status prüfen
kubectl get pods -n dataspace
```

---

### Fall C: Änderungen an Helm-Charts oder Modellen im laufenden Cluster aktualisieren
Wenn du eine Konfigurationsdatei oder ein eigenes AAS-Modell unter `k8s/helm/dataspace-actor/files/custom-models/` geändert hast:

* **Alle Akteure & Infrastruktur aktualisieren**:
  * macOS / Linux: `./k8s/scripts/deploy-all.sh`
  * Windows: `.\k8s\scripts\deploy-all.ps1`
* **Nur einen einzelnen Akteur aktualisieren (z. B. Actor E)**:
  ```powershell
  helm upgrade --install actor-e k8s/helm/dataspace-actor -f k8s/values/actor-e.yaml -n dataspace
  ```

---

## 2. Architektur & Szenario-Überblick

Im Datenraum agieren 6 Akteure entlang einer industriellen Liefer- und Fertigungskette. Kein Akteur hat die Repository-URLs anderer Akteure hartcodiert – die Auflösung erfolgt immer dynamisch anhand der Asset-/Shell-/Submodel-URN über den **Company Lookup Service** (`lookup.localhost`).

```text
+-----------------+ +-----------------+ +-----------------+
|    Akteur A     | |    Akteur B     | |    Akteur C     |
|  (Servo Motor)  | |   (Getriebe)    | |    (Sensor)     |
|                 | |                 | |                 |
| Public AAS Repo | | Public AAS Repo | | Public AAS Repo |
+--------+--------+ +--------+--------+ +--------+--------+
         |                   |                   |
         +-------------+-----+-------------------+
                       | Oeffentlicher Komponentenvergleich via Lookup
                       v
            +---------------------+
            |      Akteur D       |
            |  (Maschinenbauer)   |
            |                     |
            | - MachineTypeAAS    |
            | - Simulation SM     | <--- Geschuetzt (Keycloak + Leo STS + BaSyx SecSM)
            +----------+----------+      Nur fuer Kunden mit Rolle 'customer-d' (Akteur E)
                       |
                       | Kauf der Maschine & Zugriff auf SimulationModel
                       v
            +---------------------+
            |      Akteur E       |
            | (Bauteilfertigung)  |
            |                     |
            | - Nameplate SM      | <--- Fuer alle authentifizierten Partner sichtbar
            | - TimeSeries SM     | <--- Geschuetzt (Keycloak + Leo STS + BaSyx SecSM)
            +----------+----------+      Nur fuer Kunden mit Rolle 'customer-e' (Akteur F)
                       |
                       | Kauf des gefertigten Bauteils
                       v
            +---------------------+
            |      Akteur F       |
            |     (Endkunde)      |
            |                     |
            | Zugriff auf         |
            | TimeSeries SM von E |
            +---------------------+
```

### Die 6 Akteure im Detail

| Akteur | Rolle & Kontext | Standard-AAS & Teilmodelle | Zugriffssteuerung & Rollen |
|---|---|---|---|
| **Actor A** | Servomotor-Zulieferer | `ServoMotorAAS` (`urn:dataspace:a:aas:servo-motor-001`)<br>- `Nameplate`<br>- `TechnicalData` (15 kW, IE4) | **Öffentlich** (kein Token erforderlich) |
| **Actor B** | Getriebe-Zulieferer | `IndustrialGearboxAAS` (`urn:dataspace:b:aas:gearbox-001`)<br>- `Nameplate`<br>- `TechnicalData` (10:1, 450 Nm) | **Öffentlich** (kein Token erforderlich) |
| **Actor C** | Sensor-Zulieferer | `VibrationSensorAAS` (`urn:dataspace:c:aas:sensor-001`)<br>- `Nameplate`<br>- `TechnicalData` (25.6 kHz, IO-Link) | **Öffentlich** (kein Token erforderlich) |
| **Actor D** | Maschinenbauer (OEM) | `MillingMachineTypeAAS` (`urn:dataspace:d:aas:machine-type-001`)<br>- `Nameplate`<br>- `TechnicalData` (Referenzen auf A, B, C)<br>- `SimulationModel` | **Keycloak + STS + BaSyx Security SM**<br>- Eigene Rolle: `partner-d`<br>- `SimulationModel` erfordert `customer-d` |
| **Actor E** | Bauteilfertiger (Kunde von D) | `TurbineBladeProductAAS` (`urn:dataspace:e:aas:produced-part-001`)<br>- `Nameplate` (Referenz auf Maschine D)<br>- `TimeSeries` (Prozessdaten) | **Keycloak + STS + BaSyx Security SM**<br>- Eigene Rollen: `customer-d`, `partner-e`<br>- `Nameplate`: lesbar für Partner (`partner-d`, `customer-e`)<br>- `TimeSeries`: erfordert `customer-e` |
| **Actor F** | Endkunde (Kunde von E) | `CustomerAeroEngineOEM` (`urn:dataspace:f:aas:customer-profile-001`)<br>- `Nameplate` (Kaufreferenz auf Bauteil E) | **Keycloak-Identität**<br>- Eigene Rollen: `customer-e`, `partner-f`<br>- Erhält Vollzugriff auf `TimeSeries` von E |

---

## 3. Endpunkte im Cluster (Traefik Ingress auf Port 80)

| Dienst / Akteur | Gateway / API-URL | Offizieller BaSyx AAS Viewer | Lookup Asset-ID Regex |
|---|---|---|---|
| **Company Lookup** | `http://lookup.localhost/api/v2/companies` | - | - |
| **Keycloak IdP** | `http://keycloak.localhost` | - | - |
| **Actor A** | `http://actor-a.localhost/shells` | `http://viewer-a.localhost` | `^urn:dataspace:a:` |
| **Actor B** | `http://actor-b.localhost/shells` | `http://viewer-b.localhost` | `^urn:dataspace:b:` |
| **Actor C** | `http://actor-c.localhost/shells` | `http://viewer-c.localhost` | `^urn:dataspace:c:` |
| **Actor D** | `http://actor-d.localhost/shells` | `http://viewer-d.localhost` | `^urn:dataspace:d:` |
| **Actor E** | `http://actor-e.localhost/shells` | `http://viewer-e.localhost` | `^urn:dataspace:e:` |
| **Actor F** | `http://actor-f.localhost/shells` | `http://viewer-f.localhost` | `^urn:dataspace:f:` |

### Hinweis zu `*.localhost` unter Windows
Browser (Chrome, Edge, Firefox) und der Vite-Proxy der Workbench lösen `*.localhost` automatisch auf `127.0.0.1` auf. Damit auch Windows-CLI-Tools oder die Postman-Desktop-App unter Windows alle `*.localhost`-Domains direkt auflösen, kann einmalig in einer **Administrator-PowerShell** das Skript ausgeführt werden:
```powershell
.\k8s\scripts\setup-hosts.ps1
```

---

## 4. Eigene AAS-Shells & Submodels einbinden (Git-ignoriert mit Fallback)

Du kannst die bestehenden Demo-Shells auf zwei Wegen durch eigene Modelle ersetzen oder ergänzen:

### Weg 1: Dauerhaft über Dateien (`k8s/helm/dataspace-actor/files/custom-models/`)
1. Lege im Ordner `k8s/helm/dataspace-actor/files/custom-models/` eine JSON-Datei mit dem Namen des Akteurs an (z. B. `actor-e.json` oder `actor-a.json`).
2. Das Format entspricht dem offiziellen IDTA / Eclipse BaSyx V3.0 AAS-Environment-Standard:
   ```json
   {
     "assetAdministrationShells": [ ... ],
     "submodels": [ ... ],
     "conceptDescriptions": [ ... ]
   }
   ```
3. Alle `*.json`- und `*.aasx`-Dateien in `custom-models/` werden von **Git ignoriert** (`.gitignore`).
4. Beim Ausführen von `deploy-all` (bzw. `helm upgrade --install actor-e ...`) lädt Helm automatisch deine Datei aus `custom-models/`. Löschst du die Datei wieder aus `custom-models/`, greift automatisch der **Fallback** auf die Standard-Demo-Datei unter `k8s/helm/dataspace-actor/files/models/<actor>.json`.

### Weg 2: Zur Laufzeit über die Workbench (`Verwaltung`)
Oben rechts in der Workbench (`http://localhost:5173`) öffnet der Button **`Verwaltung`** drei Werkzeuge:
1. **Zugriffsrechte (`Actor D` / `Actor E`)**: Steuert live in der MongoDB des **BaSyx Security Submodels** (`/secsm/submodel-elements`), welche Rolle (`customer-e`, `partner-d`, `customer-d`, `partner-f` usw.) Lesezugriff auf welches Teilmodell hat – inklusive 1-Klick-Reset auf die Standard-Berechtigungen.
2. **Shells & Submodels**: Importiert eigene AAS/Submodel-JSONs zur Laufzeit direkt in das `InMemory`-Repository des gewählten Akteurs und erlaubt das gezielte Löschen einzelner Shells und Submodels.
3. **Akteure verwalten**: Registriert zusätzliche Akteure persistent in der PostgreSQL-Datenbank des Company Lookup Service und erlaubt deren vollständiges Löschen.

---

## 5. Vue Workbench & E2E-Tests starten

### 1. Vue Dataspace Workbench starten (`http://localhost:5173`)
* **macOS / Linux**:
  ```bash
  ./k8s/scripts/workbench.sh
  ```
* **Windows (PowerShell)**:
  ```powershell
  .\k8s\scripts\workbench.ps1
  ```
* **Oder direkt manuell**:
  ```bash
  cd workbench
  npm install
  npm run dev
  ```

### 2. Automatisierte E2E-Testsuite (CLI)
Prüft alle 6 Akteure, den Company Lookup, den STS-Token-Tausch sowie alle Positiv- und Negativ-Zugriffstests (`200 OK`, `401 Unauthorized`, `403 Forbidden`):
* **macOS / Linux**:
  ```bash
  ./k8s/tests/verify_6actor_chain.sh
  ```
* **Windows (PowerShell)**:
  ```powershell
  .\k8s\tests\verify_6actor_chain.ps1
  ```

### 3. Postman Collection / Newman
Die vollständige E2E-Collection liegt unter `k8s/postman/6-Actor-Dataspace.postman_collection.json`:
```bash
npx newman run k8s/postman/6-Actor-Dataspace.postman_collection.json
```
