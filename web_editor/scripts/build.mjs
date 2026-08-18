#!/usr/bin/env node
// Builds the TinyMCE editor web assets (web_editor/) from TypeScript source.
//
// Usage:
//   node web_editor/scripts/build.mjs [web_editor_dir]
//
// Invoked automatically by the plugin's CMake during a host build (see
// windows/CMakeLists.txt) so the editor JS is always compiled from source and
// published to the host's build directory. Also usable standalone.
import { execSync } from 'node:child_process';
import { existsSync, realpathSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';

// Resolve symlinks: when invoked from the host's CMake build, the web_editor
// dir may be reached through flutter's .plugin_symlinks (a symlink), which
// breaks vite's relative output-path computation.
const webEditorDir = realpathSync(
  resolve(process.argv[2] ?? join(import.meta.dirname, '..')),
);

console.log(`[cef_editor] building editor web assets in ${webEditorDir}`);

if (!existsSync(join(webEditorDir, 'package.json'))) {
  throw new Error(`web_editor package.json not found in ${webEditorDir}`);
}

const logPath = join(tmpdir(), 'cef_editor_build.log');
const appendLog = (text) => {
  try {
    writeFileSync(logPath, `${new Date().toISOString()}\n${text}\n`, { flag: 'a' });
  } catch (_) {}
};

const run = (cmd) => {
  try {
    const out = execSync(cmd, {
      cwd: webEditorDir,
      encoding: 'utf8',
      shell: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    console.log(out);
  } catch (e) {
    const detail = `[cef_editor] command failed: ${cmd}\n` +
      `stderr:\n${e.stderr ?? '(none)'}\n` +
      `stdout:\n${e.stdout ?? '(none)'}\n` +
      `error: ${e.message}`;
    appendLog(detail);
    console.error(detail);
    throw e;
  }
};

run('npm ci --no-audit --no-fund');

// The npm-script route mis-resolves the vite root under some MSBuild
// environments, so drive vite directly with an explicit --root.
const viteBin = join(webEditorDir, 'node_modules', 'vite', 'bin', 'vite.js');
if (!existsSync(viteBin)) {
  throw new Error(`vite not found at ${viteBin}; run "npm ci" in web_editor first`);
}
run(`node "${viteBin}" build --base=/mail-editor/ "${webEditorDir}"`);
run('node scripts/copy-tinymce-assets.cjs');

console.log('[cef_editor] editor web assets built: web_editor/dist');
