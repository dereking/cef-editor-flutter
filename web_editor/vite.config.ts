import { defineConfig } from 'vite';

export default defineConfig({
  base: '/mail-editor/',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: false,
  },
  server: {
    host: '127.0.0.1',
    port: 5178,
    strictPort: true,
  },
});
