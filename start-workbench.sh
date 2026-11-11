#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKBENCH_DIR="$SCRIPT_DIR/workbench"

echo ">>> Starting Industrial Dataspace Workbench (Siemens iX)..."
echo ">>> Ingress target: http://127.0.0.1:80 (k3d Traefik loadbalancer)"
echo ">>> Workbench URL:  http://localhost:5173"

cd "$WORKBENCH_DIR"
npm run dev
