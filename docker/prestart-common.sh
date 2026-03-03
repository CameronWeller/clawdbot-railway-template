#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-openclaw}"
APP_GROUP="${APP_GROUP:-openclaw}"

log() {
  echo "[prestart] $*"
}

ensure_dir() {
  local dir="$1"
  mkdir -p "$dir" || true
  if [ "$(id -u)" = "0" ] || [ ! -w "$dir" ]; then
    chown -R "${APP_USER}:${APP_GROUP}" "$dir" || true
  fi
}

run_as_app() {
  if [ "$(id -u)" = "0" ]; then
    gosu "${APP_USER}:${APP_GROUP}" "$@"
  else
    "$@"
  fi
}

write_runtime_env_file() {
  local env_file="/data/workspace/.openclaw-runtime.env"
  local allow_list="${OPENCLAW_EXPOSE_ENV_VARS:-}"

  log "Writing runtime env for agent context (paths always; optional expose vars)"
  : > "${env_file}"

  # Always write path context so the agent can run openclaw CLI and know workspace without OPENCLAW_EXPOSE_ENV_VARS.
  printf "OPENCLAW_STATE_DIR=%q\n" "/data/.openclaw" >> "${env_file}"
  printf "OPENCLAW_WORKSPACE_DIR=%q\n" "/data/workspace" >> "${env_file}"

  # Append any operator-allowed env var names (may include secrets; do not add secret names unless intended).
  [ -n "$allow_list" ] || true
  IFS=',' read -r -a names <<< "${allow_list}"
  for raw_name in "${names[@]}"; do
    local name
    name="$(echo "${raw_name}" | tr -d '[:space:]')"
    [ -n "${name}" ] || continue
    if [[ ! "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      continue
    fi
    # Skip if we already wrote it above.
    if [ "${name}" = "OPENCLAW_STATE_DIR" ] || [ "${name}" = "OPENCLAW_WORKSPACE_DIR" ]; then
      continue
    fi
    local value="${!name-}"
    printf "%s=%q\n" "${name}" "${value}" >> "${env_file}"
  done

  chmod 600 "${env_file}" || true
  chown "${APP_USER}:${APP_GROUP}" "${env_file}" || true
}

write_default_agent_files() {
  local write_agents_md="${OPENCLAW_WRITE_AGENTS_MD:-true}"
  local write_skills="${OPENCLAW_BOOTSTRAP_SKILLS:-true}"
  local agents_file="/data/workspace/AGENTS.md"
  local skills_dir="/data/workspace/.openclaw/skills"

  if [ "${write_agents_md}" = "true" ] && [ ! -f "${agents_file}" ]; then
    cat > "${agents_file}" <<'EOF'
# Workspace Agent Guidance

This workspace runs in Railway with a persistent volume at `/data`.

## Environment
- **State dir:** `/data/.openclaw` — config, credentials, gateway state.
- **Workspace:** `/data/workspace` — your working files and this guidance.
- **Runtime vars:** `/data/workspace/.openclaw-runtime.env` includes `OPENCLAW_STATE_DIR` and `OPENCLAW_WORKSPACE_DIR`; do not log or commit secrets from it.

## What you can do
- Use **file tools** (read, write, edit) and **exec** (shell) in this workspace. Prefer paths under `/data/workspace` and `/data/.openclaw` for persistence.
- Run the **OpenClaw CLI** for diagnostics: set `OPENCLAW_STATE_DIR=/data/.openclaw` and `OPENCLAW_WORKSPACE_DIR=/data/workspace` (e.g. source or read from `.openclaw-runtime.env`), then run `openclaw health`, `openclaw status`, `openclaw logs --tail N`, etc.
- You have coding-style tools (fs, runtime, sessions, memory, image). Exec runs on the gateway (this container); no sudo.

## Constraints
- No sudo; Tailscale and the wrapper handle networking and auth. Do not print secrets in logs or commit them to git.
- **Gateway:** Wrapper-managed (no systemd). Use Setup UI or SSH for restarts, not `/restart` or systemctl. Ignore "systemd not installed" in status.
- **Bootstrap:** `/data/workspace/bootstrap.sh` runs at wrapper startup if present; use it for one-time setup (e.g. venv, symlinks), not for secrets.
EOF
    chmod 644 "${agents_file}" || true
    chown "${APP_USER}:${APP_GROUP}" "${agents_file}" || true
  fi

  if [ "${write_skills}" = "true" ]; then
    ensure_dir "${skills_dir}"

    if [ ! -f "${skills_dir}/railway-runtime.md" ]; then
      cat > "${skills_dir}/railway-runtime.md" <<'EOF'
# Skill: Railway Runtime Operations

- Verify `/healthz` before deeper debugging.
- Keep state under `/data/.openclaw`.
- Keep working files under `/data/workspace`.
- Prefer non-destructive diagnostics first.
- You have coding-style tools (files, exec, sessions, memory). Exec runs on the gateway (this container); use workdir under `/data` for persistence. Check health with `openclaw health` after setting state/workspace env from `/data/workspace/.openclaw-runtime.env`.
- **No systemd:** The gateway is wrapper-managed. Ignore "systemd not installed" or daemon messages in `openclaw status`. Restarts are done via the Setup UI or SSH (wrapper restarts the process), not via `/restart` or systemctl.
EOF
      chmod 644 "${skills_dir}/railway-runtime.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/railway-runtime.md" || true
    fi

    if [ ! -f "${skills_dir}/workspace-self-service.md" ]; then
      cat > "${skills_dir}/workspace-self-service.md" <<'EOF'
# Skill: Workspace Self-Service

You can manage your own environment within this deploy:

- **Run commands:** Use exec with workdir `/data/workspace` or `/data`. Commands run as the gateway user (no sudo).
- **Edit files:** Use read/write/edit under `/data/workspace` and `/data/.openclaw` for persistence.
- **OpenClaw CLI:** To run `openclaw` from a task (e.g. health, logs), ensure `OPENCLAW_STATE_DIR` and `OPENCLAW_WORKSPACE_DIR` are set. Read or source `/data/workspace/.openclaw-runtime.env`, then run e.g. `openclaw health` or `openclaw logs --tail 200`.
- **Web and sessions:** Use web_fetch if enabled; use sessions and memory tools as needed.
EOF
      chmod 644 "${skills_dir}/workspace-self-service.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/workspace-self-service.md" || true
    fi

    if [ ! -f "${skills_dir}/tailscale-troubleshooting.md" ]; then
      cat > "${skills_dir}/tailscale-troubleshooting.md" <<'EOF'
# Skill: Tailscale Troubleshooting

- Treat logpolicy/TPM/UDP buffer warnings as non-fatal in containers.
- Confirm successful join via: "Tailscale joined. Node ready for SSH access."
- Use `tailscale ssh <hostname>` with userspace networking.
- Keep app setup independent from Tailscale startup health.
EOF
      chmod 644 "${skills_dir}/tailscale-troubleshooting.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/tailscale-troubleshooting.md" || true
    fi
  fi
}

install_global_npm_packages() {
  local enabled="${OPENCLAW_AUTO_PREINSTALL:-true}"
  [ "${enabled}" = "true" ] || return 0

  local pkg_list="${OPENCLAW_PREINSTALL_NPM_PACKAGES:-clawhub}"
  [ -n "${pkg_list}" ] || return 0

  # Install comma-separated packages if missing.
  IFS=',' read -r -a pkgs <<< "${pkg_list}"
  for raw_pkg in "${pkgs[@]}"; do
    local pkg
    pkg="$(echo "${raw_pkg}" | xargs)"
    [ -n "${pkg}" ] || continue
    log "Ensuring npm global package: ${pkg}"
    run_as_app bash -lc "npm ls -g --depth=0 '${pkg}' >/dev/null 2>&1 || npm i -g '${pkg}'" || true
  done
}

install_python_packages() {
  local enabled="${OPENCLAW_AUTO_PREINSTALL:-true}"
  [ "${enabled}" = "true" ] || return 0

  local pkg_list="${OPENCLAW_PREINSTALL_PIP_PACKAGES:-}"
  [ -n "${pkg_list}" ] || return 0

  IFS=',' read -r -a pkgs <<< "${pkg_list}"
  for raw_pkg in "${pkgs[@]}"; do
    local pkg
    pkg="$(echo "${raw_pkg}" | xargs)"
    [ -n "${pkg}" ] || continue
    log "Installing python package: ${pkg}"
    run_as_app python3 -m pip install --user "${pkg}" || true
  done
}

prestart_common() {
  ensure_dir /data
  ensure_dir /data/.openclaw
  ensure_dir /data/workspace
  ensure_dir /data/npm
  ensure_dir /data/npm-cache
  ensure_dir /data/pnpm
  ensure_dir /data/pnpm-store
  ensure_dir /app
  ensure_dir /home/openclaw

  write_runtime_env_file
  write_default_agent_files
  install_global_npm_packages
  install_python_packages
}
