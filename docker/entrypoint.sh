#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-openclaw}"
APP_GROUP="${APP_GROUP:-openclaw}"

ensure_dir() {
  local dir="$1"
  mkdir -p "$dir" || true
  if [ ! -w "$dir" ]; then
    chown -R "${APP_USER}:${APP_GROUP}" "$dir" || true
  fi
}

# Keep persistent paths writable even when Railway mounts /data as root-owned.
ensure_dir /data
ensure_dir /data/.openclaw
ensure_dir /data/workspace
ensure_dir /data/npm
ensure_dir /data/npm-cache
ensure_dir /data/pnpm
ensure_dir /data/pnpm-store
ensure_dir /app
ensure_dir /home/openclaw

exec gosu "${APP_USER}:${APP_GROUP}" "$@"
