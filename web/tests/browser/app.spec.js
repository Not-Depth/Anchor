import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Find your way.' })).toBeVisible();
});

test('route planning and manual guidance work from start through arrival', async ({ page }) => {
  const failures = [];
  page.on('pageerror', (error) => failures.push(error.message));
  await page.getByRole('button', { name: 'Find a route' }).click();
  await expect(page.locator('#result')).toContainText('Includes stairs');
  await expect(page.locator('#result')).toContainText('6 connections');
  await page.getByText('Review all route steps', { exact: true }).click();
  await expect(page.locator('.steps')).toContainText('Walk up the five front steps');
  await page.getByRole('button', { name: 'Start guidance' }).click();
  await expect(page.getByRole('button', { name: 'Previous step' })).toBeDisabled();
  await page.locator('#confirm-step').click();
  await expect(page.locator('#guidance-instruction')).toContainText('Walk up the five front steps');
  await page.getByRole('button', { name: 'Previous step' }).click();
  await expect(page.locator('#guidance-instruction')).toContainText('Start at North Plaza');
  for (let index = 0; index < 7; index++) await page.locator('#confirm-step').click();
  await expect(page.getByRole('heading', { name: 'You’ve arrived.' })).toBeVisible();
  await page.getByRole('button', { name: 'Back to route overview' }).click();
  await expect(page.getByRole('button', { name: 'Start guidance' })).toBeVisible();
  expect(failures).toEqual([]);
});

test('step-free mode, persisted preferences and elevator outage are consistent', async ({
  page,
}) => {
  await page.locator('#route-step-free').check();
  await page.getByRole('button', { name: 'Find a route' }).click();
  await expect(page.locator('#result')).toContainText('87 m recorded');
  await expect(page.locator('#result')).toContainText('7 connections');
  await page.getByRole('button', { name: 'Start guidance' }).click();
  await page.getByRole('link', { name: 'Settings', exact: true }).first().click();
  await page.getByRole('checkbox', { name: /Simulate elevator outage/ }).check();
  await page.reload();
  await expect(page.getByRole('checkbox', { name: /Simulate elevator outage/ })).toBeChecked();
  await page.getByRole('link', { name: 'Routes', exact: true }).click();
  await expect(page.locator('#route-step-free')).toBeChecked();
  await page.getByRole('button', { name: 'Find a route' }).click();
  await expect(page.getByRole('heading', { name: 'No suitable route found' })).toBeVisible();
  await expect(page.locator('#result')).toContainText('Elevator A (unavailable)');
  await expect(page.getByRole('button', { name: 'Start guidance' })).toHaveCount(0);
});

test('skybridge warnings and same-location validation are visible', async ({ page }) => {
  await page.locator('#destination').selectOption('annex-reading-room');
  await page.getByRole('button', { name: 'Find a route' }).click();
  await expect(page.locator('#result')).toContainText('current availability is not confirmed');
  await expect(page.locator('#result')).toContainText('step-free suitability is unknown');
  await page.locator('#route-step-free').check();
  await page.getByRole('button', { name: 'Find a route' }).click();
  await expect(page.locator('#result')).toContainText(
    'Skybridge to Annex (step-free suitability unknown)',
  );
  await page.locator('#destination').selectOption('plaza');
  await page.getByRole('button', { name: 'Find a route' }).click();
  await expect(page.locator('#result')).toContainText('different from your starting point');
});

test('changing locations invalidates an active route', async ({ page }) => {
  await page.getByRole('button', { name: 'Find a route' }).click();
  await page.getByRole('button', { name: 'Start guidance' }).click();
  await page.locator('#start').selectOption('room-105');
  await expect(page.locator('#confirm-step')).toHaveCount(0);
  await expect(page.locator('#route-notice')).toContainText('Find a new route');
});

test('nearby remains explicitly simulated and stops after leaving its view', async ({ page }) => {
  await page.getByRole('link', { name: /Nearby/ }).click();
  await expect(page.getByText('Simulation only', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Start simulation' }).click();
  await page.locator('#distance').fill('0.5');
  await expect(page.locator('#nearby-event')).toContainText('Simulated surface within 0.50 meters');
  await page.getByRole('checkbox', { name: /Simulate lost readings/ }).check();
  await expect(page.locator('#nearby-event')).toContainText('Simulated depth readings unavailable');
  await page.getByRole('checkbox', { name: /Simulate lost readings/ }).uncheck();
  await expect(page.locator('#sensor-state')).toContainText('Inside the alert distance');
  await page.getByRole('link', { name: 'Routes', exact: true }).click();
  await page.getByRole('link', { name: /Nearby/ }).click();
  await expect(page.getByRole('button', { name: 'Start simulation' })).toBeVisible();
  await expect(page.locator('#sensor-state')).toHaveText('Simulation stopped');
});

test('map loading failure can be retried and malformed maps fail closed', async ({ page }) => {
  await page.route('**/data/demo_map.json', (route) =>
    route.fulfill({ status: 200, json: { schemaVersion: 1 } }),
  );
  await page.reload();
  await expect(page.getByRole('heading', { name: 'We couldn’t load the map' })).toBeVisible();
  await expect(page.locator('#app')).toBeHidden();
  await page.unroute('**/data/demo_map.json');
  await page.getByRole('button', { name: 'Try again' }).click();
  await expect(page.getByRole('heading', { name: 'Find your way.' })).toBeVisible();
});

test('denied storage and unavailable speech do not prevent routing', async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperty(window, 'localStorage', {
      get() {
        throw new Error('Storage denied');
      },
    });
    delete window.speechSynthesis;
    delete window.SpeechSynthesisUtterance;
  });
  await page.reload();
  await page.locator('#route-step-free').check();
  await page.getByRole('button', { name: 'Find a route' }).click();
  await expect(page.locator('#result')).toContainText('87 m recorded');
  await page.getByRole('link', { name: 'Settings', exact: true }).first().click();
  await expect(page.locator('#settings-status')).toContainText('Storage is unavailable');
});

test('keyboard skip link, landmarks and 320px reflow are usable', async ({ page }) => {
  await page.keyboard.press('Tab');
  await expect(page.getByRole('link', { name: 'Skip to main content' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#main')).toBeFocused();
  await page.setViewportSize({ width: 320, height: 800 });
  for (const tab of ['routes', 'nearby', 'settings']) {
    await page.goto(`/#${tab}`);
    await expect(page.locator(`#${tab}-view`)).toBeVisible();
    expect(
      await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth),
    ).toBe(true);
  }
});

test('main views and guidance pass automated WCAG accessibility checks', async ({ page }) => {
  async function check() {
    const report = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .analyze();
    expect(report.violations).toEqual([]);
  }
  await check();
  await page.getByRole('button', { name: 'Find a route' }).click();
  await check();
  await page.getByRole('button', { name: 'Start guidance' }).click();
  await check();
  await page.getByRole('link', { name: /Nearby/ }).click();
  await check();
  await page.getByRole('link', { name: 'Settings', exact: true }).first().click();
  await check();
});
