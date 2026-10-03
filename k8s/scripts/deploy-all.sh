#!/usr/bin/env bash
# ==============================================================================
# deploy-all.sh
# Deploys the entire 4-actor dataspace infrastructure and actors via Helm
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="dataspace"

echo ">>> Creating namespace '$NAMESPACE' if not present..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ">>> 1. Deploying/Upgrading shared infrastructure (Keycloak + MongoDB)..."
helm upgrade --install infra "$K8S_DIR/helm/dataspace-infra" -n "$NAMESPACE"

echo ">>> Waiting for Keycloak & MongoDB to become ready..."
kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l app=keycloak --timeout=180s || true
kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l app=mongodb --timeout=120s || true

echo ">>> 2. Deploying/Upgrading 4 Dataspace Actors (OEM, Tier 1, Tier 2, Tier 3)..."
for actor in oem tier1 tier2 tier3; do
  echo "  --> Deploying $actor..."
  helm upgrade --install "$actor" "$K8S_DIR/helm/dataspace-actor" \
    -f "$K8S_DIR/values/actor-$actor.yaml" \
    -n "$NAMESPACE"
done

echo ">>> Waiting for Gateways to become ready..."
for actor in oem tier1 tier2 tier3; do
  kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l "app=$actor-gateway" --timeout=120s || true
done

echo ">>> Waiting for AAS Environments to become ready..."
for actor in oem tier1 tier2 tier3; do
  kubectl wait --namespace "$NAMESPACE" --for=condition=ready pod -l "app=$actor-aas" --timeout=180s || true
done

echo "======================================================================"
echo " Deployment Complete!"
echo " Ingress Host Endpoints (on localhost:80 via Traefik):"
echo "   - Keycloak: http://keycloak.localhost"
echo "   - OEM:      http://oem.localhost"
echo "   - Tier 1:   http://tier1.localhost"
echo "   - Tier 2:   http://tier2.localhost"
echo "   - Tier 3:   http://tier3.localhost"
echo " Run tests with: $K8S_DIR/tests/verify_4actor_chain.sh"
echo "======================================================================"
