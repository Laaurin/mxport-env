# ==============================================================================
#  MX-PORT LEO & BASYX ENVIRONMENT SETUP (Windows PowerShell)
# ==============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReposDir = Join-Path $ScriptDir "repos"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "   MX-PORT LEO & BASYX ENVIRONMENT SETUP (Windows PowerShell)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

# 1. Prerequisites check (git, openssl)
Write-Host "==> Checking prerequisites (git, openssl)..."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git is not installed or not in PATH. Please install Git for Windows: https://git-scm.com"
    exit 1
}

# Locate OpenSSL (either in PATH or in default Git for Windows directories)
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
    Write-Host "[WARN] OpenSSL was not found in PATH or default Git directories." -ForegroundColor Yellow
    Write-Host "       Tip: Run: winget install ShiningLight.OpenSSL.Light" -ForegroundColor Yellow
    Write-Host "       Or run setup via Git Bash: ./setup.sh" -ForegroundColor Yellow
    Write-Error "Aborted: OpenSSL is required to generate STS signing keys."
    exit 1
}

Write-Host "  [OK] git and openssl ($openSslPath) are available." -ForegroundColor Green

# Enable long paths in Git on Windows (prevents 'Filename too long' in deep Java packages)
git config --global core.longpaths true 2>$null

# 2. Ensure directories exist
$null = New-Item -ItemType Directory -Force -Path $ReposDir
$null = New-Item -ItemType Directory -Force -Path (Join-Path $ScriptDir "consumer\sts\signingkey")
$null = New-Item -ItemType Directory -Force -Path (Join-Path $ScriptDir "provider\sts\signingkey")

# 3. Helper function to clone and pin sub-repositories
function Clone-Repo {
    param (
        [string]$RepoName,
        [string]$RepoUrl,
        [string]$PinnedCommit
    )
    $targetDir = Join-Path $ReposDir $RepoName
    if (Test-Path (Join-Path $targetDir ".git")) {
        git -C $targetDir config core.longpaths true 2>$null
        $nonGitItems = Get-ChildItem -Path $targetDir -Force | Where-Object { $_.Name -ne ".git" }
        if (-not $nonGitItems) {
            Write-Host "  [WARN] Incomplete checkout detected. Repairing $RepoName..." -ForegroundColor Yellow
            git -C $targetDir checkout -f $PinnedCommit
            Write-Host "  [OK] Repaired $RepoName" -ForegroundColor Green
        } else {
            Write-Host "  [OK] Already present: $RepoName" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  [INFO] Cloning $RepoName from $RepoUrl..." -ForegroundColor Yellow
        git clone -c core.longpaths=true $RepoUrl $targetDir
        git -C $targetDir config core.longpaths true 2>$null
        $shortCommit = $PinnedCommit.Substring(0, 7)
        Write-Host "  [INFO] Pinning $RepoName to commit $shortCommit..." -ForegroundColor Yellow
        git -C $targetDir checkout -q $PinnedCommit
        Write-Host "  [OK] Cloned $RepoName" -ForegroundColor Green
    }
}

Write-Host "==> Cloning / verifying external repositories in repos/..."
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

# 4. Generate STS signing keys if not present
Write-Host "==> Checking STS signing keys..."
$consumerPrivKey = Join-Path $ScriptDir "consumer\sts\signingkey\private_key.pem"
$consumerPubKey  = Join-Path $ScriptDir "consumer\sts\signingkey\public.pem"
if (-not (Test-Path $consumerPrivKey)) {
    Write-Host "  [INFO] Generating Consumer STS Key (RSA 4096)..." -ForegroundColor Yellow
    & $openSslPath genrsa -out $consumerPrivKey 4096
    & $openSslPath rsa -in $consumerPrivKey -pubout -out $consumerPubKey
    Write-Host "  [OK] Consumer STS Key generated." -ForegroundColor Green
} else {
    Write-Host "  [OK] Consumer STS Key already exists." -ForegroundColor DarkGray
}

$providerPrivKey = Join-Path $ScriptDir "provider\sts\signingkey\private_key.pem"
$providerPubKey  = Join-Path $ScriptDir "provider\sts\signingkey\public.pem"
if (-not (Test-Path $providerPrivKey)) {
    Write-Host "  [INFO] Generating Provider STS Key (RSA 4096)..." -ForegroundColor Yellow
    & $openSslPath genrsa -out $providerPrivKey 4096
    & $openSslPath rsa -in $providerPrivKey -pubout -out $providerPubKey
    Write-Host "  [OK] Provider STS Key generated." -ForegroundColor Green
} else {
    Write-Host "  [OK] Provider STS Key already exists." -ForegroundColor DarkGray
}

# 5. Create .env from .env.example if not present
Write-Host "==> Checking .env configuration..."
$envFile = Join-Path $ScriptDir ".env"
$envExampleFile = Join-Path $ScriptDir ".env.example"
if (-not (Test-Path $envFile)) {
    if (Test-Path $envExampleFile) {
        Write-Host "  [INFO] Creating .env from .env.example..." -ForegroundColor Yellow
        Copy-Item $envExampleFile $envFile
        Write-Host "  [OK] .env created." -ForegroundColor Green
    }
} else {
    Write-Host "  [OK] .env already exists." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "[OK] SETUP COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Next steps (k3d 6-Actor Dataspace):"
Write-Host "  1. Start k3d cluster and deploy all 6 actors:"
Write-Host "     .\k8s\scripts\cluster-up.ps1"
Write-Host ""
Write-Host "  2. Run 6-actor E2E verification:"
Write-Host "     .\k8s\tests\verify_6actor_chain.ps1"
Write-Host ""
Write-Host "  3. Start Vue Workbench UI:"
Write-Host "     .\k8s\scripts\workbench.ps1"
Write-Host "==============================================================================" -ForegroundColor Cyan
