#!/usr/bin/env bash
# ==============================================================================
# verify_4actor_chain.sh
# End-to-End Verification of the 4-Actor Cascading Supply Chain in k3d
#
# Supply Chain Cascade:
#   OEM (Client) ──► Tier 1 (Battery Pack)
#                      └──► Tier 2 (Battery Module)
#                             └──► Tier 3 (Battery Cell)
#
# Enforces:
#   1. Valid RFC 8693 Token Exchange at each hop via Siemens STS
#   2. Dynamic RBAC Submodel validation in BaSyx AAS
#   3. Isolation: Direct cross-hop skips (e.g. OEM -> Tier 3) are rejected (401)
# ==============================================================================
set -euo pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASSED_TESTS=0
FAILED_TESTS=0

log_header() {
  echo -e "\n${BOLD}${BLUE}================================================================${NC}" >&2
  echo -e "${BOLD}${BLUE}  $1${NC}" >&2
  echo -e "${BOLD}${BLUE}================================================================${NC}" >&2
}

log_step() {
  echo -e "\n${BOLD}${YELLOW}>>> $1${NC}" >&2
}

log_success() {
  echo -e "  ${GREEN}✓ PASS:${NC} $1" >&2
  PASSED_TESTS=$((PASSED_TESTS + 1))
}

log_fail() {
  echo -e "  ${RED}✗ FAIL:${NC} $1" >&2
  FAILED_TESTS=$((FAILED_TESTS + 1))
}

assert_status() {
  local actual="$1"
  local expected="$2"
  local desc="$3"
  if [[ "$actual" == "$expected" ]]; then
    log_success "$desc (HTTP $actual)"
  else
    log_fail "$desc (Expected HTTP $expected, got $actual)"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local desc="$3"
  if echo "$haystack" | grep -q "$needle"; then
    log_success "$desc (Found '$needle')"
  else
    log_fail "$desc (Missing '$needle')"
  fi
}

KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak.localhost}"
OEM_GW="${OEM_GW:-http://oem.localhost}"
TIER1_GW="${TIER1_GW:-http://tier1.localhost}"
TIER2_GW="${TIER2_GW:-http://tier2.localhost}"
TIER3_GW="${TIER3_GW:-http://tier3.localhost}"

log_header "4-Actor Dataspace Cascading Supply Chain Verification"
echo "Keycloak Base URL: $KEYCLOAK_URL"
echo "OEM Gateway:       $OEM_GW"
echo "Tier 1 Gateway:    $TIER1_GW"
echo "Tier 2 Gateway:    $TIER2_GW"
echo "Tier 3 Gateway:    $TIER3_GW"

# ------------------------------------------------------------------------------
# Phase 0: Infrastructure Health Check
# ------------------------------------------------------------------------------
log_step "Phase 0: Checking Infrastructure & Gateway Health"

check_health() {
  local url="$1"
  local name="$2"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
  if [[ "$code" == "200" ]]; then
    log_success "$name is reachable (HTTP 200)"
  else
    log_fail "$name unreachable at $url (HTTP $code)"
  fi
}

check_health "$KEYCLOAK_URL/realms/BaSyx/.well-known/openid-configuration" "Keycloak (BaSyx Realm)"
check_health "$OEM_GW/healthz" "OEM Gateway"
check_health "$TIER1_GW/healthz" "Tier 1 Gateway"
check_health "$TIER2_GW/healthz" "Tier 2 Gateway"
check_health "$TIER3_GW/healthz" "Tier 3 Gateway"

# ------------------------------------------------------------------------------
# Phase 1: Obtain Client Credentials Tokens from Keycloak
# ------------------------------------------------------------------------------
log_step "Phase 1: Fetching Identity Tokens from Keycloak Realms"

get_token() {
  local realm="$1"
  local client_id="$2"
  local client_secret="$3"
  local resp
  resp=$(curl -s -X POST "$KEYCLOAK_URL/realms/$realm/protocol/openid-connect/token" \
    -d "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret" \
    -H "Content-Type: application/x-www-form-urlencoded")
  local token
  token=$(echo "$resp" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || true)
  if [[ -n "$token" ]]; then
    log_success "Obtained token for $client_id in realm $realm"
    echo "$token"
  else
    log_fail "Failed to get token for $client_id: $resp"
    echo ""
  fi
}

OEM_TOKEN=$(get_token "oem" "oem-client" "oem-secret-12345")
TIER1_TOKEN=$(get_token "tier1" "tier1-client" "tier1-secret-12345")
TIER2_TOKEN=$(get_token "tier2" "tier2-client" "tier2-secret-12345")

# ------------------------------------------------------------------------------
# Phase 2: Hop 1: OEM -> Tier 1 (Battery Pack)
# ------------------------------------------------------------------------------
log_step "Phase 2: Hop 1 - OEM queries Tier 1 (BatteryPackAAS)"

PACK_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $OEM_TOKEN" "$TIER1_GW/shells")
PACK_CODE=$(echo "$PACK_RESP" | tail -n1)
PACK_BODY=$(echo "$PACK_RESP" | sed '$d')

assert_status "$PACK_CODE" "200" "OEM queries Tier 1 /shells"
assert_contains "$PACK_BODY" "BatteryPackAAS" "Tier 1 returns BatteryPackAAS"
assert_contains "$PACK_BODY" "urn:dataspace:tier1:aas:battery-pack-001" "BatteryPackAAS ID matches"

# Query Technical Data
SM_PACK_TECH=$(echo -n "urn:dataspace:tier1:sm:pack-tech-data" | base64)
TECH_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $OEM_TOKEN" "$TIER1_GW/submodels/$SM_PACK_TECH")
TECH_CODE=$(echo "$TECH_RESP" | tail -n1)
TECH_BODY=$(echo "$TECH_RESP" | sed '$d')

assert_status "$TECH_CODE" "200" "OEM queries Tier 1 TechnicalData submodel"
assert_contains "$TECH_BODY" "PackCapacityKWh" "TechnicalData contains PackCapacityKWh"

# Query Carbon Footprint
SM_PACK_PCF=$(echo -n "urn:dataspace:tier1:sm:pack-pcf" | base64)
PCF_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $OEM_TOKEN" "$TIER1_GW/submodels/$SM_PACK_PCF")
PCF_CODE=$(echo "$PCF_RESP" | tail -n1)
PCF_BODY=$(echo "$PCF_RESP" | sed '$d')

assert_status "$PCF_CODE" "200" "OEM queries Tier 1 CarbonFootprint submodel"
assert_contains "$PCF_BODY" "ProductCarbonFootprintKgCO2e" "CarbonFootprint contains PCF value"

# ------------------------------------------------------------------------------
# Phase 3: Hop 2: Tier 1 -> Tier 2 (Battery Module)
# ------------------------------------------------------------------------------
log_step "Phase 3: Hop 2 - Tier 1 queries Tier 2 (BatteryModuleAAS)"

MODULE_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TIER1_TOKEN" "$TIER2_GW/shells")
MODULE_CODE=$(echo "$MODULE_RESP" | tail -n1)
MODULE_BODY=$(echo "$MODULE_RESP" | sed '$d')

assert_status "$MODULE_CODE" "200" "Tier 1 queries Tier 2 /shells"
assert_contains "$MODULE_BODY" "BatteryModuleAAS" "Tier 2 returns BatteryModuleAAS"
assert_contains "$MODULE_BODY" "urn:dataspace:tier2:aas:battery-module-001" "BatteryModuleAAS ID matches"

# Query Technical Data
SM_MOD_TECH=$(echo -n "urn:dataspace:tier2:sm:module-tech-data" | base64)
MOD_TECH_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TIER1_TOKEN" "$TIER2_GW/submodels/$SM_MOD_TECH")
MOD_TECH_CODE=$(echo "$MOD_TECH_RESP" | tail -n1)
MOD_TECH_BODY=$(echo "$MOD_TECH_RESP" | sed '$d')

assert_status "$MOD_TECH_CODE" "200" "Tier 1 queries Tier 2 TechnicalData submodel"
assert_contains "$MOD_TECH_BODY" "CellConfiguration" "TechnicalData contains CellConfiguration"
assert_contains "$MOD_TECH_BODY" "12S1P" "TechnicalData contains 12S1P"

# ------------------------------------------------------------------------------
# Phase 4: Hop 3: Tier 2 -> Tier 3 (Battery Cell)
# ------------------------------------------------------------------------------
log_step "Phase 4: Hop 3 - Tier 2 queries Tier 3 (BatteryCellAAS)"

CELL_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TIER2_TOKEN" "$TIER3_GW/shells")
CELL_CODE=$(echo "$CELL_RESP" | tail -n1)
CELL_BODY=$(echo "$CELL_RESP" | sed '$d')

assert_status "$CELL_CODE" "200" "Tier 2 queries Tier 3 /shells"
assert_contains "$CELL_BODY" "BatteryCellAAS" "Tier 3 returns BatteryCellAAS"
assert_contains "$CELL_BODY" "urn:dataspace:tier3:aas:battery-cell-001" "BatteryCellAAS ID matches"

# Query Technical Data
SM_CELL_TECH=$(echo -n "urn:dataspace:tier3:sm:cell-tech-data" | base64)
CELL_TECH_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TIER2_TOKEN" "$TIER3_GW/submodels/$SM_CELL_TECH")
CELL_TECH_CODE=$(echo "$CELL_TECH_RESP" | tail -n1)
CELL_TECH_BODY=$(echo "$CELL_TECH_RESP" | sed '$d')

assert_status "$CELL_TECH_CODE" "200" "Tier 2 queries Tier 3 TechnicalData submodel"
assert_contains "$CELL_TECH_BODY" "NMC 811" "TechnicalData contains NMC 811 chemistry"

# Query PCF
SM_CELL_PCF=$(echo -n "urn:dataspace:tier3:sm:cell-pcf" | base64)
CELL_PCF_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TIER2_TOKEN" "$TIER3_GW/submodels/$SM_CELL_PCF")
CELL_PCF_CODE=$(echo "$CELL_PCF_RESP" | tail -n1)
CELL_PCF_BODY=$(echo "$CELL_PCF_RESP" | sed '$d')

assert_status "$CELL_PCF_CODE" "200" "Tier 2 queries Tier 3 CarbonFootprint submodel"
assert_contains "$CELL_PCF_BODY" "18.5" "CarbonFootprint contains 18.5 kg CO2e"

# ------------------------------------------------------------------------------
# Phase 5: Negative Tests & Cascading Security Isolation
# ------------------------------------------------------------------------------
log_step "Phase 5: Negative Testing - Verifying Dataspace Boundary Enforcement"

# 1. OEM directly calls Tier 3 (must be rejected by Tier 3 STS)
NEG1_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $OEM_TOKEN" "$TIER3_GW/shells")
assert_status "$NEG1_CODE" "401" "OEM bypass call to Tier 3 is blocked"

# 2. OEM directly calls Tier 2 (must be rejected by Tier 2 STS)
NEG2_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $OEM_TOKEN" "$TIER2_GW/shells")
assert_status "$NEG2_CODE" "401" "OEM bypass call to Tier 2 is blocked"

# 3. Tier 1 directly calls Tier 3 (must be rejected by Tier 3 STS)
NEG3_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TIER1_TOKEN" "$TIER3_GW/shells")
assert_status "$NEG3_CODE" "401" "Tier 1 bypass call to Tier 3 is blocked"

# 4. Request with no token at all
NEG4_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TIER1_GW/shells")
assert_status "$NEG4_CODE" "401" "Unauthenticated request to Tier 1 is blocked"

# 5. Request with forged / bogus token
NEG5_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.e30.fake" "$TIER1_GW/shells")
assert_status "$NEG5_CODE" "401" "Bogus token request to Tier 1 is blocked"

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
log_header "Verification Results"
echo -e "${GREEN}Passed Tests: $PASSED_TESTS${NC}"
if [[ "$FAILED_TESTS" -gt 0 ]]; then
  echo -e "${RED}Failed Tests: $FAILED_TESTS${NC}"
  exit 1
else
  echo -e "${BOLD}${GREEN}All tests passed successfully! 4-Actor Cascading Supply Chain is fully operational.${NC}\n"
  exit 0
fi
