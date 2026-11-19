# 6-Akteure Datenraum in k3d (Kubernetes) — Komplettanleitung (Windows & macOS/Linux)

Dieses Dokument enthält alle Befehle zum **Aufbauen**, **Starten**, **Aktualisieren (`deploy-all`)** und **Testen** des 6-Akteure-Datenraums – sowohl über die mitgelieferten Skripte als auch als direkte Copy-Paste-Blöcke für PowerShell und Bash.

---

## 1. Schnellübersicht: Alle wichtigen Skripte

Falls unter Windows PowerShell das Ausführen von `.ps1`-Skripten durch die ExecutionPolicy blockiert wird, führe einmalig im aktuellen PowerShell-Fenster diesen Befehl aus:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

| Aufgabe | Windows (PowerShell) | macOS / Linux (Bash) |
|---|---|---|
| **1. Externe Repos (`repos/`) klonen** | `.\setup.ps1` | `./setup.sh` |
| **2. Cluster erstellen/starten + Images + `deploy-all`** | `.\k8s\scripts\cluster-up.ps1` | `./k8s/scripts/cluster-up.sh` |
| **3. Nur Helm-Charts aktualisieren (laufendes Cluster)** | `.\k8s\scripts\deploy-all.ps1` | `./k8s/scripts/deploy-all.sh` |
| **4. E2E-Tests (31/48 Checks) ausführen** | `.\k8s\tests\verify_6actor_chain.ps1` | `./k8s/tests/verify_6actor_chain.sh` |
| **5. Vue Workbench starten (`http://localhost:5173`)** | `.\k8s\scripts\workbench.ps1` | `./k8s/scripts/workbench.sh` |
| **6. Cluster komplett löschen** | `.\k8s\scripts\cluster-down.ps1` | `./k8s/scripts/cluster-down.sh` |
| **7. Windows `hosts`-Datei ergänzen (als Admin)** | `.\k8s\scripts\setup-hosts.ps1` | *(nicht nötig)* |

---

## 2. Typische Betriebs-Szenarien (inkl. Fehlerbehebung)

### Szenario A: `no nodes found for given cluster` oder `Kubernetes cluster unreachable` / `dial tcp 192.168.x.x: connectex`
Wenn Docker Desktop beendet/neugestartet wurde, die `k3d`-Container gelöscht wurden oder nach einem WLAN-Wechsel `host.docker.internal` in `~/.kube/config` auf eine alte IP (`192.168.x.x`) zeigt:

#### Schnellfix bei `Get "https://host.docker.internal:...": dial tcp 192.168.x.x` (WLAN gewechselt unter Windows)
Docker Desktop schreibt unter Windows eine alte WLAN-IP für `host.docker.internal` in die Windows-`hosts`-Datei. `deploy-all.ps1` und `cluster-up.ps1` ersetzen `https://host.docker.internal:` in `~/.kube/config` jetzt automatisch durch `https://127.0.0.1:`.
Du kannst das auch jederzeit mit diesem Einzeiler in PowerShell reparieren und danach sofort `.\k8s\scripts\deploy-all.ps1` ausführen:
```powershell
(Get-Content "$HOME\.kube\config" -Raw) -replace 'https://host\.docker\.internal:', 'https://127.0.0.1:' | Set-Content "$HOME\.kube\config"
.\k8s\scripts\deploy-all.ps1
```

#### Option 1: Per Skript (`cluster-up` erkennt defekte/leere Cluster jetzt automatisch!)
* **Windows (PowerShell)**:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  .\k8s\scripts\cluster-up.ps1
  ```
* **macOS / Linux**:
  ```bash
  ./k8s/scripts/cluster-up.sh
  ```
*(Das Skript prüft automatisch, ob `k3d cluster start dataspace` funktioniert. Falls `no nodes found for given cluster` auftritt, löscht es den verwaisten Eintrag, erstellt das Cluster neu, importiert die lokal vorhandenen Docker-Images und ruft `deploy-all` auf.)*

#### Option 2: Manuell per Copy & Paste (ohne Skripte)
```powershell
# 1. Verwaisten Cluster-Eintrag löschen und neu erstellen
k3d cluster delete dataspace
k3d cluster create --config k8s/cluster/k3d-config.yaml

# 2. Lokale Docker-Images in das neue k3d-Cluster importieren
k3d image import mxport-leo-gateway:local -c dataspace
k3d image import mxport-leo-sts:local -c dataspace
k3d image import mxport-leo-company-lookup:local -c dataspace

# 3. Alle Helm-Charts über deploy-all ausrollen (oder die Einzelbefehle aus Abschnitt 3 nutzen)
.\k8s\scripts\deploy-all.ps1
```

---

### Szenario B: Cluster läuft bereits — nur Änderungen ausrollen (`deploy-all`)
Wenn das `k3d`-Cluster läuft (`kubectl get nodes` zeigt `Ready`) und du nach einem `git pull` oder nach dem Hinzufügen eigener AAS-Modelle die Kubernetes-Deployments aktualisieren möchtest:

* **Über `deploy-all` (aktualisiert Keycloak-Realms, Infra, Company Lookup & alle 6 Akteure A–F)**:
  * **Windows (PowerShell)**:
    ```powershell
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    .\k8s\scripts\deploy-all.ps1
    ```
  * **macOS / Linux**:
    ```bash
    ./k8s/scripts/deploy-all.sh
    ```
* **Oder nur einzelne Akteure per Helm aktualisieren (z. B. Actor D und Actor E)**:
  ```powershell
  helm upgrade --install actor-d k8s/helm/dataspace-actor -f k8s/values/actor-d.yaml -n dataspace
  helm upgrade --install actor-e k8s/helm/dataspace-actor -f k8s/values/actor-e.yaml -n dataspace
  ```

---

## 3. Kompletter Aufbau von Grund auf (100% Manuell zum Kopieren ohne `.ps1`-Skripte)

Falls du auf einem neuen Gerät komplett ohne Skript-Aufrufe von Null starten möchtest, kopiere die folgenden Blöcke nacheinander im Projekt-Hauptverzeichnis `mxport-env` in dein Terminal:

### Schritt 1: Externe Quell-Repositories (`repos/`) klonen
*(Nur beim allerersten Mal nötig, falls `repos/` noch leer ist)*
```powershell
git config --global core.longpaths true
mkdir -Force repos

git clone -c core.longpaths=true https://github.com/factory-x-contributions/mxport-leo-token-exchange.git repos/mxport-leo-token-exchange
git -C repos/mxport-leo-token-exchange checkout 4ad9a6011db4326fee6b518a18f239647ea4069c

git clone -c core.longpaths=true https://github.com/factory-x-contributions/mxport-leo-company-lookup.git repos/mxport-leo-company-lookup
git -C repos/mxport-leo-company-lookup checkout a9937d1f5d016927722e7de1432a2a7e767646ab
```

### Schritt 2: Lokale Docker-Images bauen
*(Nur nötig, falls die Images noch nicht lokal in Docker existieren. `--provenance=false` verhindert unter Windows Docker Desktop den `content digest sha256 not found`-Fehler beim Import in `k3d`.)*
```powershell
docker build --provenance=false -t mxport-leo-gateway:local -f provider/gateway/Dockerfile provider/gateway
docker build --provenance=false -t mxport-leo-sts:local repos/mxport-leo-token-exchange
docker build --provenance=false -t mxport-leo-company-lookup:local repos/mxport-leo-company-lookup
```

### Schritt 3: `k3d`-Cluster erstellen & lokale Images importieren
```powershell
k3d cluster delete dataspace
k3d cluster create --config k8s/cluster/k3d-config.yaml

k3d image import mxport-leo-gateway:local -c dataspace
k3d image import mxport-leo-sts:local -c dataspace
k3d image import mxport-leo-company-lookup:local -c dataspace
```

### Schritt 4: Alles ausrollen (Entspricht `deploy-all.ps1` / `deploy-all.sh`)
```powershell
kubectl create namespace dataspace
kubectl create configmap keycloak-realms --from-file=k8s/infra/keycloak/realms -n dataspace --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install infra k8s/helm/dataspace-infra -n dataspace

helm upgrade --install actor-a k8s/helm/dataspace-actor -f k8s/values/actor-a.yaml -n dataspace
helm upgrade --install actor-b k8s/helm/dataspace-actor -f k8s/values/actor-b.yaml -n dataspace
helm upgrade --install actor-c k8s/helm/dataspace-actor -f k8s/values/actor-c.yaml -n dataspace
helm upgrade --install actor-d k8s/helm/dataspace-actor -f k8s/values/actor-d.yaml -n dataspace
helm upgrade --install actor-e k8s/helm/dataspace-actor -f k8s/values/actor-e.yaml -n dataspace
helm upgrade --install actor-f k8s/helm/dataspace-actor -f k8s/values/actor-f.yaml -n dataspace

kubectl get pods -n dataspace
```

### Schritt 5: Vue Workbench starten (`http://localhost:5173`)
```powershell
cd workbench
npm install
npm run dev
```

---

## 4. Architektur & Szenario-Überblick

Im Datenraum agieren 6 Akteure entlang einer industriellen Liefer- und Fertigungskette. Kein Akteur hat die Repository-URLs anderer Akteure hartcodiert – die Auflösung erfolgt immer dynamisch anhand der Asset-/Shell-/Submodel-URN über den **Company Lookup Service** (`lookup.localhost`).

| Akteur | Rolle & Kontext | Standard-AAS & Teilmodelle | Zugriffssteuerung & Rollen |
|---|---|---|---|
| **Actor A** | Energiemessgeräte-Zulieferer 1 | `PowerMeterModbusAAS` (`urn:dataspace:a:aas:servo-motor-001`)<br>- `Nameplate`<br>- `TechnicalData` (400V, 63A, Modbus-RTU) | **Öffentlich** (kein Token erforderlich) |
| **Actor B** | Energiemessgeräte-Zulieferer 2 | `PowerQualityAnalyzerAAS` (`urn:dataspace:b:aas:gearbox-001`)<br>- `Nameplate`<br>- `TechnicalData` (690V, 125A, Class 0.2S) | **Öffentlich** (kein Token erforderlich) |
| **Actor C** | Energiemessgeräte-Zulieferer 3 | `IoTEnergySensorAAS` (`urn:dataspace:c:aas:sensor-001`)<br>- `Nameplate`<br>- `TechnicalData` (400V, 500A Rogowski, MQTT) | **Öffentlich** (kein Token erforderlich) |
| **Actor D** | Maschinenbauer (OEM) | `MillingMachineTypeAAS` (`urn:dataspace:d:aas:machine-type-001`)<br>- `Nameplate`<br>- `TechnicalData` (Referenzen auf Energiemessgeräte A, B, C)<br>- `SimulationModel` | **Keycloak + STS + BaSyx Security SM**<br>- Eigene Rolle: `partner-d`<br>- `SimulationModel` erfordert `customer-d` |
| **Actor E** | Bauteilfertiger (Kunde von D) | `PrecisionGearProductAAS` (`urn:dataspace:e:aas:produced-part-001`)<br>- `Nameplate` (Zahnrad, gefräst auf Maschine D)<br>- `TimeSeries` (Prozessdaten der Fertigung) | **Keycloak + STS + BaSyx Security SM**<br>- Eigene Rollen: `customer-d`, `partner-e`<br>- `Nameplate`: lesbar für Partner (`partner-d`, `customer-e`)<br>- `TimeSeries`: erfordert `customer-e` |
| **Actor F** | Endkunde (Kunde von E) | `CustomerDriveSystemsOEM` (`urn:dataspace:f:aas:customer-profile-001`)<br>- `Nameplate` (Kaufreferenz auf Zahnrad von E) | **Keycloak-Identität**<br>- Eigene Rollen: `customer-e`, `partner-f`<br>- Erhält Vollzugriff auf `TimeSeries` von E |

---

## 5. Endpunkte im Cluster (Traefik Ingress auf Port 80)

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

---

## 6. Eigene AAS-Shells & Submodels einbinden (Git-ignoriert mit Fallback)

### Weg 1: Dauerhaft über Dateien (`k8s/helm/dataspace-actor/files/custom-models/`)
1. Lege im Ordner `k8s/helm/dataspace-actor/files/custom-models/` eine JSON-Datei mit dem Namen des Akteurs an (z. B. `actor-e.json` oder `actor-a.json`).
2. Das Format entspricht dem offiziellen IDTA / Eclipse BaSyx V3.0 AAS-Environment-Standard (`{ "assetAdministrationShells": [...], "submodels": [...], "conceptDescriptions": [...] }`).
3. Alle `*.json`- und `*.aasx`-Dateien in `custom-models/` werden von **Git ignoriert** (`.gitignore`).
4. Beim Ausführen von `deploy-all` lädt Helm automatisch deine Datei aus `custom-models/`. Löschst du die Datei wieder aus `custom-models/`, greift automatisch der **Fallback** auf die Standard-Demo-Datei unter `k8s/helm/dataspace-actor/files/models/<actor>.json`.

### Weg 2: Zur Laufzeit über die Workbench (`Verwaltung`)
Oben rechts in der Workbench (`http://localhost:5173`) öffnet der Button **`Verwaltung`** drei Werkzeuge:
1. **Zugriffsrechte (`Actor D` / `Actor E`)**: Steuert live in der MongoDB des **BaSyx Security Submodels** (`/secsm/submodel-elements`), welche Rolle Lesezugriff auf welches Teilmodell hat – inklusive 1-Klick-Reset auf die Standard-Berechtigungen.
2. **Shells & Submodels**: Importiert eigene AAS/Submodel-JSONs zur Laufzeit direkt in das `InMemory`-Repository des gewählten Akteurs und erlaubt das gezielte Löschen einzelner Shells und Submodels.
3. **Akteure verwalten**: Registriert zusätzliche Akteure persistent in der PostgreSQL-Datenbank des Company Lookup Service und erlaubt deren vollständiges Löschen.
