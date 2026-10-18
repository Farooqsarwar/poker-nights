import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { expectNoText, expectText, launchApp, screenshot, tap } from '../acceptance/helpers/flutter';
import { ensureAccount } from '../acceptance/helpers/auth';
import { openChipSets } from '../acceptance/helpers/nav';

const OUT = path.join(import.meta.dirname, 'out');

async function valueSnapshot(page: import('@playwright/test').Page) {
  return await page.evaluate(() =>
    Array.from(document.querySelectorAll('input, textarea')).map((el) => ({
      aria: el.getAttribute('aria-label'),
      value: (el as HTMLInputElement).value,
    })),
  );
}

async function active(page: import('@playwright/test').Page) {
  return await page.evaluate(() => {
    const el = document.activeElement as HTMLElement | null;
    if (!el) return 'none';
    return `${el.tagName.toLowerCase()} aria=${el.getAttribute('aria-label')} ph=${el.getAttribute('placeholder')}`;
  });
}

/** Probe 9: geometry-free field focus — direct JS focus vs Tab traversal. */
test('probe: field focus without clicking', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await openChipSets(page);
    await tap(page, '+ New');
    await expectText(page, 'New Chip Set', 30_000);

    await tap(page, '+ Add denomination');
    await expectText(page, 'Pick a color for your chip', 20_000);
    await tap(page, 'Red');
    await tap(page, 'Add chip');
    await expectNoText(page, 'Pick a color for your chip', 10_000);

    await tap(page, '+ Add denomination');
    await expectText(page, 'Pick a color for your chip', 20_000);
    await tap(page, 'Green');
    await tap(page, 'Add chip');
    await expectNoText(page, 'Pick a color for your chip', 10_000);

    // --- METHOD A: direct DOM focus on the row-2 Value input.
    const focused = await page.evaluate(() => {
      const inputs = Array.from(document.querySelectorAll('input[aria-label="Value"]')) as HTMLInputElement[];
      if (inputs.length < 2) return `only ${inputs.length} value inputs`;
      inputs[1].focus();
      return `focused #1 of ${inputs.length}`;
    });
    console.log(`A: ${focused}, active=${await active(page)}`);

    await page.keyboard.insertText('100');
    await page.waitForTimeout(700);
    console.log(`A after typing: ${JSON.stringify(await valueSnapshot(page))}`);
    console.log(`A active now: ${await active(page)}`);
    await screenshot(page, 'focus-method-a');

    // --- METHOD B: Tab traversal from the current position.
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Backspace');
    await page.waitForTimeout(300);

    console.log('B: tab order walk:');
    for (let i = 0; i < 10; i++) {
      await page.keyboard.press('Tab');
      await page.waitForTimeout(250);
      console.log(`  tab ${i + 1}: ${await active(page)}`);
    }
    const snapB = await valueSnapshot(page);
    console.log(`B after walk: ${JSON.stringify(snapB)}`);

    // Type into whatever ended up focused (if it is the row-2 value field).
    await page.keyboard.insertText('137');
    await page.waitForTimeout(700);
    console.log(`B after typing: ${JSON.stringify(await valueSnapshot(page))}`);
    await screenshot(page, 'focus-method-b');

    fs.writeFileSync(path.join(OUT, 'focus-methods.json'), JSON.stringify({ ok: true }, null, 2));
  } finally {
    await app.close();
  }
});
