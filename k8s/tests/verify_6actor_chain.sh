#!/usr/bin/env bash
# ==============================================================================
# verify_6actor_chain.sh
# End-to-End Verification of the 6-Actor Dataspace in k3d
#
# Scenario:
#   - Akteur A, B, C: Public product information on AAS Repo (Motor, Gearbox, Sensor).
#   - Akteur D: Machine Manufacturer, compares data of A, B, C;
#               hosts MachineTypeAAS with protected Simulation Submodel (Keycloak + SecSM).
#   - Akteur E: Buys machine from D -> has access to D's Machine + Simulation.
#               Manufactures products, logs TimeSeries SM in its AAS Repo.
#               Customers get access to TimeSeries SM; others see only Nameplate.
#   - Akteur F: Buys product from E -> gets access to TimeSeries Submodel.
# ==============================================================================
set -euo pipefail

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
ACTOR_A_GW="${ACTOR_A_GW:-http://actor-a.localhost}"
ACTOR_B_GW="${ACTOR_B_GW:-http://actor-b.localhost}"
ACTOR_C_GW="${ACTOR_C_GW:-http://actor-c.localhost}"
ACTOR_D_GW="${ACTOR_D_GW:-http://actor-d.localhost}"
ACTOR_E_GW="${ACTOR_E_GW:-http://actor-e.localhost}"
ACTOR_F_GW="${ACTOR_F_GW:-http://actor-f.localhost}"

log_header "6-Actor Industrial Dataspace Verification"
echo "Keycloak: $KEYCLOAK_URL"
echo "Actor A:  $ACTOR_A_GW"
echo "Actor B:  $ACTOR_B_GW"
echo "Actor C:  $ACTOR_C_GW"
echo "Actor D:  $ACTOR_D_GW"
echo "Actor E:  $ACTOR_E_GW"
echo "Actor F:  $ACTOR_F_GW"

# ------------------------------------------------------------------------------
# Phase 0: Health Checks
# ------------------------------------------------------------------------------
log_step "Phase 0: Health Checks"

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
check_health "$ACTOR_A_GW/healthz" "Actor A Gateway"
check_health "$ACTOR_B_GW/healthz" "Actor B Gateway"
check_health "$ACTOR_C_GW/healthz" "Actor C Gateway"
check_health "$ACTOR_D_GW/healthz" "Actor D Gateway"
check_health "$ACTOR_E_GW/healthz" "Actor E Gateway"
check_health "$ACTOR_F_GW/healthz" "Actor F Gateway"

# ------------------------------------------------------------------------------
# Phase 1: Public Product Information (Actor A, B, C)
# ------------------------------------------------------------------------------
log_step "Phase 1: Public Access to Product Information (Actor A, B, C)"

# Actor A: Servo Motor
RESP_A=$(curl -s -w "\n%{http_code}" "$ACTOR_A_GW/shells")
CODE_A=$(echo "$RESP_A" | tail -n1)
BODY_A=$(echo "$RESP_A" | sed '$d')
assert_status "$CODE_A" "200" "Public query to Actor A /shells (no token required)"
assert_contains "$BODY_A" "ServoMotorAAS" "Actor A returns ServoMotorAAS"

SM_A_TECH=$(echo -n "urn:dataspace:a:sm:technical-data" | base64)
RESP_A_TECH=$(curl -s -w "\n%{http_code}" "$ACTOR_A_GW/submodels/$SM_A_TECH")
CODE_A_TECH=$(echo "$RESP_A_TECH" | tail -n1)
BODY_A_TECH=$(echo "$RESP_A_TECH" | sed '$d')
assert_status "$CODE_A_TECH" "200" "Public query to Actor A TechnicalData submodel"
assert_contains "$BODY_A_TECH" "NominalPowerKW" "Actor A returns motor technical data"

# Actor B: Industrial Gearbox
RESP_B=$(curl -s -w "\n%{http_code}" "$ACTOR_B_GW/shells")
CODE_B=$(echo "$RESP_B" | tail -n1)
BODY_B=$(echo "$RESP_B" | sed '$d')
assert_status "$CODE_B" "200" "Public query to Actor B /shells (no token required)"
assert_contains "$BODY_B" "IndustrialGearboxAAS" "Actor B returns IndustrialGearboxAAS"

SM_B_TECH=$(echo -n "urn:dataspace:b:sm:technical-data" | base64)
RESP_B_TECH=$(curl -s -w "\n%{http_code}" "$ACTOR_B_GW/submodels/$SM_B_TECH")
CODE_B_TECH=$(echo "$RESP_B_TECH" | tail -n1)
BODY_B_TECH=$(echo "$RESP_B_TECH" | sed '$d')
assert_status "$CODE_B_TECH" "200" "Public query to Actor B TechnicalData submodel"
assert_contains "$BODY_B_TECH" "GearRatio" "Actor B returns gearbox technical data"

# Actor C: Vibration Sensor
RESP_C=$(curl -s -w "\n%{http_code}" "$ACTOR_C_GW/shells")
CODE_C=$(echo "$RESP_C" | tail -n1)
BODY_C=$(echo "$RESP_C" | sed '$d')
assert_status "$CODE_C" "200" "Public query to Actor C /shells (no token required)"
assert_contains "$BODY_C" "VibrationSensorAAS" "Actor C returns VibrationSensorAAS"

SM_C_TECH=$(echo -n "urn:dataspace:c:sm:technical-data" | base64)
RESP_C_TECH=$(curl -s -w "\n%{http_code}" "$ACTOR_C_GW/submodels/$SM_C_TECH")
CODE_C_TECH=$(echo "$RESP_C_TECH" | tail -n1)
BODY_C_TECH=$(echo "$RESP_C_TECH" | sed '$d')
assert_status "$CODE_C_TECH" "200" "Public query to Actor C TechnicalData submodel"
assert_contains "$BODY_C_TECH" "SamplingRateKHz" "Actor C returns sensor technical data"

# ------------------------------------------------------------------------------
# Phase 2: Negative Testing on Actor D (Protected Simulation Submodel)
# ------------------------------------------------------------------------------
log_step "Phase 2: Security Validation on Actor D (Simulation SM Protection)"

SM_D_SIM=$(echo -n "urn:dataspace:d:sm:machine-simulation" | base64)

# 2.1 Unauthenticated query to D's Simulation Submodel (Must fail with 401)
UNAUTH_RESP=$(curl -s -w "\n%{http_code}" "$ACTOR_D_GW/submodels/$SM_D_SIM")
UNAUTH_CODE=$(echo "$UNAUTH_RESP" | tail -n1)
assert_status "$UNAUTH_CODE" "401" "Unauthenticated request to Actor D Simulation SM is rejected"

# Function to get token from Keycloak
get_token() {
  local realm="$1"
  local client_id="$2"
  local client_secret="$3"
  local resp
  resp=$(curl -s -X POST "$KEYCLOAK_URL/realms/$realm/protocol/openid-connect/token" \
    -d "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret" \
    -H "Content-Type: application/x-www-form-urlencoded")
  echo "$resp" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4 || true
}

TOKEN_E=$(get_token "actor-e" "actor-e-client" "actor-e-secret-12345")
TOKEN_F=$(get_token "actor-f" "actor-f-client" "actor-f-secret-12345")
TOKEN_D=$(get_token "actor-d" "actor-d-client" "actor-d-secret-12345")

if [[ -n "$TOKEN_E" ]]; then
  log_success "Obtained Actor E token (role: customer-d)"
else
  log_fail "Failed to obtain token for Actor E"
fi

if [[ -n "$TOKEN_F" ]]; then
  log_success "Obtained Actor F token (role: customer-e)"
else
  log_fail "Failed to obtain token for Actor F"
fi

# 2.2 Unauthorized query: Actor F queries Actor D Simulation SM (Must be rejected)
UNAUTH_F_RESP=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN_F" "$ACTOR_D_GW/submodels/$SM_D_SIM")
UNAUTH_F_CODE=$(echo "$UNAUTH_F_RESP" | tail -n1)
if [[ "$UNAUTH_F_CODE" =~ ^(401|403)$ ]]; then
  log_success "Non-customer Actor F is denied access to Actor D Simulation SM (HTTP $UNAUTH_F_CODE)"
else
  log_fail "Non-customer Actor F was NOT denied (Expected 401/403, got $UNAUTH_F_CODE)"
fi

# ------------------------------------------------------------------------------
# Phase 3: Actor E (Customer of D) accesses Machine Type AAS & Simulation SM
# ------------------------------------------------------------------------------
log_step "Phase 3: Authorized Customer E queries Actor D (MachineTypeAAS & Simulation)"

RESP_D_SHELLS=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN_E" "$ACTOR_D_GW/shells")
CODE_D_SHELLS=$(echo "$RESP_D_SHELLS" | tail -n1)
BODY_D_SHELLS=$(echo "$RESP_D_SHELLS" | sed '$d')
assert_status "$CODE_D_SHELLS" "200" "Customer E queries Actor D /shells"
assert_contains "$BODY_D_SHELLS" "MillingMachineTypeAAS" "Actor D returns MillingMachineTypeAAS"

# Technical data with integrated references to A, B, C
SM_D_TECH=$(echo -n "urn:dataspace:d:sm:technical-data" | base64)
RESP_D_TECH=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN_E" "$ACTOR_D_GW/submodels/$SM_D_TECH")
CODE_D_TECH=$(echo "$RESP_D_TECH" | tail -n1)
BODY_D_TECH=$(echo "$RESP_D_TECH" | sed '$d')
assert_status "$CODE_D_TECH" "200" "Customer E queries Actor D TechnicalData"
assert_contains "$BODY_D_TECH" "IntegratedMotorRef" "Actor D compares and integrates Actor A Motor"
assert_contains "$BODY_D_TECH" "IntegratedGearboxRef" "Actor D compares and integrates Actor B Gearbox"
assert_contains "$BODY_D_TECH" "IntegratedSensorRef" "Actor D compares and integrates Actor C Sensor"

# Customer E queries Simulation Submodel (Authorized!)
RESP_D_SIM=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN_E" "$ACTOR_D_GW/submodels/$SM_D_SIM")
CODE_D_SIM=$(echo "$RESP_D_SIM" | tail -n1)
BODY_D_SIM=$(echo "$RESP_D_SIM" | sed '$d')
assert_status "$CODE_D_SIM" "200" "Customer E receives Simulation Submodel from Actor D"
assert_contains "$BODY_D_SIM" "KinematicAndThermalFEA" "Simulation model contains FEA parameters"
assert_contains "$BODY_D_SIM" "ToolCenterPointPrecisionMicron" "Simulation model contains precision metrics"

# ------------------------------------------------------------------------------
# Phase 4: Actor E Access Control: Nameplate (Others) vs TimeSeries (Customers)
# ------------------------------------------------------------------------------
log_step "Phase 4: Access Control on Actor E: Public Nameplate vs Protected TimeSeries"

SM_E_NAMEPLATE=$(echo -n "urn:dataspace:e:sm:nameplate" | base64)
SM_E_TIMESERIES=$(echo -n "urn:dataspace:e:sm:timeseries" | base64)

# 4.1 Actor D (non-customer) queries Actor E Nameplate (Allowed!)
RESP_E_NP_D=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN_D" "$ACTOR_E_GW/submodels/$SM_E_NAMEPLATE")
CODE_E_NP_D=$(echo "$RESP_E_NP_D" | tail -n1)
BODY_E_NP_D=$(echo "$RESP_E_NP_D" | sed '$d')
assert_status "$CODE_E_NP_D" "200" "Actor D can read Actor E Nameplate ('andere sehen Nameplate')"
assert_contains "$BODY_E_NP_D" "Turbine Blade" "Nameplate returns product designation"

# 4.2 Actor D (non-customer) queries Actor E TimeSeries (Must be 403 Forbidden!)
RESP_E_TS_D=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN_D" "$ACTOR_E_GW/submodels/$SM_E_TIMESERIES")
CODE_E_TS_D=$(echo "$RESP_E_TS_D" | tail -n1)
if [[ "$CODE_E_TS_D" =~ ^(401|403)$ ]]; then
  log_success "Actor D is denied access to Actor E TimeSeries SM (HTTP $CODE_E_TS_D)"
else
  log_fail "Actor D was NOT denied access to TimeSeries SM (Expected 401/403, got $CODE_E_TS_D)"
fi

# ------------------------------------------------------------------------------
# Phase 5: Actor F (Customer of E) queries TimeSeries Submodel
# ------------------------------------------------------------------------------
log_step "Phase 5: Customer F queries Actor E TimeSeries Submodel (Authorized!)"

RESP_E_TS_F=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN_F" "$ACTOR_E_GW/submodels/$SM_E_TIMESERIES")
CODE_E_TS_F=$(echo "$RESP_E_TS_F" | tail -n1)
BODY_E_TS_F=$(echo "$RESP_E_TS_F" | sed '$d')
assert_status "$CODE_E_TS_F" "200" "Customer F receives TimeSeries Submodel from Actor E"
assert_contains "$BODY_E_TS_F" "ProcessRecordCount" "TimeSeries contains process data record count"
assert_contains "$BODY_E_TS_F" "AverageMillingTemperatureCelsius" "TimeSeries contains milling temperature"
assert_contains "$BODY_E_TS_F" "PeakVibrationRMS" "TimeSeries contains vibration RMS"

# Customer F also queries Nameplate
RESP_E_NP_F=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN_F" "$ACTOR_E_GW/submodels/$SM_E_NAMEPLATE")
CODE_E_NP_F=$(echo "$RESP_E_NP_F" | tail -n1)
assert_status "$CODE_E_NP_F" "200" "Customer F can also read Nameplate"

# ------------------------------------------------------------------------------
# Phase 6: Unauthenticated request to Actor E TimeSeries
# ------------------------------------------------------------------------------
log_step "Phase 6: Unauthenticated request to Actor E TimeSeries"

UNAUTH_E_RESP=$(curl -s -w "\n%{http_code}" "$ACTOR_E_GW/submodels/$SM_E_TIMESERIES")
UNAUTH_E_CODE=$(echo "$UNAUTH_E_RESP" | tail -n1)
assert_status "$UNAUTH_E_CODE" "401" "Unauthenticated request to Actor E TimeSeries is rejected with HTTP 401"

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
log_header "Verification Summary"
echo -e "Total Tests Passed: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Total Tests Failed: ${RED}${FAILED_TESTS}${NC}"

if [[ "$FAILED_TESTS" -eq 0 ]]; then
  echo -e "\n${BOLD}${GREEN}All 6-Actor Dataspace Requirements Satisfied Successfully!${NC}\n"
  exit 0
else
  echo -e "\n${BOLD}${RED}Some tests failed. Check logs above.${NC}\n"
  exit 1
fi
