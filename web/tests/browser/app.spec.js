import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

async function choose(page, kind, name) {
  await page.locator(`#${kind}-picker`).click();
  await page.getByRole('radio', { name, exact: true }).check();
  await expect(page.locator('#routes-view')).toBeVisible();
}
async function locations(page, destination = 'Room 201 (demo lab)') {
  await choose(page, 'start', 'North Plaza (outside)');
  await choose(page, 'destination', destination);
}
async function findRoute(page) {
  await page.getByRole('button', { name: 'Find route', exact: true }).click();
}
async function backToPlanner(page) {
  await page.locator('#route-view').getByRole('button', { name: 'Routes', exact: true }).click();
}

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { name: 'Routes', exact: true })).toBeVisible();
});

test('native-style pickers require two different places and support back navigation', async ({
  page,
}) => {
  await expect(page.locator('#find-route')).toBeDisabled();
  await expect(page.locator('#start-value')).toHaveText('Not selected');
  await expect(page.locator('#map')).toHaveCount(0);
  await page.locator('#start-picker').click();
  await expect(page.getByRole('heading', { name: 'Floor 1', exact: true })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Floor 2', exact: true })).toBeVisible();
  await page.getByRole('radio', { name: 'North Plaza (outside)', exact: true }).check();
  await expect(page.locator('#start-picker')).toBeFocused();
  await page.locator('#start-picker').click();
  await page.getByRole('radio', { name: 'North Plaza (outside)', exact: true }).click();
  await expect(page.locator('#routes-view')).toBeVisible();
  await choose(page, 'destination', 'North Plaza (outside)');
  await expect(page.locator('#find-route')).toBeDisabled();
  await expect(page.locator('#search-hint')).toHaveText(
    'Starting point and destination are the same.',
  );
  await choose(page, 'destination', 'Room 201 (demo lab)');
  await findRoute(page);
  await expect(page.locator('#route-view')).toBeVisible();
  await page.goBack();
  await expect(page.locator('#routes-view')).toBeVisible();
  await expect(page.locator('#destination-value')).toHaveText('Room 201 (demo lab)');
});

test('summary and full-screen manual guidance match the native screen flow', async ({ page }) => {
  const failures = [];
  page.on('pageerror', (error) => failures.push(error.message));
  await locations(page);
  await findRoute(page);
  await expect(page.locator('#routes-view')).toBeHidden();
  await expect(page.locator('#result')).toContainText('Shortest (may use stairs)');
  await expect(page.locator('dt', { hasText: 'Steps to confirm' }).locator('..')).toContainText(
    '7',
  );
  await expect(page.locator('.route-steps li')).toHaveCount(6);
  await expect(page.locator('.route-steps')).toContainText('Walk up the five front steps');
  await expect(page.locator('#map .floor')).toHaveCount(2);
  await page.getByRole('button', { name: 'Start guidance', exact: true }).click();
  await expect(page.locator('#tab-bar')).toBeHidden();
  await expect(page.getByRole('button', { name: 'Previous step', exact: true })).toBeDisabled();
  await expect(page.getByRole('heading', { name: 'Next', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Repeat', exact: true })).toHaveCount(0);
  await page.locator('#confirm-step').click();
  await expect(page.locator('#guidance-instruction')).toContainText('Walk up the five front steps');
  await expect(page.getByRole('heading', { name: 'Previous', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Previous step', exact: true }).click();
  for (let index = 0; index < 7; index++) await page.locator('#confirm-step').click();
  await expect(page.locator('#guidance-instruction')).toContainText('You have arrived at Room 201');
  await page.getByRole('button', { name: 'Finish', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Start guidance', exact: true })).toBeVisible();
  await expect(page.locator('#tab-bar')).toBeVisible();
  expect(failures).toEqual([]);
});

test('ending guidance requires confirmation and can be cancelled', async ({ page }) => {
  await locations(page);
  await findRoute(page);
  await page.getByRole('button', { name: 'Start guidance', exact: true }).click();
  await page.getByRole('button', { name: 'End route', exact: true }).click();
  await expect(page.getByRole('dialog', { name: 'End this route?' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Keep going', exact: true })).toBeFocused();
  await page.getByRole('button', { name: 'Keep going', exact: true }).click();
  await expect(page.locator('#guidance-view')).toBeVisible();
  await page.getByRole('button', { name: 'End route', exact: true }).click();
  await page.locator('#confirm-end-route').click();
  await expect(page.locator('#route-view')).toBeVisible();
  await expect(page.locator('#guidance-view')).toBeHidden();
});

test('settings recalculate the summary and persist independently', async ({ page }) => {
  await locations(page);
  await page.locator('#route-step-free').check();
  await findRoute(page);
  await expect(page.locator('#result')).toContainText(
    '87 m (simulated), plus 1 without a recorded length',
  );
  await expect(page.locator('.route-steps li')).toHaveCount(7);
  await page.getByRole('link', { name: 'Settings', exact: true }).click();
  await page.getByRole('switch', { name: 'Simulate elevator outage', exact: true }).check();
  await page.getByRole('link', { name: 'Routes', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'No suitable route found' })).toBeVisible();
  await expect(page.locator('#result')).toContainText('Elevator A (unavailable)');
  await expect(page.getByRole('button', { name: 'Start guidance', exact: true })).toHaveCount(0);
  await page.getByRole('link', { name: 'Settings', exact: true }).click();
  await page.reload();
  await expect(
    page.getByRole('switch', { name: 'Simulate elevator outage', exact: true }),
  ).toBeChecked();
  await expect(
    page.getByRole('switch', { name: 'Step-free routes only', exact: true }),
  ).toBeChecked();
  await expect(page.getByRole('switch', { name: 'Audio alerts', exact: true })).not.toBeChecked();
});

test('skybridge warnings remain visible with the native summary layout', async ({ page }) => {
  await locations(page, 'Annex reading room (via skybridge)');
  await findRoute(page);
  await expect(page.locator('#result')).toContainText('current availability is not confirmed');
  await expect(page.locator('#result')).toContainText('step-free suitability is unknown');
  await backToPlanner(page);
  await page.locator('#route-step-free').check();
  await findRoute(page);
  await expect(page.locator('#result')).toContainText(
    'Skybridge to Annex (step-free suitability unknown)',
  );
});

test('voice testing, repeat and pause controls work without speaking during automation', async ({
  page,
}) => {
  await page.addInitScript(() => {
    window.testSpeech = [];
    window.speechSynthesis.speak = (utterance) => window.testSpeech.push(utterance.text);
    window.speechSynthesis.cancel = () => {};
  });
  await page.reload();
  await page.getByRole('link', { name: 'Settings', exact: true }).click();
  await page.getByRole('button', { name: 'Test voice', exact: true }).click();
  expect(await page.evaluate(() => window.testSpeech)).toEqual([
    'This is how route directions will sound.',
  ]);
  await page.getByRole('switch', { name: 'Speak directions', exact: true }).check();
  await page.getByRole('link', { name: 'Routes', exact: true }).click();
  await locations(page);
  await findRoute(page);
  await page.getByRole('button', { name: 'Start guidance', exact: true }).click();
  expect(await page.evaluate(() => window.testSpeech.length)).toBe(2);
  await page.getByRole('button', { name: 'Pause speech', exact: true }).click();
  await page.locator('#confirm-step').click();
  expect(await page.evaluate(() => window.testSpeech.length)).toBe(2);
  await page.getByRole('button', { name: 'Repeat', exact: true }).click();
  expect(await page.evaluate(() => window.testSpeech.length)).toBe(3);
  await page.getByRole('button', { name: 'Resume speech', exact: true }).click();
  expect(await page.evaluate(() => window.testSpeech.length)).toBe(4);
});

test('Nearby shows unsupported hardware first and explicitly opts into simulation', async ({
  page,
}) => {
  await page.getByRole('link', { name: 'Nearby', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Not available on this device' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Start simulation' })).toBeHidden();
  await page.getByText('Try simulated readings', { exact: true }).click();
  await expect(page.getByText('Simulation only.', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Start simulation' }).click();
  await page.locator('#distance').fill('0.5');
  await expect(page.locator('#nearby-event')).toContainText('Simulated surface within 0.50 meters');
  await page.getByRole('switch', { name: 'Simulate lost readings' }).check();
  await expect(page.locator('#nearby-event')).toContainText('Simulated depth readings unavailable');
  await page.getByRole('switch', { name: 'Simulate lost readings' }).uncheck();
  await expect(page.locator('#sensor-state')).toContainText('Inside the alert distance');
  await page.getByText('Try simulated readings', { exact: true }).click();
  await page.getByText('Try simulated readings', { exact: true }).click();
  await expect(page.getByRole('button', { name: 'Start simulation' })).toBeVisible();
  await page.getByRole('button', { name: 'Start simulation' }).click();
  await page.getByRole('link', { name: 'Routes', exact: true }).click();
  await page.getByRole('link', { name: 'Nearby', exact: true }).click();
  await expect(page.locator('#sensor-state')).toHaveText('Simulation stopped');
  await expect(page.locator('#distance-reading')).toHaveText('—');
});

test('malformed maps fail closed and can be retried', async ({ page }) => {
  await page.route('**/data/demo_map.json', (route) =>
    route.fulfill({ status: 200, json: { schemaVersion: 1 } }),
  );
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Map could not be loaded' })).toBeVisible();
  await expect(page.locator('#app')).toBeHidden();
  await page.unroute('**/data/demo_map.json');
  await page.getByRole('button', { name: 'Try again' }).click();
  await expect(page.getByRole('heading', { name: 'Routes', exact: true })).toBeVisible();
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
  await locations(page);
  await page.locator('#route-step-free').check();
  await findRoute(page);
  await expect(page.locator('#result')).toContainText('87 m (simulated)');
  await page.getByRole('link', { name: 'Settings', exact: true }).click();
  await expect(page.locator('#settings-status')).toContainText('Storage is unavailable');
  await expect(page.getByRole('button', { name: 'Test voice', exact: true })).toBeDisabled();
});

test('keyboard skip link and 320px reflow work in all screens', async ({ page }) => {
  await page.keyboard.press('Tab');
  await expect(page.getByRole('link', { name: 'Skip to main content' })).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.locator('#main')).toBeFocused();
  await page.setViewportSize({ width: 320, height: 800 });
  const fits = async () =>
    expect(
      await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth),
    ).toBe(true);
  for (const tab of ['routes', 'nearby', 'settings']) {
    await page.goto(`/#${tab}`);
    await expect(page.locator(`#${tab}-view`)).toBeVisible();
    await fits();
  }
  await page.getByRole('link', { name: 'Routes', exact: true }).click();
  await locations(page);
  await findRoute(page);
  await fits();
  await page.getByRole('button', { name: 'Start guidance', exact: true }).click();
  await fits();
  await page.locator('#confirm-step').click();
  await fits();
});

test('light and dark screens pass automated WCAG accessibility checks', async ({ page }) => {
  async function check() {
    const report = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa'])
      .analyze();
    expect(report.violations).toEqual([]);
  }
  for (const colorScheme of ['light', 'dark']) {
    await page.emulateMedia({ colorScheme });
    await page.goto('/');
    await expect(page.locator('#app')).toBeVisible();
    await check();
    await page.locator('#start-picker').click();
    await check();
    await page.getByRole('radio', { name: 'North Plaza (outside)', exact: true }).check();
    await choose(page, 'destination', 'Room 201 (demo lab)');
    await findRoute(page);
    await check();
    await page.getByRole('button', { name: 'Start guidance', exact: true }).click();
    await check();
    await page.getByRole('button', { name: 'End route', exact: true }).click();
    await check();
    await page.locator('#confirm-end-route').click();
    await page.getByRole('link', { name: 'Nearby', exact: true }).click();
    await check();
    await page.getByText('Try simulated readings', { exact: true }).click();
    await check();
    await page.getByRole('link', { name: 'Settings', exact: true }).click();
    await check();
  }
});
