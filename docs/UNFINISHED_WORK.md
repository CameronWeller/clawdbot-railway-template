# Unfinished Work Tracker

Use this file to track work that was started but not completed in the same session/PR.

## How to use

- Add new items at the top of **Active Items**.
- Keep entries short and concrete so someone else can pick up quickly.
- Move completed items to **Closed Items** with the close date.
- Link related PRs/issues where possible.

## Status values

- `blocked` - cannot proceed due to dependency/access/bug outside this repo.
- `deferred` - intentionally postponed to a later PR.
- `needs-verification` - code change done, but external validation still pending.

## Active Items

### UW-20260302-01 - Restore deterministic OpenClaw build lockfile
- Status: needs-verification
- Owner: @maintainers
- Area: `Dockerfile` openclaw build stage
- Started: 2026-03-02
- Context: The Docker build previously rewrote extension `package.json` dependencies from `workspace:*` / strict ranges to `*` before install. That broke lockfile parity. We removed the rewrite and restored `pnpm install --frozen-lockfile` for deterministic builds.
- Why unfinished: CI must validate the build passes. If it fails (e.g. upstream tag has unpublished deps), revert to the rewrite + `--no-frozen-lockfile` and document in this file.
- Next step: Confirm CI passes. If it fails, revert Dockerfile and add: "Re-enable rewrite (see git history) and use `--no-frozen-lockfile` until upstream fixes packaging."
- Depends on: upstream OpenClaw packaging at pinned tag v2026.2.9
- Links: none

### Entry template

```md
### UW-YYYYMMDD-01 - Short title
- Status: blocked | deferred | needs-verification
- Owner: @name
- Area: file/path/or/system
- Started: YYYY-MM-DD
- Context: one-paragraph summary of what was attempted
- Why unfinished: exact blocker or reason for deferral
- Next step: first concrete action to resume
- Depends on: issue/PR/env access/person (or "none")
- Links: PR #123, Issue #456
```

## Closed Items

### UW-20260302-02 - Tailscale SSH integration and credential segregation
- Status: closed (2026-03-02)
- Owner: @cwelleron
- Area: `Dockerfile-tailscale`, `docker/entrypoint-tailscale.sh`, `docs/SECURITY.md`, `README.md`
- Context: Added a Tailscale-enabled Docker variant (`Dockerfile-tailscale`) that starts `tailscaled` in userspace networking mode and runs `tailscale up --ssh` at container startup. This enables passwordless SSH access via `tailscale ssh <hostname>` from any device on the tailnet without exposing an SSH port.
- Resolution:
  - Created `Dockerfile-tailscale` installing Tailscale from the official Debian repo.
  - Created `docker/entrypoint-tailscale.sh` that starts `tailscaled`, calls `tailscale up`, then drops to the `openclaw` user.
  - Security-hardened: replaced personal hostname `claw-archimedes` with generic default `openclaw-railway`; `TS_AUTHKEY` is always injected at runtime, never baked into the image.
  - Created `access-controls.example.json` as a sanitized ACL policy template.
  - Added `access controls.json` to `.gitignore` to prevent real email/tag/name from ever being committed.
  - Created `docs/SECURITY.md` with full credential segregation guide, contributor checklist, and Tailscale flag explanations.
  - Expanded `README.md` with a Security section and improved Tailscale SSH instructions.
- Links: commits `2fc9ea4`, `19b9bd9`
