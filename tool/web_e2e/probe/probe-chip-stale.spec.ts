import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { expectNoText, expectText, launchApp, screenshot, tap } from '../acceptance/helpers/flutter';
import { ensureAccount, typeInto } from '../acceptance/helpers/auth';
import { openChipSets } from '../acceptance/helpers/nav';

const OUT = path.join(import.meta.dirname, 'out');

/** Probe 11: rects around the REAL failing sequence + mouse-move flush test. */
test('probe: stale rects and flushes', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await openChipSets(page);
    await tap(page, '+ New');
    await expectText(page, 'New Chip Set', 30_000);

    const rects = async (tag: string) => {
      const data = await page.evaluate(() => {
        const rect = (el: Element) => {
          const r = el.getBoundingClientRect();
          return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
        };
        const inputs = Array.from(document.querySelectorAll('input, textarea')).map((el) => ({
          aria: el.getAttribute('aria-label'),
          value: (el as HTMLInputElement).value,
          r: rect(el),
        }));
        const add = Array.from(document.querySelectorAll('flt-semantics')).find((el) =>
          ((el as HTMLElement).innerText ?? '').includes('Add denomination'),
        );
        const addRect = add ? rect(add) : null;
        return { inputs, addRect };
      });
      fs.writeFileSync(path.join(OUT, `stale-${tag}.json`), JSON.stringify(data, null, 2));
      console.log(`--- ${tag}: add@${JSON.stringify(data.addRect)}`);
      for (const i of data.inputs) console.log(`    ${i.aria} value=${i.value} @${JSON.stringify(i.r)}`);
      return data;
    };

    // Exactly the failing sequence: row 1 (Red, value 25, quantity 100), then row 2 (Green).
    await tap(page, '+ Add denomination');
    await expectText(page, 'Pick a color for your chip', 20_000);
    await tap(page, 'Red');
    await tap(page, 'Add chip');
    await expectNoText(page, 'Pick a color for your chip', 10_000);
    await typeInto(page, 'Value', '25', { nth: 0 });

    await tap(page, 'Red chip quantity', { exact: false });
    await expectText(page, 'Enter number', 20_000);
    await page.waitForTimeout(400);
    await page.locator('input, textarea').last().evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
    await page.keyboard.press('Control+A');
    await page.keyboard.insertText('100');
    await page.waitForTimeout(250);
    await tap(page, 'Apply');
    await page.waitForTimeout(400);
    await rects('after-row1-complete');

    await tap(page, '+ Add denomination');
    await expectText(page, 'Pick a color for your chip', 20_000);
    await tap(page, 'Green');
    await tap(page, 'Add chip');
    await expectNoText(page, 'Pick a color for your chip', 10_000);

    const before = await rects('row2-before-flush');
    await screenshot(page, 'stale-before-flush');

    // Harmless flush: move the pointer (hopefully forces a frame + semantics update).
    await page.mouse.move(10, 10);
    await page.waitForTimeout(250);
    const afterMove = await rects('row2-after-move');

    await page.keyboard.press('Shift');
    await page.waitForTimeout(250);
    const afterKey = await rects('row2-after-shift');

    console.log('CHANGED after move:', JSON.stringify(before.inputs) !== JSON.stringify(afterMove.inputs) || JSON.stringify(before.addRect) !== JSON.stringify(afterMove.addRect));
    console.log('CHANGED after shift:', JSON.stringify(before.inputs) !== JSON.stringify(afterKey.inputs) || JSON.stringify(before.addRect) !== JSON.stringify(afterKey.addRect));

    const valueInputs = afterKey.inputs.filter((i) => i.aria === 'Value');
    console.log(`Value inputs after flush: ${valueInputs.length}`);
    for (const v of valueInputs) console.log(`   @${JSON.stringify(v.r)} value=${v.value}`);
  } finally {
    await app.close();
  }
});
