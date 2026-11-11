# ==============================================================================
# workbench.ps1
# Windows PowerShell Script to launch the Vue Dataspace Workbench UI
# ==============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$K8sDir       = Split-Path -Parent $ScriptDir
$RootDir      = Split-Path -Parent $K8sDir
$WorkbenchDir = Join-Path $RootDir "workbench"

if (-not (Test-Path (Join-Path $WorkbenchDir "node_modules"))) {
    Write-Host ">>> Installing workbench dependencies (npm install)..." -ForegroundColor Cyan
    Push-Location $WorkbenchDir
    npm install
    Pop-Location
}

Write-Host ">>> Starting Vue Dataspace Workbench on http://localhost:5173 ..." -ForegroundColor Green
Push-Location $WorkbenchDir
npm run dev
Pop-Location
