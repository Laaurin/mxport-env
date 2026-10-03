# ==============================================================================
# verify_4actor_chain.ps1
# End-to-End Verification of 4-Actor Cascading Supply Chain in PowerShell
# ==============================================================================
$ErrorActionPreference = "Continue"

$Passed = 0
$Failed = 0

function Assert-Status {
    param([int]$Actual, [int]$Expected, [string]$Desc)
    if ($Actual -eq $Expected) {
        Write-Host "  [PASS] $Desc (HTTP $Actual)" -ForegroundColor Green
        $script:Passed++
    } else {
        Write-Host "  [FAIL] $Desc (Expected HTTP $Expected, got $Actual)" -ForegroundColor Red
        $script:Failed++
    }
}

function Assert-Contains {
    param([string]$Haystack, [string]$Needle, [string]$Desc)
    if ($Haystack -match [regex]::Escape($Needle)) {
        Write-Host "  [PASS] $Desc (Found '$Needle')" -ForegroundColor Green
        $script:Passed++
    } else {
        Write-Host "  [FAIL] $Desc (Missing '$Needle')" -ForegroundColor Red
        $script:Failed++
    }
}

$KeycloakUrl = "http://keycloak.localhost"
$OemGw       = "http://oem.localhost"
$Tier1Gw     = "http://tier1.localhost"
$Tier2Gw     = "http://tier2.localhost"
$Tier3Gw     = "http://tier3.localhost"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  4-Actor Dataspace Cascading Supply Chain Verification (PS)    " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Phase 0: Health Checks
Write-Host "`n>>> Phase 0: Checking Infrastructure & Gateway Health..." -ForegroundColor Yellow
$h = Invoke-WebRequest -Uri "$KeycloakUrl/realms/BaSyx/.well-known/openid-configuration" -Method GET -SkipHttpErrorCheck
Assert-Status $h.StatusCode 200 "Keycloak BaSyx Realm Health"

foreach ($pair in @(@{Name="OEM"; Url="$OemGw/healthz"}, @{Name="Tier 1"; Url="$Tier1Gw/healthz"}, @{Name="Tier 2"; Url="$Tier2Gw/healthz"}, @{Name="Tier 3"; Url="$Tier3Gw/healthz"})) {
    $r = Invoke-WebRequest -Uri $pair.Url -Method GET -SkipHttpErrorCheck
    Assert-Status $r.StatusCode 200 "$($pair.Name) Gateway Health"
}

# Phase 1: Tokens
Write-Host "`n>>> Phase 1: Fetching Tokens from Keycloak..." -ForegroundColor Yellow
function Get-KeycloakToken {
    param([string]$Realm, [string]$ClientId, [string]$Secret)
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $Secret
    }
    $resp = Invoke-RestMethod -Uri "$KeycloakUrl/realms/$Realm/protocol/openid-connect/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
    return $resp.access_token
}

$OemToken   = Get-KeycloakToken "oem" "oem-client" "oem-secret-12345"
$Tier1Token = Get-KeycloakToken "tier1" "tier1-client" "tier1-secret-12345"
$Tier2Token = Get-KeycloakToken "tier2" "tier2-client" "tier2-secret-12345"

if ($OemToken)   { Write-Host "  [PASS] Obtained OEM Token" -ForegroundColor Green; $Passed++ }
if ($Tier1Token) { Write-Host "  [PASS] Obtained Tier 1 Token" -ForegroundColor Green; $Passed++ }
if ($Tier2Token) { Write-Host "  [PASS] Obtained Tier 2 Token" -ForegroundColor Green; $Passed++ }

# Phase 2: Hop 1
Write-Host "`n>>> Phase 2: Hop 1 - OEM queries Tier 1 (BatteryPackAAS)..." -ForegroundColor Yellow
$h1Headers = @{ Authorization = "Bearer $OemToken" }
$r1 = Invoke-WebRequest -Uri "$Tier1Gw/shells" -Headers $h1Headers -SkipHttpErrorCheck
Assert-Status $r1.StatusCode 200 "OEM queries Tier 1 /shells"
Assert-Contains $r1.Content "BatteryPackAAS" "Tier 1 returns BatteryPackAAS"
Assert-Contains $r1.Content "urn:dataspace:tier1:aas:battery-pack-001" "BatteryPackAAS ID matches"

$smPackTech = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:tier1:sm:pack-tech-data"))
$r1Tech = Invoke-WebRequest -Uri "$Tier1Gw/submodels/$smPackTech" -Headers $h1Headers -SkipHttpErrorCheck
Assert-Status $r1Tech.StatusCode 200 "OEM queries Tier 1 Technical Data"
Assert-Contains $r1Tech.Content "PackCapacityKWh" "TechnicalData contains PackCapacityKWh"

$smPackPcf = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:tier1:sm:pack-pcf"))
$r1Pcf = Invoke-WebRequest -Uri "$Tier1Gw/submodels/$smPackPcf" -Headers $h1Headers -SkipHttpErrorCheck
Assert-Status $r1Pcf.StatusCode 200 "OEM queries Tier 1 Carbon Footprint"
Assert-Contains $r1Pcf.Content "2150.0" "CarbonFootprint contains 2150.0 kg CO2e"

# Phase 3: Hop 2
Write-Host "`n>>> Phase 3: Hop 2 - Tier 1 queries Tier 2 (BatteryModuleAAS)..." -ForegroundColor Yellow
$h2Headers = @{ Authorization = "Bearer $Tier1Token" }
$r2 = Invoke-WebRequest -Uri "$Tier2Gw/shells" -Headers $h2Headers -SkipHttpErrorCheck
Assert-Status $r2.StatusCode 200 "Tier 1 queries Tier 2 /shells"
Assert-Contains $r2.Content "BatteryModuleAAS" "Tier 2 returns BatteryModuleAAS"
Assert-Contains $r2.Content "urn:dataspace:tier2:aas:battery-module-001" "BatteryModuleAAS ID matches"

$smModTech = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:tier2:sm:module-tech-data"))
$r2Tech = Invoke-WebRequest -Uri "$Tier2Gw/submodels/$smModTech" -Headers $h2Headers -SkipHttpErrorCheck
Assert-Status $r2Tech.StatusCode 200 "Tier 1 queries Tier 2 Technical Data"
Assert-Contains $r2Tech.Content "12S1P" "TechnicalData contains 12S1P"

$smModPcf = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:tier2:sm:module-pcf"))
$r2Pcf = Invoke-WebRequest -Uri "$Tier2Gw/submodels/$smModPcf" -Headers $h2Headers -SkipHttpErrorCheck
Assert-Status $r2Pcf.StatusCode 200 "Tier 1 queries Tier 2 Carbon Footprint"
Assert-Contains $r2Pcf.Content "245.0" "CarbonFootprint contains 245.0 kg CO2e"

# Phase 4: Hop 3
Write-Host "`n>>> Phase 4: Hop 3 - Tier 2 queries Tier 3 (BatteryCellAAS)..." -ForegroundColor Yellow
$h3Headers = @{ Authorization = "Bearer $Tier2Token" }
$r3 = Invoke-WebRequest -Uri "$Tier3Gw/shells" -Headers $h3Headers -SkipHttpErrorCheck
Assert-Status $r3.StatusCode 200 "Tier 2 queries Tier 3 /shells"
Assert-Contains $r3.Content "BatteryCellAAS" "Tier 3 returns BatteryCellAAS"
Assert-Contains $r3.Content "urn:dataspace:tier3:aas:battery-cell-001" "BatteryCellAAS ID matches"

$smCellTech = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:tier3:sm:cell-tech-data"))
$r3Tech = Invoke-WebRequest -Uri "$Tier3Gw/submodels/$smCellTech" -Headers $h3Headers -SkipHttpErrorCheck
Assert-Status $r3Tech.StatusCode 200 "Tier 2 queries Tier 3 Technical Data"
Assert-Contains $r3Tech.Content "NMC 811" "TechnicalData contains NMC 811"

$smCellPcf = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:tier3:sm:cell-pcf"))
$r3Pcf = Invoke-WebRequest -Uri "$Tier3Gw/submodels/$smCellPcf" -Headers $h3Headers -SkipHttpErrorCheck
Assert-Status $r3Pcf.StatusCode 200 "Tier 2 queries Tier 3 Carbon Footprint"
Assert-Contains $r3Pcf.Content "18.5" "CarbonFootprint contains 18.5 kg CO2e"

# Phase 5: Boundary Enforcement (Negative Tests)
Write-Host "`n>>> Phase 5: Boundary Enforcement (Negative Tests)..." -ForegroundColor Yellow
$neg1 = Invoke-WebRequest -Uri "$Tier3Gw/shells" -Headers $h1Headers -SkipHttpErrorCheck
Assert-Status $neg1.StatusCode 401 "OEM bypass to Tier 3 blocked"

$neg2 = Invoke-WebRequest -Uri "$Tier2Gw/shells" -Headers $h1Headers -SkipHttpErrorCheck
Assert-Status $neg2.StatusCode 401 "OEM bypass to Tier 2 blocked"

$neg3 = Invoke-WebRequest -Uri "$Tier3Gw/shells" -Headers $h2Headers -SkipHttpErrorCheck
Assert-Status $neg3.StatusCode 401 "Tier 1 bypass to Tier 3 blocked"

$neg4 = Invoke-WebRequest -Uri "$Tier1Gw/shells" -SkipHttpErrorCheck
Assert-Status $neg4.StatusCode 401 "Unauthenticated request to Tier 1 blocked"

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  Results: Passed: $Passed | Failed: $Failed" -ForegroundColor $(if ($Failed -eq 0) { "Green" } else { "Red" })
Write-Host "================================================================" -ForegroundColor Cyan
if ($Failed -gt 0) { exit 1 } else { exit 0 }
