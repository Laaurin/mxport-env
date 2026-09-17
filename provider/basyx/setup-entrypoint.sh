#!/bin/sh
set -e

echo "Waiting for Keycloak and Security Submodel..."
until curl -s "http://keycloak-rbac:8080/realms/BaSyx/.well-known/openid-configuration" | grep -q "token_endpoint"; do
  echo "Waiting for Keycloak..."
  sleep 2
done

until curl -s "http://security-submodel:8081/actuator/health" | grep -q "UP"; do
  echo "Waiting for Security Submodel..."
  sleep 2
done

echo "Fetching token from Keycloak..."
TOKEN=$(curl -s -X POST "http://keycloak-rbac:8080/realms/BaSyx/protocol/openid-connect/token" \
  -d "client_id=workstation-1&client_secret=nY0mjyECF60DGzNmQUjL81XurSl8etom&grant_type=client_credentials&scope=openid" \
  -H "Content-Type: application/x-www-form-urlencoded" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "ERROR: Failed to obtain token from Keycloak."
  exit 1
fi

echo "Uploading initial SecuritySubmodel..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://security-submodel:8081/submodels" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @/initial-submodel.json)

if [ "$STATUS" = "201" ] || [ "$STATUS" = "409" ]; then
  echo "SecuritySubmodel initialized successfully (HTTP $STATUS)."
else
  echo "Warning: SecuritySubmodel init returned HTTP $STATUS."
fi
