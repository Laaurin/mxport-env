# ==============================================================================
# setup-hosts.ps1
# Adds *.localhost entries for the 6-Actor Dataspace to Windows hosts file
# Must be run in an Administrator PowerShell session on Windows
# ==============================================================================
$ErrorActionPreference = "Stop"

$HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$Domains = @(
    "keycloak.localhost",
    "lookup.localhost",
    "actor-a.localhost",
    "actor-b.localhost",
    "actor-c.localhost",
    "actor-d.localhost",
    "actor-e.localhost",
    "actor-f.localhost",
    "viewer-a.localhost",
    "viewer-b.localhost",
    "viewer-c.localhost",
    "viewer-d.localhost",
    "viewer-e.localhost",
    "viewer-f.localhost"
)

$CurrentContent = Get-Content -Path $HostsFile -Raw -ErrorAction SilentlyContinue
if ($null -eq $CurrentContent) { $CurrentContent = "" }

$Added = 0
foreach ($d in $Domains) {
    if ($CurrentContent -notmatch "(?m)^\s*127\.0\.0\.1\s+.*\b$([regex]::Escape($d))\b") {
        Add-Content -Path $HostsFile -Value "127.0.0.1 $d"
        Write-Host "  [ADDED] 127.0.0.1 $d" -ForegroundColor Green
        $Added++
    } else {
        Write-Host "  [OK]    $d already in hosts file" -ForegroundColor DarkGray
    }
}

Write-Host "`n[OK] Windows hosts file check complete ($Added entries added)." -ForegroundColor Cyan
