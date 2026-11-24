import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Hosted previews proxy requests with their own hostname. Accept that one when
// the environment provides it, rather than hardcoding a machine-specific host.
const previewHost = process.env.VITE_PREVIEW_HOST;

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    strictPort: true,
    allowedHosts: previewHost ? [previewHost, 'localhost', '127.0.0.1'] : undefined,
  },
});
