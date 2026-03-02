import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

function readServerSource() {
  return fs.readFileSync(new URL("../src/server.js", import.meta.url), "utf8");
}

test("server exits fast when SETUP_PASSWORD is missing", () => {
  const src = readServerSource();
  assert.match(src, /FATAL: SETUP_PASSWORD is required/);
  assert.match(src, /process\.exit\(1\)/);
});

test("mutating setup endpoints include CSRF middleware", () => {
  const src = readServerSource();
  assert.match(src, /app\.post\("\/setup\/api\/run", requireSetupAuth, requireSetupCsrf,/);
  assert.match(src, /app\.post\("\/setup\/api\/console\/run", requireSetupAuth, requireSetupCsrf,/);
  assert.match(src, /app\.post\("\/setup\/api\/config\/raw", requireSetupAuth, requireSetupCsrf,/);
  assert.match(src, /app\.post\("\/setup\/api\/pairing\/approve", requireSetupAuth, requireSetupCsrf,/);
  assert.match(src, /app\.post\("\/setup\/api\/devices\/approve", requireSetupAuth, requireSetupCsrf,/);
  assert.match(src, /app\.post\("\/setup\/api\/reset", requireSetupAuth, requireSetupCsrf,/);
  assert.match(src, /app\.post\("\/setup\/import", requireSetupAuth, requireSetupCsrf,/);
});

test("tar import hardening blocks link entries and preserves safe paths", () => {
  const src = readServerSource();
  assert.match(src, /function looksSafeTarEntry\(entry\)/);
  assert.match(src, /type !== "SymbolicLink"/);
  assert.match(src, /type !== "Link"/);
  assert.match(src, /preservePaths:\s*false/);
  assert.match(src, /looksSafeTarPath\(p\) && looksSafeTarEntry\(entry\)/);
});
