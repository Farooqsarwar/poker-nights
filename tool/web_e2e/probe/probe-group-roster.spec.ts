import { test } from '@playwright/test';
import { appText, expectText, launchApp, screenshot, tap } from '../acceptance/helpers/flutter';
import { ensureAccount } from '../acceptance/helpers/auth';

async function roster(page: import('@playwright/test').Page, tag: string) {
  const data = await page.evaluate(() => {
    const norm = (s: string) => s.replace(/\s+/g, ' ').trim();
    const rect = (el: Element) => {
      const r = el.getBoundingClientRect();
      return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
    };
    const rows: Array<Record<string, unknown>> = [];
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const t = norm((el as HTMLElement).innerText ?? '');
      if (/Test Club|Office|New group|Switch group|Choose|Group/.test(t) && t.length < 80) {
        rows.push({ text: t, role: el.getAttribute('role'), r: rect(el) });
      }
    }
    return rows;
  });
  console.log(`--- roster ${tag}:`);
  for (const r of data) console.log(`    "${r.text}" role=${r.role} @${JSON.stringify(r.r)}`);
  return data;
}

async function readCode(page: import('@playwright/test').Page): Promise<string | undefined> {
  const start = Date.now();
  while (Date.now() - start < 25_000) {
    const text = await appText(page);
    const m =
      text.match(/(?:GROUP|JOIN) CODE\s*:?\s*([A-HJ-NP-Z2-9]{6})/)?.[1] ??
      text.match(/\b[A-HJ-NP-Z2-9]{6}\b/)?.[0];
    if (m) return m;
    await page.waitForTimeout(500);
  }
  return undefined;
}

/** Probe 13: how many Test Clubs exist and how does the switcher behave? */
test('probe: group roster', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await expectText(page, 'Welcome back', 30_000);
    console.log(`home chip: ${(await appText(page)).match(/Switch group, ([^\n]+)/)?.[1] ?? '?'}`);

    for (let round = 0; round < 2; round++) {
      await tap(page, 'Switch group', { exact: false });
      await page.waitForTimeout(1_200);
      await roster(page, `round${round}-sheet`);
      await screenshot(page, `probe13-round${round}-sheet`);

      await tap(page, 'Test Club', { exact: false });
      await expectText(page, 'Switch group, Test Club', 30_000).catch(() => console.log('chip did not change'));
      const code = await readCode(page);
      console.log(`round${round}: landed on Test Club, code=${code}`);
      await screenshot(page, `probe13-round${round}-group`);
      await tap(page, 'Home', { exact: true }).catch(() => {});
      await page.waitForTimeout(800);
    }
  } finally {
    await app.close();
  }
});
