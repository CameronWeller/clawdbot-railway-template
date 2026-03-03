# WSL Docker testing

Use **WSL** (Windows Subsystem for Linux) to run the same Docker image and run patterns as Railway. This validates “Docker deployment power and functionality” locally before you deploy to Railway. Passing these steps gives confidence that the same image + volume + env will behave correctly on Railway.

---

## Purpose

- Build the same image Railway uses (default Dockerfile or Dockerfile-tailscale).
- Run the container with a `/data` volume and env vars mirroring Railway.
- Verify `/healthz` and `/setup/healthz`, and optionally complete setup and hit `/openclaw`.

---

## Prerequisites

- **WSL2** with a Linux distro (e.g. Ubuntu).
- **Docker** inside WSL:
  - Install [Docker Engine in WSL](https://docs.docker.com/desktop/wsl/) (e.g. Ubuntu: `sudo apt update && sudo apt install docker.io` and `sudo usermod -aG docker $USER`), or
  - Use **Docker Desktop** with the WSL 2 backend and ensure your project directory is under a WSL filesystem (e.g. `\\wsl$\Ubuntu\home\...`) so Docker runs in WSL.

---

## Steps

### 1. Clone or open the repo in WSL

```bash
cd /path/to/clawdbot-railway-template
# or: git clone https://github.com/vignesh07/clawdbot-railway-template.git && cd clawdbot-railway-template
```

### 2. Build the image

Default (same as Railway when not using Tailscale):

```bash
docker build -t clawdbot-railway-template .
```

Tailscale variant:

```bash
docker build -f Dockerfile-tailscale -t clawdbot-railway-template:tailscale .
```

### 3. Run with volume and env

Use a local directory for `/data` so state and workspace persist across runs. Example:

```bash
mkdir -p .tmpdata
docker run --rm -p 8080:8080 \
  -e PORT=8080 \
  -e SETUP_PASSWORD=test \
  -e OPENCLAW_STATE_DIR=/data/.openclaw \
  -e OPENCLAW_WORKSPACE_DIR=/data/workspace \
  -v "$(pwd)/.tmpdata:/data" \
  clawdbot-railway-template
```

For the Tailscale image, add Tailscale env (e.g. `-e TS_AUTHKEY=...` and `-e TS_HOSTNAME=openclaw-wsl-test`). See [SECURITY.md](SECURITY.md).

### 4. Verify

In another terminal (WSL or Windows with `curl`):

**Health (no auth):**

```bash
curl -s http://localhost:8080/healthz
```

Expect a successful response (e.g. `{"ok":true}` or similar).

**Setup health (Basic auth; password is the value of `SETUP_PASSWORD`):**

```bash
curl -s -u ":test" http://localhost:8080/setup/healthz
```

**Browser:**

- Open `http://localhost:8080/setup` in your browser. You should get an HTTP Basic auth prompt (password: `test`).
- After auth, the Setup wizard should load.

### 5. Optional: full onboarding

- Complete the Setup wizard (e.g. choose an auth provider and paste an API key).
- After onboarding, the gateway starts. Visit `http://localhost:8080/openclaw` (same Basic auth) to use the Control UI.

---

## Optional: Makefile and scripts

The repo provides optional targets so you can run build/run/smoke with one command.

| Target / script | Purpose |
|-----------------|--------|
| `make build` | Build the default image. |
| `make run` | Run the container with `.tmpdata` and default env (password: `test`). |
| `make smoke` | After container is running: curl `/healthz` and `/setup/healthz`. |
| `scripts/docker-run-wsl.sh` | Convenience script to build and run (default image). Use from WSL/bash. |
| `scripts/docker-run.ps1` | **Windows PowerShell:** build, run detached, and run smoke in one go. Requires Docker Desktop. |

See the [Makefile](../Makefile) and [scripts/docker-run-wsl.sh](../scripts/docker-run-wsl.sh) for details. If you don’t use Make, the manual steps above are sufficient.

---

## Parity with Railway

- **Same image** — Railway builds from the same Dockerfile(s); you build the same locally.
- **Same volume layout** — `/data` for state and workspace; same env vars (`OPENCLAW_STATE_DIR`, `OPENCLAW_WORKSPACE_DIR`).
- **Same env** — `PORT`, `SETUP_PASSWORD`, and optional Tailscale vars. Railway injects `PORT`; locally you set `PORT=8080` (or your chosen port).

If the container passes health and setup checks in WSL, it should behave the same on Railway once the volume and variables are configured there.

---

## See also

- [DEPLOYMENT.md](DEPLOYMENT.md) — Full deployment reference (Railway + Docker, env, flexibility).
- [README.md](../README.md) — Local smoke test one-liner and troubleshooting.
