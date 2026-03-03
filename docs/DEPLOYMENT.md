# Deployment reference

This document is the single reference for deploying the OpenClaw agent on Railway and for running the same stack locally with Docker.

- **Local validation (WSL):** [WSL-DOCKER-TESTING.md](WSL-DOCKER-TESTING.md) — build and run the same image locally before deploying.
- **Epic and validation:** [EPIC-AGENT-DEPLOYMENT.md](EPIC-AGENT-DEPLOYMENT.md) — goals, scope, and how we validate (CI, WSL, Railway).

---

## Path to a working agent

1. **Deploy** — Create a Railway project from this template (or use your own repo). Add a **Volume** at `/data` and set required variables (see below).
2. **Configure** — Set `SETUP_PASSWORD` (required), and recommended `OPENCLAW_STATE_DIR=/data/.openclaw`, `OPENCLAW_WORKSPACE_DIR=/data/workspace`. Optionally set `OPENCLAW_GATEWAY_TOKEN` and, for Tailscale, `RAILWAY_DOCKERFILE_PATH=Dockerfile-tailscale`, `TS_AUTHKEY`, `TS_HOSTNAME`.
3. **Open `/setup`** — Visit `https://<your-app>.up.railway.app/setup`. Use HTTP Basic auth (any username; password = `SETUP_PASSWORD`).
4. **Onboard** — Complete the Setup wizard (e.g. choose an auth provider and paste API keys). The wrapper runs `openclaw onboard` and starts the gateway.
5. **Use the agent** — Visit `/` or `/openclaw` (same Basic auth). Use the Control UI or connect via Telegram/Discord/Slack once configured.

---

## Railway

### Template steps (Railway Template Composer)

1. Create a new template from this GitHub repo.
2. Add a **Volume** mounted at `/data`.
3. Set variables (see tables below).
4. Enable **Public Networking** (HTTP). The service listens on Railway’s injected `PORT`.
5. Deploy.

### Required variables

| Variable | Purpose |
|----------|--------|
| `SETUP_PASSWORD` | HTTP Basic auth for `/setup` and Control UI at `/openclaw`. The wrapper exits at startup if this is missing. |

### Recommended variables

| Variable | Recommended value |
|----------|-------------------|
| `OPENCLAW_STATE_DIR` | `/data/.openclaw` |
| `OPENCLAW_WORKSPACE_DIR` | `/data/workspace` |

### Optional variables

| Variable | Purpose |
|----------|--------|
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth token. If unset, the wrapper generates one (less ideal for templates; set a generated secret in production). |
| `RAILWAY_DOCKERFILE_PATH` | `Dockerfile-tailscale` if you want Tailscale SSH. Omit or leave unset for the default Dockerfile. |
| `TS_AUTHKEY`, `TS_HOSTNAME`, etc. | For Tailscale variant only. See [README.md](../README.md#tailscale-ssh-optional) and [SECURITY.md](SECURITY.md). |

### railway.json vs railway.toml

This repo contains **both** Railway config files. Which one Railway uses depends on how the project was created:

| File | Builder | When it’s used |
|------|---------|----------------|
| **railway.json** | `RAILPACK` | Often used when deploying from the Railway template or when Railway prefers the JSON schema. Build may use Nixpacks/Railpack. |
| **railway.toml** | `dockerfile` | Explicit Dockerfile build. Specifies `healthcheckPath = "/setup/healthz"`, `requiredMountPath = "/data"`, and default variables. Use this when you want Railway to build from the Dockerfile. |

If you need the **Dockerfile** (default or Tailscale), ensure the project is configured to use the Dockerfile builder — e.g. set the builder to Dockerfile in the Railway dashboard, or rely on `railway.toml` if your project reads it. For the template, the one-click flow may use either; both result in the same runtime (volume at `/data`, same env).

---

## Docker (local / self-hosted)

Same image and run pattern as Railway, so you can validate locally (e.g. on WSL) before deploying.

### Build

```bash
docker build -t clawdbot-railway-template .
```

For the Tailscale variant:

```bash
docker build -f Dockerfile-tailscale -t clawdbot-railway-template:tailscale .
```

### Run

```bash
docker run --rm -p 8080:8080 \
  -e PORT=8080 \
  -e SETUP_PASSWORD=test \
  -e OPENCLAW_STATE_DIR=/data/.openclaw \
  -e OPENCLAW_WORKSPACE_DIR=/data/workspace \
  -v "$(pwd)/.tmpdata:/data" \
  clawdbot-railway-template
```

Then open `http://localhost:8080/setup` (password: `test`). For Tailscale image, add `-e TS_AUTHKEY=...` and `-e TS_HOSTNAME=...` (see [SECURITY.md](SECURITY.md)).

### Persistence

Only the mounted volume persists. Use a host path (e.g. `.tmpdata`) or a named volume. Same layout as Railway: state in `/data/.openclaw`, workspace in `/data/workspace`.

---

## Flexibility: agent and deployment knobs

### Agent levers (Setup UI or config)

- **Tool profile** — Default is `coding` (files, exec, sessions, memory, image). Override with `messaging`, `minimal`, or custom in config.
- **tools.deny** — Default denies `gateway` so the agent cannot restart the gateway. Add more in config if needed.
- **tools.exec** — Exec runs on the gateway container with `security: full` (non-root). Allowlist and other options can be set in config.
- **agents.defaults.workspace** — Set to `OPENCLAW_WORKSPACE_DIR` by the wrapper so the agent uses the persistent workspace.
- **Presets** — In Setup, use the **Ergonomics presets** card to insert snippets from [docs/agent-ergonomics-presets.json5](agent-ergonomics-presets.json5) (replace placeholders before saving).

### Environment and bootstrap

- **OPENCLAW_EXPOSE_ENV_VARS** — Comma-separated names of env vars to append to `/data/workspace/.openclaw-runtime.env`. Paths are always written; add only names you intend the agent to see (avoid secrets unless intentional).
- **OPENCLAW_WRITE_AGENTS_MD** — `true` (default): create `/data/workspace/AGENTS.md` if missing.
- **OPENCLAW_BOOTSTRAP_SKILLS** — `true` (default): seed starter skills under `/data/workspace/.openclaw/skills`.
- **OPENCLAW_PREINSTALL_NPM_PACKAGES** / **OPENCLAW_PREINSTALL_PIP_PACKAGES** — Preinstall at startup into `/data/npm` and user pip.
- **Bootstrap script** — If `/data/workspace/bootstrap.sh` exists, the wrapper runs it on startup (best-effort).

### Which image to use

| Image | When to use |
|-------|-------------|
| Default Dockerfile | Standard deploy; no SSH. |
| Dockerfile-tailscale | You want passwordless SSH over Tailscale. Set `RAILWAY_DOCKERFILE_PATH=Dockerfile-tailscale` and add `TS_AUTHKEY`, `TS_HOSTNAME`. See [SECURITY.md](SECURITY.md) and [SSH-SETUP.md](SSH-SETUP.md). |

---

## See also

| Doc | Purpose |
|-----|--------|
| [README.md](../README.md) | Quick start, Tailscale, persistence, troubleshooting, local smoke test. |
| [WSL-DOCKER-TESTING.md](WSL-DOCKER-TESTING.md) | Validate Docker on WSL (build, run, healthz) before Railway. |
| [EPIC-AGENT-DEPLOYMENT.md](EPIC-AGENT-DEPLOYMENT.md) | Deployment epic: goals, deliverables, validation (CI + WSL + Railway). |
| [SECURITY.md](SECURITY.md) | Credentials, Tailscale ACL, contributor checklist. |
| [SSH-SETUP.md](SSH-SETUP.md) | SSH over Tailscale: connect, paths, OpenClaw commands. |
