import { test } from '@playwright/test';
import { appText, expectText, goto, hasText, launchApp, screenshot, tap } from './helpers/flutter';
import { ensureAccount, typeInto } from './helpers/auth';
import { openHome } from './helpers/nav';

/**
 * M1 — Quick game ("Start a game now"), from the acceptance document:
 *
 *   start the quick game → answer the setup → approve the starting stack →
 *   edit a level and recalculate around it → start the clock.
 *
 * Key expectation: with the document's setup (Home 25 chip set, standard
 * night) the suggested starting stack is ≈5,000 at blinds 25/50. A slightly
 * different figure is fine when it is round and playable — 4,300–5,700.
 *
 * DECISION: the "Your game is live" modal (showAppModal → showGeneralDialog) is
 * not exposed in the accessibility tree — only the screen behind it is — so
 * the test reads completion from the Start button's busy state and proves the
 * live game from a fresh boot on Home (the "LIVE" badge).
 */
test('M1: quick game — setup, stack ≈5,000 at 25/50, level edit, start', async () => {
  const app = await launchApp('qa-a');
  try {
    const { page } = app;
    await ensureAccount(page, 'A');
    await openHome(page);

    // Home hero → QuickStartScreen (same for every home state).
    await tap(page, 'Start a game now', { exact: false, timeout: 40_000 });
    await expectText(page, 'Next: starting stack', 30_000);

    // 1. Setup inputs — defaults carry the document's configuration.
    await tap(page, 'Next: starting stack');

    // 2. Starting stack ≈5,000.
    await expectText(page, 'Starting stack', 20_000);
    await screenshot(page, 'm1-stack-step');
    const stepText = await appText(page);
    const stack = (stepText.match(/\b[45][\d,]{2,5}\b/g) ?? [])
      .map((t) => Number(t.replace(/,/g, '')))
      .find((n) => n >= 4_300 && n <= 5_700);
    if (!stack) {
      throw new Error(`M1: no ≈5,000 stack figure on the stack step: ${stepText.replace(/\s+/g, ' ').slice(0, 500)}`);
    }
    console.log(`M1: suggested starting stack = ${stack}`);

    // 3. Approve → the levels must open at 25/50.
    await tap(page, 'Approve stack');
    await expectText(page, 'minute levels', 20_000);
    await expectText(page, '25 / 50', 20_000);
    await screenshot(page, 'm1-structure-step');

    // 4. Edit level 1 (BB 50 → 60), save, then recalculate around it.
    await tap(page, 'Edit level 1');
    await typeInto(page, 'BB', '60', { nth: 0 });
    await tap(page, 'Save');
    await expectText(page, 'Recalculate around this', 15_000);
    await tap(page, 'Recalculate around this', { role: 'button' });
    await page.waitForTimeout(600);

    // 5. Start the clock — the game goes live. Creation writes to production
    //    Firebase and can take over a minute. A leftover live game from an
    //    earlier run is closed by the replace dialog that appears on Start.
    await tap(page, 'Start the clock');
    const startedAt = Date.now();
    while (Date.now() - startedAt < 8_000) {
      if (await hasText(page, 'End it and start')) {
        console.log('M1: an earlier live game exists — ending it to start this one');
        await tap(page, 'End it and start');
        break;
      }
      await page.waitForTimeout(300);
    }

    const startButtonState = (): Promise<string> =>
      page.evaluate(() => {
        const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
        const el = Array.from(document.querySelectorAll('flt-semantics')).find(
          (e) => norm((e as HTMLElement).innerText) === 'Start the clock',
        );
        if (!el) return 'gone';
        return el.getAttribute('aria-disabled') === 'true' ? 'busy' : 'enabled';
      });

    // Wait for creation: the Start button goes busy, then enables again the
    // moment the game is running. If the busy state never shows, wait a fixed
    // floor instead (creation must not be interrupted — a reload mid-flight
    // would kill it).
    let sawBusy = false;
    while (Date.now() - startedAt < 300_000) {
      if (await hasText(page, 'Your game is live')) break;
      if (await hasText(page, 'The chip case')) {
        throw new Error('M1: the game could not start — the chip case cannot fund it');
      }
      const state = await startButtonState();
      if (state === 'busy') sawBusy = true;
      if (sawBusy && state !== 'busy') break;
      if (!sawBusy && Date.now() - startedAt > 180_000) break;
      await page.waitForTimeout(700);
    }
    console.log('M1: creation finished');

    // 6. Fresh boot on Home reads the game back from Firebase — the LIVE badge
    //    is the proof that the clock is running.
    await goto(page, '/home');
    await expectText(page, 'LIVE', 90_000);
    await screenshot(page, 'm1-game-live');
    console.log('M1: game is live (LIVE badge on Home)');
  } finally {
    await app.close();
  }
});
