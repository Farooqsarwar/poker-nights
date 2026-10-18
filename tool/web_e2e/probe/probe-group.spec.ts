import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { launchApp, expectText, screenshot, tap } from '../acceptance/helpers/flutter';
import { ensureAccount } from '../acceptance/helpers/auth';

const OUT = path.join(import.meta.dirname, 'out');

/**
 * Probe 4: open the "Create a group" dialog on the deployed app and dump its
 * fields and buttons. Submits nothing.
 */
test('probe: inspect the create-group dialog', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    const { account, how } = await ensureAccount(page, 'A');
    console.log(`Account A: ${how} — ${account.email}`);

    await expectText(page, 'Create a group', 30_000);
    await tap(page, 'Create a group');
    await page.waitForTimeout(2_500);
    await screenshot(page, 'create-group-dialog');

    const dump = await page.evaluate(() => {
      const inputs = Array.from(document.querySelectorAll('input, textarea')).map((el, i) => ({
        index: i,
        tag: el.tagName.toLowerCase(),
        type: el.getAttribute('type'),
        ariaLabel: el.getAttribute('aria-label'),
        placeholder: el.getAttribute('placeholder'),
      }));
      const buttons = Array.from(document.querySelectorAll('flt-semantics[role="button"]')).map((el) => ({
        text: (el as HTMLElement).innerText?.replace(/\s+/g, ' ').trim().slice(0, 80) ?? null,
      }));
      const allText = Array.from(document.querySelectorAll('flt-semantics'))
        .filter((el) => !el.querySelector('flt-semantics'))
        .map((el) => (el as HTMLElement).innerText?.replace(/\s+/g, ' ').trim())
        .filter(Boolean);
      return { inputs, buttons, allText };
    });

    fs.mkdirSync(OUT, { recursive: true });
    fs.writeFileSync(path.join(OUT, 'create-group-dom.json'), JSON.stringify(dump, null, 2));
    console.log('INPUTS:', JSON.stringify(dump.inputs));
    console.log('BUTTONS:', JSON.stringify(dump.buttons));
    console.log('TEXTS:', JSON.stringify(dump.allText));
  } finally {
    await app.close();
  }
});
