#!/usr/bin/env bash
# Run inside the Railway container over Tailscale SSH for a quick health check.
# Usage: bash healthcheck-ssh.sh  (or copy to /data/workspace and run there)
set -e
export OPENCLAW_STATE_DIR=/data/.openclaw
export OPENCLAW_WORKSPACE_DIR=/data/workspace
echo "=== OpenClaw ==="
openclaw --version 2>/dev/null || true
openclaw status 2>/dev/null || true
openclaw health 2>/dev/null || true
echo ""
echo "=== Config ==="
[ -f /data/.openclaw/openclaw.json ] && echo "Config: /data/.openclaw/openclaw.json" || echo "No config yet"
openclaw config get gateway.auth.mode 2>/dev/null || true
echo ""
echo "=== Paths ==="
ls -la /data/.openclaw 2>/dev/null | head -5 || true
ls -la /data/workspace 2>/dev/null | head -5 || true
echo ""
echo "=== Done ==="
