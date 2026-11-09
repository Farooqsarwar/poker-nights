import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { launchApp, expectText, screenshot, tap } from '../acceptance/helpers/flutter';
import { ensureAccount } from '../acceptance/helpers/auth';

const OUT = path.join(import.meta.dirname, 'out');

/** Probe 5: find the "create another group" entry point for an account that already has a group. */
test('probe: More sheet entries after A has a group', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    const { how } = await ensureAccount(page, 'A');
    console.log('A:', how);
    await expectText(page, 'Welcome back', 30_000);

    await tap(page, 'More');
    await page.waitForTimeout(2_000);
    await screenshot(page, 'more-sheet');

    const dump = await page.evaluate(() => {
      const allText = Array.from(document.querySelectorAll('flt-semantics'))
        .filter((el) => !el.querySelector('flt-semantics'))
        .map((el) => (el as HTMLElement).innerText?.replace(/\s+/g, ' ').trim())
        .filter(Boolean);
      const buttons = Array.from(document.querySelectorAll('flt-semantics[role="button"]')).map((el) =>
        (el as HTMLElement).innerText?.replace(/\s+/g, ' ').trim().slice(0, 60),
      );
      return { allText, buttons };
    });

    fs.mkdirSync(OUT, { recursive: true });
    fs.writeFileSync(path.join(OUT, 'more-sheet.json'), JSON.stringify(dump, null, 2));
    console.log('TEXTS:', JSON.stringify(dump.allText, null, 1));
    console.log('BUTTONS:', JSON.stringify(dump.buttons));
  } finally {
    await app.close();
  }
});
