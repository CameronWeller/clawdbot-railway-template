#!/usr/bin/env bash
# Convenience script: build and run the default Docker image with Railway-like env and volume.
# Use from WSL or any Linux environment. See docs/WSL-DOCKER-TESTING.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-clawdbot-railway-template}"
DATA_DIR="${DATA_DIR:-.tmpdata}"
PORT="${PORT:-8080}"

cd "$REPO_ROOT"
mkdir -p "$DATA_DIR"

echo "[docker-run-wsl] Building $IMAGE_NAME..."
docker build -t "$IMAGE_NAME" .

echo "[docker-run-wsl] Running (port $PORT, data $DATA_DIR)..."
exec docker run --rm -p "${PORT}:${PORT}" \
  -e PORT="$PORT" \
  -e SETUP_PASSWORD="${SETUP_PASSWORD:-test}" \
  -e OPENCLAW_STATE_DIR=/data/.openclaw \
  -e OPENCLAW_WORKSPACE_DIR=/data/workspace \
  -v "$(pwd)/$DATA_DIR:/data" \
  "$IMAGE_NAME"
