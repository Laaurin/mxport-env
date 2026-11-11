import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
export default defineConfig({
    plugins: [
        vue({
            template: {
                compilerOptions: {
                    isCustomElement: function (tag) { return tag.startsWith('ix-'); },
                },
            },
        }),
    ],
    server: {
        port: 5173,
        host: '0.0.0.0',
        proxy: {
            // 1. Central Keycloak Identity Provider Ingress
            '/cluster-api/keycloak': {
                target: 'http://127.0.0.1:80',
                changeOrigin: true,
                headers: {
                    Host: 'keycloak.localhost',
                },
                rewrite: function (path) { return path.replace(/^\/cluster-api\/keycloak/, ''); },
            },
            // 2. Central Factory-X Company Lookup Discovery Service Ingress
            '/cluster-api/lookup': {
                target: 'http://127.0.0.1:80',
                changeOrigin: true,
                headers: {
                    Host: 'lookup.localhost',
                },
                rewrite: function (path) { return path.replace(/^\/cluster-api\/lookup/, ''); },
            },
            // 3. Dynamic Dataspace Endpoint Proxy (No hardcoded actor hosts!)
            // Routes to whatever host was dynamically resolved via Company Lookup:
            // /cluster-api/host/<resolved-domain>/<path> -> http://127.0.0.1:80/<path> with Host: <resolved-domain>
            '/cluster-api/host': {
                target: 'http://127.0.0.1:80',
                changeOrigin: true,
                configure: function (proxy) {
                    proxy.on('proxyReq', function (proxyReq, req) {
                        var headerHost = req.headers['x-dataspace-target-host'];
                        if (typeof headerHost === 'string' && headerHost.length > 0) {
                            proxyReq.setHeader('Host', headerHost);
                            return;
                        }
                        var rawUrl = req.originalUrl || req.url || '';
                        var match = rawUrl.match(/^\/cluster-api\/host\/([^/?#]+)/);
                        if (match && match[1]) {
                            proxyReq.setHeader('Host', match[1]);
                        }
                    });
                },
                rewrite: function (path) { return path.replace(/^\/cluster-api\/host\/[^/?#]+/, ''); },
            },
        },
    },
});
