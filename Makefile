# Optional convenience targets for Docker build/run/smoke.
# See docs/WSL-DOCKER-TESTING.md for full WSL workflow.

IMAGE_NAME ?= clawdbot-railway-template
DATA_DIR  ?= .tmpdata
PORT      ?= 8080
SETUP_PWD ?= test

.PHONY: build run run-tailscale smoke

build:
	docker build -t $(IMAGE_NAME) .

run: build
	mkdir -p $(DATA_DIR)
	docker run --rm -p $(PORT):$(PORT) \
	  -e PORT=$(PORT) \
	  -e SETUP_PASSWORD=$(SETUP_PWD) \
	  -e OPENCLAW_STATE_DIR=/data/.openclaw \
	  -e OPENCLAW_WORKSPACE_DIR=/data/workspace \
	  -v "$(CURDIR)/$(DATA_DIR):/data" \
	  $(IMAGE_NAME)

run-tailscale:
	docker build -f Dockerfile-tailscale -t $(IMAGE_NAME):tailscale .
	mkdir -p $(DATA_DIR)
	docker run --rm -p $(PORT):$(PORT) \
	  -e PORT=$(PORT) \
	  -e SETUP_PASSWORD=$(SETUP_PWD) \
	  -e OPENCLAW_STATE_DIR=/data/.openclaw \
	  -e OPENCLAW_WORKSPACE_DIR=/data/workspace \
	  -v "$(CURDIR)/$(DATA_DIR):/data" \
	  $(IMAGE_NAME):tailscale

# Run after 'make run' in another terminal, or run container in background.
smoke:
	@echo "Checking /healthz..."
	@curl -sf http://localhost:$(PORT)/healthz && echo " OK" || (echo " FAIL"; exit 1)
	@echo "Checking /setup/healthz..."
	@curl -sf -u ":$(SETUP_PWD)" http://localhost:$(PORT)/setup/healthz && echo " OK" || (echo " FAIL"; exit 1)
	@echo "Smoke checks passed."
