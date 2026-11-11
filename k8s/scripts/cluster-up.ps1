# ==============================================================================
# cluster-up.ps1
# Windows PowerShell Script to create k3d cluster 'dataspace' and deploy all
# ==============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$K8sDir    = Split-Path -Parent $ScriptDir
$RootDir   = Split-Path -Parent $K8sDir
$ClusterName = "dataspace"

Write-Host ">>> Checking Prerequisites..." -ForegroundColor Cyan
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not running or not in PATH. Please start Docker Desktop."
}
if (-not (Get-Command k3d -ErrorAction SilentlyContinue)) {
    Write-Error "k3d is not installed. Install via: choco install k3d OR winget install Rancher.k3d"
}
if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Error "helm is not installed. Install via: choco install kubernetes-helm OR winget install Helm.Helm"
}
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed. Install via: choco install kubernetes-cli"
}

Write-Host ">>> Checking if cluster '$ClusterName' exists..." -ForegroundColor Cyan
$existing = k3d cluster list $ClusterName --no-headers 2>$null
if ($existing) {
    Write-Host ">>> Cluster '$ClusterName' already exists." -ForegroundColor Yellow
} else {
    Write-Host ">>> Creating k3d cluster '$ClusterName' from config..." -ForegroundColor Cyan
    k3d cluster create --config "$K8sDir\cluster\k3d-config.yaml"
}

Write-Host ">>> Checking local images..." -ForegroundColor Cyan
$gwInspect = docker image inspect mxport-leo-gateway:local 2>$null
if (-not $gwInspect) {
    Write-Host "  --> Building mxport-leo-gateway:local..." -ForegroundColor Gray
    docker build -t mxport-leo-gateway:local -f "$RootDir\provider\gateway\Dockerfile" "$RootDir\provider\gateway"
}
$stsInspect = docker image inspect mxport-leo-sts:local 2>$null
if (-not $stsInspect) {
    Write-Host "  --> Building mxport-leo-sts:local..." -ForegroundColor Gray
    docker build -t mxport-leo-sts:local "$RootDir\repos\mxport-leo-token-exchange"
}
$lookupInspect = docker image inspect mxport-leo-company-lookup:local 2>$null
if (-not $lookupInspect) {
    Write-Host "  --> Building mxport-leo-company-lookup:local..." -ForegroundColor Gray
    docker build -t mxport-leo-company-lookup:local "$RootDir\repos\mxport-leo-company-lookup"
}
$pgInspect = docker image inspect postgres:16-alpine 2>$null
if (-not $pgInspect) {
    Write-Host "  --> Pulling postgres:16-alpine..." -ForegroundColor Gray
    docker pull postgres:16-alpine
}

Write-Host ">>> Importing images into k3d cluster '$ClusterName'..." -ForegroundColor Cyan
$images = @(
  "mxport-leo-gateway:local",
  "mxport-leo-sts:local",
  "mxport-leo-company-lookup:local",
  "postgres:16-alpine",
  "eclipsebasyx/aas-environment:2.0.0-SNAPSHOT",
  "eclipsebasyx/submodel-repository:2.0.0-SNAPSHOT",
  "eclipsebasyx/aas-gui:SNAPSHOT",
  "quay.io/keycloak/keycloak:25.0",
  "mongo:8",
  "curlimages/curl:8.5.0"
)
foreach ($img in $images) {
    $exists = docker image inspect $img 2>$null
    if ($exists) {
        k3d image import $img -c $ClusterName
    }
}

Write-Host ">>> Deploying Helm charts..." -ForegroundColor Cyan
& "$ScriptDir\deploy-all.ps1"
