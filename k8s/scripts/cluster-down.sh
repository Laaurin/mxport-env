#!/usr/bin/env bash
# ==============================================================================
# cluster-down.sh
# Deletes the k3d cluster 'dataspace' and cleans up resources
# ==============================================================================
set -euo pipefail

CLUSTER_NAME="dataspace"

echo ">>> Deleting k3d cluster '$CLUSTER_NAME'..."
if k3d cluster list "$CLUSTER_NAME" >/dev/null 2>&1; then
  k3d cluster delete "$CLUSTER_NAME"
  echo ">>> Cluster '$CLUSTER_NAME' successfully deleted."
else
  echo ">>> Cluster '$CLUSTER_NAME' does not exist."
fi
