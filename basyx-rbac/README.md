# BaSyx Dynamic RBAC – Standalone Lokale Entwicklungsumgebung

Dieses Setup bietet eine schlanke, eigenständige Entwicklerumgebung für **Eclipse BaSyx Dynamic Role-Based Access Control (RBAC)** – vollständig isoliert ohne STS- oder Gateway-Overhead. Es ist **100% kompatibel mit Windows (Docker Desktop / WSL2), macOS und Linux**.

---

## 🏗️ Komponenten & Aktuelle Images

| Service | Container Name | Image | Port (Host) | Beschreibung |
| :--- | :--- | :--- | :--- | :--- |
| **BaSyx AAS Environment** | `basyx-aas` | `eclipsebasyx/aas-environment:2.0.0-SNAPSHOT` | `8081` | AAS Environment mit Dynamic RBAC Feature |
| **BaSyx AAS Web UI** | `basyx-aas-gui` | `eclipsebasyx/aas-gui:SNAPSHOT` | `3000` | Web UI / Dashboard mit Keycloak-Login |
| **Security Submodel Repo** | `security-submodel` | `eclipsebasyx/submodel-repository:2.0.0-SNAPSHOT` | `8086` | Dynamic Policy Storage (SecuritySubmodel) |
| **Security Initializer** | `security-sm-setup` | `curlimages/curl:8.5.0` | - | Idempotenter Init-Container für `SecuritySubmodel` |
| **Keycloak IAM** | `keycloak-rbac` | `quay.io/keycloak/keycloak:25.0` | `8085` | OIDC / OAuth2 Provider (Realm: `BaSyx`) |
| **MongoDB** | `basyx-mongo` | `mongo:8` | `27017` | Backend-Datenbank für Security Submodels |

---

## 🔑 Login & Zugangsdaten

### Web UI (AAS GUI)
- **URL**: [http://localhost:3000](http://localhost:3000)
- **Benutzername**: `admin` (oder `basyx-admin`)
- **Passwort**: `admin`
- **Rechte**: Vollzugriff (**Lese-, Schreib- und Löschrechte**: `CREATE`, `READ`, `UPDATE`, `DELETE`, `EXECUTE` auf alle Shells, Submodels, SubmodelElements und ConceptDescriptions)

### Keycloak Administrationskonsole
- **URL**: [http://localhost:8085](http://localhost:8085)
- **Admin**: `admin` / `admin`
- **Realm**: `BaSyx`

---

## 🚀 Schnellstart

### Stack starten
```bash
docker compose up -d
# Alternativ mit explizitem Compose-File:
docker compose -f docker-compose.basyx-rbac.yml up -d
```

### Status & Health prüfen
```bash
docker compose ps
```
Sobald alle Container als `healthy` markiert sind, ist die Umgebung vollständig einsatzbereit.

### Stack stoppen
```bash
docker compose down
```

---

## 🧪 Lokale Validierung (Tests)

### Unter macOS / Linux
```bash
chmod +x ./basyx-rbac/test-rbac.sh
./basyx-rbac/test-rbac.sh
```

### Unter Windows (PowerShell)
```powershell
.\basyx-rbac\test-rbac.ps1
```

Der Test führt folgende Schritte automatisch durch:
1. Token-Abruf für Benutzer `admin` von Keycloak (`http://localhost:8085`)
2. **READ**: Abruf aller Shells (`GET /shells` $\rightarrow$ `HTTP 200`)
3. **WRITE**: Anlegen einer neuen Test-Shell (`POST /shells` $\rightarrow$ `HTTP 201`)
4. **DELETE**: Löschen der Test-Shell (`DELETE /shells/{id}` $\rightarrow$ `HTTP 204`)
5. Verifikation der Löschung (`GET /shells/{id}` $\rightarrow$ `HTTP 404`)

---

## ⚙️ Technische Details & Windows-Kompatibilität

1. **Kein CRLF-Problem auf Windows**: Der Initializer-Container führt Scripts mit `tr -d '\r'` aus, sodass Windows-Zeilenumbrüche automatisch bereinigt werden. Zudem erzwingt `.gitattributes` LF für alle Shell- und Konfigurationsdateien.
2. **JWKS Key Resolution (`jwk-set-uri`)**: Anstelle einer strikten `issuer-uri` verwendet `basyx-aas` `spring.security.oauth2.resourceserver.jwt.jwk-set-uri=http://keycloak-rbac:8080/realms/BaSyx/protocol/openid-connect/certs`. Dadurch werden sowohl Tokens validiert, die im Browser über `http://localhost:8085` ausgestellt wurden, als auch container-interne Tokens über `http://keycloak-rbac:8080`.
3. **Dynamic RBAC Synchronisation**: BaSyx lädt die Basis-Regeln aus `basyx-rbac/rules/aas_env_rbac_rules.json` und synchronisiert sie automatisch in das `SecuritySubmodel`. Jede Änderung am `SecuritySubmodel` wird sofort zur Laufzeit wirksam.
