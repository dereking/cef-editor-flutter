#!/usr/bin/env node
// Regenerates the `assets:` list in the cef_editor pubspec from the built
// web_editor/dist contents.
//
// Flutter's web asset bundler skips the nested `skins/` directory when it is
// declared as a directory asset, but bundles the same files when they are
// listed explicitly. This script keeps the explicit list in sync with the
// editor build.
//
// Usage: node web_editor/scripts/pubspec_assets.mjs
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';

const root = resolve(process.argv[2] ?? join(import.meta.dirname, '..', '..'));
const distDir = join(root, 'web_editor', 'dist');
const pubspecPath = join(root, 'pubspec.yaml');

const files = [];
(function walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else files.push(relative(distDir, full).replaceAll('\\', '/'));
  }
})(distDir);
files.sort();

const lines = [
  '  assets:',
  ...files.map((f) => `    - web_editor/dist/${f}`),
];

const pubspec = readFileSync(pubspecPath, 'utf8');
const updated = pubspec.replace(/  assets:[\s\S]*?(?=\n(?:  \w|$))/, lines.join('\n'));
writeFileSync(pubspecPath, updated);

console.log(`[cef_editor] pubspec assets updated with ${files.length} files`);
