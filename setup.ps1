# ══════════════════════════════════════════════════════════════════════════════
#  MX-PORT LEO & BASYX ENVIRONMENT SETUP (Windows PowerShell)
# ══════════════════════════════════════════════════════════════════════════════
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReposDir = Join-Path $ScriptDir "repos"

Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   MX-PORT LEO & BASYX ENVIRONMENT SETUP (Windows PowerShell)" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# 1. Voraussetzungen prüfen (git, openssl)
Write-Host "==> Überprüfe Voraussetzungen (git, openssl)..."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git ist nicht installiert oder nicht im PATH. Bitte Git für Windows installieren: https://git-scm.com"
    exit 1
}

# OpenSSL lokalisieren (entweder im PATH oder in Standard-Pfade von Git für Windows)
$openSslCmd = Get-Command openssl -ErrorAction SilentlyContinue
$openSslPath = $null

if ($openSslCmd) {
    $openSslPath = $openSslCmd.Source
} else {
    $candidates = @(
        "C:\Program Files\Git\usr\bin\openssl.exe",
        "C:\Program Files (x86)\Git\usr\bin\openssl.exe",
        "$env:LOCALAPPDATA\Programs\Git\usr\bin\openssl.exe"
    )
    foreach ($cand in $candidates) {
        if (Test-Path $cand) {
            $openSslPath = $cand
            break
        }
    }
}

if (-not $openSslPath) {
    Write-Host "⚠️ OpenSSL wurde nicht automatisch im PATH oder Git-Verzeichnis gefunden." -ForegroundColor Yellow
    Write-Host "   Tipp: Führe aus: winget install ShiningLight.OpenSSL.Light" -ForegroundColor Yellow
    Write-Host "   Oder nutze die Git Bash für das Setup: ./setup.sh" -ForegroundColor Yellow
    Write-Error "Abbruch: OpenSSL erforderlich zur Generierung der STS-Signing-Keys."
    exit 1
}

Write-Host "  ✔ git und openssl ($openSslPath) sind verfügbar." -ForegroundColor Green

# 2. Verzeichnisse sicherstellen
$null = New-Item -ItemType Directory -Force -Path $ReposDir
$null = New-Item -ItemType Directory -Force -Path (Join-Path $ScriptDir "consumer\sts\signingkey")
$null = New-Item -ItemType Directory -Force -Path (Join-Path $ScriptDir "provider\sts\signingkey")

# 3. Helper-Funktion zum Klonen und Pinnen der Sub-Repositories
function Clone-Repo {
    param (
        [string]$RepoName,
        [string]$RepoUrl,
        [string]$PinnedCommit
    )
    $targetDir = Join-Path $ReposDir $RepoName
    if (Test-Path (Join-Path $targetDir ".git")) {
        Write-Host "  ✔ [Bereits vorhanden] $RepoName" -ForegroundColor DarkGray
    } else {
        Write-Host "  ⬇ Klone $RepoName von $RepoUrl..." -ForegroundColor Yellow
        git clone $RepoUrl $targetDir
        Write-Host "  📌 Setze $RepoName auf getesteten Stand ($($PinnedCommit.Substring(0,7)))..." -ForegroundColor Yellow
        git -C $targetDir checkout -q $PinnedCommit
        Write-Host "  ✔ [Erfolgreich geklont] $RepoName" -ForegroundColor Green
    }
}

Write-Host "==> Klone / Überprüfe externe Repositories in repos/..."
Clone-Repo "mxport-leo-token-exchange" `
    "https://github.com/factory-x-contributions/mxport-leo-token-exchange.git" `
    "4ad9a6011db4326fee6b518a18f239647ea4069c"

Clone-Repo "mxport-leo-gateway" `
    "https://github.com/factory-x-contributions/mxport-leo-gateway.git" `
    "eb686698e7e3947a9cbec728e89a647bec6faadf"

Clone-Repo "mxport-leo-company-lookup" `
    "https://github.com/factory-x-contributions/mxport-leo-company-lookup.git" `
    "a9937d1f5d016927722e7de1432a2a7e767646ab"

Clone-Repo "basyx-java-server-sdk" `
    "https://github.com/eclipse-basyx/basyx-java-server-sdk.git" `
    "568f5d04f2ac52522962894f99c7525f952c64aa"

# 4. STS-Signing-Keys generieren (falls nicht vorhanden)
Write-Host "==> Überprüfe STS-Signing-Keys..."
$consumerPrivKey = Join-Path $ScriptDir "consumer\sts\signingkey\private_key.pem"
$consumerPubKey  = Join-Path $ScriptDir "consumer\sts\signingkey\public.pem"
if (-not (Test-Path $consumerPrivKey)) {
    Write-Host "  🔑 Generiere Consumer STS Key (RSA 4096)..." -ForegroundColor Yellow
    & $openSslPath genrsa -out $consumerPrivKey 4096
    & $openSslPath rsa -in $consumerPrivKey -pubout -out $consumerPubKey
    Write-Host "  ✔ Consumer STS Key generiert." -ForegroundColor Green
} else {
    Write-Host "  ✔ Consumer STS Key vorhanden." -ForegroundColor DarkGray
}

$providerPrivKey = Join-Path $ScriptDir "provider\sts\signingkey\private_key.pem"
$providerPubKey  = Join-Path $ScriptDir "provider\sts\signingkey\public.pem"
if (-not (Test-Path $providerPrivKey)) {
    Write-Host "  🔑 Generiere Provider STS Key (RSA 4096)..." -ForegroundColor Yellow
    & $openSslPath genrsa -out $providerPrivKey 4096
    & $openSslPath rsa -in $providerPrivKey -pubout -out $providerPubKey
    Write-Host "  ✔ Provider STS Key generiert." -ForegroundColor Green
} else {
    Write-Host "  ✔ Provider STS Key vorhanden." -ForegroundColor DarkGray
}

# 5. .env Konfiguration bereitstellen (falls noch nicht vorhanden)
Write-Host "==> Überprüfe .env Konfiguration..."
$envFile = Join-Path $ScriptDir ".env"
$envExampleFile = Join-Path $ScriptDir ".env.example"
if (-not (Test-Path $envFile)) {
    if (Test-Path $envExampleFile) {
        Write-Host "  📄 Erstelle .env aus .env.example..." -ForegroundColor Yellow
        Copy-Item $envExampleFile $envFile
        Write-Host "  ✔ .env erstellt." -ForegroundColor Green
    }
} else {
    Write-Host "  ✔ .env bereits vorhanden." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✔ SETUP ERFOLGREICH ABGESCHLOSSEN!" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Nächste Schritte:"
Write-Host "  1. Container im Hintergrund starten:"
Write-Host "     docker compose up -d"
Write-Host ""
Write-Host "  2. End-to-End Pipeline verifizieren:"
Write-Host "     In Git Bash / WSL2: ./tests/verify_token_pipeline.sh"
Write-Host "     Oder in Postman: Collection Runner mit postman/MXPort_BaSyx_E2E.postman_collection.json"
Write-Host "══════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
