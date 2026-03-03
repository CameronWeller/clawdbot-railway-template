# Epic: Functional, Powerful, Flexible Agent on Railway + WSL Docker Testing

This document describes the epic for making the OpenClaw agent deployment on Railway **functional**, **powerful**, and **highly flexible**, with **WSL as a testing ground** for Docker deployment before pushing to Railway.

---

## Get started (roll locally first)

1. **Have Docker** — WSL2 + Docker, or [Docker Desktop](https://docs.docker.com/desktop/install/windows-install/) with WSL2 backend. Start Docker so `docker ps` works.
2. **Build** — From repo root (in WSL or PowerShell):  
   `docker build -t clawdbot-railway-template .`
3. **Run** — Same env/volume as Railway (password `test`):  
   - **WSL / bash:** `./scripts/docker-run-wsl.sh` or `make run`  
   - **PowerShell:** `.\scripts\docker-run.ps1` (or run the `docker run` one-liner from [README](../README.md#local-smoke-test))
4. **Smoke** — In another terminal:  
   `curl -s http://localhost:8080/healthz` and `curl -s -u ":test" http://localhost:8080/setup/healthz`  
   Or **WSL:** `make smoke`
5. **Browser** — Open `http://localhost:8080/setup` (password: `test`), complete setup, then use `http://localhost:8080/openclaw`.

Once this passes, deploy the same image to Railway; see [DEPLOYMENT.md](DEPLOYMENT.md) and the README.

---

## Goals

| Goal | Meaning |
|------|--------|
| **Functional** | End-to-end working: build → run → Setup → onboard → gateway → Control UI and channels; healthchecks pass; persistence and backup/import work. |
| **Powerful** | Agent is capable and well-configured: tools (coding profile), exec, skills, presets; optional Tailscale SSH; runtime env and workspace guidance (e.g. AGENTS.md, `.openclaw-runtime.env`) clear and reliable. |
| **Highly flexible** | Operators can tailor deployment via env, Setup UI, and presets; choose default vs Tailscale Dockerfile; customize volume layout, bootstrap, preinstall; document all knobs. |
| **WSL as testing ground** | Use WSL to run the **same** Docker image and run patterns as Railway, to validate “Docker deployment power and functionality” locally before deploying. |

---

## Scope

### In scope

- Documentation and scripts that make setup and deployment clear and repeatable.
- WSL-oriented workflow: build image in WSL, run with volume and env mirroring Railway, hit `/healthz` and `/setup`, optional onboarding smoke path.
- Docs that describe the epic, the deployment model, and the WSL testing workflow.
- Aligning or clarifying `railway.json` vs `railway.toml` in docs (when to use which).

### Out of scope

- Changing OpenClaw upstream or adding new agent features in the upstream repo.
- Non-WSL local testing (e.g. native Windows Docker) — can be documented later as alternative.
- Railway platform changes or multi-region tuning beyond what’s already in config.

---

## Deliverables

1. **Deployment and setup clarity** — Single place (or clear cross-links) for Railway template steps, required volume and env, optional Tailscale, backup/import, persistence layout. Explicit “path to a working agent”: deploy → set vars → open `/setup` → onboard → use Control UI/channels.

2. **Power and flexibility** — Document agent levers: tool profile, `tools.deny`, exec security, workspace, presets, `OPENCLAW_EXPOSE_ENV_VARS`, bootstrap/preinstall. Document when to use default Dockerfile vs `Dockerfile-tailscale` and how to set `RAILWAY_DOCKERFILE_PATH`.

3. **WSL Docker testing** — Documented workflow: WSL + Docker, build same image as Railway, run with `/data` volume and same env, then verify `/healthz`, `/setup`, and optionally complete setup and hit `/openclaw`. Optional script(s) or Makefile targets for build, run, smoke.

4. **Epic docs** — This file (EPIC-AGENT-DEPLOYMENT.md), [DEPLOYMENT.md](DEPLOYMENT.md), and [WSL-DOCKER-TESTING.md](WSL-DOCKER-TESTING.md).

---

## Relationship to other docs

| Doc | Purpose |
|-----|--------|
| [README.md](../README.md) | Main entry; what you get, Railway deploy steps, Tailscale, persistence, troubleshooting. Links here for deployment reference and WSL testing. |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Full deployment reference: Railway + Docker, env, volume, railway.json vs railway.toml, path to a working agent, flexibility knobs. |
| [WSL-DOCKER-TESTING.md](WSL-DOCKER-TESTING.md) | Step-by-step WSL + Docker validation before deploying to Railway. |
| [SECURITY.md](SECURITY.md) | Credentials, Tailscale ACL, contributor checklist. |
| [SSH-SETUP.md](SSH-SETUP.md) | SSH over Tailscale: connect, paths, OpenClaw commands, debugging. |

---

## How we validate

1. **CI** — [.github/workflows/docker-build.yml](../.github/workflows/docker-build.yml) builds the default Docker image on every push/PR, then runs the container and hits `/healthz` and `/setup/healthz`. If the build or smoke step fails, the container is broken.

2. **WSL Docker run** — On a dev machine with WSL + Docker, build the same image, run with `/data` volume and same env as Railway, then:
   - `curl` `/healthz` and `/setup/healthz` (optional: complete setup and hit `/openclaw`).
   - See [WSL-DOCKER-TESTING.md](WSL-DOCKER-TESTING.md) for the full workflow.

3. **Railway** — Deploy the same image (or let Railway build from the repo). Same image + volume + env yields the same behavior; passing WSL run gives confidence for Railway.

---

## Backlog / checklist

- [x] docs/EPIC-AGENT-DEPLOYMENT.md (this file)
- [x] docs/DEPLOYMENT.md
- [x] docs/WSL-DOCKER-TESTING.md
- [x] Optional Makefile or scripts for `docker-run`, `smoke`
- [x] README “Deployment and testing” section with links to the above
- [x] CI: run container and hit `/healthz` + `/setup/healthz` after build (docker-build.yml)
