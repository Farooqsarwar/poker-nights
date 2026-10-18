import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { appText, expectText, launchApp, screenshot, tap } from '../acceptance/helpers/flutter';
import { ensureAccount } from '../acceptance/helpers/auth';
import { openChipSets } from '../acceptance/helpers/nav';

const OUT = path.join(import.meta.dirname, 'out');

async function dump(page: import('@playwright/test').Page, tag: string) {
  const data = await page.evaluate(() => {
    const inputs = Array.from(document.querySelectorAll('input, textarea')).map((el) => {
      const r = el.getBoundingClientRect();
      return {
        aria: el.getAttribute('aria-label'),
        placeholder: el.getAttribute('placeholder'),
        value: (el as HTMLInputElement).value,
        x: Math.round(r.x),
        y: Math.round(r.y),
        w: Math.round(r.width),
        h: Math.round(r.height),
      };
    });
    const buttons: Array<Record<string, unknown>> = [];
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const t = ((el as HTMLElement).innerText ?? '').replace(/\s+/g, ' ').trim();
      if (t.length === 0 || t.length > 30) continue;
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) continue;
      if (el.getAttribute('role') !== 'button' && t.length > 12) continue;
      buttons.push({ text: t, role: el.getAttribute('role'), x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) });
    }
    return { inputs, buttons, text: ((document.body as HTMLElement).innerText ?? '').replace(/\s+/g, ' ').slice(0, 300) };
  });
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, `chip-${tag}.json`), JSON.stringify(data, null, 2));
  await screenshot(page, `chip-${tag}`);
  console.log(`--- ${tag}: ${data.text.slice(0, 200)}`);
  for (const i of data.inputs) console.log(`  input aria=${i.aria} ph=${i.placeholder} value=${i.value} @${i.x},${i.y} ${i.w}x${i.h}`);
}

/** Probe 7: chip editor steps — swatch selection timing and Value-field input. */
test('probe: chip editor steps', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await openChipSets(page);
    await tap(page, '+ New');
    await expectText(page, 'New Chip Set', 30_000);
    await dump(page, '01-editor');

    await tap(page, '+ Add denomination');
    await expectText(page, 'Pick a color for your chip', 20_000);
    await page.waitForTimeout(100);
    await dump(page, '02-dialog-fresh');
    await page.waitForTimeout(800);
    await dump(page, '03-dialog-settled');

    await tap(page, 'Red');
    await page.waitForTimeout(400);
    await dump(page, '04-after-red');

    await tap(page, 'Add chip');
    await page.waitForTimeout(600);
    await dump(page, '05-row-added');

    // Value-field input experiments on row 0.
    const valueInput = page.locator('input[aria-label="Value"]');
    console.log(`value inputs: ${await valueInput.count()}`);
    const anyInputs = page.locator('input, textarea');
    console.log(`all inputs: ${await anyInputs.count()}`);

    const target = (await valueInput.count()) > 0 ? valueInput.nth(0) : anyInputs.nth(1);
    await target.click({ force: true });
    await page.waitForTimeout(200);

    // Experiment A: insertText (single event)
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.insertText('25');
    await page.waitForTimeout(400);
    console.log(`A insertText -> DOM value "${await anyInputs.nth(1).inputValue().catch(() => '?')}"`);
    await dump(page, '06-inserttext');

    // Experiment B: per-char typing with End between chars
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Backspace');
    for (const ch of '137') {
      await page.keyboard.press('End');
      await page.keyboard.type(ch);
      await page.waitForTimeout(180);
    }
    await page.waitForTimeout(300);
    console.log(`B end+type -> DOM value "${await anyInputs.nth(1).inputValue().catch(() => '?')}"`);
    await dump(page, '07-endtype');

    // Experiment C: slow typing without clearing (append)
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type('25', { delay: 350 });
    await page.waitForTimeout(400);
    console.log(`C slow -> DOM value "${await anyInputs.nth(1).inputValue().catch(() => '?')}"`);
    await dump(page, '08-slow');

    console.log(`TEXT: ${(await appText(page)).replace(/\s+/g, ' ').slice(0, 400)}`);
  } finally {
    await app.close();
  }
});
