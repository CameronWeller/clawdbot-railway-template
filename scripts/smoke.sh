#!/usr/bin/env bash
# One-shot smoke: build image, run container, curl /healthz and /setup/healthz, then stop.
# Use from WSL or any Linux env. See docs/WSL-DOCKER-TESTING.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-clawdbot-railway-template}"
DATA_DIR="${DATA_DIR:-.tmpdata}"
PORT="${PORT:-8080}"
SETUP_PASSWORD="${SETUP_PASSWORD:-test}"

cd "$REPO_ROOT"
mkdir -p "$DATA_DIR"

echo "[smoke] Building $IMAGE_NAME..."
docker build -t "$IMAGE_NAME" .

echo "[smoke] Running container (port $PORT)..."
docker run --rm -d -p "${PORT}:${PORT}" \
  -e PORT="$PORT" \
  -e SETUP_PASSWORD="$SETUP_PASSWORD" \
  -e OPENCLAW_STATE_DIR=/data/.openclaw \
  -e OPENCLAW_WORKSPACE_DIR=/data/workspace \
  -v "$(pwd)/$DATA_DIR:/data" \
  --name clawdbot-smoke \
  "$IMAGE_NAME"

echo "[smoke] Waiting for server..."
for i in $(seq 1 24); do
  if curl -sf "http://localhost:${PORT}/healthz" >/dev/null 2>&1; then break; fi
  if [ "$i" -eq 24 ]; then
    echo "[smoke] Timeout waiting for /healthz"
    docker logs clawdbot-smoke 2>&1 | tail -30
    docker stop clawdbot-smoke 2>/dev/null || true
    exit 1
  fi
  sleep 5
done

echo "[smoke] Checking /healthz..."
curl -sf "http://localhost:${PORT}/healthz" && echo " OK"

echo "[smoke] Checking /setup/healthz..."
curl -sf -u ":$SETUP_PASSWORD" "http://localhost:${PORT}/setup/healthz" && echo " OK"

docker stop clawdbot-smoke
echo "[smoke] Done. Smoke checks passed."
