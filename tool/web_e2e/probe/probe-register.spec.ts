import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { launchApp, expectText, screenshot, tap } from '../acceptance/helpers/flutter';

const OUT = path.join(import.meta.dirname, 'out');

/**
 * Probe 3: open the registration screen on the deployed app and dump its
 * exact fields (inputs, checkboxes, buttons) so the setup spec can create
 * the QA accounts reliably. Submits nothing.
 */
test('probe: inspect the register screen', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await expectText(page, 'Create Account', 30_000);
    await tap(page, 'Create Account');
    await page.waitForTimeout(3_000);
    await screenshot(page, 'register-screen');

    const dump = await page.evaluate(() => {
      const inputs = Array.from(document.querySelectorAll('input, textarea')).map((el, i) => ({
        index: i,
        tag: el.tagName.toLowerCase(),
        type: el.getAttribute('type'),
        placeholder: el.getAttribute('placeholder'),
        ariaLabel: el.getAttribute('aria-label'),
        value: (el as HTMLInputElement).value?.slice(0, 20) ?? null,
      }));

      const checkboxes = Array.from(document.querySelectorAll('flt-semantics')).filter(
        (el) => el.getAttribute('role') === 'checkbox' || el.getAttribute('aria-checked') !== null,
      ).map((el) => ({
        role: el.getAttribute('role'),
        checked: el.getAttribute('aria-checked'),
        label: el.getAttribute('aria-label'),
        text: (el as HTMLElement).innerText?.replace(/\s+/g, ' ').trim().slice(0, 120),
      }));

      const allText = Array.from(document.querySelectorAll('flt-semantics'))
        .filter((el) => !el.querySelector('flt-semantics'))
        .map((el) => (el as HTMLElement).innerText?.replace(/\s+/g, ' ').trim())
        .filter(Boolean);

      return { inputs, checkboxes, allText };
    });

    fs.mkdirSync(OUT, { recursive: true });
    fs.writeFileSync(path.join(OUT, 'register-dom.json'), JSON.stringify(dump, null, 2));
    console.log('INPUTS:', JSON.stringify(dump.inputs, null, 2));
    console.log('CHECKBOXES:', JSON.stringify(dump.checkboxes, null, 2));
    console.log('TEXTS:', JSON.stringify(dump.allText, null, 2));
  } finally {
    await app.close();
  }
});
