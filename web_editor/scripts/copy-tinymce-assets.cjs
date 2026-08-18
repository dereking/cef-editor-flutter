const fs = require('fs');
const path = require('path');

const srcBase = path.join(__dirname, '..', 'node_modules', 'tinymce');
const dstBase = path.join(__dirname, '..', 'dist');

// Copy TinyMCE skin files (CSS) to dist/skins.
// Vite bundles JS but TinyMCE loads skin CSS dynamically at runtime.
const skinsSrc = path.join(srcBase, 'skins');
const skinsDst = path.join(dstBase, 'skins');
if (fs.existsSync(skinsSrc)) {
  copyRecursive(skinsSrc, skinsDst);
  console.log('Copied TinyMCE skins to dist/skins');
} else {
  console.warn('TinyMCE skins directory not found');
}

function copyRecursive(src, dst) {
  if (!fs.existsSync(dst)) {
    fs.mkdirSync(dst, { recursive: true });
  }
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const dstPath = path.join(dst, entry.name);
    if (entry.isDirectory()) {
      copyRecursive(srcPath, dstPath);
    } else {
      fs.copyFileSync(srcPath, dstPath);
    }
  }
}
