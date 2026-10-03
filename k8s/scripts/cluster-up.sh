#!/usr/bin/env bash
# ==============================================================================
# cluster-up.sh
# Creates the k3d cluster 'dataspace' and deploys all 4 actors + infrastructure
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

echo ">>> Checking if k3d cluster '$CLUSTER_NAME' already exists..."
if k3d cluster list "$CLUSTER_NAME" >/dev/null 2>&1; then
  echo ">>> Cluster '$CLUSTER_NAME' already exists."
else
  echo ">>> Creating k3d cluster '$CLUSTER_NAME'..."
  k3d cluster create --config "$K8S_DIR/cluster/k3d-config.yaml"
fi

echo ">>> Ensuring custom images are present in cluster..."
# Build local gateway & STS if not present
if ! docker image inspect mxport-leo-gateway:local >/dev/null 2>&1; then
  echo "  --> Building mxport-leo-gateway:local..."
  docker build -t mxport-leo-gateway:local -f "$ROOT_DIR/provider/gateway/Dockerfile" "$ROOT_DIR/provider/gateway"
fi

if ! docker image inspect mxport-leo-sts:local >/dev/null 2>&1; then
  echo "  --> Tagging local STS image..."
  docker pull mxport-leo-sts:local || true
fi

echo ">>> Importing images into k3d cluster (avoids re-pulling)..."
k3d image import \
  mxport-leo-gateway:local \
  mxport-leo-sts:local \
  eclipsebasyx/aas-environment:2.0.0-SNAPSHOT \
  eclipsebasyx/submodel-repository:2.0.0-SNAPSHOT \
  quay.io/keycloak/keycloak:25.0 \
  mongo:8 \
  curlimages/curl:8.5.0 \
  -c "$CLUSTER_NAME" || true

echo ">>> Deploying all charts..."
"$SCRIPT_DIR/deploy-all.sh"
