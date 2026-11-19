#!/usr/bin/env bash
# ==============================================================================
# cluster-up.sh
# Creates or starts the k3d cluster 'dataspace', builds/imports images,
# and deploys all 6 actors + infrastructure via deploy-all.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$K8S_DIR/.." && pwd)"
CLUSTER_NAME="dataspace"

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is not installed or not in PATH"; exit 1; }
command -v k3d >/dev/null 2>&1 || { echo "ERROR: k3d is not installed. Install via brew install k3d or choco install k3d"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm is not installed. Install via brew install helm or choco install kubernetes-helm"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is not installed."; exit 1; }

echo ">>> Checking if k3d cluster '$CLUSTER_NAME' exists and has active nodes..."
NEEDS_CREATE=true
if k3d cluster list "$CLUSTER_NAME" >/dev/null 2>&1; then
  echo ">>> Found cluster '$CLUSTER_NAME'. Starting if stopped..."
  if k3d cluster start "$CLUSTER_NAME" >/dev/null 2>&1; then
    k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-switch-context >/dev/null 2>&1 || true
    if kubectl get nodes >/dev/null 2>&1; then
      echo ">>> Cluster '$CLUSTER_NAME' is running and healthy."
      NEEDS_CREATE=false
    fi
  fi
  if [ "$NEEDS_CREATE" = true ]; then
    echo ">>> Cluster '$CLUSTER_NAME' has no nodes ('no nodes found'). Recreating..."
    k3d cluster delete "$CLUSTER_NAME" >/dev/null 2>&1 || true
  fi
fi

if [ "$NEEDS_CREATE" = true ]; then
  echo ">>> Creating k3d cluster '$CLUSTER_NAME'..."
  k3d cluster create --config "$K8S_DIR/cluster/k3d-config.yaml"
fi

echo ">>> Ensuring custom images are present..."
if ! docker image inspect mxport-leo-gateway:local >/dev/null 2>&1; then
  echo "  --> Building mxport-leo-gateway:local..."
  docker build -t mxport-leo-gateway:local -f "$ROOT_DIR/provider/gateway/Dockerfile" "$ROOT_DIR/provider/gateway"
fi

if ! docker image inspect mxport-leo-sts:local >/dev/null 2>&1; then
  echo "  --> Building mxport-leo-sts:local..."
  docker build -t mxport-leo-sts:local "$ROOT_DIR/repos/mxport-leo-token-exchange"
fi

if ! docker image inspect mxport-leo-company-lookup:local >/dev/null 2>&1; then
  echo "  --> Building mxport-leo-company-lookup:local..."
  docker build -t mxport-leo-company-lookup:local "$ROOT_DIR/repos/mxport-leo-company-lookup"
fi

if ! docker image inspect postgres:16-alpine >/dev/null 2>&1; then
  echo "  --> Pulling postgres:16-alpine..."
  docker pull postgres:16-alpine
fi

echo ">>> Importing images into k3d cluster (avoids re-pulling)..."
for img in \
  mxport-leo-gateway:local \
  mxport-leo-sts:local \
  mxport-leo-company-lookup:local \
  postgres:16-alpine \
  eclipsebasyx/aas-environment:2.0.0-SNAPSHOT \
  eclipsebasyx/submodel-repository:2.0.0-SNAPSHOT \
  eclipsebasyx/aas-gui:SNAPSHOT \
  quay.io/keycloak/keycloak:25.0 \
  mongo:8 \
  curlimages/curl:8.5.0; do
  if docker image inspect "$img" >/dev/null 2>&1; then
    k3d image import "$img" -c "$CLUSTER_NAME" || true
  fi
done

echo ">>> Deploying all charts via deploy-all.sh..."
"$SCRIPT_DIR/deploy-all.sh"
