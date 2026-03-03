# SSH setup guide (Railway deploy)

You have SSH access when using `Dockerfile-tailscale` with `TS_AUTHKEY` set. Connect from any Tailscale device:

```bash
tailscale ssh openclaw-railway
# or: tailscale ssh <your TS_HOSTNAME>
```

You land as the `openclaw` user inside the container. No sudo; persistence is under `/data`.

**Important:** So the CLI uses the same config as the wrapper/gateway, set the state dir in your SSH session:

```bash
export OPENCLAW_STATE_DIR=/data/.openclaw
export OPENCLAW_WORKSPACE_DIR=/data/workspace
```

(If your Railway Variables use different paths, match those.) Without this, `openclaw` may use `~/.openclaw` and you’ll see “gateway token mismatch” or wrong config.

---

## 1. Fix “gateway token mismatch” (1008)

If `openclaw health` says `gateway token mismatch (set gateway.remote.token to match gateway.auth.token)`:

1. **Use the same state dir as the wrapper** (see above):
   ```bash
   export OPENCLAW_STATE_DIR=/data/.openclaw
   export OPENCLAW_WORKSPACE_DIR=/data/workspace
   ```
2. **Align the tokens** in that config. If you have `OPENCLAW_GATEWAY_TOKEN` in this shell (e.g. from a profile), run:
   ```bash
   openclaw config set gateway.auth.token "$OPENCLAW_GATEWAY_TOKEN"
   openclaw config set gateway.remote.token "$OPENCLAW_GATEWAY_TOKEN"
   ```
   Otherwise copy the auth token into the remote token:
   ```bash
   TOKEN=$(openclaw config get gateway.auth.token)
   openclaw config set gateway.remote.token "$TOKEN"
   ```
3. **Retry:** `openclaw health`

---

## 2. Verify the deployment

```bash
# Wrapper and gateway
curl -s http://127.0.0.1:8080/healthz
curl -s -u "user:YOUR_SETUP_PASSWORD" http://127.0.0.1:8080/setup/healthz

# OpenClaw CLI (after exporting OPENCLAW_STATE_DIR as above)
openclaw status
openclaw health
openclaw doctor
```

---

## 3. Paths and env (no sudo)

| Purpose | Path |
|--------|------|
| OpenClaw state & config | `/data/.openclaw` |
| Config file | `/data/.openclaw/openclaw.json` |
| Workspace (skills, code) | `/data/workspace` |
| Preinstalled skills | `/data/workspace/.openclaw/skills/*.md` (18+ files when `OPENCLAW_BOOTSTRAP_SKILLS=true`) |
| Tailscale state | `/data/tailscale` |
| npm globals | `/data/npm` (binaries in `/data/npm/bin`) |
| pnpm | `/data/pnpm`, `/data/pnpm-store` |

To enable the preinstalled skills in config, use the Setup UI **Ergonomics presets** card (choose "Workspace skills bundle" or "Full Railway ergonomics", then Insert into config and Save), or paste snippets from `docs/agent-ergonomics-presets.json5` (in the repo) into `/data/.openclaw/openclaw.json` and restart the gateway.

In an SSH session, **export** these so the CLI matches the wrapper: `OPENCLAW_STATE_DIR=/data/.openclaw`, `OPENCLAW_WORKSPACE_DIR=/data/workspace` (or whatever you set in Railway Variables). The same paths are always in `/data/workspace/.openclaw-runtime.env` for the agent. The default agent has a **coding** tool profile; to restrict it see [docs/SECURITY.md](SECURITY.md#agent-tool-defaults-and-locking-down).

---

## 4. Useful OpenClaw commands

```bash
# Config (read/write)
openclaw config get gateway.auth.mode
openclaw config get agents.defaults.model.primary

# Devices (pairing/approval)
openclaw devices list
openclaw devices approve <requestId>

# Plugins
openclaw plugins list
openclaw plugins enable <name>

# Logs
openclaw logs --tail 100
```

---

## 5. Edit config on disk

Config is JSON at `/data/.openclaw/openclaw.json`. Edit with:

```bash
nano /data/.openclaw/openclaw.json
# or
vi /data/.openclaw/openclaw.json
```

After editing, restart the gateway so the wrapper picks up changes (or use the Setup UI “Run” with `gateway.restart`).

---

## 6. Install extra tools (no sudo)

- **npm global** (goes to `/data/npm`):
  ```bash
  npm i -g some-package
  ```
- **pnpm global** (goes to `/data/pnpm`):
  ```bash
  pnpm add -g some-package
  ```
- **Python** (user install):
  ```bash
  pip install --user some-package
  ```
- **venv** (persistent under `/data`):
  ```bash
  python3 -m venv /data/venv
  /data/venv/bin/pip install some-package
  ```

---

## 7. Tailscale from inside the container

```bash
# Status (if Tailscale was started by entrypoint)
tailscale status

# You can't run tailscale up as openclaw (needs tailscaled started by root).
# Use Railway Variables (TS_AUTHKEY, TS_HOSTNAME) and redeploy to change Tailscale config.
```

---

## 8. Debugging control UI / gateway

If the web UI shows “disconnected” or auth errors:

1. Confirm gateway token in config matches Railway’s `OPENCLAW_GATEWAY_TOKEN`:
   ```bash
   openclaw config get gateway.auth.token
   openclaw config get gateway.remote.token
   ```
2. Check wrapper is proxying: from your laptop, `curl -u "user:SETUP_PASSWORD" https://YOUR-RAILWAY-URL/healthz`.
3. Check logs: Railway dashboard or `openclaw logs --tail 200` over SSH.

---

## 9. Quick health script (optional)

Save and run for a quick check:

```bash
#!/usr/bin/env bash
# Save as /data/workspace/healthcheck.sh and run: bash /data/workspace/healthcheck.sh
set -e
export OPENCLAW_STATE_DIR=/data/.openclaw
export OPENCLAW_WORKSPACE_DIR=/data/workspace
echo "=== OpenClaw ==="
openclaw --version
openclaw status || true
openclaw health || true
echo "=== Paths ==="
ls -la /data/.openclaw/openclaw.json 2>/dev/null || echo "No config yet"
ls -la /data/workspace 2>/dev/null || true
echo "=== Done ==="
```
