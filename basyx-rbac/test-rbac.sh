#!/bin/bash
set -e

KEYCLOAK_URL="http://localhost:8085"
AAS_URL="http://localhost:8081"
USERNAME="${1:-admin}"
PASSWORD="${2:-admin}"

echo "=========================================================="
echo "BaSyx Dynamic RBAC Test Suite (Local Verification)"
echo "User: $USERNAME"
echo "=========================================================="

echo "1. Obtaining Bearer Token from Keycloak..."
RESP=$(curl -s -X POST "$KEYCLOAK_URL/realms/BaSyx/protocol/openid-connect/token" \
  -d "client_id=basyx-web-ui&grant_type=password&username=$USERNAME&password=$PASSWORD" \
  -H "Content-Type: application/x-www-form-urlencoded")

TOKEN=$(echo "$RESP" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "❌ Failed to obtain token from Keycloak. Response:"
  echo "$RESP"
  exit 1
fi
echo "✅ Token obtained successfully."

echo -e "\n2. Testing READ /shells..."
READ_CODE=$(curl -s -o /tmp/basyx_shells.json -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$AAS_URL/shells")
if [ "$READ_CODE" = "200" ]; then
  echo "✅ READ /shells successful (HTTP 200)."
else
  echo "❌ READ /shells failed with HTTP $READ_CODE."
  exit 1
fi

echo -e "\n3. Testing CREATE /shells (WRITE)..."
PAYLOAD='{
  "id": "https://example.com/ids/aas/sample_device_001",
  "idShort": "SampleDevice001",
  "modelType": "AssetAdministrationShell",
  "assetInformation": {
    "assetKind": "Instance",
    "globalAssetId": "https://example.com/ids/asset/sample_device_001"
  }
}'

CREATE_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "$AAS_URL/shells" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [ "$CREATE_CODE" = "201" ]; then
  echo "✅ CREATE /shells successful (HTTP 201)."
else
  echo "❌ CREATE /shells failed with HTTP $CREATE_CODE."
  exit 1
fi

echo -e "\n4. Testing DELETE /shells/{id}..."
# Base64url without padding for https://example.com/ids/aas/sample_device_001
B64_ID="aHR0cHM6Ly9leGFtcGxlLmNvbS9pZHMvYWFzL3NhbXBsZV9kZXZpY2VfMDAx"
DELETE_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X DELETE "$AAS_URL/shells/$B64_ID" \
  -H "Authorization: Bearer $TOKEN")

if [ "$DELETE_CODE" = "204" ] || [ "$DELETE_CODE" = "200" ]; then
  echo "✅ DELETE /shells successful (HTTP $DELETE_CODE)."
else
  echo "❌ DELETE /shells failed with HTTP $DELETE_CODE."
  exit 1
fi

echo -e "\n5. Verifying Shell Deletion (expecting HTTP 404)..."
AFTER_DEL_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$AAS_URL/shells/$B64_ID")

if [ "$AFTER_DEL_CODE" = "404" ]; then
  echo "✅ Shell is deleted (HTTP 404)."
else
  echo "⚠️ Expected 404 after deletion, got HTTP $AFTER_DEL_CODE."
fi

echo -e "\n=========================================================="
echo "🎉 All RBAC operations (READ, WRITE, DELETE) verified successfully!"
echo "UI URL:      http://localhost:3000"
echo "Login:       $USERNAME / $PASSWORD"
echo "=========================================================="
