import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

function readServerSource() {
  return fs.readFileSync(new URL("../src/server.js", import.meta.url), "utf8");
}

// Fix 1: startup config-sync must NOT call ensureGatewayRunning() before config set.
// If the gateway is up during config set, its file-watcher sends SIGUSR1 on every
// write → repeated gateway restarts (the restart loop seen in production logs).
test("startup config sync does not start gateway before config set", () => {
  const src = readServerSource();

  // Find the sync block that runs on startup.
  const syncStart = src.indexOf("syncing gateway tokens and trustedProxies in config");
  assert.ok(syncStart >= 0, "sync log line not found");

  // The first config set command in the sync block.
  const firstConfigSet = src.indexOf('clawArgs(["config", "set", "gateway.auth.mode"', syncStart);
  assert.ok(firstConfigSet >= 0, "first config set in sync block not found");

  // ensureGatewayRunning() must NOT appear between the start of the sync block and the
  // first config set – that would start the gateway before the file writes.
  const between = src.slice(syncStart, firstConfigSet);
  assert.ok(
    !between.includes("ensureGatewayRunning()"),
    "ensureGatewayRunning() must not be called before config set in the startup sync block",
  );
});

// Fix 1 (also): setup/api/run post-onboard config section must NOT call ensureGatewayRunning().
test("setup run handler does not start gateway before post-onboard config set", () => {
  const src = readServerSource();

  // Find the post-onboard config section.
  const okBlock = src.indexOf("Optional setup (only after successful onboarding)");
  assert.ok(okBlock >= 0, "post-onboard setup block comment not found");

  const firstConfigSet = src.indexOf('clawArgs(["config", "set", "gateway.auth.mode"', okBlock);
  assert.ok(firstConfigSet >= 0, "first config set in post-onboard block not found");

  const between = src.slice(okBlock, firstConfigSet);
  assert.ok(
    !between.includes("ensureGatewayRunning()"),
    "ensureGatewayRunning() must not be called before config set in the post-onboard block",
  );
});

// Fix 2: proxy handlers must inject the token into the URL path (not just headers).
// OpenClaw's Control UI reads the token from the ?token= URL param for WS connections.
test("proxyReq handler injects token into URL path", () => {
  const src = readServerSource();
  const idx = src.indexOf('proxy.on("proxyReq"');
  assert.ok(idx >= 0);
  const snippet = src.slice(idx, idx + 500);
  assert.match(snippet, /injectTokenIntoPath/);
});

test("proxyReqWs handler injects token into URL path", () => {
  const src = readServerSource();
  const idx = src.indexOf('proxy.on("proxyReqWs"');
  assert.ok(idx >= 0);
  const snippet = src.slice(idx, idx + 500);
  assert.match(snippet, /injectTokenIntoPath/);
});

test("injectTokenIntoPath appends token= to URL when missing", () => {
  const src = readServerSource();
  // Verify the function exists and handles the two URL cases (with/without existing query).
  assert.match(src, /function injectTokenIntoPath\(proxyReq\)/);
  assert.match(src, /currentPath\.includes\("token="\)/);
  assert.match(src, /encodeURIComponent\(OPENCLAW_GATEWAY_TOKEN\)/);
});

// Fix 3: util._extend shim silences DEP0060 on Node >=22.
test("util._extend is patched to Object.assign to suppress DEP0060", () => {
  const src = readServerSource();
  assert.match(src, /import util from "node:util"/);
  assert.match(src, /util\._extend\s*=\s*Object\.assign/);
});
