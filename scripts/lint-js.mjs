#!/usr/bin/env node
/**
 * Syntax-check all src/*.js and test/*.js with node --check.
 * Cross-platform (Node 22+). Used by npm run lint.
 */
import { readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { spawnSync } from 'child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dirs = ['src', 'test'];

const files = [];
for (const d of dirs) {
  const path = join(root, d);
  try {
    for (const name of readdirSync(path)) {
      if (name.endsWith('.js')) files.push(join(path, name));
    }
  } catch {
    // dir missing, skip
  }
}

let failed = 0;
for (const file of files.sort()) {
  const r = spawnSync(process.execPath, ['--check', file], {
    stdio: 'inherit',
    cwd: root,
  });
  if (r.status !== 0) failed++;
}
process.exit(failed ? 1 : 0);
