# ==============================================================================
# verify_6actor_chain.ps1
# Windows PowerShell 5.1 & 7+ End-to-End Verification of the 6-Actor Dataspace
# Uses HttpWebRequest with explicit .Host property and 127.0.0.1 routing so it
# works on Windows without requiring C:\Windows\System32\drivers\etc\hosts
# ==============================================================================
$ErrorActionPreference = "Continue"
[System.Net.ServicePointManager]::DefaultConnectionLimit = 100

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
        $script:PassedTests++
    } else {
        Write-Host "  [FAIL] $desc (Expected HTTP $expected, got $actual)" -ForegroundColor Red
        $script:FailedTests++
    }
}

function Assert-Contains($haystack, $needle, $desc) {
    if ($haystack -like "*$needle*") {
        Write-Host "  [PASS] $desc (Found '$needle')" -ForegroundColor Green
        $script:PassedTests++
    } else {
        Write-Host "  [FAIL] $desc (Missing '$needle')" -ForegroundColor Red
        $script:FailedTests++
    }
}

# Helper that routes *.localhost to 127.0.0.1 and sets $req.Host directly
# (avoids .NET WebHeaderCollection ArgumentException on the 'Host' header)
function Invoke-DataspaceHttp {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$Body = $null,
        [string]$ContentType = $null
    )

    $parsed = [System.Uri]$Uri
    $targetHost = $parsed.Host
    $targetUri = $Uri

    if ($targetHost -like "*.localhost") {
        $portPart = if ($parsed.IsDefaultPort) { "" } else { ":$($parsed.Port)" }
        $targetUri = "$($parsed.Scheme)://127.0.0.1$portPart$($parsed.PathAndQuery)"
    }

    $resp = $null
    try {
        $req = [System.Net.HttpWebRequest]::Create($targetUri)
        $req.Method = $Method
        $req.Timeout = 10000
        $req.ReadWriteTimeout = 10000
        $req.KeepAlive = $false

        if ($targetHost -like "*.localhost") {
            $req.Host = if ($parsed.IsDefaultPort) { $targetHost } else { "$($targetHost):$($parsed.Port)" }
        }

        foreach ($k in $Headers.Keys) {
            if ($k -ieq "Accept") {
                $req.Accept = $Headers[$k]
            } elseif ($k -ieq "Host") {
                $req.Host = $Headers[$k]
            } elseif ($k -ieq "Content-Type") {
                $req.ContentType = $Headers[$k]
            } else {
                $req.Headers.Add($k, $Headers[$k])
            }
        }

        if ($null -ne $ContentType) {
            $req.ContentType = $ContentType
        }

        if ($null -ne $Body) {
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
            $req.ContentLength = $bodyBytes.Length
            $reqStream = $req.GetRequestStream()
            $reqStream.Write($bodyBytes, 0, $bodyBytes.Length)
            $reqStream.Close()
        }

        $resp = [System.Net.HttpWebResponse]$req.GetResponse()
        $statusCode = [int]$resp.StatusCode
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $content = $reader.ReadToEnd()
        $reader.Close()

        return @{
            StatusCode = $statusCode
            Content    = $content
        }
    } catch [System.Net.WebException] {
        $statusCode = 0
        $errBody = ""
        if ($_.Exception.Response) {
            $errResp = [System.Net.HttpWebResponse]$_.Exception.Response
            $statusCode = [int]$errResp.StatusCode
            try {
                $reader = New-Object System.IO.StreamReader($errResp.GetResponseStream(), [System.Text.Encoding]::UTF8)
                $errBody = $reader.ReadToEnd()
                $reader.Close()
            } catch {}
            $errResp.Close()
        }
        return @{
            StatusCode = $statusCode
            Content    = $errBody
            Error      = $_.Exception.Message
        }
    } catch {
        return @{
            StatusCode = 0
            Content    = ""
            Error      = $_.Exception.Message
        }
    } finally {
        if ($null -ne $resp) {
            $resp.Close()
        }
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
    $resp = Invoke-DataspaceHttp -Uri $url -Method "GET"
    if ($resp.StatusCode -eq 200) {
        Write-Host "  [PASS] $name is reachable (HTTP 200)" -ForegroundColor Green
        $script:PassedTests++
    } else {
        Write-Host "  [FAIL] $name unreachable at $url (HTTP $($resp.StatusCode)) $($resp.Error)" -ForegroundColor Red
        $script:FailedTests++
    }
}

function ConvertTo-Base64Url($text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Resolve-ActorGateway($assetId, $label) {
    $b64 = ConvertTo-Base64Url $assetId
    $resp = Invoke-DataspaceHttp -Uri "$LookupUrl/companies?asset_id=$b64" -Method "GET"
    if ($resp.StatusCode -eq 200 -and $resp.Content) {
        try {
            $json = $resp.Content | ConvertFrom-Json
            $ep = $json.result[0].endpoints | Where-Object { $_.interface -like "AAS-REPOSITORY*" } | Select-Object -First 1
            $gw = $ep.protocolInformation.href -replace '/shells$', ''
            if ($gw) {
                Write-Host "  [PASS] Resolved $label via Lookup: $gw" -ForegroundColor Green
                $script:PassedTests++
                return $gw
            }
        } catch {}
    }
    Write-Host "  [FAIL] Failed to resolve $label via Lookup ($assetId)" -ForegroundColor Red
    $script:FailedTests++
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

$rA = Invoke-DataspaceHttp -Uri "$ActorAGw/shells"
Assert-Status $rA.StatusCode 200 "Public query to Actor A /shells"
Assert-Contains $rA.Content "ServoMotorAAS" "Actor A returns ServoMotorAAS"

$rB = Invoke-DataspaceHttp -Uri "$ActorBGw/shells"
Assert-Status $rB.StatusCode 200 "Public query to Actor B /shells"
Assert-Contains $rB.Content "IndustrialGearboxAAS" "Actor B returns IndustrialGearboxAAS"

$rC = Invoke-DataspaceHttp -Uri "$ActorCGw/shells"
Assert-Status $rC.StatusCode 200 "Public query to Actor C /shells"
Assert-Contains $rC.Content "VibrationSensorAAS" "Actor C returns VibrationSensorAAS"

# Keycloak Token Retrieval
function Get-Token($realm, $clientId, $clientSecret) {
    $formBody = "grant_type=client_credentials&client_id=$clientId&client_secret=$clientSecret"
    $resp = Invoke-DataspaceHttp `
        -Uri "$KeycloakUrl/realms/$realm/protocol/openid-connect/token" `
        -Method "POST" `
        -Body $formBody `
        -ContentType "application/x-www-form-urlencoded"
    if ($resp.StatusCode -eq 200 -and $resp.Content) {
        $json = $resp.Content | ConvertFrom-Json
        return $json.access_token
    }
    Write-Host "  [FAIL] Failed to obtain token from realm $realm (HTTP $($resp.StatusCode)) $($resp.Error)" -ForegroundColor Red
    return $null
}

$TokenE = Get-Token "actor-e" "actor-e-client" "actor-e-secret-12345"
$TokenF = Get-Token "actor-f" "actor-f-client" "actor-f-secret-12345"
$TokenD = Get-Token "actor-d" "actor-d-client" "actor-d-secret-12345"

# Phase 2: Security Validation on Actor D
Log-Step "Phase 2: Security Validation on Actor D (Simulation SM Protection)"

$SmDSim = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:d:sm:machine-simulation"))

$unauthD = Invoke-DataspaceHttp -Uri "$ActorDGw/submodels/$SmDSim"
Assert-Status $unauthD.StatusCode 401 "Unauthenticated request to Actor D Simulation SM rejected (HTTP 401)"

$nonCustF = Invoke-DataspaceHttp -Uri "$ActorDGw/submodels/$SmDSim" -Headers @{ Authorization = "Bearer $TokenF" }
if ($nonCustF.StatusCode -eq 401 -or $nonCustF.StatusCode -eq 403) {
    Write-Host "  [PASS] Non-customer Actor F is denied access to Actor D Simulation SM (HTTP $($nonCustF.StatusCode))" -ForegroundColor Green
    $script:PassedTests++
} else {
    Write-Host "  [FAIL] Non-customer Actor F should be denied (got HTTP $($nonCustF.StatusCode))" -ForegroundColor Red
    $script:FailedTests++
}

# Phase 3: Customer E queries Actor D (Simulation SM)
Log-Step "Phase 3: Customer E queries Actor D (MachineTypeAAS & Simulation)"

$headersE = @{ Authorization = "Bearer $TokenE" }
$rDShells = Invoke-DataspaceHttp -Uri "$ActorDGw/shells" -Headers $headersE
Assert-Status $rDShells.StatusCode 200 "Customer E queries Actor D /shells"
Assert-Contains $rDShells.Content "MillingMachineTypeAAS" "Actor D returns MillingMachineTypeAAS"

$rDSim = Invoke-DataspaceHttp -Uri "$ActorDGw/submodels/$SmDSim" -Headers $headersE
Assert-Status $rDSim.StatusCode 200 "Customer E receives Simulation Submodel from Actor D"
Assert-Contains $rDSim.Content "KinematicAndThermalFEA" "Simulation model contains FEA parameters"

# Phase 4: Access Control on Actor E: Nameplate vs TimeSeries
Log-Step "Phase 4: Access Control on Actor E: Nameplate vs TimeSeries"

$SmENameplate  = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:e:sm:nameplate"))
$SmETimeSeries = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("urn:dataspace:e:sm:timeseries"))

$headersD = @{ Authorization = "Bearer $TokenD" }
$rENpD = Invoke-DataspaceHttp -Uri "$ActorEGw/submodels/$SmENameplate" -Headers $headersD
Assert-Status $rENpD.StatusCode 200 "Actor D reads Actor E Nameplate ('andere sehen Nameplate')"

$rETsD = Invoke-DataspaceHttp -Uri "$ActorEGw/submodels/$SmETimeSeries" -Headers $headersD
if ($rETsD.StatusCode -eq 401 -or $rETsD.StatusCode -eq 403) {
    Write-Host "  [PASS] Actor D is denied access to Actor E TimeSeries SM (HTTP $($rETsD.StatusCode))" -ForegroundColor Green
    $script:PassedTests++
} else {
    Write-Host "  [FAIL] Expected 401/403 for Actor D on TimeSeries, got $($rETsD.StatusCode)" -ForegroundColor Red
    $script:FailedTests++
}

# Phase 5: Customer F queries Actor E TimeSeries Submodel
Log-Step "Phase 5: Customer F queries Actor E TimeSeries Submodel"

$headersF = @{ Authorization = "Bearer $TokenF" }
$rETsF = Invoke-DataspaceHttp -Uri "$ActorEGw/submodels/$SmETimeSeries" -Headers $headersF
Assert-Status $rETsF.StatusCode 200 "Customer F receives TimeSeries Submodel from Actor E"
Assert-Contains $rETsF.Content "ProcessRecordCount" "TimeSeries contains process record count"
Assert-Contains $rETsF.Content "AverageMillingTemperatureCelsius" "TimeSeries contains milling temperature"

Log-Header "Verification Summary"
Write-Host "Total Tests Passed: $PassedTests" -ForegroundColor Green
Write-Host "Total Tests Failed: $FailedTests" -ForegroundColor $(if ($FailedTests -eq 0) { "Green" } else { "Red" })

if ($FailedTests -eq 0) {
    Write-Host "`nAll 6-Actor Dataspace Requirements Satisfied Successfully!`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed. Check logs above.`n" -ForegroundColor Red
    exit 1
}
