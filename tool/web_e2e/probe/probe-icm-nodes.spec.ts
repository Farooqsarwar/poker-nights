import { test } from '@playwright/test';
import { goto, launchApp, expectText, screenshot } from '../acceptance/helpers/flutter';

/** Probe: what the ICM calculator exposes in the semantics tree. */
test('probe: ICM screen semantics', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await goto(page, '/tools/icm');
    await expectText(page, 'ICM Calculator', 30_000);
    await page.waitForTimeout(1_000);
    const rows = await page.evaluate(() => {
      const norm = (s: string | null | undefined) => (s ?? '').replace(/\s+/g, ' ').trim();
      const rect = (el: Element) => {
        const r = el.getBoundingClientRect();
        return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
      };
      const out: Array<Record<string, unknown>> = [];
      for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
        const t = norm((el as HTMLElement).innerText);
        const label = norm(el.getAttribute('aria-label'));
        const role = el.getAttribute('role');
        const value = el.getAttribute('aria-valuetext') ?? el.getAttribute('aria-valuenow');
        if (/stack|pool|prize|player|\d{3,4}/i.test(`${t} ${label}`) && (t.length < 40 || label.length < 40)) {
          out.push({ t: t.slice(0, 32), label: label.slice(0, 32), role, value, r: rect(el) });
        }
      }
      return out;
    });
    for (const r of rows) console.log(JSON.stringify(r));
    await screenshot(page, 'probe-icm-nodes');
  } finally {
    await app.close();
  }
});
