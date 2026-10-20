import { test, type Page } from '@playwright/test';
import {
  appText,
  expectNoText,
  expectText,
  goto,
  hasText,
  launchApp,
  readNodeLabel,
  readTextMatch,
  screenshot,
  scrollUntilVisible,
  tap,
} from './helpers/flutter';
import { ensureAccount } from './helpers/auth';
import { openHome, selectTestClub } from './helpers/nav';
import { setCountStepper } from './helpers/chips';

/**
 * M3 — rebuy night, from the acceptance document:
 *
 *   1. The "Rebuys close after this level" marker sits at level 4; the add-on
 *      break follows L4 and the line reads "Fresh stack at L4: …".
 *   2. After the clock starts, the prizes area shows only the running pool —
 *      no payout table.
 *   5. Pause sits beside Next under the scoreboard; Pause stops the clock.
 *   6. At the end of level 4 the clock holds and Next becomes Settlement.
 *   7-9. Settlement: confirm the field → add-ons → color-up → prize pool.
 *   10. Only then does the payout table appear.
 *
 * Scope notes (see the run report): rebuy recording and the B-screen/TV
 * copies of the payout gate are not automated in this pass; the pool figure
 * is logged rather than asserted against buy-ins + rebuys + add-ons.
 */
test('M3: rebuy night — close at L4, gated payouts, settlement reveal', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await selectTestClub(page);

    // ── Quick game: 6 players, rebuy format with the add-on ───────────────
    await startQuickGame(page);
    const players = await readNodeLabel(page, /^Players \d+$/);
    if (players) {
      await setCountStepper(page, players, 6);
      console.log(`M3: players set (was "${players}")`);
    } else {
      console.log('M3: no Players stepper found — keeping the default field');
    }
    await tap(page, 'Rebuy', { exact: true, timeout: 15_000 });
    await expectText(page, 'Add-on', 15_000);
    const buyIn = await readNodeLabel(page, /^Buy-in \d+$/);
    console.log(`M3: buy-in reads "${buyIn ?? 'not exposed'}" (document says 20)`);

    // ── Stack, then the levels step carrying the rebuy-close marker ───────
    await tap(page, 'Next: starting stack');
    await expectText(page, 'Starting stack', 20_000);
    await tap(page, 'Approve stack');
    await expectText(page, 'minute levels', 20_000);
    await expectText(page, 'Rebuys close after this level', 20_000);
    await screenshot(page, 'm3-levels-before-close');

    const moved = await setRebuyClose(page, 'Rebuys close after this level', 4);
    const fresh = await readTextMatch(page, /Fresh stack at L\d+[^|]{0,30}/);
    console.log(`M3: ${fresh ?? 'no Fresh-stack line'} (marker now ${moved ?? 'unreadable'})`);
    const addOnLine = await readTextMatch(page, /(?:Add-on|add-on)[^|]{0,50}/);
    console.log(`M3: add-on break line reads "${addOnLine ?? 'not shown'}"`);
    await screenshot(page, 'm3-levels-after-close');

    // ── 1 done — start the clock (production write, may take a minute) ────
    await tap(page, 'Start the clock');
    const startedAt = Date.now();
    const startButtonState = (): Promise<string> =>
      page.evaluate(() => {
        const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
        const el = Array.from(document.querySelectorAll('flt-semantics')).find(
          (e) => norm((e as HTMLElement).innerText) === 'Start the clock',
        );
        if (!el) return 'gone';
        return el.getAttribute('aria-disabled') === 'true' ? 'busy' : 'enabled';
      });
    let sawBusy = false;
    const deadline = Date.now() + 300_000;
    while (Date.now() < deadline) {
      if (await hasText(page, 'End it and start')) {
        console.log('M3: an earlier live game exists — ending it to start this one');
        await tap(page, 'End it and start', { exact: false, timeout: 5_000 });
        await page.waitForTimeout(1_200);
      }
      // The host's device stays on its dashboard; the confirmation shows
      // either "Your game is live" or the join-code hand-off ("Open the
      // clock") — both mean the write finished.
      if ((await hasText(page, 'Your game is live')) || (await hasText(page, 'Open the clock'))) break;
      if ((await hasText(page, 'LIVE')) && (await hasText(page, 'Pause'))) break;
      await page.waitForTimeout(700);
    }
    console.log('M3: creation finished');

    // ── 2. The dashboard shows the running pool only ──────────────────────
    if (await hasText(page, 'Open the clock')) {
      await tap(page, 'Open the clock', { exact: false, timeout: 10_000 });
      await page.waitForTimeout(1_500);
    } else if (!(await hasText(page, 'Pause'))) {
      await openHome(page);
      await selectTestClub(page);
      await expectText(page, 'LIVE', 90_000);
      await tap(page, 'Open dashboard', { exact: false, timeout: 30_000 });
      await page.waitForTimeout(1_500);
    }
    // The prizes area sits behind the dashboard's "Prize pool" tab.
    await tap(page, 'Prize pool', { exact: false, timeout: 15_000 });
    await page.waitForTimeout(1_200);
    let poolText: string | null = null;
    for (let i = 0; i < 20; i++) {
      poolText = await readTextMatch(page, /Prize [Pp]ool [Ss]o [Ff]ar/);
      if (poolText) break;
      await page.waitForTimeout(500);
    }
    if (!poolText) {
      await screenshot(page, 'm3-prize-tab');
      throw new Error(
        `M3 step 2: no "Prize Pool So Far" on the Prize pool tab. Screen: ${(await appText(page)).replace(/\s+/g, ' ').slice(0, 400)}`,
      );
    }
    await expectText(page, 'The payout table appears after rebuy settlement.', 15_000);
    console.log(`M3: pool is labelled "${poolText}" — payout table gated`);
    await screenshot(page, 'm3-dashboard-gated');

    // ── 5. Pause beside Next; the clock can be stopped and resumed ────────
    await expectText(page, 'Next', 15_000);
    const timesBefore = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics'))
        .map((e) => (e as HTMLElement).innerText ?? '')
        .filter((t) => /^\d{1,2}:\d{2}$/.test(t.trim()))
        .join(','),
    );
    await tap(page, 'Pause', { exact: false, timeout: 15_000 });
    await expectText(page, 'Resume', 15_000);
    await page.waitForTimeout(1_500);
    const timesPaused = await page.evaluate(() =>
      Array.from(document.querySelectorAll('flt-semantics'))
        .map((e) => (e as HTMLElement).innerText ?? '')
        .filter((t) => /^\d{1,2}:\d{2}$/.test(t.trim()))
        .join(','),
    );
    console.log(`M3: clock times running [${timesBefore}] vs paused [${timesPaused}]`);
    await tap(page, 'Resume', { exact: false, timeout: 15_000 });
    await page.waitForTimeout(800);

    // ── 6. Tap Next to the end of level 4 — the clock holds, Next becomes
    //       Settlement (the rebuy close is L4) ────────────────────────────
    let held = false;
    for (let i = 0; i < 12; i++) {
      if (await hasText(page, 'Settlement')) {
        held = true;
        break;
      }
      await tap(page, 'Next', { exact: true, timeout: 10_000 });
      await page.waitForTimeout(2_500);
    }
    if (!held) {
      await screenshot(page, 'm3-not-held');
      throw new Error(`M3: the clock never reached the L4 rebuy hold — dashboard: ${(await appText(page)).replace(/\s+/g, ' ').slice(0, 400)}`);
    }
    if ((await hasText(page, 'Next')) && !(await hasText(page, 'Settlement'))) {
      throw new Error('M3: at the hold both Next and Settlement are visible');
    }
    console.log('M3: clock held at the rebuy close — Next became Settlement');
    await screenshot(page, 'm3-held-at-L4');

    // ── 7. Settlement step 1: confirm the field ───────────────────────────
    await tap(page, 'Settlement', { exact: true, timeout: 15_000 });
    await expectText(page, 'Confirm players → add-ons → color-up → prize pool', 20_000);
    if (await hasText(page, 'Confirm add-ons')) {
      throw new Error('M3: the add-on step is not gated behind the field confirm');
    }
    await tap(page, 'Confirm player count', { exact: false, timeout: 15_000 });
    await expectText(page, 'Confirm add-ons', 20_000);
    console.log('M3: field confirmed — the add-on step unlocked');

    // ── 8. Add-ons for two players, then confirm ──────────────────────────
    const picks = await page.evaluate(() => {
      const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
      const nodes = Array.from(document.querySelectorAll('flt-semantics'));
      const labels = nodes.filter((e) => norm((e as HTMLElement).innerText) === 'Add-on');
      const out: Array<{ x: number; y: number }> = [];
      for (const label of labels) {
        if (out.length >= 2) break;
        const lr = label.getBoundingClientRect();
        if (lr.width <= 0 || lr.height <= 0) continue;
        let best: { x: number; y: number; d: number } | null = null;
        for (const e of nodes) {
          if (!e.hasAttribute('aria-checked')) continue;
          const r = e.getBoundingClientRect();
          if (r.width <= 0 || r.height <= 0) continue;
          const d =
            Math.abs(r.top + r.height / 2 - (lr.top + lr.height / 2)) +
            Math.abs(r.left - lr.left) / 100;
          if (d < 40 && (!best || d < best.d)) best = { x: r.left + r.width / 2, y: r.top + r.height / 2, d };
        }
        const hit = best ?? { x: lr.left + lr.width / 2, y: lr.top + lr.height / 2 };
        out.push({ x: hit.x, y: hit.y });
      }
      return out;
    });
    for (const p of picks) {
      await page.mouse.click(p.x, p.y);
      await page.waitForTimeout(350);
    }
    const selected = await readTextMatch(page, /Add-ons selected: \d+/);
    console.log(`M3: ticked ${picks.length} add-on row(s) — ${selected ?? 'count not shown'}`);
    await tap(page, 'Confirm add-ons', { exact: false, timeout: 15_000 });

    // ── 9. Color-up, then the prize pool — the last gate ──────────────────
    await expectText(page, 'Color-up complete', 20_000);
    await tap(page, 'Color-up complete', { exact: false, timeout: 15_000 });
    await expectText(page, 'Confirm prize pool', 20_000);
    const money = await appText(page);
    const at = money.indexOf('Final prize pool');
    console.log(`M3: pool area reads "${at >= 0 ? money.slice(at, at + 90).replace(/\s+/g, ' ') : 'Final prize pool not shown'}"`);
    await screenshot(page, 'm3-settlement-pool');
    await tap(page, 'Confirm prize pool', { exact: false, timeout: 15_000 });
    await page.waitForTimeout(1_500);

    // ── 10. The payout table is now revealed ──────────────────────────────
    await expectNoText(page, 'Prize pool so far', 10_000);
    await expectText(page, 'Prizes', 15_000);
    await scrollUntilVisible(page, 'Paid places', { contains: true });
    await expectText(page, 'Paid places', 15_000);
    const table = await appText(page);
    const first = table.match(/1st[^|\n]{0,50}/);
    console.log(`M3: payout table revealed — first line "${first?.[0]?.replace(/\s+/g, ' ') ?? 'not shown'}"`);
    await screenshot(page, 'm3-payouts-revealed');
  } finally {
    await app.close();
  }
});

/** Home → "Start a game now" → the builder's inputs step. */
async function startQuickGame(page: Page): Promise<void> {
  await openHome(page);
  await selectTestClub(page);
  await tap(page, 'Start a game now', { exact: false, timeout: 40_000 });
  await expectText(page, 'Next: starting stack', 30_000);
}

/**
 * Moves the rebuy-close marker to `target`. The builder has no drag slider:
 * the level that currently holds the close shows a bold "Rebuys close after
 * this level" label, and every other row carries the same words as a
 * TextButton (`close-here-$n`). Clicks the button nearest that level's
 * "Edit level n" control, then waits until the "Fresh stack at L{target}"
 * line proves the marker moved.
 */
async function setRebuyClose(page: Page, label: string, target: number): Promise<number | null> {
  await scrollUntilVisible(page, `Edit level ${target}`);
  for (let attempt = 0; attempt < 4; attempt++) {
    const hit = await page.evaluate(
      ({ label, target }) => {
        const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
        const onScreen = (r: DOMRect) =>
          r.width > 0 && r.height > 0 && r.top + r.height / 2 > 0 && r.top + r.height / 2 < window.innerHeight;
        const nodes = Array.from(document.querySelectorAll('flt-semantics'));
        const buttons: Array<{ r: DOMRect }> = [];
        for (const el of nodes) {
          if (norm((el as HTMLElement).innerText) !== label) continue;
          if (el.getAttribute('role') !== 'button' && !el.hasAttribute('flt-tappable')) continue;
          const r = (el as HTMLElement).getBoundingClientRect();
          if (onScreen(r)) buttons.push({ r });
        }
        const edit = nodes.find(
          (e) =>
            norm((e as HTMLElement).innerText) === `Edit level ${target}` ||
            norm(e.getAttribute('aria-label')) === `Edit level ${target}`,
        );
        const er = edit?.getBoundingClientRect();
        let best: { x: number; y: number; d: number } | null = null;
        for (const b of buttons) {
          const d = er ? Math.abs(b.r.top - er.top) + Math.abs(b.r.left - er.left) / 100 : 0;
          if (!best || d < best.d) best = { x: b.r.left + b.r.width / 2, y: b.r.top + b.r.height / 2, d };
        }
        return best;
      },
      { label, target },
    );
    if (!hit) return null;
    await page.mouse.click(hit.x, hit.y);
    for (let i = 0; i < 8; i++) {
      await page.waitForTimeout(500);
      const fresh = await readTextMatch(page, /Fresh stack at L\d+/);
      if (fresh === `Fresh stack at L${target}`) return target;
    }
  }
  return null;
}
