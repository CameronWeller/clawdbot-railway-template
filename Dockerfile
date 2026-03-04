# Build openclaw from source to avoid npm packaging gaps (some dist files are not shipped).
FROM node:22-bookworm AS openclaw-build

# Dependencies needed for openclaw build (cache mounts speed repeated CI/builds)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

# Install Bun (openclaw build uses it)
ARG BUN_VERSION=1.2.22
RUN curl -fsSL https://bun.sh/install | bash -s -- "bun-v${BUN_VERSION}" \
  && /root/.bun/bin/bun --version | grep -Fx "${BUN_VERSION}"
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /openclaw

# Pin to a known-good ref (tag/branch). Override in Railway template settings if needed.
# Using a released tag avoids build breakage when `main` temporarily references unpublished packages.
ARG OPENCLAW_GIT_REF=v2026.2.9
RUN git clone --depth 1 --branch "${OPENCLAW_GIT_REF}" https://github.com/openclaw/openclaw.git .

# Deterministic install: use frozen lockfile for reproducible builds.
# If upstream adds workspace:* or strict ranges that cause install to fail, see docs/UNFINISHED_WORK.md (UW-20260302-01).
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
  pnpm install --frozen-lockfile
RUN pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:install && pnpm ui:build


# Runtime image
FROM node:22-bookworm
ENV NODE_ENV=production

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    tini \
    gosu \
    python3 \
    python3-venv \
  && rm -rf /var/lib/apt/lists/*

# `openclaw update` expects pnpm. Provide it in the runtime image.
RUN corepack enable && corepack prepare pnpm@10.23.0 --activate

# Persist user-installed tools by default by targeting the Railway volume.
# - npm global installs -> /data/npm
# - pnpm global installs -> /data/pnpm (binaries) + /data/pnpm-store (store)
ENV NPM_CONFIG_PREFIX=/data/npm
ENV NPM_CONFIG_CACHE=/data/npm-cache
ENV PNPM_HOME=/data/pnpm
ENV PNPM_STORE_DIR=/data/pnpm-store
ENV PATH="/data/npm/bin:/data/pnpm:${PATH}"

WORKDIR /app

# Wrapper deps
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# Copy built openclaw
COPY --from=openclaw-build /openclaw /openclaw

# Provide an openclaw executable
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec node /openclaw/dist/entry.js "$@"' > /usr/local/bin/openclaw \
  && chmod +x /usr/local/bin/openclaw

COPY src ./src
COPY docs ./docs
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/prestart-common.sh /usr/local/bin/prestart-common.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/prestart-common.sh \
  && chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/prestart-common.sh \
  && groupadd --system --gid 110 openclaw \
  && useradd --system --uid 110 --gid openclaw --create-home --home-dir /home/openclaw openclaw

# Optional out-of-box bootstrap behavior (non-root safe):
# - installs npm globals (default: clawhub) into /data/npm
# - can install optional python packages into user site
# - can project selected env vars into /data/workspace/.openclaw-runtime.env for agent context
ENV OPENCLAW_AUTO_PREINSTALL=true
ENV OPENCLAW_PREINSTALL_NPM_PACKAGES="clawhub"
ENV OPENCLAW_PREINSTALL_PIP_PACKAGES=""
ENV OPENCLAW_EXPOSE_ENV_VARS=""
ENV OPENCLAW_WRITE_AGENTS_MD=true
ENV OPENCLAW_BOOTSTRAP_SKILLS=true

# The wrapper listens on $PORT.
# IMPORTANT: Do not set a default PORT here.
# Railway injects PORT at runtime and routes traffic to that port.
# If we force a different port, deployments can come up but the domain will route elsewhere.
EXPOSE 8080

# Ensure PID 1 reaps zombies and forwards signals, and drop to non-root before app start.
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["node", "src/server.js"]
