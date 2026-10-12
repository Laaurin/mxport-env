# 6-Akteure Datenraum-Architektur in k3d (Kubernetes)

Dieses Verzeichnis enthält die vollständige Kubernetes-Implementierung eines **6-Akteure Datenraums** für die Masterarbeit.

---

## 1. Architektur & Szenario-Überblick

Im industriellen Datenraum agieren 6 Akteure entlang einer Fertigungskette (von Komponentenherstellern bis zum Endkunden):

```text
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│    Akteur A     │ │    Akteur B     │ │    Akteur C     │
│  (Servo Motor)  │ │   (Getriebe)    │ │    (Sensor)     │
│                 │ │                 │ │                 │
│ Public AAS Repo │ │ Public AAS Repo │ │ Public AAS Repo │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         └─────────────┬─────┴───────────────────┘
                       │ Öffentlicher Datenvergleich
                       ▼
            ┌─────────────────────┐
            │      Akteur D       │
            │  (Maschinenbauer)   │
            │                     │
            │ - MachineTypeAAS    │
            │ - Simulation SM 🔒  │ ◄─── Nur autorisierte Kunden (Keycloak + SecSM)
            └──────────┬──────────┘
                       │ Kauf von Maschine & Zugriff auf Simulation
                       ▼
            ┌─────────────────────┐
            │      Akteur E       │
            │ (Bauteilfertigung)  │
            │                     │
            │ - Nameplate SM 🌐   │ ◄─── Für alle im Datenraum lesbar
            │ - TimeSeries SM 🔒  │ ◄─── Nur für Endkunden (Keycloak + SecSM)
            └──────────┬──────────┘
                       │ Kauf des hergestellten Bauteils
                       ▼
            ┌─────────────────────┐
            │      Akteur F       │
            │     (Endkunde)      │
            │                     │
            │ Zugriff auf         │
            │ TimeSeries SM       │
            └─────────────────────┘
```

---

## 2. Die Akteure im Detail

| Akteur | Rolle & Industrieller Kontext | Bereitgestellte AAS & Teilmodelle | Schutz & Autorisierung |
|---|---|---|---|
| **Akteur A** | Zulieferer für Servomotoren | `ServoMotorAAS` (`urn:dataspace:a:aas:servo-motor-001`)<br>• `Nameplate`<br>• `TechnicalData` (15 kW, IE4) | **100% Öffentlich**<br>(Ohne Auth/Token erreichbar) |
| **Akteur B** | Zulieferer für Industriegetriebe | `IndustrialGearboxAAS` (`urn:dataspace:b:aas:gearbox-001`)<br>• `Nameplate`<br>• `TechnicalData` (10:1 Untersetzung, 450 Nm) | **100% Öffentlich**<br>(Ohne Auth/Token erreichbar) |
| **Akteur C** | Zulieferer für Vibrationssensoren | `VibrationSensorAAS` (`urn:dataspace:c:aas:sensor-001`)<br>• `Nameplate`<br>• `TechnicalData` (25.6 kHz, IO-Link) | **100% Öffentlich**<br>(Ohne Auth/Token erreichbar) |
| **Akteur D** | CNC-Maschinenhersteller | `MillingMachineTypeAAS` (`urn:dataspace:d:aas:machine-type-001`)<br>• `Nameplate`<br>• `TechnicalData` (integriert A, B, C)<br>• `SimulationModel` (Kinematik & Thermo-FEA) | **Geschützt (Keycloak + SecSM)**<br>Zugriff auf Simulation SM nur für Kunden (Akteur E mit Rolle `customer-d`) |
| **Akteur E** | Präzisions-Fertiger (Turbinenschaufeln) | `TurbineBladeProductAAS` (`urn:dataspace:e:aas:produced-part-001`)<br>• `Nameplate` (Hersteller, Maschine D)<br>• `TimeSeries` (Prozessdaten: Frästemperatur, Vibration) | **Geschützt (Keycloak + SecSM)**<br>• **Nameplate**: Für alle Partner sichtbar<br>• **TimeSeries**: Strikt nur für Kunde F (`customer-e`) |
| **Akteur F** | Endkunde (Triebwerksbauer) | Fragt Bauteildaten von E ab für Qualitäts- & Abnahmezwecke | **Client mit Keycloak-Identität**<br>Erhält Zugriff auf `TimeSeries` SM von Akteur E |

---

## 3. IDTA-Metamodell & TypeScript SDK

Alle AAS-Modelle werden über das offizielle TypeScript SDK (`@aas-core-works/aas-core3.0-typescript`) typisiert erstellt und gegen die formale IDTA V3-Spezifikation validiert:

* **Generator-Skript**: `models/src/generate-models.ts`
* **Ausgabe**: `k8s/helm/dataspace-actor/files/models/actor-{a..f}.json`
* **Ausführen**:
  ```bash
  npm run generate --prefix models
  ```

---

## 4. Endpunkte (Traefik Ingress auf Port 80)

Dank `*.localhost` sind **keine `/etc/hosts`-Einträge erforderlich**:

| Komponente / Akteur | Ingress URL | Zweck / Authentifizierung |
|---|---|---|
| **Keycloak** | `http://keycloak.localhost` | Identity Provider (Realms: `BaSyx`, `actor-d`, `actor-e`, `actor-f`) |
| **Akteur A** | `http://actor-a.localhost` | Public AAS Repo (Servomotor Produktdaten) |
| **Akteur B** | `http://actor-b.localhost` | Public AAS Repo (Getriebe Produktdaten) |
| **Akteur C** | `http://actor-c.localhost` | Public AAS Repo (Sensor Produktdaten) |
| **Akteur D** | `http://actor-d.localhost` | Maschinenbauer (Geschützte Simulationsdaten) |
| **Akteur E** | `http://actor-e.localhost` | Bauteilfertiger (Öffentliche Nameplate, geschützte TimeSeries) |
| **Akteur F** | `http://actor-f.localhost` | Kunde von Akteur E |

---

## 5. Bereitstellung & Testen

### 5.1 Windows 11 (PowerShell)

```powershell
# 1. Cluster starten & alle 6 Akteure bereitstellen
.\k8s\scripts\cluster-up.ps1

# 2. Automatisierte End-to-End Testsuite ausführen
.\k8s\tests\verify_6actor_chain.ps1

# 3. Cluster stoppen
.\k8s\scripts\cluster-down.ps1
```

### 5.2 macOS / Linux (Bash)

```bash
# 1. Cluster starten & alle 6 Akteure bereitstellen
./k8s/scripts/cluster-up.sh

# 2. Automatisierte End-to-End Testsuite ausführen
./k8s/tests/verify_6actor_chain.sh

# 3. Cluster stoppen
./k8s/scripts/cluster-down.sh
```

---

## 6. Verifikation der Schutzanforderungen

Die automatisierte Testsuite überprüft folgende Anforderungen:
1. **Akteure A, B, C sind öffentlich**: Beliebige Aufrufe auf `/shells` und `/submodels` gelingen ohne Token (HTTP 200).
2. **Akteur D schützt Simulation**:
   - Aufruf ohne Token: **HTTP 401 Unauthorized**.
   - Aufruf mit Token von Akteur F (kein Kunde von D): **HTTP 401/403 Forbidden**.
   - Aufruf von Akteur E (Kunde von D mit Token `actor-e-client`): **HTTP 200 OK** (Simulation Submodel wird geliefert).
3. **Akteur E differenziert Nameplate vs. TimeSeries**:
   - Akteur D (nicht-Kunde von E) fragt `Nameplate` ab: **HTTP 200 OK** (*"andere sehen nur Nameplate"*).
   - Akteur D fragt `TimeSeries` ab: **HTTP 403 Forbidden**.
   - Kunde F fragt `TimeSeries` ab: **HTTP 200 OK** (Prozess- und Fertigungsdaten werden geliefert).
   - Aufruf ohne Token auf `TimeSeries`: **HTTP 401 Unauthorized**.
