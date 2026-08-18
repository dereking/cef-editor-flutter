import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const mainSource = await readFile(
  new URL('../src/main.ts', import.meta.url),
  'utf8',
);
const assetScript = await readFile(
  new URL('../scripts/copy-tinymce-assets.cjs', import.meta.url),
  'utf8',
);

test('registers TinyMCE default icons through the module bundle', () => {
  assert.match(mainSource, /import ['"]tinymce\/icons\/default['"];?/);
  assert.doesNotMatch(mainSource, /__mailEditorIcons|new Function\(iconCode\)/);
  assert.doesNotMatch(assetScript, /icons\.min\.js|__mailEditorIcons/);
});
