# Security & Credential Segregation Guide

This document covers how credentials, personal identifiers, and sensitive configuration are kept out of the public repository, and what safe defaults look like for contributors and self-hosters alike.

---

## Guiding principle

> **Nothing personal or secret belongs in the repo.**
> Runtime secrets go in Railway Variables (or your equivalent secrets manager).
> Personal device identifiers stay local and git-ignored.

---

## What is and is not committed

| File / value | Committed? | Why |
|---|---|---|
| `Dockerfile-tailscale` | Yes | Contains only generic defaults; no personal data |
| `docker/entrypoint-tailscale.sh` | Yes | Reads all secrets from env at runtime |
| `access-controls.example.json` | Yes | Sanitized placeholder — safe for contributors |
| `access controls.json` | **No** (git-ignored) | Contains your real email, tag name, device names |
| `TS_AUTHKEY` value | **Never** | Injected at runtime via Railway Variables |
| `TS_HOSTNAME` personal value | **Never** | Overridden at runtime; generic default in image |
| `SETUP_PASSWORD` | **Never** | Runtime Railway Variable |
| `OPENCLAW_GATEWAY_TOKEN` | **Never** | Runtime Railway Variable or auto-generated |

---

## Environment variables — what goes where

### Must be set at runtime (Railway Variables or `-e`)

| Variable | Purpose | Notes |
|---|---|---|
| `SETUP_PASSWORD` | HTTP Basic auth for `/setup` and `/openclaw` | Required — container refuses to start without it |
| `OPENCLAW_GATEWAY_TOKEN` | Protects the OpenClaw gateway | If unset, one is auto-generated (less ideal for templates) |
| `TS_AUTHKEY` | Authenticates the container to your Tailscale network | Generate at [Tailscale Admin → Settings → Keys](https://login.tailscale.com/admin/settings/keys). Mark as ephemeral if desired. |
| `TS_HOSTNAME` | Node name visible in your tailnet | Set to something meaningful to you (e.g. `myapp-prod`). Default is the generic `openclaw-railway`. |

### Recommended (set in Railway Variables)

| Variable | Recommended value |
|---|---|
| `OPENCLAW_STATE_DIR` | `/data/.openclaw` |
| `OPENCLAW_WORKSPACE_DIR` | `/data/workspace` |
| `RAILWAY_DOCKERFILE_PATH` | `Dockerfile-tailscale` (only if using Tailscale variant) |

### Never set in the Dockerfile or committed config

- `TS_AUTHKEY` — auth keys are credentials; treat like passwords
- `SETUP_PASSWORD` — user-defined secret
- Any real email address, device IP, or personal hostname

---

## Tailscale — secure setup guide

### 1. Generate an auth key

Go to [Tailscale Admin → Settings → Keys](https://login.tailscale.com/admin/settings/keys) and create a key.

Options:
- **Reusable**: useful during development; rotate regularly.
- **Ephemeral**: node is auto-removed from the tailnet when it disconnects — recommended for Railway deployments since containers are ephemeral by nature.
- **Pre-authorized**: skips the approval step in the admin console.

### 2. Set the key in Railway — never in the Dockerfile

In Railway → your service → Variables:

```
TS_AUTHKEY=tskey-auth-<your-key-here>
```

Mark it as a **secret** variable so it is masked in logs.

### 3. Set your hostname

```
TS_HOSTNAME=myapp-railway
```

This is what you'll use to SSH: `tailscale ssh myapp-railway`. Choose something that identifies the deployment, not your personal machine name.

### 4. ACL policy (access controls)

The Tailscale admin console lets you paste a JSON ACL policy that controls who can SSH into what.

- Use `access-controls.example.json` in this repo as a starting template.
- Copy it into your Tailscale admin console and replace the placeholders:
  - `you@example.com` → your Tailscale login email
  - `tag:yourdeploymenttag` → the tag you assign to the Railway container (must match the tag in `TS_EXTRA_ARGS` if using tagged auth keys)
- **Do not commit your real policy.** The real `access controls.json` is git-ignored.

### 5. Flags used and why

The image sets these defaults via `TS_EXTRA_ARGS`:

| Flag | Reason |
|---|---|
| `--accept-routes` | Accept subnet routes advertised by other nodes on your tailnet |
| `--accept-dns=false` | Do not override container DNS with Tailscale's MagicDNS — Railway containers rely on their own DNS |
| `--tun=userspace-networking` | Required in containers that don't have access to `/dev/net/tun` (Railway, most cloud containers) |
| `--ssh` | Enable Tailscale SSH so you can `tailscale ssh <hostname>` without running a separate OpenSSH daemon |

Override any of these in Railway Variables:

```
TS_EXTRA_ARGS=--accept-routes --accept-dns=false --advertise-tags=tag:yourdeploymenttag
```

### 6. Connect

Once deployed:

```bash
tailscale ssh <TS_HOSTNAME>
# e.g. tailscale ssh myapp-railway
```

No password. No exposed SSH port. Access is gated entirely by your Tailscale ACL policy.

---

## Contributor checklist — before opening a PR

Before pushing or opening a pull request, verify:

- [ ] `git status` shows `access controls.json` as **untracked** (not staged, not committed)
- [ ] No real email addresses appear in any committed file (`git grep -i "@.*\\.com"`)
- [ ] No `tskey-` strings appear in any committed file (`git grep "tskey"`)
- [ ] No personal hostnames (machine names, usernames) appear in Dockerfiles or scripts
- [ ] `TS_AUTHKEY` in `Dockerfile-tailscale` is empty string `""` — never a real key
- [ ] `TS_HOSTNAME` default in committed files is the generic `openclaw-railway`, not your personal name

Quick command to run before any commit:

```bash
git diff --cached | grep -iE "tskey-|@gmail|@.*\.com|password\s*=\s*\S"
```

If that grep returns anything, stop and review before committing.

---

## What Tailscale Userspace Networking means for SSH

Because Railway containers don't have `/dev/net/tun`, this deployment uses `--tun=userspace-networking`. This means:

- `tailscaled` runs entirely in userspace — no kernel module required.
- **Tailscale SSH** (`tailscale ssh <hostname>`) works correctly.
- Standard `openssh-server` with a regular `ssh` client does **not** work in this mode — use `tailscale ssh` instead.
- The container is reachable from any device on your tailnet (subject to ACL policy) at its Tailscale IP or hostname.

---

## File reference

| File | Purpose |
|---|---|
| `Dockerfile-tailscale` | Docker image with Tailscale installed; use via `RAILWAY_DOCKERFILE_PATH=Dockerfile-tailscale` |
| `docker/entrypoint-tailscale.sh` | Starts `tailscaled`, runs `tailscale up`, then drops to the `openclaw` user |
| `access-controls.example.json` | Sanitized ACL policy template — copy to Tailscale admin console |
| `access controls.json` | Your real ACL policy — **git-ignored**, local only |
| `.gitignore` | Explicitly excludes `access controls.json` |
