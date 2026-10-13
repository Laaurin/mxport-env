# ==============================================================================
# workbench.ps1
# Windows PowerShell Script to launch Dataspace Test Workbench UI
# ==============================================================================
$ErrorActionPreference = "Stop"

$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$K8sDir        = Split-Path -Parent $ScriptDir
$WorkbenchDir  = Join-Path $K8sDir "workbench"
$Port          = 3333

Write-Host ">>> Starting Dataspace Test Workbench on port $Port..." -ForegroundColor Cyan
Write-Host ">>> Serving UI at: http://localhost:$Port" -ForegroundColor Green

Start-Process "http://localhost:$Port"

node "$WorkbenchDir\server.js"
