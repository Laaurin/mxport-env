#!/usr/bin/env bash
# ==============================================================================
# workbench.sh
# Starts the Vue Dataspace Workbench UI on http://localhost:5173
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$K8S_DIR/.." && pwd)"
WORKBENCH_DIR="$ROOT_DIR/workbench"

if [ ! -d "$WORKBENCH_DIR/node_modules" ]; then
  echo ">>> Installing workbench dependencies (npm install)..."
  (cd "$WORKBENCH_DIR" && npm install)
fi

echo ">>> Starting Vue Dataspace Workbench on http://localhost:5173 ..."
cd "$WORKBENCH_DIR"
exec npm run dev
