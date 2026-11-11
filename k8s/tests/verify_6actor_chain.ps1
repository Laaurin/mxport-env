# ==============================================================================
# verify_6actor_chain.ps1
# Windows PowerShell End-to-End Verification of the 6-Actor Dataspace in k3d
# ==============================================================================
$ErrorActionPreference = "Continue"

$PassedTests = 0
$FailedTests = 0

function Log-Header($title) {
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
}

function Log-Step($step) {
    Write-Host "`n>>> $step" -ForegroundColor Yellow
}

function Assert-Status($actual, $expected, $desc) {
    if ($actual -eq $expected) {
        Write-Host "  [PASS] $desc (HTTP $actual)" -ForegroundColor Green
        $global:PassedTests++
    } else {
        Write-Host "  [FAIL] $desc (Expected HTTP $expected, got $actual)" -ForegroundColor Red
        $global:FailedTests++
    }
}

function Assert-Contains($haystack, $needle, $desc) {
    if ($haystack -like "*$needle*") {
        Write-Host "  [PASS] $desc (Found '$needle')" -ForegroundColor Green
        $global:PassedTests++
    } else {
        Write-Host "  [FAIL] $desc (Missing '$needle')" -ForegroundColor Red
        $global:FailedTests++
    }
}

$KeycloakUrl = "http://keycloak.localhost"
$LookupUrl   = "http://lookup.localhost/api/v2"
$ActorAGw    = "http://actor-a.localhost"
$ActorBGw    = "http://actor-b.localhost"
$ActorCGw    = "http://actor-c.localhost"
$ActorDGw    = "http://actor-d.localhost"
$ActorEGw    = "http://actor-e.localhost"
$ActorFGw    = "http://actor-f.localhost"

Log-Header "6-Actor Industrial Dataspace Verification"

# Phase 0: Health Checks & Dynamic Discovery via Company Lookup
Log-Step "Phase 0: Health Checks & Dynamic Discovery via Company Lookup"

function Check-Health($url, $name) {
    try {
        $resp = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($resp.StatusCode -eq 200) {
            Write-Host "  [PASS] $name is reachable (HTTP 200)" -ForegroundColor Green
            $global:PassedTests++
        } else {
            Write-Host "  [FAIL] $name unreachable at $url (HTTP $($resp.StatusCode))" -ForegroundColor Red
            $global:FailedTests++
        }
    } catch {
        Write-Host "  [FAIL] $name error at $url: $_" -ForegroundColor Red
        $global:FailedTests++
    }
}

function ConvertTo-Base64Url($text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Resolve-ActorGateway($assetId, $label) {
    try {
        $b64 = ConvertTo-Base64Url $assetId
        $r = Invoke-RestMethod -Uri "$LookupUrl/companies?asset_id=$b64" -Method Get -TimeoutSec 5
        $ep = $r.result[0].endpoints | Where-Object { $_.interface -like "AAS-REPOSITORY*" } | Select-Object -First 1
        $gw = $ep.protocolInformation.href -replace '/shells$', ''
        if ($gw) {
            Write-Host "  [PASS] Resolved $label via Lookup: $gw" -ForegroundColor Green
            $global:PassedTests++
            return $gw
        }
    } catch {}
    Write-Host "  [FAIL] Failed to resolve $label via Lookup ($assetId)" -ForegroundColor Red
    $global:FailedTests++
    return $null
}

Check-Health "$KeycloakUrl/realms/BaSyx/.well-known/openid-configuration" "Keycloak (BaSyx Realm)"
Check-Health "$LookupUrl/openapi.json" "Company Lookup Service"

$resA = Resolve-ActorGateway "urn:dataspace:a:aas:servo-motor-001" "Actor A"
$resB = Resolve-ActorGateway "urn:dataspace:b:aas:gearbox-001" "Actor B"
$resC = Resolve-ActorGateway "urn:dataspace:c:aas:sensor-001" "Actor C"
$resD = Resolve-ActorGateway "urn:dataspace:d:aas:machine-type-001" "Actor D"
$resE = Resolve-ActorGateway "urn:dataspace:e:aas:produced-part-001" "Actor E"
$resF = Resolve-ActorGateway "urn:dataspace:f:aas:customer-profile-001" "Actor F"

if ($resA) { $ActorAGw = $resA }
if ($resB) { $ActorBGw = $resB }
if ($resC) { $ActorCGw = $resC }
if ($resD) { $ActorDGw = $resD }
if ($resE) { $ActorEGw = $resE }
if ($resF) { $ActorFGw = $resF }
Check-Health "$ActorAGw/healthz" "Actor A Gateway"
Check-Health "$ActorBGw/healthz" "Actor B Gateway"
Check-Health "$ActorCGw/healthz" "Actor C Gateway"
Check-Health "$ActorDGw/healthz" "Actor D Gateway"
Check-Health "$ActorEGw/healthz" "Actor E Gateway"
Check-Health "$ActorFGw/healthz" "Actor F Gateway"

# Phase 1: Public Product Information (Actor A, B, C)
Log-Step "Phase 1: Public Access to Product Information (Actor A, B, C)"

try {
    $rA = Invoke-WebRequest -Uri "$ActorAGw/shells" -Method Get -UseBasicParsing
    Assert-Status $rA.StatusCode 200 "Public query to Actor A /shells"
    Assert-Contains $rA.Content "ServoMotorAAS" "Actor A returns ServoMotorAAS"
} catch {
    Assert-Status 0 200 "Public query to Actor A /shells failed: $_"
}

try {
    $rB = Invoke-WebRequest -Uri "$ActorBGw/shells" -Method Get -UseBasicParsing
    Assert-Status $rB.StatusCode 200 "Public query to Actor B /shells"
    Assert-Contains $rB.Content "IndustrialGearboxAAS" "Actor B returns IndustrialGearboxAAS"
} catch {
    Assert-Status 0 200 "Public query to Actor B /shells failed: $_"
}

try {
    $rC = Invoke-WebRequest -Uri "$ActorCGw/shells" -Method Get -UseBasicParsing
    Assert-Status $rC.StatusCode 200 "Public query to Actor C /shells"
    Assert-Contains $rC.Content "VibrationSensorAAS" "Actor C returns VibrationSensorAAS"
} catch {
    Assert-Status 0 200 "Public query to Actor C /shells failed: $_"
}

# Keycloak Token Retrieval
function Get-Token($realm, $clientId, $clientSecret) {
    try {
        $body = @{
            grant_type    = "client_credentials"
            client_id     = $clientId
            client_secret = $clientSecret
        }
        $r = Invoke-RestMethod -Uri "$KeycloakUrl/realms/$realm/protocol/openid-connect/token" -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
        return $r.access_token
    } catch {
        Write-Host "  [FAIL] Failed to obtain token from realm $realm: $_" -ForegroundColor Red
        return $null
    }
}

$TokenE = Get-Token "actor-e" "actor-e-client" "actor-e-secret-12345"
$TokenF = Get-Token "actor-f" "actor-f-client" "actor-f-secret-12345"
$TokenD = Get-Token "actor-d" "actor-d-client" "actor-d-secret-12345"

# Phase 2: Security Validation on Actor D
Log-Step "Phase 2: Security Validation on Actor D (Simulation SM Protection)"

$SmDSim = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:d:sm:machine-simulation"))

try {
    $unauthD = Invoke-WebRequest -Uri "$ActorDGw/submodels/$SmDSim" -Method Get -UseBasicParsing -ErrorAction Stop
    Assert-Status $unauthD.StatusCode 401 "Unauthenticated request to Actor D Simulation SM should be rejected"
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Assert-Status $code 401 "Unauthenticated request to Actor D Simulation SM rejected (HTTP 401)"
}

# Phase 3: Customer E queries Actor D (Simulation SM)
Log-Step "Phase 3: Customer E queries Actor D (MachineTypeAAS & Simulation)"

try {
    $headersE = @{ Authorization = "Bearer $TokenE" }
    $rDShells = Invoke-WebRequest -Uri "$ActorDGw/shells" -Headers $headersE -Method Get -UseBasicParsing
    Assert-Status $rDShells.StatusCode 200 "Customer E queries Actor D /shells"
    Assert-Contains $rDShells.Content "MillingMachineTypeAAS" "Actor D returns MillingMachineTypeAAS"

    $rDSim = Invoke-WebRequest -Uri "$ActorDGw/submodels/$SmDSim" -Headers $headersE -Method Get -UseBasicParsing
    Assert-Status $rDSim.StatusCode 200 "Customer E receives Simulation Submodel from Actor D"
    Assert-Contains $rDSim.Content "KinematicAndThermalFEA" "Simulation model contains FEA parameters"
} catch {
    Write-Host "  [FAIL] Customer E failed to query Actor D: $_" -ForegroundColor Red
    $global:FailedTests++
}

# Phase 4: Access Control on Actor E: Nameplate vs TimeSeries
Log-Step "Phase 4: Access Control on Actor E: Nameplate vs TimeSeries"

$SmENameplate  = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:e:sm:nameplate"))
$SmETimeSeries = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:e:sm:timeseries"))

try {
    $headersD = @{ Authorization = "Bearer $TokenD" }
    $rENpD = Invoke-WebRequest -Uri "$ActorEGw/submodels/$SmENameplate" -Headers $headersD -Method Get -UseBasicParsing
    Assert-Status $rENpD.StatusCode 200 "Actor D reads Actor E Nameplate ('andere sehen Nameplate')"
} catch {
    Write-Host "  [FAIL] Actor D failed to read Nameplate: $_" -ForegroundColor Red
    $global:FailedTests++
}

try {
    $rETsD = Invoke-WebRequest -Uri "$ActorEGw/submodels/$SmETimeSeries" -Headers $headersD -Method Get -UseBasicParsing -ErrorAction Stop
    Write-Host "  [FAIL] Actor D should not have access to TimeSeries SM (HTTP $($rETsD.StatusCode))" -ForegroundColor Red
    $global:FailedTests++
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code -eq 401 -or $code -eq 403) {
        Write-Host "  [PASS] Actor D is denied access to Actor E TimeSeries SM (HTTP $code)" -ForegroundColor Green
        $global:PassedTests++
    } else {
        Write-Host "  [FAIL] Expected 401/403, got $code" -ForegroundColor Red
        $global:FailedTests++
    }
}

# Phase 5: Customer F queries Actor E TimeSeries Submodel
Log-Step "Phase 5: Customer F queries Actor E TimeSeries Submodel"

try {
    $headersF = @{ Authorization = "Bearer $TokenF" }
    $rETsF = Invoke-WebRequest -Uri "$ActorEGw/submodels/$SmETimeSeries" -Headers $headersF -Method Get -UseBasicParsing
    Assert-Status $rETsF.StatusCode 200 "Customer F receives TimeSeries Submodel from Actor E"
    Assert-Contains $rETsF.Content "ProcessRecordCount" "TimeSeries contains process record count"
    Assert-Contains $rETsF.Content "AverageMillingTemperatureCelsius" "TimeSeries contains milling temperature"
} catch {
    Write-Host "  [FAIL] Customer F failed to query TimeSeries: $_" -ForegroundColor Red
    $global:FailedTests++
}

Log-Header "Verification Summary"
Write-Host "Total Tests Passed: $PassedTests" -ForegroundColor Green
Write-Host "Total Tests Failed: $FailedTests" -ForegroundColor $(if ($FailedTests -eq 0) { "Green" } else { "Red" })

if ($FailedTests -eq 0) {
    Write-Host "`nAll 6-Actor Dataspace Requirements Satisfied Successfully!`n" -ForegroundColor Green
} else {
    Write-Host "`nSome tests failed. Check logs above.`n" -ForegroundColor Red
}
