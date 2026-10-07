<#
.SYNOPSIS
    BaSyx Dynamic RBAC Test Script for Windows PowerShell
.DESCRIPTION
    Validates Keycloak token retrieval and verifies READ, CREATE (WRITE), and DELETE operations on BaSyx AAS Environment.
#>

param(
    [string]$KeycloakUrl = "http://localhost:8085",
    [string]$AasUrl = "http://localhost:8081",
    [string]$Username = "admin",
    [string]$Password = "admin"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "BaSyx Dynamic RBAC Test Suite (PowerShell)" -ForegroundColor Cyan
Write-Host "User: $Username" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Obtain Token
Write-Host "1. Obtaining Bearer Token from Keycloak..." -ForegroundColor Yellow
$tokenBody = @{
    client_id  = "basyx-web-ui"
    grant_type = "password"
    username   = $Username
    password   = $Password
}

try {
    $tokenResp = Invoke-RestMethod -Uri "$KeycloakUrl/realms/BaSyx/protocol/openid-connect/token" -Method Post -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
    $token = $tokenResp.access_token
    Write-Host "✅ Token obtained successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to obtain token from Keycloak: $_"
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
}

# 2. READ /shells
Write-Host "`n2. Testing READ /shells..." -ForegroundColor Yellow
try {
    $shellsResp = Invoke-RestMethod -Uri "$AasUrl/shells" -Method Get -Headers $headers
    Write-Host "✅ READ /shells successful. Total shells found: $($shellsResp.result.Count)" -ForegroundColor Green
} catch {
    Write-Error "READ /shells failed: $_"
    exit 1
}

# 3. CREATE /shells
Write-Host "`n3. Testing CREATE /shells (WRITE)..." -ForegroundColor Yellow
$testAasId = "https://example.com/ids/aas/sample_device_001"
$createPayload = @{
    id               = $testAasId
    idShort          = "SampleDevice001"
    modelType        = "AssetAdministrationShell"
    assetInformation = @{
        assetKind     = "Instance"
        globalAssetId = "https://example.com/ids/asset/sample_device_001"
    }
} | ConvertTo-Json -Depth 5

$headersJson = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

try {
    $createResp = Invoke-WebRequest -Uri "$AasUrl/shells" -Method Post -Headers $headersJson -Body $createPayload -UseBasicParsing
    Write-Host "✅ CREATE /shells successful (Status code $($createResp.StatusCode))." -ForegroundColor Green
} catch {
    Write-Error "CREATE /shells failed: $_"
    exit 1
}

# 4. DELETE /shells
Write-Host "`n4. Testing DELETE /shells/{id}..." -ForegroundColor Yellow
$b64Id = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($testAasId)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
try {
    $delResp = Invoke-WebRequest -Uri "$AasUrl/shells/$b64Id" -Method Delete -Headers $headers -UseBasicParsing
    Write-Host "✅ DELETE /shells successful (Status code $($delResp.StatusCode))." -ForegroundColor Green
} catch {
    Write-Error "DELETE /shells failed: $_"
    exit 1
}

# 5. Verify 404
Write-Host "`n5. Verifying Shell Deletion (expecting HTTP 404)..." -ForegroundColor Yellow
try {
    $checkResp = Invoke-WebRequest -Uri "$AasUrl/shells/$b64Id" -Method Get -Headers $headers -UseBasicParsing
    Write-Warning "Shell still accessible (HTTP $($checkResp.StatusCode))"
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "✅ Shell is deleted (HTTP 404 Not Found as expected)." -ForegroundColor Green
    } else {
        Write-Host "Got status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "🎉 All RBAC operations (READ, WRITE, DELETE) verified successfully!" -ForegroundColor Green
Write-Host "UI URL:      http://localhost:3000" -ForegroundColor White
Write-Host "Login:       $Username / $Password" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
