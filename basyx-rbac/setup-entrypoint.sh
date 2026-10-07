#!/bin/sh
set -e

echo "[Setup] Waiting for Keycloak and Security Submodel..."
until curl -s "http://keycloak-rbac:8080/realms/BaSyx/.well-known/openid-configuration" | grep -q "token_endpoint"; do
  echo "[Setup] Waiting for Keycloak..."
  sleep 2
done

until curl -s "http://security-submodel:8081/actuator/health" | grep -q "UP"; do
  echo "[Setup] Waiting for Security Submodel..."
  sleep 2
done

echo "[Setup] Ensuring Keycloak admin users exist and have credentials..."
MASTER_TOKEN=$(curl -s -X POST "http://keycloak-rbac:8080/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli&grant_type=password&username=admin&password=admin" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$MASTER_TOKEN" ] && [ "$MASTER_TOKEN" != "null" ]; then
  for USER in admin basyx-admin; do
    USER_ID=$(curl -s -H "Authorization: Bearer $MASTER_TOKEN" "http://keycloak-rbac:8080/admin/realms/BaSyx/users?username=$USER" | grep -o '"id":"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)
    
    if [ -z "$USER_ID" ]; then
      echo "[Setup] Creating user $USER in BaSyx realm..."
      curl -s -X POST "http://keycloak-rbac:8080/admin/realms/BaSyx/users" \
        -H "Authorization: Bearer $MASTER_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$USER\",\"enabled\":true,\"emailVerified\":true,\"email\":\"$USER@basyx.local\",\"firstName\":\"BaSyx\",\"lastName\":\"Admin\",\"credentials\":[{\"type\":\"password\",\"value\":\"admin\",\"temporary\":false}]}"
      
      USER_ID=$(curl -s -H "Authorization: Bearer $MASTER_TOKEN" "http://keycloak-rbac:8080/admin/realms/BaSyx/users?username=$USER" | grep -o '"id":"[^"]*"' | head -n 1 | cut -d'"' -f4)
    fi

    if [ -n "$USER_ID" ]; then
      # Reset password to 'admin' (ensures password is valid even on existing volumes)
      curl -s -X PUT "http://keycloak-rbac:8080/admin/realms/BaSyx/users/$USER_ID/reset-password" \
        -H "Authorization: Bearer $MASTER_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"type":"password","value":"admin","temporary":false}' >/dev/null 2>&1 || true

      # Get all available realm roles and assign admin roles
      ROLES_JSON=$(curl -s -H "Authorization: Bearer $MASTER_TOKEN" "http://keycloak-rbac:8080/admin/realms/BaSyx/roles")
      ADMIN_ROLE=$(echo "$ROLES_JSON" | grep -o '{"id":"[^"]*","name":"admin"[^}]*}' || true)
      CREATOR_ROLE=$(echo "$ROLES_JSON" | grep -o '{"id":"[^"]*","name":"basyx-creator"[^}]*}' || true)
      UPDATER_ROLE=$(echo "$ROLES_JSON" | grep -o '{"id":"[^"]*","name":"basyx-updater"[^}]*}' || true)
      DELETER_ROLE=$(echo "$ROLES_JSON" | grep -o '{"id":"[^"]*","name":"basyx-deleter"[^}]*}' || true)
      READER_ROLE=$(echo "$ROLES_JSON" | grep -o '{"id":"[^"]*","name":"basyx-reader"[^}]*}' || true)

      ROLES_TO_ADD=""
      for R in "$ADMIN_ROLE" "$CREATOR_ROLE" "$UPDATER_ROLE" "$DELETER_ROLE" "$READER_ROLE"; do
        if [ -n "$R" ]; then
          if [ -z "$ROLES_TO_ADD" ]; then
            ROLES_TO_ADD="$R"
          else
            ROLES_TO_ADD="$ROLES_TO_ADD,$R"
          fi
        fi
      done

      if [ -n "$ROLES_TO_ADD" ]; then
        curl -s -X POST "http://keycloak-rbac:8080/admin/realms/BaSyx/users/$USER_ID/role-mappings/realm" \
          -H "Authorization: Bearer $MASTER_TOKEN" \
          -H "Content-Type: application/json" \
          -d "[$ROLES_TO_ADD]" >/dev/null 2>&1 || true
      fi
      echo "[Setup] User $USER configured with full permissions."
    fi
  done
fi

echo "[Setup] Fetching M2M token for Security Submodel initialization..."
TOKEN=$(curl -s -X POST "http://keycloak-rbac:8080/realms/BaSyx/protocol/openid-connect/token" \
  -d "client_id=workstation-1&client_secret=nY0mjyECF60DGzNmQUjL81XurSl8etom&grant_type=client_credentials&scope=openid" \
  -H "Content-Type: application/x-www-form-urlencoded" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "[Setup] ERROR: Failed to obtain token from Keycloak."
  exit 1
fi

echo "[Setup] Uploading initial SecuritySubmodel..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://security-submodel:8081/submodels" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @/initial-submodel.json)

if [ "$STATUS" = "201" ] || [ "$STATUS" = "409" ]; then
  echo "[Setup] SecuritySubmodel initialized successfully (HTTP $STATUS)."
else
  echo "[Setup] Warning: SecuritySubmodel init returned HTTP $STATUS."
fi

echo "[Setup] All services and users ready!"
