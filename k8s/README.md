# 4-Akteure Kaskadierende Supply-Chain in k3d (Kubernetes)

Dieses Verzeichnis enthält die vollständige Kubernetes-Implementierung einer **4-Akteure kaskadierenden Lieferkette** (Supply Chain) für die Masterarbeit.

---

## 1. Architekturüberblick

In der automobilen Lieferkette werden Batteriedaten (technische Daten & Product Carbon Footprint - PCF) über mehrere Stufen hinweg vertraulich und souverän geteilt:

```text
┌──────────────────────┐         ┌──────────────────────┐         ┌──────────────────────┐         ┌──────────────────────┐
│         OEM          │  Hop 1  │        Tier 1        │  Hop 2  │        Tier 2        │  Hop 3  │        Tier 3        │
│  (Fahrzeugfertiger)  ├────────►│  (Batterie-Pack)     ├────────►│  (Batterie-Modul)    ├────────►│   (Batterie-Zelle)   │
│                      │         │                      │         │                      │         │                      │
│ - Keycloak (oem)     │         │ - Keycloak (tier1)   │         │ - Keycloak (tier2)   │         │ - Keycloak (tier3)   │
│ - OpenResty Gateway  │         │ - OpenResty Gateway  │         │ - OpenResty Gateway  │         │ - OpenResty Gateway  │
│ - Siemens STS        │         │ - Siemens STS        │         │ - Siemens STS        │         │ - Siemens STS        │
│ - BaSyx AAS          │         │ - BaSyx AAS (Pack)   │         │ - BaSyx AAS (Module) │         │ - BaSyx AAS (Cell)   │
│ - Security Submodel  │         │ - Security Submodel  │         │ - Security Submodel  │         │ - Security Submodel  │
└──────────────────────┘         └──────────────────────┘         └──────────────────────┘         └──────────────────────┘
```

### Kaskaden-Prinzip & Sicherheitsgrenzen
1. **Hop 1 (OEM ➔ Tier 1)**: Der OEM authentifiziert sich über seinen Keycloak (`realm: oem`). Das Gateway und der STS von Tier 1 prüfen das Token und tauschen es per RFC 8693 Token Exchange gegen ein internes AAS-Token aus. Der OEM erhält Zugriff auf die `BatteryPackAAS` (Kapazität: 80 kWh, PCF: 2150 kg CO2e).
2. **Hop 2 (Tier 1 ➔ Tier 2)**: Tier 1 fragt Tier 2 mit seinem Tier-1-Token an. Tier 2 validiert das Token und liefert die `BatteryModuleAAS` (12S1P, PCF: 245 kg CO2e).
3. **Hop 3 (Tier 2 ➔ Tier 3)**: Tier 2 fragt Tier 3 mit seinem Tier-2-Token an. Tier 3 liefert die `BatteryCellAAS` (NMC 811 Chemie, PCF: 18.5 kg CO2e).
4. **Boundary Isolation (Negative Testing)**:
   - Ein direkter Aufruf des OEM auf Tier 3 oder Tier 2 wird vom jeweiligen STS **strikt mit HTTP 401 abgelehnt**, da Tier 3 ausschließlich Tier 2 und Tier 2 ausschließlich Tier 1 vertraut.
   - Anfragen ohne Token oder mit gefälschten Signaturen werden sofort verworfen.

---

## 2. Koexistenz mit dem bisherigen 2-Akteure Docker Compose Setup

Das ursprüngliche 2-Akteure Docker Compose Setup bleibt **vollständig unberührt und funktionstüchtig**:
- **Git Tag**: `v1.0-2actors-compose`
- **Git Branch**: `scenario/2-actors-compose`
- **Dateien**: Die Ordner `compose/`, `provider/`, `consumer/`, `postman/` und `tests/` bleiben für Docker Compose unverändert erhalten.
- Das neue k3d/Helm-Setup lebt isoliert im Verzeichnis `k8s/`.

---

## 3. Windows 11 Setup-Anleitung (32 GB RAM, Docker Desktop)

Das Setup wurde speziell so optimiert, dass alle 18 Pods zusammen nur **ca. 3,5 GB RAM** benötigen. Auf einem 32 GB Windows 11 Laptop mit Docker Desktop läuft das System daher absolut flüssig und ressourcenschonend.

### 3.1 Voraussetzungen installieren
In einer administrativen PowerShell:
```powershell
# Paketmanager Winget oder Chocolatey nutzen:
winget install Rancher.k3d
winget install Helm.Helm
winget install Kubernetes.kubectl
```
*Hinweis: Docker Desktop muss laufen (WSL 2 Backend empfohlen).*

### 3.2 Cluster starten & bereitstellen (1-Klick)
```powershell
# Im Projekt-Root:
cd mxport-env
.\k8s\scripts\cluster-up.ps1
```
Dieses Skript:
1. Erstellt den k3d-Cluster `dataspace` mit Traefik Ingress auf Port 80.
2. Konfiguriert Kubelet so, dass Disk-Pressure-Evictions auf Entwickler-Laptops verhindert werden.
3. Importiert alle Docker-Images in den Cluster.
4. Rollt die Shared Infrastructure (MongoDB, Keycloak mit 5 vorkonfigurierten Realms) aus.
5. Rollt alle 4 Akteure (`oem`, `tier1`, `tier2`, `tier3`) per Helm aus.

### 3.3 Automatisierte Tests ausführen
Entweder mit dem PowerShell-Testskript:
```powershell
.\k8s\tests\verify_4actor_chain.ps1
```

Oder mit Newman / Postman:
```powershell
npx -y newman run k8s/postman/4-Actor-Supply-Chain.postman_collection.json
```
*(34 von 34 Assertions laufen in ca. 2 Sekunden erfolgreich durch!)*

### 3.4 Cluster stoppen / bereinigen
```powershell
.\k8s\scripts\cluster-down.ps1
```

---

## 4. macOS / Linux Anleitung

### Cluster starten & bereitstellen:
```bash
./k8s/scripts/cluster-up.sh
```

### Tests ausführen:
```bash
# Bash-Testsuite (30 Tests)
./k8s/tests/verify_4actor_chain.sh

# Newman / Postman Testsuite (34 Tests)
npx -y newman run k8s/postman/4-Actor-Supply-Chain.postman_collection.json
```

### Cluster löschen:
```bash
./k8s/scripts/cluster-down.sh
```

---

## 5. Endpunkte & Domain-Mapping

Dank des integrierten Traefik Ingress Controllers auf Port 80 sind **keine Änderungen an `/etc/hosts` nötig** (da moderne Betriebssysteme und Browser `*.localhost` automatisch auf `127.0.0.1` auflösen):

| Komponente | Ingress URL | Zweck |
|---|---|---|
| **Keycloak** | `http://keycloak.localhost` | Identity Provider für alle 5 Realms (`BaSyx`, `oem`, `tier1`, `tier2`, `tier3`) |
| **OEM Gateway** | `http://oem.localhost` | Einstiegspunkt für den OEM |
| **Tier 1 Gateway** | `http://tier1.localhost` | Liefert `BatteryPackAAS` (Port 80 Ingress) |
| **Tier 2 Gateway** | `http://tier2.localhost` | Liefert `BatteryModuleAAS` (Port 80 Ingress) |
| **Tier 3 Gateway** | `http://tier3.localhost` | Liefert `BatteryCellAAS` (Port 80 Ingress) |

---

## 6. Technische Details der Komponenten

### OpenResty / Nginx Gateway
- Dynamische LUA-Skripte (`sts.lua`) fangen eingehende Anfragen ab.
- Führen RFC 8693 Token Exchange gegen den akteursspezifischen STS durch.
- Cachen Tokens in der Shared Memory Zone `sts_token_cache` (5 Minuten TTL).
- Leiten den Aufruf mit dem STS-signierten Token an die lokale BaSyx AAS weiter.

### Siemens STS (Security Token Service)
- Validiert externe Partner-Tokens anhand konfigurierter JWKS-Endpunkte.
- Mappt Attribute und Rollen per Filter-Pipeline (`BasyxFilter`, `ClaimsCopyFilter`, `ClaimsAppenderFilter`).
- Signiert neue JWT-Tokens für die BaSyx AAS Audience.

### Eclipse BaSyx AAS & Security Submodel
- **Dynamic RBAC Backend**: Nutzt `basyx.feature.authorization.rules.backend=Submodel`.
- **Preconfiguration Loader**: Initialisiert die Shells und Submodels (`TechnicalData`, `CarbonFootprint`) beim Pod-Start unter Einhaltung des RBAC-Modells.
- **MongoDB**: Persistiert die dynamischen RBAC-Regeln der Security Submodels im Cluster.
