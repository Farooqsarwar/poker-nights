import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { launchApp, expectText, screenshot, tap } from '../acceptance/helpers/flutter';
import { ensureAccount } from '../acceptance/helpers/auth';
import { openChipSets } from '../acceptance/helpers/nav';

const OUT = path.join(import.meta.dirname, 'out');

/** Probe 6: dump how the chip palette dialog renders in the semantics DOM. */
test('probe: chip palette dialog DOM', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await openChipSets(page);
    await tap(page, '+ New');
    await expectText(page, 'New Chip Set', 30_000);
    await tap(page, '+ Add denomination');
    await expectText(page, 'Pick a color for your chip', 20_000);
    await page.waitForTimeout(1_500);
    await screenshot(page, 'probe-palette-dialog');

    const dump = await page.evaluate(() => {
      const rows: Array<Record<string, unknown>> = [];
      for (const el of Array.from(document.querySelectorAll('*'))) {
        const tag = el.tagName.toLowerCase();
        if (tag === 'script' || tag === 'style') continue;
        const text = ((el as HTMLElement).innerText ?? el.textContent ?? '').trim();
        const label = el.getAttribute('aria-label');
        const isCandidate =
          el.getAttribute('role') === 'button' ||
          (text.length > 0 && text.length < 24 && /^\s*Red\s*$/i.test(text)) ||
          (label != null && /red/i.test(label));
        if (!isCandidate) continue;
        const r = el.getBoundingClientRect();
        if (r.width === 0 && r.height === 0) continue;
        rows.push({
          tag,
          role: el.getAttribute('role'),
          label,
          text: text.slice(0, 40),
          x: Math.round(r.x),
          y: Math.round(r.y),
          w: Math.round(r.width),
          h: Math.round(r.height),
        });
      }
      return rows;
    });

    fs.mkdirSync(OUT, { recursive: true });
    fs.writeFileSync(path.join(OUT, 'palette-dialog-dom.json'), JSON.stringify(dump, null, 2));
    console.log(`candidates: ${dump.length}`);
    for (const r of dump) console.log(JSON.stringify(r));
  } finally {
    await app.close();
  }
});
