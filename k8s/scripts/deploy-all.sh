#!/usr/bin/env bash
# ==============================================================================
# deploy-all.sh
# Deploys the entire 6-actor dataspace infrastructure and actors via Helm
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="dataspace"

echo ">>> Creating namespace '$NAMESPACE' if not present..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ">>> Configuring Keycloak realms ConfigMap..."
kubectl create configmap keycloak-realms \
  --from-file="$K8S_DIR/infra/keycloak/realms" \
  -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ">>> 1. Deploying/Upgrading shared infrastructure (Keycloak + MongoDB + Company Lookup)..."
helm upgrade --install infra "$K8S_DIR/helm/dataspace-infra" -n "$NAMESPACE"

echo ">>> Waiting for Keycloak, MongoDB & Company Lookup to become ready..."
kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l app=keycloak --timeout=180s || true
kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l app=mongodb --timeout=120s || true
kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l app=company-lookup-db --timeout=120s || true
kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l app=company-lookup --timeout=120s || true

ACTORS=("actor-a" "actor-b" "actor-c" "actor-d" "actor-e" "actor-f")

echo ">>> 2. Deploying/Upgrading 6 Dataspace Actors..."
for actor in "${ACTORS[@]}"; do
  echo "  --> Deploying $actor..."
  helm upgrade --install "$actor" "$K8S_DIR/helm/dataspace-actor" \
    -f "$K8S_DIR/values/$actor.yaml" \
    -n "$NAMESPACE"
done

echo ">>> Waiting for Gateways to become ready..."
for actor in "${ACTORS[@]}"; do
  kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l "app=$actor-gateway" --timeout=120s || true
done

echo ">>> Waiting for AAS Environments to become ready..."
for actor in "${ACTORS[@]}"; do
  kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l "app=$actor-aas" --timeout=180s || true
done

echo ">>> Waiting for Actor AAS Viewers to become ready..."
for actor in "${ACTORS[@]}"; do
  kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l "app=$actor-gui" --timeout=120s || true
done

echo "======================================================================"
echo " Deployment Complete!"
echo " Ingress Host Endpoints (on localhost:80 via Traefik):"
echo "   - Keycloak:       http://keycloak.localhost"
echo "   - Company Lookup: http://lookup.localhost/api/v2/companies"
echo "   - Actor A:  http://actor-a.localhost (AAS Viewer: http://viewer-a.localhost)"
echo "   - Actor B:  http://actor-b.localhost (AAS Viewer: http://viewer-b.localhost)"
echo "   - Actor C:  http://actor-c.localhost (AAS Viewer: http://viewer-c.localhost)"
echo "   - Actor D:  http://actor-d.localhost (AAS Viewer: http://viewer-d.localhost)"
echo "   - Actor E:  http://actor-e.localhost (AAS Viewer: http://viewer-e.localhost)"
echo "   - Actor F:  http://actor-f.localhost (AAS Viewer: http://viewer-f.localhost)"
echo " Run tests with: $K8S_DIR/tests/verify_6actor_chain.sh"
echo "======================================================================"
