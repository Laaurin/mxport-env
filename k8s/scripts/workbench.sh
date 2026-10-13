#!/usr/bin/env bash
# ==============================================================================
# workbench.sh
# Starts the interactive Dataspace Test Workbench & Security Inspector UI
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKBENCH_DIR="$K8S_DIR/workbench"

PORT="${PORT:-3333}"

echo ">>> Starting Dataspace Test Workbench on port $PORT..."
echo ">>> Serving UI at: http://localhost:$PORT"

# Try to open in default browser
if command -v open >/dev/null 2>&1; then
  (sleep 1 && open "http://localhost:$PORT") &
elif command -v xdg-open >/dev/null 2>&1; then
  (sleep 1 && xdg-open "http://localhost:$PORT") &
fi

exec node "$WORKBENCH_DIR/server.js"
