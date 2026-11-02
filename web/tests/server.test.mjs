import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createAppServer } from '../scripts/server.mjs';
import { build } from '../scripts/build.mjs';

test('development and built servers serve the app, shared map and modules safely', async () => {
  const output = await build();
  for (const options of [{}, { root: output, built: true }]) {
    const server = createAppServer(options);
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const base = `http://127.0.0.1:${server.address().port}`;
    try {
      const page = await fetch(base);
      assert.equal(page.status, 200);
      assert.match(await page.text(), /Anchor · Access Navigator/);
      assert.match(page.headers.get('content-security-policy'), /script-src 'self'/);
      const data = await fetch(`${base}/data/demo_map.json`);
      assert.equal((await data.json()).connections.length, 14);
      assert.match((await fetch(`${base}/src/app.js`)).headers.get('content-type'), /javascript/);
      for (const path of [
        '/.git/config',
        '/scripts/server.mjs',
        '/package.json',
        '/src/%2e%2e%2f%2e%2e%2fsecret.js',
      ])
        assert.equal((await fetch(base + path)).status, 404);
      assert.equal((await fetch(base, { method: 'POST' })).status, 405);
      assert.equal(await (await fetch(base, { method: 'HEAD' })).text(), '');
    } finally {
      server.closeAllConnections();
      await new Promise((resolve) => server.close(resolve));
    }
  }
});
