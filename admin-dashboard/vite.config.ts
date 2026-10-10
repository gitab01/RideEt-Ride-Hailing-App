import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: process.env.VITE_API_PROXY ?? 'http://localhost:8080',
        changeOrigin: true,
        // The live map rides on STOMP over a WebSocket upgrade; a plain http proxy answers
        // the REST calls and silently drops the socket.
        ws: true,
      },
    },
  },
})
