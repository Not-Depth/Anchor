import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { extname, resolve, relative, isAbsolute, sep } from 'node:path';
import { webRoot, mapPath } from './build.mjs';

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
};
export function createAppServer({ root = webRoot, built = false } = {}) {
  return createServer(async (request, response) => {
    if (!['GET', 'HEAD'].includes(request.method)) {
      response.writeHead(405, { Allow: 'GET, HEAD' });
      response.end();
      return;
    }
    try {
      const urlPath = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
      // Allow only browser assets, never the repository's .git directory or scripts.
      const allowed =
        ['/', '/index.html', '/styles.css', '/favicon.svg', '/data/demo_map.json'].includes(
          urlPath,
        ) ||
        (urlPath.startsWith('/src/') && urlPath.endsWith('.js'));
      if (!allowed || urlPath.includes('\\') || urlPath.includes('\0')) {
        response.writeHead(404);
        response.end('Not found');
        return;
      }
      const file =
        !built && urlPath === '/data/demo_map.json'
          ? mapPath
          : resolve(root, urlPath === '/' ? 'index.html' : `.${urlPath}`);
      const rel = relative(root, file);
      const sharedMap = !built && file === mapPath;
      if (!sharedMap && (rel === '..' || rel.startsWith(`..${sep}`) || isAbsolute(rel))) {
        response.writeHead(404);
        response.end('Not found');
        return;
      }
      const body = await readFile(file);
      response.writeHead(200, {
        'Content-Type': contentTypes[extname(file)] || 'application/octet-stream',
        'Cache-Control': 'no-cache',
        'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy':
          "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'",
      });
      response.end(request.method === 'HEAD' ? undefined : body);
    } catch (error) {
      response.writeHead(error instanceof URIError ? 400 : error.code === 'ENOENT' ? 404 : 500);
      response.end('Unable to serve this file.');
    }
  });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.PORT ?? 5173);
  if (!Number.isInteger(port) || port < 1 || port > 65535)
    throw new Error('PORT must be a number between 1 and 65535.');
  const built = process.argv.includes('--built');
  const server = createAppServer({ root: built ? resolve(webRoot, 'dist') : webRoot, built });
  server.on('error', (error) => {
    console.error(
      error.code === 'EADDRINUSE'
        ? `Port ${port} is busy. Set PORT to another value and try again.`
        : error.message,
    );
    process.exitCode = 1;
  });
  server.listen(port, '127.0.0.1', () => console.log(`Anchor Web: http://127.0.0.1:${port}`));
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close());
}
