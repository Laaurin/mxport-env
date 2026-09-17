#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="${SCRIPT_DIR}/repos"

echo "══════════════════════════════════════════════════════════════════════════════"
echo "   MX-PORT LEO & BASYX ENVIRONMENT SETUP"
echo "══════════════════════════════════════════════════════════════════════════════"

# 1. Voraussetzungen prüfen
echo "==> Überprüfe Voraussetzungen (git, openssl)..."
for cmd in git openssl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Fehler: '$cmd' ist nicht installiert oder nicht im PATH."
    exit 1
  fi
done
echo "  ✔ git und openssl sind verfügbar."

# 2. Verzeichnisse sicherstellen
mkdir -p "${REPOS_DIR}"
mkdir -p "${SCRIPT_DIR}/consumer/sts/signingkey"
mkdir -p "${SCRIPT_DIR}/provider/sts/signingkey"

# 3. Helper-Funktion zum Klonen und Pinnen der Sub-Repositories
clone_repo() {
  local repo_name="$1"
  local repo_url="$2"
  local pinned_commit="$3"
  local target_dir="${REPOS_DIR}/${repo_name}"

  if [ -d "${target_dir}/.git" ]; then
    echo "  ✔ [Bereits vorhanden] ${repo_name}"
  else
    echo "  ⬇ Klone ${repo_name} von ${repo_url}..."
    git clone "${repo_url}" "${target_dir}"
    echo "  📌 Setze ${repo_name} auf getesteten Stand (${pinned_commit:0:7})..."
    git -C "${target_dir}" checkout -q "${pinned_commit}"
    echo "  ✔ [Erfolgreich geklont] ${repo_name}"
  fi
}

echo "==> Klone / Überprüfe externe Repositories in repos/..."
clone_repo "mxport-leo-token-exchange" \
  "https://github.com/factory-x-contributions/mxport-leo-token-exchange.git" \
  "4ad9a6011db4326fee6b518a18f239647ea4069c"

clone_repo "mxport-leo-gateway" \
  "https://github.com/factory-x-contributions/mxport-leo-gateway.git" \
  "eb686698e7e3947a9cbec728e89a647bec6faadf"

clone_repo "mxport-leo-company-lookup" \
  "https://github.com/factory-x-contributions/mxport-leo-company-lookup.git" \
  "a9937d1f5d016927722e7de1432a2a7e767646ab"

clone_repo "basyx-java-server-sdk" \
  "https://github.com/eclipse-basyx/basyx-java-server-sdk.git" \
  "568f5d04f2ac52522962894f99c7525f952c64aa"

# 4. STS-Signing-Keys generieren (falls nicht vorhanden)
echo "==> Überprüfe STS-Signing-Keys..."
if [ ! -f "${SCRIPT_DIR}/consumer/sts/signingkey/private_key.pem" ]; then
  echo "  🔑 Generiere Consumer STS Key (RSA 4096)..."
  openssl genrsa -out "${SCRIPT_DIR}/consumer/sts/signingkey/private_key.pem" 4096
  openssl rsa -in "${SCRIPT_DIR}/consumer/sts/signingkey/private_key.pem" -pubout -out "${SCRIPT_DIR}/consumer/sts/signingkey/public.pem"
  echo "  ✔ Consumer STS Key generiert."
else
  echo "  ✔ Consumer STS Key vorhanden."
fi

if [ ! -f "${SCRIPT_DIR}/provider/sts/signingkey/private_key.pem" ]; then
  echo "  🔑 Generiere Provider STS Key (RSA 4096)..."
  openssl genrsa -out "${SCRIPT_DIR}/provider/sts/signingkey/private_key.pem" 4096
  openssl rsa -in "${SCRIPT_DIR}/provider/sts/signingkey/private_key.pem" -pubout -out "${SCRIPT_DIR}/provider/sts/signingkey/public.pem"
  echo "  ✔ Provider STS Key generiert."
else
  echo "  ✔ Provider STS Key vorhanden."
fi

# 5. .env Konfiguration bereitstellen (falls noch nicht vorhanden)
echo "==> Überprüfe .env Konfiguration..."
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
  if [ -f "${SCRIPT_DIR}/.env.example" ]; then
    echo "  📄 Erstelle .env aus .env.example..."
    cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
    echo "  ✔ .env erstellt."
  fi
else
  echo "  ✔ .env bereits vorhanden."
fi

echo ""
echo "══════════════════════════════════════════════════════════════════════════════"
echo "✔ SETUP ERFOLGREICH ABGESCHLOSSEN!"
echo "══════════════════════════════════════════════════════════════════════════════"
echo "Nächste Schritte:"
echo "  1. Container im Hintergrund starten:"
echo "     docker compose up -d"
echo ""
echo "  2. End-to-End Pipeline verifizieren:"
echo "     ./tests/verify_token_pipeline.sh"
echo "══════════════════════════════════════════════════════════════════════════════"
