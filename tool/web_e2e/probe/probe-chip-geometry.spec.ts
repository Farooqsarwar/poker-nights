import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { expectNoText, expectText, launchApp, screenshot, tap } from '../acceptance/helpers/flutter';
import { ensureAccount } from '../acceptance/helpers/auth';
import { openChipSets } from '../acceptance/helpers/nav';

const OUT = path.join(import.meta.dirname, 'out');

/** Probe 8: geometry of the row-2 Value field right after the row is inserted. */
test('probe: chip editor row-2 geometry', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await openChipSets(page);
    await tap(page, '+ New');
    await expectText(page, 'New Chip Set', 30_000);

    // Row 1 — Red, no field edits needed for the geometry question.
    await tap(page, '+ Add denomination');
    await expectText(page, 'Pick a color for your chip', 20_000);
    await tap(page, 'Red');
    await tap(page, 'Add chip');
    await expectNoText(page, 'Pick a color for your chip', 10_000);

    // Row 2 — Green, the fresh insertion.
    await tap(page, '+ Add denomination');
    await expectText(page, 'Pick a color for your chip', 20_000);
    await tap(page, 'Green');
    await tap(page, 'Add chip');
    await expectNoText(page, 'Pick a color for your chip', 10_000);

    await screenshot(page, 'probe-geo-after-green');

    const snapshot = async (tag: string) => {
      const data = await page.evaluate(() => {
        const rect = (el: Element) => {
          const r = el.getBoundingClientRect();
          return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
        };
        const inputs = Array.from(document.querySelectorAll('input, textarea')).map((el) => ({
          aria: el.getAttribute('aria-label'),
          value: (el as HTMLInputElement).value,
          rect: rect(el),
        }));
        const nodes: Array<Record<string, unknown>> = [];
        for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
          const t = ((el as HTMLElement).innerText ?? '').replace(/\s+/g, ' ').trim();
          if (t === 'Add denomination' || t === '+ Add denomination' || t === 'Green' || t === 'Red' || t.includes('chip quantity')) {
            nodes.push({ text: t.slice(0, 30), rect: rect(el) });
          }
        }
        return { inputs, nodes };
      });
      fs.writeFileSync(path.join(OUT, `geo-${tag}.json`), JSON.stringify(data, null, 2));
      console.log(`--- ${tag}`);
      for (const i of data.inputs) console.log(`  input aria=${i.aria} value=${i.value} @${i.rect.x},${i.rect.y} ${i.rect.w}x${i.rect.h}`);
      for (const n of data.nodes) console.log(`  node "${n.text}" @${(n.rect as Record<string, number>).x},${(n.rect as Record<string, number>).y}`);
      return data;
    };

    const geo = await snapshot('after-green');

    const valueInputs = geo.inputs.filter((i) => i.aria === 'Value');
    console.log(`Value inputs: ${valueInputs.length}`);
    const row2 = valueInputs[1];
    if (!row2) throw new Error('no row-2 Value input found');
    const cx = row2.rect.x + row2.rect.w / 2;
    const cy = row2.rect.y + row2.rect.h / 2;
    console.log(`clicking row-2 Value at (${Math.round(cx)}, ${Math.round(cy)})`);

    const hit = await page.evaluate(
      ({ cx, cy }) => {
        const el = document.elementFromPoint(cx, cy);
        if (!el) return 'none';
        return `${el.tagName} aria=${el.getAttribute('aria-label')} role=${el.getAttribute('role')} text="${((el as HTMLElement).innerText ?? '').replace(/\s+/g, ' ').trim().slice(0, 40)}"`;
      },
      { cx, cy },
    );
    console.log(`elementFromPoint: ${hit}`);

    await page.mouse.click(cx, cy);
    await page.waitForTimeout(400);

    const after = await page.evaluate(() => {
      const el = document.activeElement as HTMLElement | null;
      const paletteOpen = Array.from(document.querySelectorAll('flt-semantics')).some((n) =>
        ((n as HTMLElement).innerText ?? '').includes('Pick a color for your chip'),
      );
      return {
        active: el ? `${el.tagName} aria=${el.getAttribute('aria-label')}` : 'none',
        paletteOpen,
      };
    });
    console.log(`after click: active=${after.active} paletteOpen=${after.paletteOpen}`);
    await screenshot(page, 'probe-geo-after-click');
    await snapshot('after-click');

    // Leave no dialog behind; nothing was saved.
    if (after.paletteOpen) {
      await tap(page, 'Cancel');
      await page.waitForTimeout(400);
    }
  } finally {
    await app.close();
  }
});
