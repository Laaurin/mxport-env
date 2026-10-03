# ==============================================================================
# deploy-all.ps1
# Windows PowerShell Script to deploy infra + 4 actors via Helm
# ==============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$K8sDir    = Split-Path -Parent $ScriptDir
$Namespace = "dataspace"

Write-Host ">>> Creating namespace '$Namespace'..." -ForegroundColor Cyan
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

Write-Host ">>> 1. Deploying/Upgrading Shared Infrastructure (Keycloak + MongoDB)..." -ForegroundColor Cyan
helm upgrade --install infra "$K8sDir\helm\dataspace-infra" -n $Namespace

Write-Host ">>> Waiting for Keycloak & MongoDB to become ready..." -ForegroundColor Yellow
kubectl wait --namespace $Namespace --for=condition=ready pod -l app=keycloak --timeout=180s
kubectl wait --namespace $Namespace --for=condition=ready pod -l app=mongodb --timeout=120s

Write-Host ">>> 2. Deploying/Upgrading 4 Dataspace Actors..." -ForegroundColor Cyan
$actors = @("oem", "tier1", "tier2", "tier3")
foreach ($actor in $actors) {
    Write-Host "  --> Deploying $actor..." -ForegroundColor Gray
    helm upgrade --install $actor "$K8sDir\helm\dataspace-actor" `
      -f "$K8sDir\values\actor-$actor.yaml" `
      -n $Namespace
}

Write-Host ">>> Waiting for Gateways..." -ForegroundColor Yellow
foreach ($actor in $actors) {
    kubectl wait --namespace $Namespace --for=condition=ready pod -l "app=$actor-gateway" --timeout=120s
}

Write-Host ">>> Waiting for AAS Environments..." -ForegroundColor Yellow
foreach ($actor in $actors) {
    kubectl wait --namespace $Namespace --for=condition=ready pod -l "app=$actor-aas" --timeout=180s
}

Write-Host "======================================================================" -ForegroundColor Green
Write-Host " Deployment Complete!" -ForegroundColor Green
Write-Host " Ingress Host Endpoints (on localhost:80 via Traefik):" -ForegroundColor White
Write-Host "   - Keycloak: http://keycloak.localhost" -ForegroundColor White
Write-Host "   - OEM:      http://oem.localhost" -ForegroundColor White
Write-Host "   - Tier 1:   http://tier1.localhost" -ForegroundColor White
Write-Host "   - Tier 2:   http://tier2.localhost" -ForegroundColor White
Write-Host "   - Tier 3:   http://tier3.localhost" -ForegroundColor White
Write-Host " Run tests with: & `"$K8sDir\tests\verify_4actor_chain.ps1`"" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Green
