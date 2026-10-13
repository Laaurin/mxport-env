const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = process.env.PORT || 3333;
const PUBLIC_DIR = __dirname;

const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

function handleCors(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return true;
  }
  return false;
}

const server = http.createServer((req, res) => {
  if (handleCors(req, res)) return;

  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = parsedUrl.pathname;

  // 1. API Proxy for Dataspace requests (bypasses browser CORS when testing local k3d ingress)
  if (pathname === '/api/proxy' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        const targetUrl = payload.url;
        const targetMethod = payload.method || 'GET';
        const targetHeaders = payload.headers || {};
        const targetBody = payload.body || null;

        if (!targetUrl) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Missing target url' }));
          return;
        }

        const parsedTarget = new URL(targetUrl);
        const options = {
          hostname: parsedTarget.hostname,
          port: parsedTarget.port || (parsedTarget.protocol === 'https:' ? 443 : 80),
          path: parsedTarget.pathname + parsedTarget.search,
          method: targetMethod,
          headers: {
            ...targetHeaders,
            'Host': parsedTarget.hostname
          },
          timeout: 8000
        };

        const client = http.request(options, targetRes => {
          let responseBody = '';
          targetRes.on('data', chunk => { responseBody += chunk; });
          targetRes.on('end', () => {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
              status: targetRes.statusCode,
              statusText: targetRes.statusMessage,
              headers: targetRes.headers,
              body: responseBody
            }));
          });
        });

        client.on('error', err => {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            status: 0,
            statusText: 'Network Error',
            error: err.message
          }));
        });

        client.on('timeout', () => {
          client.destroy();
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            status: 504,
            statusText: 'Gateway Timeout',
            error: 'Request timed out after 8000ms'
          }));
        });

        if (targetBody) {
          client.write(typeof targetBody === 'string' ? targetBody : JSON.stringify(targetBody));
        }
        client.end();
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON payload' }));
      }
    });
    return;
  }

  // 2. Static File Serving
  let filePath = path.join(PUBLIC_DIR, pathname === '/' ? 'index.html' : pathname);
  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('404 Not Found');
      } else {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('500 Internal Server Error');
      }
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content);
    }
  });
});

server.listen(PORT, () => {
  console.log(`\n================================================================`);
  console.log(` 🚀 Dataspace Test Workbench running at: http://localhost:${PORT}`);
  console.log(`================================================================\n`);
});
