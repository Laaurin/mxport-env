#!/usr/bin/env bash
# ==============================================================================
# MX-Port Leo & BaSyx Dynamic RBAC – Runtime Token Pipeline Verification Suite
# ==============================================================================
# Architecture:
#   Consumer Keycloak (8080) -> Consumer STS (9050) -> Consumer Gateway (8081)
#   -> Provider Gateway (8082) -> Provider STS (9051) -> Provider AAS (8083)
#   Policy backend: Keycloak RBAC (8085) & BaSyx Security Submodel (8086)
# ==============================================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Visual Formatting & Logging Utilities
# ──────────────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

TESTS_RUN=0
TESTS_FAILED=0

log_header() {
  echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}   $1${NC}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════════════════════${NC}"
}

log_info() {
  echo -e "${BLUE}${BOLD}==>${NC} $1"
}

log_pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "  ${GREEN}✔ [PASS]${NC} $1"
}

log_fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "  ${RED}✘ [FAIL]${NC} $1"
  if [[ "${STOP_ON_FAILURE:-true}" == "true" ]]; then
    echo -e "\n${RED}${BOLD}Test suite aborted due to failure.${NC}\n"
    exit 1
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Central Assertions
# ──────────────────────────────────────────────────────────────────────────────
assert_status_code() {
  local actual="$1"
  local expected="$2"
  local description="$3"

  if [[ "$actual" == "$expected" ]]; then
    log_pass "$description (HTTP $actual)"
  else
    log_fail "$description: expected HTTP $expected, got HTTP $actual"
  fi
}

assert_status_in() {
  local actual="$1"
  local expected_csv="$2"
  local description="$3"

  IFS=',' read -r -a allowed <<< "$expected_csv"
  for code in "${allowed[@]}"; do
    if [[ "$actual" == "$code" ]]; then
      log_pass "$description (HTTP $actual in [$expected_csv])"
      return 0
    fi
  done
  log_fail "$description: expected HTTP in [$expected_csv], got HTTP $actual"
}

assert_json_field() {
  local json="$1"
  local query="$2"
  local expected_pattern="$3"
  local description="$4"

  local val
  val=$(echo "$json" | jq -r "$query" 2>/dev/null || true)
  if [[ "$val" =~ $expected_pattern ]]; then
    log_pass "$description ($val)"
  else
    log_fail "$description: expected pattern '$expected_pattern', got '$val'"
  fi
}

decode_jwt() {
  local token="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import sys, base64; p = sys.argv[1].split('.')[1]; p += '=' * ((4 - len(p) % 4) % 4); print(base64.urlsafe_b64decode(p).decode('utf-8'))" "$token"
  elif echo "test" | base64 -d >/dev/null 2>&1; then
    echo "$token" | cut -d'.' -f2 | tr '_-' '/+' | base64 -d 2>/dev/null || true
  else
    echo "$token" | cut -d'.' -f2 | tr '_-' '/+' | base64 -D 2>/dev/null || true
  fi
}

# ──────────────────────────────────────────────────────────────────────────────
# Configuration & Constants
# ──────────────────────────────────────────────────────────────────────────────
KEYCLOAK_CONSUMER_URL="${KEYCLOAK_CONSUMER_URL:-http://localhost:8080/realms/mxport/protocol/openid-connect/token}"
KEYCLOAK_RBAC_URL="${KEYCLOAK_RBAC_URL:-http://localhost:8085/realms/BaSyx/protocol/openid-connect/token}"
CONSUMER_STS_URL="${CONSUMER_STS_URL:-http://localhost:9050/sts/token}"
CONSUMER_GATEWAY_URL="${CONSUMER_GATEWAY_URL:-http://localhost:8081}"
PROVIDER_STS_URL="${PROVIDER_STS_URL:-http://localhost:9051/sts/token}"
PROVIDER_GATEWAY_URL="${PROVIDER_GATEWAY_URL:-http://localhost:8082}"
PROVIDER_AAS_URL="${PROVIDER_AAS_URL:-http://localhost:8083}"
SECURITY_SUBMODEL_URL="${SECURITY_SUBMODEL_URL:-http://localhost:8086/submodels}"

FRAME_SHELL_ID="aHR0cHM6Ly9leGFtcGxlLmNvbS9pZHMvc20vNTI1NV81MTkxXzkwNDJfODEyNw=="
SECURITY_SM_ID="U2VjdXJpdHlTdWJtb2RlbA=="
FRAME_RULE_ID="YWRtaW5SRUFEb3JnLmVjbGlwc2UuZGlnaXRhbHR3aW4uYmFzeXguYWFzcmVwb3NpdG9yeS5mZWF0dXJlLmF1dGhvcml6YXRpb24uQWFzVGFyZ2V0SW5mb3JtYXRpb24="

# Global tokens populated across steps
CONSUMER_TOKEN=""
FX_TOKEN=""
PROVIDER_TOKEN=""
ADMIN_TOKEN=""

# ──────────────────────────────────────────────────────────────────────────────
# Test 0: Prerequisites Check
# ──────────────────────────────────────────────────────────────────────────────
test_prerequisites() {
  log_info "Verifying required local CLI tools (curl, jq, python3)..."
  command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "python3 is required"; exit 1; }
  log_pass "Prerequisites verified"
}

# ──────────────────────────────────────────────────────────────────────────────
# Test 1: Consumer IdP (Keycloak) Token Minting
# ──────────────────────────────────────────────────────────────────────────────
test_consumer_token_minting() {
  log_info "Requesting Consumer access token from Keycloak ($KEYCLOAK_CONSUMER_URL)..."
  local resp http_code body

  resp=$(curl -s -w "\n%{http_code}" -X POST "$KEYCLOAK_CONSUMER_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=mxport-client&grant_type=password&username=testuser&password=testpass&scope=data-consumer")

  http_code=$(echo "$resp" | tail -n1)
  body=$(echo "$resp" | sed '$d')

  assert_status_code "$http_code" "200" "Consumer Keycloak token minting"
  CONSUMER_TOKEN=$(echo "$body" | jq -r .access_token)

  local payload
  payload=$(decode_jwt "$CONSUMER_TOKEN")
  assert_json_field "$payload" ".iss" "realms/mxport" "Consumer token issuer claim"
  assert_json_field "$payload" ".scope" "data-consumer" "Consumer token scope claim"
  assert_json_field "$payload" ".sub" "^[a-zA-Z0-9_-]+$" "Consumer token subject claim present"

  log_info "Executing negative test: Invalid credentials against Keycloak..."
  local bad_code
  bad_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KEYCLOAK_CONSUMER_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=mxport-client&grant_type=password&username=testuser&password=wrong-password")
  assert_status_code "$bad_code" "401" "Negative test: Keycloak invalid credentials rejected"
}

# ──────────────────────────────────────────────────────────────────────────────
# Test 2: Consumer STS Token Exchange (RFC 8693)
# ──────────────────────────────────────────────────────────────────────────────
test_consumer_sts_exchange() {
  log_info "Exchanging Consumer token (🟠) for Factory-X token (🔵) at Consumer STS ($CONSUMER_STS_URL)..."
  local resp http_code body

  resp=$(curl -s -w "\n%{http_code}" -X POST "$CONSUMER_STS_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
    -d "subject_token_type=urn:ietf:params:oauth:token-type:jwt" \
    -d "subject_token=$CONSUMER_TOKEN")

  http_code=$(echo "$resp" | tail -n1)
  body=$(echo "$resp" | sed '$d')

  assert_status_code "$http_code" "200" "Consumer STS token exchange"
  FX_TOKEN=$(echo "$body" | jq -r .access_token)

  local payload
  payload=$(decode_jwt "$FX_TOKEN")
  assert_json_field "$payload" ".iss" "http://consumer-sts:9050/sts" "Factory-X token issuer"
  assert_json_field "$payload" ".environment" "consumer" "Factory-X token environment claim"

  log_info "Executing negative test: Forged subject token to Consumer STS..."
  local forged_code
  forged_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$CONSUMER_STS_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
    -d "subject_token_type=urn:ietf:params:oauth:token-type:jwt" \
    -d "subject_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.tamperedSignature")
  assert_status_code "$forged_code" "400" "Negative test: Consumer STS rejects forged token"
}

# ──────────────────────────────────────────────────────────────────────────────
# Test 3: Provider STS Token Exchange & Role Transformation
# ──────────────────────────────────────────────────────────────────────────────
test_provider_sts_exchange() {
  log_info "Exchanging Factory-X token (🔵) for Provider token (🟣) at Provider STS ($PROVIDER_STS_URL)..."
  local resp http_code body

  resp=$(curl -s -w "\n%{http_code}" -X POST "$PROVIDER_STS_URL" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
    -d "subject_token_type=urn:ietf:params:oauth:token-type:jwt" \
    -d "subject_token=$FX_TOKEN")

  http_code=$(echo "$resp" | tail -n1)
  body=$(echo "$resp" | sed '$d')

  assert_status_code "$http_code" "200" "Provider STS token exchange"
  PROVIDER_TOKEN=$(echo "$body" | jq -r .access_token)

  local payload
  payload=$(decode_jwt "$PROVIDER_TOKEN")
  assert_json_field "$payload" ".iss" "http://provider-sts:9050/sts" "Provider token issuer"
  assert_json_field "$payload" ".aud" "provider-aas" "Provider token audience"
  assert_json_field "$payload" ".realm_access.roles[] | select(. == \"admin\")" "admin" "Role 'admin' in realm_access"
}

# ──────────────────────────────────────────────────────────────────────────────
# Test 4: Negative Security Boundaries (Requirements 3a & 3b)
# ──────────────────────────────────────────────────────────────────────────────
test_negative_security_boundaries() {
  log_info "Requirement 3a: Testing completely unauthenticated access (no token)..."
  local code_aas_no_token code_gw_no_token

  code_aas_no_token=$(curl -s -o /dev/null -w "%{http_code}" "$PROVIDER_AAS_URL/shells/$FRAME_SHELL_ID")
  assert_status_code "$code_aas_no_token" "401" "Negative test 3a: Direct Provider AAS access without token rejected"

  code_gw_no_token=$(curl -s -o /dev/null -w "%{http_code}" "$PROVIDER_GATEWAY_URL/shells/$FRAME_SHELL_ID")
  assert_status_code "$code_gw_no_token" "401" "Negative test 3a: Provider Gateway access without token rejected"

  log_info "Requirement 3b: Testing unexchanged Consumer token (🟠) sent directly to Provider..."
  local code_aas_unexchanged code_gw_unexchanged

  code_aas_unexchanged=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $CONSUMER_TOKEN" \
    "$PROVIDER_AAS_URL/shells/$FRAME_SHELL_ID")
  assert_status_in "$code_aas_unexchanged" "401,403" "Negative test 3b: Direct Provider AAS access with unexchanged Consumer token rejected"

  code_gw_unexchanged=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $CONSUMER_TOKEN" \
    "$PROVIDER_GATEWAY_URL/shells/$FRAME_SHELL_ID")
  assert_status_in "$code_gw_unexchanged" "401,403" "Negative test 3b: Provider Gateway access with unexchanged Consumer token rejected"
}

# ──────────────────────────────────────────────────────────────────────────────
# Test 5: Gateway End-to-End Hop
# ──────────────────────────────────────────────────────────────────────────────
test_gateway_e2e_hop() {
  log_info "Testing Gateway Hop: Consumer Gateway ($CONSUMER_GATEWAY_URL) -> Provider Gateway..."
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $CONSUMER_TOKEN" \
    "$CONSUMER_GATEWAY_URL/external/provider-gateway/healthz")
  assert_status_code "$code" "200" "Consumer Gateway forwarded request to Provider Gateway"
}

# ──────────────────────────────────────────────────────────────────────────────
# Test 6: BaSyx Dynamic RBAC Policy Lifecycle (403 -> 201 -> 200 -> 204 -> 403)
# ──────────────────────────────────────────────────────────────────────────────
test_dynamic_rbac_lifecycle() {
  local aas_url="$CONSUMER_GATEWAY_URL/external/provider-gateway/shells/$FRAME_SHELL_ID"

  log_info "Obtaining Admin token from Keycloak RBAC ($KEYCLOAK_RBAC_URL)..."
  ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_RBAC_URL" \
    -H "Host: keycloak-rbac:8080" \
    -d "client_id=workstation-1&client_secret=nY0mjyECF60DGzNmQUjL81XurSl8etom&grant_type=client_credentials&scope=openid" \
    -H "Content-Type: application/x-www-form-urlencoded" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

  if [[ -z "$ADMIN_TOKEN" || "$ADMIN_TOKEN" == "null" ]]; then
    log_fail "Failed to retrieve admin token from Keycloak RBAC"
  fi
  log_pass "Keycloak RBAC admin token obtained"

  log_info "Ensuring clean initial state: deleting leftover dynamic rule if present..."
  curl -s -o /dev/null -X DELETE \
    "$SECURITY_SUBMODEL_URL/$SECURITY_SM_ID/submodel-elements/$FRAME_RULE_ID" \
    -H "Authorization: Bearer $ADMIN_TOKEN" || true

  # Phase 6a: Pre-access check (Must be 403 Forbidden)
  log_info "Phase 6a: Requesting AAS shell before rule injection (expecting HTTP 403 Forbidden)..."
  local code_pre
  code_pre=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $CONSUMER_TOKEN" \
    "$aas_url")
  assert_status_code "$code_pre" "403" "Phase 6a: Pre-access correctly denied"

  # Phase 6b: Inject Dynamic RBAC Rule into Security Submodel
  log_info "Phase 6b: Injecting dynamic RBAC rule for role 'admin' into SecuritySubmodel..."
  local rule_payload inject_code
  rule_payload='{
    "modelType": "SubmodelElementCollection",
    "idShort": "'"$FRAME_RULE_ID"'",
    "value": [
      {
        "modelType": "Property",
        "value": "admin",
        "idShort": "role"
      },
      {
        "modelType": "SubmodelElementList",
        "idShort": "action",
        "orderRelevant": true,
        "value": [
          {
            "modelType": "Property",
            "value": "READ"
          }
        ]
      },
      {
        "modelType": "SubmodelElementCollection",
        "idShort": "targetInformation",
        "value": [
          {
            "modelType": "SubmodelElementList",
            "idShort": "aasIds",
            "orderRelevant": true,
            "value": [
              {
                "modelType": "Property",
                "value": "https://example.com/ids/sm/5255_5191_9042_8127"
              }
            ]
          },
          {
            "modelType": "Property",
            "value": "aas",
            "idShort": "@type"
          }
        ]
      }
    ]
  }'

  inject_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$SECURITY_SUBMODEL_URL/$SECURITY_SM_ID/submodel-elements" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$rule_payload")
  assert_status_in "$inject_code" "201,409" "Phase 6b: Dynamic RBAC rule injected into SecuritySubmodel"

  # Phase 6c: Request AAS shell after rule injection (Must be 200 OK)
  log_info "Phase 6c: Requesting AAS shell after rule injection (expecting HTTP 200 OK)..."
  local post_resp post_code post_body=""
  for _ in {1..5}; do
    post_resp=$(curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer $CONSUMER_TOKEN" \
      "$aas_url")
    post_code=$(echo "$post_resp" | tail -n1)
    if [[ "$post_code" == "200" ]]; then
      post_body=$(echo "$post_resp" | sed '$d')
      break
    fi
    sleep 1
  done
  assert_status_code "$post_code" "200" "Phase 6c: Dynamic access granted to AAS"
  assert_json_field "$post_body" ".id" "5255_5191_9042_8127" "AAS payload contains correct FrameAAS ID"

  # Phase 6d: Revocation / Rule Deletion
  log_info "Phase 6d: Revoking rule from SecuritySubmodel..."
  local del_code
  del_code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    "$SECURITY_SUBMODEL_URL/$SECURITY_SM_ID/submodel-elements/$FRAME_RULE_ID" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
  assert_status_in "$del_code" "200,204" "Phase 6d: Dynamic rule revoked from SecuritySubmodel"

  # Phase 6e: Post-revocation check (Must revert to 403 Forbidden)
  log_info "Phase 6e: Requesting AAS shell after revocation (expecting HTTP 403 Forbidden)..."
  local code_revoked
  code_revoked=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $CONSUMER_TOKEN" \
    "$aas_url")
  assert_status_code "$code_revoked" "403" "Phase 6e: Access immediately revoked upon rule deletion"
}

# ──────────────────────────────────────────────────────────────────────────────
# Main Runner
# ──────────────────────────────────────────────────────────────────────────────
main() {
  log_header "MX-PORT LEO & BASYX DYNAMIC RBAC VERIFICATION SUITE"

  test_prerequisites
  test_consumer_token_minting
  test_consumer_sts_exchange
  test_provider_sts_exchange
  test_negative_security_boundaries
  test_gateway_e2e_hop
  test_dynamic_rbac_lifecycle

  log_header "TEST SUITE SUMMARY"
  echo -e "Total Checks Executed : ${BOLD}$TESTS_RUN${NC}"
  echo -e "Total Failed          : ${BOLD}$TESTS_FAILED${NC}"

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}${BOLD}✔ ALL RUNTIME TOKEN & RBAC VERIFICATION TESTS PASSED SUCCESSFULLY!${NC}\n"
    exit 0
  else
    echo -e "\n${RED}${BOLD}✘ RUNTIME VERIFICATION SUITE FAILED (${TESTS_FAILED} errors).${NC}\n"
    exit 1
  fi
}

main "$@"
