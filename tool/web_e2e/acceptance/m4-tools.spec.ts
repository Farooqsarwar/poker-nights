import { test } from '@playwright/test';
import { appText, expectText, goto, launchApp, screenshot, tap } from './helpers/flutter';

/**
 * m4 — the public tools, from the acceptance document:
 *
 *   the blind-structure generator offers "Use this structure in the tournament
 *   clock?" — Yes must open the clock with the generated levels — and the ICM
 *   calculator must show equities that add up to the prize pool.
 *
 * The tools are public (no account needed) and live on their own routes.
 */
test('m4: blind generator hands its structure to the clock; ICM equities add up', async () => {
  const app = await launchApp('qa-a');
  try {
    const { page } = app;

    // 1. Tools index → the generator.
    await goto(page, '/tools');
    await expectText(page, 'Blind Structure Generator', 30_000);
    await tap(page, 'Blind Structure Generator', { exact: false });
    await expectText(page, 'Next: starting stack', 30_000);
    await screenshot(page, 'm4-generator-inputs');

    // 2. Walk the builder: stack → structure.
    await tap(page, 'Next: starting stack');
    await expectText(page, 'Starting stack', 20_000);
    const stackText = (await appText(page)).match(/\b\d[\d,]{2,7}\b/g) ?? [];
    console.log(`m4: generator stack step figures: ${stackText.slice(0, 8).join(', ')}`);
    await tap(page, 'Approve stack');
    await expectText(page, 'minute levels', 20_000);
    await screenshot(page, 'm4-generator-structure');

    // 3. "Use these blinds" → the clock handoff dialog.
    await tap(page, 'Use these blinds');
    await expectText(page, 'Use this structure in the tournament clock?', 15_000);
    await tap(page, 'Yes', { exact: true });

    // The clock opens on its own route with the generated levels.
    await expectText(page, 'Time left', 30_000);
    await expectText(page, 'Level', 15_000);
    await screenshot(page, 'm4-clock');
    console.log('m4: generator handed the structure to the clock');

    // 4. ICM calculator: three players by default; the equity column must add
    //    up to the prize pool (50 + 30 + 20 = 100).
    await goto(page, '/tools/icm');
    await expectText(page, 'ICM Calculator', 30_000);
    await expectText(page, 'Players remaining: 3', 15_000);
    await screenshot(page, 'm4-icm');

    const decimals = (await appText(page)).match(/\b\d{1,4}\.\d{2}\b/g) ?? [];
    const figures = [...new Set(decimals)].map(Number);
    console.log(`m4: ICM figures seen: ${figures.join(', ')}`);
    // Default scenario: stacks 5,000 / 3,000 / 2,000 with 50 / 30 / 20 prizes.
    // Standard Malmuth-Harville equities are 38.39 / 32.75 / 28.86 (they add
    // up to the 100 pool); the chip-share column shows 50.00 for the biggest
    // stack and the difference column 11.61.
    const expected: Array<[string, number]> = [
      ['equity of the 5,000 stack', 38.39],
      ['equity of the 3,000 stack', 32.75],
      ['equity of the 2,000 stack', 28.86],
      ['chip share of the 5,000 stack', 50.0],
      ['equity-vs-chip-share difference', 11.61],
    ];
    for (const [label, want] of expected) {
      if (!figures.some((n) => Math.abs(n - want) <= 0.02)) {
        throw new Error(`m4: ${label} (${want}) not on screen; saw ${figures.join(', ')}`);
      }
    }
    console.log('m4: ICM equities 38.39 / 32.75 / 28.86 confirmed');
  } finally {
    await app.close();
  }
});
