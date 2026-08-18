import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import ts from 'typescript';

async function loadSizingHelper() {
  const source = await readFile(
    new URL('../src/pasted_image_size.ts', import.meta.url),
    'utf8',
  );
  const output = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  return import(`data:text/javascript;base64,${Buffer.from(output).toString('base64')}`);
}

test('converts intrinsic pixels to logical pixels at common display scalings', async () => {
  const { calculatePastedImageSize } = await loadSizingHelper();

  assert.deepEqual(
    calculatePastedImageSize({
      naturalWidth: 1000,
      naturalHeight: 600,
      devicePixelRatio: 1,
      maxWidth: 1200,
    }),
    { width: 1000, height: 600 },
  );
  assert.deepEqual(
    calculatePastedImageSize({
      naturalWidth: 1500,
      naturalHeight: 900,
      devicePixelRatio: 1.5,
      maxWidth: 1200,
    }),
    { width: 1000, height: 600 },
  );
  assert.deepEqual(
    calculatePastedImageSize({
      naturalWidth: 2000,
      naturalHeight: 1200,
      devicePixelRatio: 2,
      maxWidth: 1200,
    }),
    { width: 1000, height: 600 },
  );
});

test('caps the logical width while preserving its aspect ratio', async () => {
  const { calculatePastedImageSize } = await loadSizingHelper();

  assert.deepEqual(
    calculatePastedImageSize({
      naturalWidth: 4000,
      naturalHeight: 2000,
      devicePixelRatio: 2,
      maxWidth: 900,
    }),
    { width: 900, height: 450 },
  );
});

test('returns null for invalid sizing input', async () => {
  const { calculatePastedImageSize } = await loadSizingHelper();

  assert.equal(
    calculatePastedImageSize({
      naturalWidth: 0,
      naturalHeight: 600,
      devicePixelRatio: 1,
      maxWidth: 1200,
    }),
    null,
  );
  assert.equal(
    calculatePastedImageSize({
      naturalWidth: 1000,
      naturalHeight: 600,
      devicePixelRatio: Number.NaN,
      maxWidth: 1200,
    }),
    null,
  );
});

test('normalizes pasted images through the shared sizing policy', async () => {
  const mainSource = await readFile(
    new URL('../src/main.ts', import.meta.url),
    'utf8',
  );

  assert.match(mainSource, /calculatePastedImageSize/);
  assert.match(mainSource, /PastePostProcess/);
});

test('uses the host display scale instead of the CEF page scale when provided', async () => {
  const mainSource = await readFile(
    new URL('../src/main.ts', import.meta.url),
    'utf8',
  );

  assert.match(mainSource, /devicePixelRatio\?: number/);
  assert.match(mainSource, /config\.devicePixelRatio/);
});
