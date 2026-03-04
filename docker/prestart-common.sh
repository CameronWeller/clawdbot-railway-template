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

This workspace runs in Railway with a persistent volume at `/data`. You are a fully capable agent: install tools, edit files, run commands.

## Environment
- **State dir:** `/data/.openclaw` — config, credentials, gateway state.
- **Workspace:** `/data/workspace` — your working files and this guidance.
- **Runtime vars:** `/data/workspace/.openclaw-runtime.env` includes `OPENCLAW_STATE_DIR` and `OPENCLAW_WORKSPACE_DIR`; do not log or commit secrets from it.

## What you can do
- **File tools:** Read, write, edit under `/data/workspace` and `/data/.openclaw`. All changes persist across restarts.
- **Exec:** Run shell commands with workdir `/data/workspace` or `/data`. Commands run as the gateway user (no sudo).
- **Install your own tools:** npm/pnpm/pip installs persist under `/data`. Use `npm i -g <pkg>`, `pnpm add -g <pkg>`, or `pip install --user <pkg>`. Binaries land in `/data/npm/bin` and `/data/pnpm` (already in PATH).
- **OpenClaw CLI:** Source `/data/workspace/.openclaw-runtime.env` then run `openclaw health`, `openclaw config set`, etc. You can enable skills or adjust config via `openclaw config set --json skills.load '{"extraDirs":["/data/workspace/.openclaw/skills"]}'` and similar.
- **Coding tools:** fs, runtime, sessions, memory, image. Gateway tool is denied; use Setup UI or SSH for restarts.

## Constraints
- No sudo; do not print secrets in logs or commit them to git.
- **Gateway:** Wrapper-managed. Use Setup UI or SSH for restarts, not `/restart` or systemctl.
- **API keys:** Model provider credentials are set by the operator via Setup; you cannot add them.
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

You can manage your own environment. Install tools, edit files, run commands—no operator approval needed for these.

- **Run commands:** Use exec with workdir `/data/workspace` or `/data`. Commands run as the gateway user (no sudo).
- **Edit files:** Use read/write/edit under `/data/workspace` and `/data/.openclaw`. All changes persist.
- **Install tools:** `npm i -g <pkg>`, `pnpm add -g <pkg>`, `pip install --user <pkg>`. Installs go to `/data/npm`, `/data/pnpm`, or user site; binaries are in PATH. Persists across restarts.
- **OpenClaw CLI:** Source `/data/workspace/.openclaw-runtime.env` then run `openclaw health`, `openclaw config set`, `openclaw logs --tail 200`, etc. You can enable skills or tweak config via `openclaw config set`.
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

    if [ ! -f "${skills_dir}/shell-diagnostics.md" ]; then
      cat > "${skills_dir}/shell-diagnostics.md" <<'EOF'
# Skill: Shell and Diagnostics

- Use exec with workdir `/data/workspace` or `/data` for persistent output.
- For OpenClaw CLI: source or read `/data/workspace/.openclaw-runtime.env` then run `openclaw health`, `openclaw status`, `openclaw logs --tail N`, `openclaw doctor`.
- Install tools as needed: `npm i -g <pkg>`, `pnpm add -g <pkg>`, `pip install --user <pkg>`. They persist under `/data`.
- Prefer `set -e` and short scripts; capture stderr. No sudo; commands run as the gateway user.
EOF
      chmod 644 "${skills_dir}/shell-diagnostics.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/shell-diagnostics.md" || true
    fi

    if [ ! -f "${skills_dir}/toolset-tuning.md" ]; then
      cat > "${skills_dir}/toolset-tuning.md" <<'EOF'
# Skill: Toolset Tuning

- Your tool profile is set in config (e.g. coding: fs, runtime, sessions, memory, image). Gateway tool is denied by default.
- You can run `openclaw config set` via exec (source `.openclaw-runtime.env` first) to enable skills, change skills.entries, or adjust agents.defaults.workspace. For tools.profile and tools.deny, the operator typically applies changes via Setup or SSH.
- Prefer read/write/edit and exec within `/data/workspace` and `/data/.openclaw` for persistence.
EOF
      chmod 644 "${skills_dir}/toolset-tuning.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/toolset-tuning.md" || true
    fi

    if [ ! -f "${skills_dir}/backup-restore.md" ]; then
      cat > "${skills_dir}/backup-restore.md" <<'EOF'
# Skill: Backup and Restore

- Operators can download a backup from Setup UI (Export backup); backup includes `/data/.openclaw` and `/data/workspace`.
- Import is via Setup UI (Import backup); it restores into `/data` and restarts the gateway. Do not commit secrets to git.
- For file-level backup: use read/write to copy important files under `/data/workspace` to another path or document where to find them.
EOF
      chmod 644 "${skills_dir}/backup-restore.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/backup-restore.md" || true
    fi

    if [ ! -f "${skills_dir}/plugin-lifecycle.md" ]; then
      cat > "${skills_dir}/plugin-lifecycle.md" <<'EOF'
# Skill: Plugin Lifecycle

- Plugins are managed by the operator: `openclaw plugins list`, `openclaw plugins enable <name>` (via Setup Debug Console or SSH).
- Config changes for plugins require a gateway restart (Setup UI or SSH). You cannot restart the gateway yourself.
- To suggest a plugin: tell the user to add it via Setup or SSH and restart.
EOF
      chmod 644 "${skills_dir}/plugin-lifecycle.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/plugin-lifecycle.md" || true
    fi

    if [ ! -f "${skills_dir}/cron-automation.md" ]; then
      cat > "${skills_dir}/cron-automation.md" <<'EOF'
# Skill: Cron and Automation

- OpenClaw cron runs in-process inside the gateway (no system cron required). Use the cron tool if allowed by your tool profile.
- Scheduled tasks run in the same container; use workdir `/data/workspace` for persistent state. No sudo.
- For recurring external triggers, use webhooks or external schedulers that call the gateway if configured.
EOF
      chmod 644 "${skills_dir}/cron-automation.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/cron-automation.md" || true
    fi

    if [ ! -f "${skills_dir}/web-research.md" ]; then
      cat > "${skills_dir}/web-research.md" <<'EOF'
# Skill: Web Research

- If web_search or web_fetch is enabled, use them for live data and docs. Respect maxChars and timeout limits.
- Prefer web_fetch for known URLs; use web_search when you need discovery. Do not log or store API keys from config.
- For SSRF safety, only fetch public or operator-allowed hosts; avoid passing user input directly into URLs when possible.
EOF
      chmod 644 "${skills_dir}/web-research.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/web-research.md" || true
    fi

    if [ ! -f "${skills_dir}/browser-canvas.md" ]; then
      cat > "${skills_dir}/browser-canvas.md" <<'EOF'
# Skill: Browser and Canvas

- If browser or canvas tools are enabled, use them for UI automation or drawing within the configured SSRF policy.
- Browser runs in the gateway environment; no separate sandbox in this Railway deploy unless configured. Prefer headless when possible.
- Do not navigate to or capture credentials; respect same-origin and operator-configured host allowlists.
EOF
      chmod 644 "${skills_dir}/browser-canvas.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/browser-canvas.md" || true
    fi

    if [ ! -f "${skills_dir}/session-governance.md" ]; then
      cat > "${skills_dir}/session-governance.md" <<'EOF'
# Skill: Session Governance

- Use sessions_list, sessions_history, sessions_send, sessions_spawn, session_status as allowed by your tool profile.
- Spawned subagents inherit tool restrictions; you cannot grant yourself tools the profile denies.
- Prefer one primary session for a task; use spawn for isolated subtasks or parallel work.
EOF
      chmod 644 "${skills_dir}/session-governance.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/session-governance.md" || true
    fi

    if [ ! -f "${skills_dir}/memory-hygiene.md" ]; then
      cat > "${skills_dir}/memory-hygiene.md" <<'EOF'
# Skill: Memory Hygiene

- Use memory_search and memory_get when the memory tool group is allowed. Do not store secrets or tokens in memory.
- Prefer short, factual entries; avoid PII unless the user explicitly asks to remember it. Respect retention settings.
- If memory is disabled by profile, use file-based state under `/data/workspace` for persistence.
EOF
      chmod 644 "${skills_dir}/memory-hygiene.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/memory-hygiene.md" || true
    fi

    if [ ! -f "${skills_dir}/config-templating.md" ]; then
      cat > "${skills_dir}/config-templating.md" <<'EOF'
# Skill: Config Templating

- Main config is at `/data/.openclaw/openclaw.json`. You can read it for diagnostics. Do not write secrets.
- You can apply config changes via exec: source `/data/workspace/.openclaw-runtime.env` then `openclaw config set --json <path> '<value>'`. Safe paths: skills.load, skills.entries, agents.defaults.workspace, tools.profile, tools.deny, tools.exec. Do not set provider credentials or gateway tokens.
- Preset snippets are in docs/agent-ergonomics-presets; use them as reference when building config values.
EOF
      chmod 644 "${skills_dir}/config-templating.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/config-templating.md" || true
    fi

    if [ ! -f "${skills_dir}/model-provider-onboarding.md" ]; then
      cat > "${skills_dir}/model-provider-onboarding.md" <<'EOF'
# Skill: Model and Provider Onboarding

- Model and auth setup is done by the operator via Setup wizard or `openclaw onboard` / config. You cannot add API keys.
- To suggest a new provider or model: point the user to Setup or OpenClaw docs; they set credentials in Railway Variables or config.
- Primary model and overrides are in agents.defaults.model and agents.defaults.models; read-only for you.
EOF
      chmod 644 "${skills_dir}/model-provider-onboarding.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/model-provider-onboarding.md" || true
    fi

    if [ ! -f "${skills_dir}/channels-health.md" ]; then
      cat > "${skills_dir}/channels-health.md" <<'EOF'
# Skill: Channels Health

- Telegram, Discord, Slack, etc. are configured by the operator. Pairing and tokens are set in Setup or config.
- If a channel shows "disconnected" or "pairing required", the user should use Setup Debug Console: openclaw devices list, openclaw devices approve <requestId>.
- You can run openclaw config get channels.telegram (or similar) for diagnostics if you have CLI env set; do not log token values.
EOF
      chmod 644 "${skills_dir}/channels-health.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/channels-health.md" || true
    fi

    if [ ! -f "${skills_dir}/git-repo-maintenance.md" ]; then
      cat > "${skills_dir}/git-repo-maintenance.md" <<'EOF'
# Skill: Git and Repo Maintenance

- You can run git commands via exec in `/data/workspace` if a repo is cloned there. No sudo; use git config for user.name/user.email if needed.
- Prefer non-destructive operations; avoid force-push or history rewrite unless the user explicitly asks. Do not commit secrets or .env with real keys.
- For clone/push over HTTPS, credentials may be in env or git credential helper; do not echo them.
EOF
      chmod 644 "${skills_dir}/git-repo-maintenance.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/git-repo-maintenance.md" || true
    fi

    if [ ! -f "${skills_dir}/secrets-hygiene.md" ]; then
      cat > "${skills_dir}/secrets-hygiene.md" <<'EOF'
# Skill: Secrets Hygiene

- Never log, echo, or commit API keys, tokens, or passwords. Do not write them into files under version control.
- Runtime env is in `/data/workspace/.openclaw-runtime.env`; only path vars are guaranteed; operator may expose more via OPENCLAW_EXPOSE_ENV_VARS. Treat all as sensitive.
- If you need to use a secret in a command, prefer env vars (e.g. from the runtime env file) over inline arguments.
EOF
      chmod 644 "${skills_dir}/secrets-hygiene.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/secrets-hygiene.md" || true
    fi

    if [ ! -f "${skills_dir}/self-healing-runbooks.md" ]; then
      cat > "${skills_dir}/self-healing-runbooks.md" <<'EOF'
# Skill: Self-Healing Runbooks

- For gateway/CLI issues: run `openclaw health`, `openclaw status` after setting OPENCLAW_STATE_DIR and OPENCLAW_WORKSPACE_DIR from `.openclaw-runtime.env`.
- For "token mismatch": operator must align gateway.auth.token and gateway.remote.token (Setup or SSH). You cannot fix this yourself.
- For "pairing required": operator uses Setup Debug Console to run openclaw devices list and openclaw devices approve <requestId>. Restarts are done via Setup UI or SSH only.
EOF
      chmod 644 "${skills_dir}/self-healing-runbooks.md" || true
      chown "${APP_USER}:${APP_GROUP}" "${skills_dir}/self-healing-runbooks.md" || true
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
