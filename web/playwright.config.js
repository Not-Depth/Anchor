import { defineConfig } from '@playwright/test';

// Keep automated tests separate from a teammate's running development preview.
const testPort = process.env.ANCHOR_TEST_PORT ?? '5175';
const testURL = `http://127.0.0.1:${testPort}`;

export default defineConfig({
  testDir: './tests/browser',
  fullyParallel: true,
  workers: 2,
  retries: process.env.CI ? 1 : 0,
  reporter: 'list',
  use: {
    baseURL: testURL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    channel: process.platform === 'win32' ? 'msedge' : undefined,
  },
  projects: [
    { name: 'desktop', use: { viewport: { width: 1440, height: 1000 } } },
    {
      name: 'mobile-layout',
      use: { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true },
    },
  ],
  webServer: {
    command: 'node scripts/server.mjs --built',
    url: testURL,
    env: { PORT: testPort },
    reuseExistingServer: false,
  },
});
