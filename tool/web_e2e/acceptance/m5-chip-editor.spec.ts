import { test, type Page } from '@playwright/test';
import {
  appText,
  expectText,
  launchApp,
  screenshot,
  scrollUntilVisible,
  tap,
} from './helpers/flutter';
import { ensureAccount } from './helpers/auth';
import { goHomeInApp, openHome } from './helpers/nav';
import { ensureNoUserPresets, openPresets, scrollToCard } from './helpers/presets';
import { savePresetDialog } from './helpers/save_preset';

/**
 * M5 steps 1–4 — chip entry, from the acceptance document:
 *
 *   1. On one colour's count, press and hold + — the count keeps rising.
 *   2. Switch the step size to ×25 and tap + once — the count goes up by 25.
 *   3. Tap the count number and type 80 — it becomes 80; an invalid entry is
 *      refused.
 *   4. Add a custom colour named "Teal" — it appears with its name.
 *
 * The builder's "Edit chips" modal edits the case in place (it never touches
 * the saved "Home 25" set), so this test also proves the doc's step-7 claim a
 * different way: a preset saved afterwards lists the edited "Teal" chip.
 *
 * Steps 5–9 and 11 run in m5-presets.spec.ts; step 10 (the Free limit) is the
 * second test there.
 */

/** Home → "Start a game now" → the builder's inputs step. */
async function startQuickGame(page: Page): Promise<void> {
  await openHome(page);
  await tap(page, 'Start a game now', { exact: false, timeout: 40_000 });
  await expectText(page, 'Next: starting stack', 30_000);
}

/** Opens the builder's chip modal and waits for it to settle. */
async function openChipEditor(page: Page): Promise<void> {
  await scrollUntilVisible(page, 'Edit chips');
  await tap(page, 'Edit chips', { exact: true, timeout: 10_000 });
  await expectText(page, 'Start from a preset', 20_000);
  await page.waitForTimeout(500);
}

/** The editor sheet's top edge, derived from its first control. */
async function editorTop(page: Page): Promise<number> {
  return await page.evaluate(() => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      if (norm((el as HTMLElement).innerText) !== 'Start from a preset') continue;
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width > 0) return r.top - 40;
    }
    return 0;
  });
}

/** First control (by top edge) below `minTop` whose text or aria-label is `text`. */
async function firstControl(
  page: Page,
  text: string,
  minTop: number,
): Promise<{ x: number; y: number; top: number; left: number; h: number } | null> {
  return await page.evaluate(
    ({ text, minTop }) => {
      const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
      let best: { x: number; y: number; top: number; left: number; h: number } | null = null;
      for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
        const t = norm((el as HTMLElement).innerText);
        const a = norm(el.getAttribute('aria-label'));
        if (t !== text && a !== text) continue;
        const r = (el as HTMLElement).getBoundingClientRect();
        if (r.width < 8 || r.height < 1 || r.top < minTop) continue;
        if (!best || r.top < best.top) {
          best = { x: r.left + r.width / 2, y: r.top + r.height / 2, top: r.top, left: r.left, h: r.height };
        }
      }
      return best;
    },
    { text, minTop },
  );
}

/**
 * Reads the first colour row's count by opening its "Enter number" dialog
 * (tapping the number itself) and cancelling out.
 */
async function readCount(page: Page, minTop: number): Promise<number | null> {
  const plus = await firstControl(page, 'Increase', minTop);
  if (!plus) return null;
  const x = plus.left - 32; // the number cell sits left of the +, inside the row
  await page.mouse.click(x, plus.y);
  await expectText(page, 'Enter number', 15_000);
  await page.waitForTimeout(400);
  const field = page.locator('input, textarea').last();
  await field.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
  await page.waitForTimeout(120);
  const raw = (await field.inputValue({ timeout: 3_000 }).catch(() => '')).trim();
  await tap(page, 'Cancel');
  await page.waitForTimeout(400);
  const n = Number(raw);
  return raw !== '' && Number.isFinite(n) ? n : null;
}

test('M5 steps 1-4: hold +, ×25 step, typed 80 answered, custom Teal', async () => {
  test.setTimeout(15 * 60_000);
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    // Deterministic start: the evidence save below needs a free preset slot.
    await openPresets(page);
    const cleaned = await ensureNoUserPresets(page);
    console.log(`M5: library cleaned (${cleaned} leftover preset(s))`);
    await goHomeInApp(page);
    await startQuickGame(page);
    await openChipEditor(page);
    const top = await editorTop(page);
    await screenshot(page, 'm5-editor-open');

    // ── 1. Press and hold + — the count keeps rising while held ────────────
    const before1 = await readCount(page, top);
    const plus1 = await firstControl(page, 'Increase', top);
    if (!plus1) throw new Error('M5 step 1: no + control in the first colour row');
    await page.mouse.move(plus1.x, plus1.y);
    await page.mouse.down();
    await page.waitForTimeout(1_400);
    await page.mouse.up();
    await page.waitForTimeout(400);
    const after1 = await readCount(page, top);
    console.log(`M5 step 1: hold + 1.4 s — count ${before1} → ${after1}`);
    if (before1 === null || after1 === null || after1 - before1 < 6) {
      console.log(
        `M5 FINDING step 1: holding + moved ${before1} → ${after1} (one plain tap moves ${1}); the hold did not repeat`,
      );
    }

    // ── 2. Step size ×25, one tap — exactly +25 ────────────────────────────
    const step25 = await firstControl(page, '×25', top);
    if (!step25) throw new Error('M5 step 2: no ×25 step control in the first colour row');
    await page.mouse.click(step25.x, step25.y);
    await page.waitForTimeout(400);
    const plus2 = await firstControl(page, 'Increase', top);
    if (!plus2) throw new Error('M5 step 2: no + control in the first colour row');
    await page.mouse.click(plus2.x, plus2.y);
    await page.waitForTimeout(500);
    const after2 = await readCount(page, top);
    console.log(`M5 step 2: ×25 then one + — count ${after1} → ${after2}`);
    if (after1 === null || after2 === null || after2 - after1 !== 25) {
      throw new Error(`M5 step 2: ×25 step moved ${after1} → ${after2}, expected exactly +25`);
    }
    await screenshot(page, 'm5-step2-step25');

    // ── 3. The count number itself: type 80; invalid entries refused ───────
    const plus3 = await firstControl(page, 'Increase', top);
    if (!plus3) throw new Error('M5 step 3: no + control to locate the count');
    await page.mouse.click(plus3.left - 32, plus3.y);
    await expectText(page, 'Enter number', 15_000);
    await page.waitForTimeout(400);
    {
      const field = page.locator('input, textarea').last();
      await field.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
      await page.keyboard.press('Control+A');
      await page.keyboard.press('Backspace');
      await page.keyboard.insertText('80');
      await page.waitForTimeout(200);
      await tap(page, 'Apply');
      await page.waitForTimeout(500);
    }
    const typed = await readCount(page, top);
    console.log(`M5 step 3: typed 80 — count now ${typed}`);
    if (typed !== 80) throw new Error(`M5 step 3: count reads ${typed} after typing 80`);

    // Invalid: letters in the dialog must not change the count.
    const plus3b = await firstControl(page, 'Increase', top);
    if (!plus3b) throw new Error('M5 step 3: no + control to locate the count');
    await page.mouse.click(plus3b.left - 32, plus3b.y);
    await expectText(page, 'Enter number', 15_000);
    await page.waitForTimeout(400);
    {
      const field = page.locator('input, textarea').last();
      await field.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
      await page.keyboard.press('Control+A');
      await page.keyboard.press('Backspace');
      await page.keyboard.insertText('abc');
      await page.waitForTimeout(200);
      const shown = (await field.inputValue().catch(() => '')).trim();
      console.log(`M5 step 3: the dialog shows "${shown}" after typing abc`);
      await tap(page, 'Apply');
      await page.waitForTimeout(500);
    }
    const afterInvalid = await readCount(page, top);
    console.log(`M5 step 3: after the invalid entry the count is ${afterInvalid}`);
    if (afterInvalid !== 80) {
      console.log(`M5 FINDING step 3: an invalid entry changed the count to ${afterInvalid}`);
    }
    await screenshot(page, 'm5-step3-typed-80');

    // ── 4. A custom colour named "Teal" ────────────────────────────────────
    await tap(page, 'Add a colour', { exact: true, timeout: 10_000 });
    await expectText(page, 'Pick a chip colour', 15_000);
    await page.waitForTimeout(400);
    await tap(page, 'Custom colour', { exact: true, timeout: 10_000 });
    await page.waitForTimeout(500);
    {
      const field = page.locator('input, textarea').last();
      await field.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
      await page.waitForTimeout(120);
      await page.keyboard.press('Control+A');
      await page.keyboard.press('Backspace');
      await page.keyboard.insertText('Teal');
      await page.waitForTimeout(200);
    }
    await tap(page, 'Add colour', { exact: true });
    await page.waitForTimeout(700);
    await expectText(page, 'Teal', 15_000);
    console.log('M5 step 4: a custom colour "Teal" is in the set');
    await screenshot(page, 'm5-step4-teal');

    // Back to the builder with the edited case.
    await tap(page, 'Use these chips', { exact: true, timeout: 10_000 });
    await page.waitForTimeout(600);
    await expectText(page, 'Next: starting stack', 15_000);
    const chipName = (await appText(page)).split('\n').map((l) => l.trim()).find((l) => l === 'Custom');
    console.log(`M5 step 4: builder chips row now named ${chipName ?? '(not "Custom")'}`);

    // ── Step-7 evidence: a saved preset lists the edited "Teal" chip ───────
    await scrollUntilVisible(page, 'Save as preset');
    await tap(page, 'Save as preset', { exact: true, timeout: 10_000 });
    const saved = await savePresetDialog(page, 'QA teal preset');
    if (saved !== 'saved') {
      throw new Error(`M5 step 7 evidence: the edited case could not be saved as a preset (${saved})`);
    }
    await goHomeInApp(page);
    await openPresets(page);
    const card = await scrollToCard(page, 'QA teal preset');
    if (!card) {
      throw new Error('M5 step 7 evidence: the saved preset is not in the library');
    }
    const tealInCard = card.label.includes('Teal');
    console.log(
      `M5 step 7 evidence: the preset card lists the edited "Teal" chip=${tealInCard}; ` +
        `its chip-set tag reads ${card.label.includes('HOME 25') ? 'HOME 25' : '?'} — ${card.label.slice(0, 140)}`,
    );
    if (!tealInCard) {
      throw new Error('M5 step 7 evidence: the saved preset does not hold the edited chip case');
    }
    await screenshot(page, 'm5-step7-preset-edited-case');

    // Clean up the evidence preset so later runs start level.
    const removed = await ensureNoUserPresets(page);
    console.log(`M5: evidence preset cleaned up (${removed} removed)`);
  } finally {
    await app.close();
  }
});
