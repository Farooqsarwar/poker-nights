import { test } from '@playwright/test';
import { appText, expectText, goto, launchApp, screenshot, tap } from '../acceptance/helpers/flutter';
import { setCountStepper } from '../acceptance/helpers/chips';

/** Probe: what does "Fill prizes from pool" produce for a 500 pool, 3 players? */
test('probe: ICM fill from pool', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await goto(page, '/home');
    await expectText(page, 'Welcome back', 30_000);
    await tap(page, 'More');
    await page.waitForTimeout(900);
    await tap(page, 'Tools', { exact: false });
    await expectText(page, 'Blind Structure Generator', 30_000);
    await tap(page, 'ICM Calculator', { exact: false });
    await expectText(page, 'Players remaining: 3', 30_000);

    console.log('--- before fill:');
    console.log((await appText(page)).replace(/\n+/g, ' | '));

    await setCountStepper(page, '100', 500);
    await tap(page, 'Fill prizes from pool');
    await page.waitForTimeout(800);
    console.log('--- after fill (pool 500, default stacks):');
    console.log((await appText(page)).replace(/\n+/g, ' | '));
    await screenshot(page, 'probe-icm-fill');
  } finally {
    await app.close();
  }
});
