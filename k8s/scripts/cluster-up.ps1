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

Write-Host ">>> Importing images into k3d cluster '$ClusterName'..." -ForegroundColor Cyan
k3d image import `
  mxport-leo-gateway:local `
  mxport-leo-sts:local `
  eclipsebasyx/aas-environment:2.0.0-SNAPSHOT `
  eclipsebasyx/submodel-repository:2.0.0-SNAPSHOT `
  quay.io/keycloak/keycloak:25.0 `
  mongo:8 `
  curlimages/curl:8.5.0 `
  -c $ClusterName

Write-Host ">>> Deploying Helm charts..." -ForegroundColor Cyan
& "$ScriptDir\deploy-all.ps1"
