// Test server: build first, bind only to loopback and expose only public files.
const { spawnSync } = require('node:child_process');
const { readFile } = require('node:fs/promises');
const { createServer } = require('node:http');
const { resolve } = require('node:path');

const root = resolve(__dirname, '../..');
const build = spawnSync(process.env.PYTHON || 'python', ['scripts/build-site.py'], {
  cwd: root, stdio: 'inherit',
});
if (build.error) throw build.error;
if (build.status !== 0) process.exit(build.status || 1);

const files = new Map([
  ['', ['index.html', 'text/html; charset=utf-8']],
  ['index.html', ['index.html', 'text/html; charset=utf-8']],
  ['styles.css', ['styles.css', 'text/css; charset=utf-8']],
  ['app.js', ['app.js', 'text/javascript; charset=utf-8']],
  ['favicon.svg', ['favicon.svg', 'image/svg+xml']],
  ['prompt.md', ['prompt.md', 'text/plain; charset=utf-8']],
]);
const prefix = '/repo-as-an-agent/';
createServer(async (request, response) => {
  const pathname = new URL(request.url, 'http://127.0.0.1').pathname;
  const file = pathname.startsWith(prefix) && files.get(pathname.slice(prefix.length));
  if (!file) { response.writeHead(404).end(); return; }
  try {
    const body = await readFile(resolve(root, '_site', file[0]));
    response.writeHead(200, { 'Content-Type': file[1], 'Cache-Control': 'no-store' }).end(body);
  } catch {
    response.writeHead(500).end();
  }
}).listen(4173, '127.0.0.1');
