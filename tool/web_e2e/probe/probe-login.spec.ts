import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { launchApp, expectText, screenshot } from '../acceptance/helpers/flutter';

const OUT = path.join(import.meta.dirname, 'out');

/**
 * Probe 2: exercises the click engine end-to-end — open the deployed app,
 * tap "Sign in", and dump how the login screen's text fields are represented
 * in the semantics DOM (needed before writing register/login helpers).
 */
test('probe: tap Sign in and inspect the login screen', async () => {
  const app = await launchApp('probe-guest');
  const { page } = app;
  try {
    // Splash lasts ~4.2 s; wait for the landing page's headline.
    await expectText(page, 'Sign in', 30_000);

    const { tap } = await import('../acceptance/helpers/flutter');
    await tap(page, 'Sign in');

    // The login screen should now exist. Its headline in the app is
    // "Welcome back" or similar — probe will reveal the truth.
    await page.waitForTimeout(3_000);
    await screenshot(page, 'login-screen');

    fs.mkdirSync(OUT, { recursive: true });

    const dump = await page.evaluate(() => {
      const roles: Record<string, number> = {};
      const interesting: Array<{
        tag: string;
        role: string | null;
        text: string | null;
        placeholder: string | null;
        type: string | null;
        id: string | null;
      }> = [];

      for (const el of Array.from(document.querySelectorAll('flt-semantics, input, textarea'))) {
        const role = el.getAttribute('role') ?? el.tagName.toLowerCase();
        roles[role] = (roles[role] ?? 0) + 1;
        if (['textbox', 'input', 'textarea'].includes(role) || el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
          interesting.push({
            tag: el.tagName.toLowerCase(),
            role: el.getAttribute('role'),
            text: (el as HTMLElement).innerText?.trim().slice(0, 80) ?? null,
            placeholder: el.getAttribute('placeholder') ?? el.getAttribute('aria-placeholder'),
            type: el.getAttribute('type'),
            id: el.id || null,
          });
        }
      }

      const allText = Array.from(document.querySelectorAll('flt-semantics'))
        .filter((el) => !el.querySelector('flt-semantics'))
        .map((el) => (el as HTMLElement).innerText?.trim())
        .filter(Boolean);

      return { roles, interesting, allText };
    });

    fs.writeFileSync(path.join(OUT, 'login-dom.json'), JSON.stringify(dump, null, 2));
    console.log('ROLES:', JSON.stringify(dump.roles));
    console.log('INPUTS:', JSON.stringify(dump.interesting, null, 2));
    console.log('TEXTS:', JSON.stringify(dump.allText, null, 2));
  } finally {
    await app.close();
  }
});
