import { test } from '@playwright/test';
import { appText, expectText, hasText, launchApp, screenshot, tap } from '../acceptance/helpers/flutter';
import { ensureAccount } from '../acceptance/helpers/auth';
import { openSettings } from '../acceptance/helpers/nav';

async function dumpNodes(page: import('@playwright/test').Page, tag: string) {
  const data = await page.evaluate(() => {
    const norm = (s: string) => s.replace(/\s+/g, ' ').trim();
    const rect = (el: Element) => {
      const r = el.getBoundingClientRect();
      return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
    };
    const rows: Array<Record<string, unknown>> = [];
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const t = norm((el as HTMLElement).innerText ?? '');
      if (/Default chip set|Used when you create|STANDARD SET|Chip sets|Currency|^None$|^£$|^€$/.test(t)) {
        if (t.length > 90) continue;
        rows.push({ text: t.slice(0, 70), role: el.getAttribute('role'), r: rect(el) });
      }
    }
    return rows;
  });
  console.log(`--- nodes ${tag}:`);
  for (const r of data) console.log(`    "${r.text}" role=${r.role} @${JSON.stringify(r.r)}`);
  return data;
}

async function clickAt(page: import('@playwright/test').Page, x: number, y: number, label: string) {
  const hit = await page.evaluate(
    ({ x, y }) => {
      const el = document.elementFromPoint(x, y);
      return el ? `${el.tagName} role=${el.getAttribute('role')} text="${((el as HTMLElement).innerText ?? '').replace(/\s+/g, ' ').trim().slice(0, 40)}"` : 'none';
    },
    { x, y },
  );
  console.log(`[click ${label}] at (${x},${y}) — elementFromPoint: ${hit}`);
  await page.mouse.click(x, y);
  await page.waitForTimeout(900);
  const sheet = await hasText(page, 'Default Chip Set');
  console.log(`[click ${label}] sheet open: ${sheet}`);
  return sheet;
}

/** Probe 12: why does the "Default chip set" row not react to a settled tap? */
test('probe: settings default chip set tap', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await openSettings(page);
    console.log(`settings reached: ${(await appText(page)).includes('Account and group preferences')}`);

    // 1. The real helper, as the test uses it.
    await tap(page, 'Default chip set', { exact: false });
    const first = await hasText(page, 'Default Chip Set');
    console.log(`after real tap: sheet open = ${first}`);
    await screenshot(page, 'probe12-after-real-tap');
    await dumpNodes(page, 'after-real-tap');

    if (!first) {
      // 2. Try the tile node centre (the row with the subtitle).
      const tile = await page.evaluate(() => {
        const norm = (s: string) => s.replace(/\s+/g, ' ').trim();
        for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
          const t = norm((el as HTMLElement).innerText ?? '');
          if (t.includes('Used when you create a new tournament')) {
            const r = el.getBoundingClientRect();
            return { x: r.x, y: r.y, w: r.width, h: r.height };
          }
        }
        return null;
      });
      console.log(`tile node: ${JSON.stringify(tile)}`);
      if (tile) {
        await clickAt(page, Math.round(tile.x + tile.w / 2), Math.round(tile.y + tile.h / 2), 'tile-centre');
      }

      // 3. Title node centre from a fresh locate-esque query.
      const title = await page.evaluate(() => {
        const norm = (s: string) => s.replace(/\s+/g, ' ').trim();
        let best: { x: number; y: number; w: number; h: number } | null = null;
        let area = Number.POSITIVE_INFINITY;
        for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
          const t = norm((el as HTMLElement).innerText ?? '');
          if (!t.includes('Default chip set')) continue;
          const r = el.getBoundingClientRect();
          const a = r.width * r.height;
          if (a > 0 && a < area) {
            area = a;
            best = { x: r.x, y: r.y, w: r.width, h: r.height };
          }
        }
        return best;
      });
      console.log(`title node: ${JSON.stringify(title)}`);
      if (title) {
        await clickAt(page, Math.round(title.x + title.w / 2), Math.round(title.y + title.h / 2), 'title-centre');
      }

      // 4. Harder: click left-mid of the tile, avoiding the badge.
      if (tile) {
        await clickAt(page, Math.round(tile.x + 40), Math.round(tile.y + tile.h / 2), 'tile-left');
      }
    }

    await screenshot(page, 'probe12-end');
    console.log(`sheet open at end: ${await hasText(page, 'Default Chip Set')}`);
    await expectText(page, 'GAME ASSETS', 5_000).catch(() => console.log('GAME ASSETS not visible'));
  } finally {
    await app.close();
  }
});
