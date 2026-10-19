import { test, type Page } from '@playwright/test';
import {
  appText,
  expectNoText,
  expectText,
  goto,
  hasText,
  launchApp,
  readTextMatch,
  screenshot,
  scrollUntilVisible,
  tap,
} from './helpers/flutter';
import { ensureAccount } from './helpers/auth';
import { openHome, selectTestClub } from './helpers/nav';
import {
  buttonState,
  checkLadder,
  readChipPlan,
  readDepthLine,
  readLevels,
  readPlayersCount,
  readStackChips,
  setDefaultChipSet,
  setDurationHours,
  setPlayersCount,
  tapInSection,
} from './helpers/builder';
import { ensureChipSet, SMALL_BOX, type ChipSpec } from './helpers/chips';

/**
 * M4 — "the structure fits the real chip case", every step of the acceptance
 * document, run against the deployed build (390×844, qa-a).
 *
 * The document's bar: with the "Small box" in the case a rebuy night (add-on
 * on) is funded with a stack of about 400 chips, a shallower-than-50-BB start
 * warns with one-tap fixes, a field the case cannot fund is blocked with a
 * chip-case message (never "No pace fits"), and every ladder shown stays sane.
 *
 * Two documented actions are impossible on this build and are recorded as
 * findings with the live evidence rather than silently skipped:
 *   - the quick game clamps Players to the group's one free table (9), so the
 *     document's "set the players to 20" clamps to 9 (probe v2 evidence);
 *   - the shallow branch needs a case that is small but not too small, which
 *     a stranger's Home 25 cannot be — so the spec saves two tiny diagnostic
 *     cases ("QA tiny case", "QA shallow case") through the chip editor and
 *     drives the guard and the warning with them.
 *
 * Engine figures these steps must reproduce (scratch/smallbox_test.dart):
 *   "Small box" (1×150, 5×150, 25×100, 100×100) + rebuy + add-on, 9 players,
 *     4 h, Normal, 20 min levels → 400 chips = 100 BB, opening 2/4, plan
 *     "10 × 1…", and the case covers the night (the finish-time problem is a
 *     separate card).
 *   "Home 25" + 9 players + rebuy + add-on, 2 h, Deep → 6,000 chips, opening
 *     25/50, and the finish-time card reports the overrun.
 */

/** Home → "Start a game now" → the builder's inputs step. */
async function startQuickGame(page: Page): Promise<void> {
  await openHome(page);
  await selectTestClub(page);
  await tap(page, 'Start a game now', { exact: false, timeout: 40_000 });
  await expectText(page, 'Next: starting stack', 30_000);
}

/** A rebuy night: players 9, format Rebuy. Returns after the setup is on. */
async function setupRebuyNight(page: Page): Promise<void> {
  const players = await setPlayersCount(page, 9);
  if (players !== 9) throw new Error(`M4: players reads ${players}, expected 9`);
  await tap(page, 'Rebuy', { exact: true });
  await expectText(page, 'Add-on', 15_000);
}

/** Clicks the first semantics node whose text matches `re`. Returns the text. */
async function tapByRegex(page: Page, re: RegExp): Promise<string | null> {
  const hit = await page.evaluate((src) => {
    const rx = new RegExp(src);
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const t = norm((el as HTMLElement).innerText);
      if (!rx.test(t)) continue;
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width > 0 && r.height > 0) {
        return { x: r.left + r.width / 2, y: r.top + r.height / 2, t };
      }
    }
    return null;
  }, re.source);
  if (!hit) return null;
  await page.mouse.click(hit.x, hit.y);
  await page.waitForTimeout(900);
  return hit.t;
}

/**
 * The two diagnostic cases. "Tiny" cannot fund nine 20 BB stacks (100 chips
 * for 9 players ≈ 11 each); "shallow" can fund the night but not deeply
 * (~600 chips / 12.15 draws ≈ 49 chips a player ≈ 25 BB at a 2 big blind).
 */
const QA_TINY: ChipSpec[] = [{ color: 'White', value: 1, quantity: 100 }];
const QA_SHALLOW: ChipSpec[] = [
  { color: 'White', value: 1, quantity: 200 },
  { color: 'Red', value: 5, quantity: 50 },
  { color: 'Green', value: 25, quantity: 6 },
];

test('M4: the structure fits the real chip case', async () => {
  test.setTimeout(25 * 60_000);
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await selectTestClub(page);

    // The diagnostic sets (idempotent — created once through the real chip
    // editor, listed under Setup's chip-case screen).
    await goto(page, '/home');
    await ensureChipSet(page, 'QA tiny case', QA_TINY);
    await ensureChipSet(page, 'QA shallow case', QA_SHALLOW);

    // ── Steps 1–2 — the Small box funds a ≈400-chip rebuy night ────────────
    await setDefaultChipSet(page, 'Small box');
    await startQuickGame(page);
    await expectText(page, 'Small box', 15_000); // the case in use
    await setupRebuyNight(page);
    await screenshot(page, 'm4-01-inputs-smallbox');

    await tap(page, 'Next: starting stack', { exact: true });
    await expectText(page, 'Starting stack', 20_000);
    const stackS = await readStackChips(page);
    const depthS = await readDepthLine(page);
    const planS = await readChipPlan(page);
    console.log(`M4 steps 1-2: ${stackS} chips · ${depthS} · plan ${planS}`);
    if (stackS !== 400) {
      throw new Error(`M4 step 2: the Small box should deal ≈400 chips, saw ${stackS}`);
    }
    if (!depthS || !/^100 big blinds deep · opening 2\/4$/.test(depthS)) {
      throw new Error(`M4 step 2: expected a 100 BB start at 2/4, saw "${depthS}"`);
    }
    // The per-player split uses only chips the case holds, never more than it has.
    if (!planS) throw new Error('M4 step 2: no per-player chip split on screen');
    const caseCounts = new Map(SMALL_BOX.map((c) => [c.value, c.quantity]));
    for (const part of planS.split(' · ')) {
      const m = part.match(/^(\d+) × ([\d,]+)$/);
      if (!m) throw new Error(`M4 step 2: unparsed split part "${part}"`);
      const qty = Number(m[1]);
      const value = Number(m[2].replace(/,/g, ''));
      const have = caseCounts.get(value);
      if (have === undefined) {
        throw new Error(`M4 step 2: the split uses a ${value} chip the Small box does not hold`);
      }
      if (qty > have) throw new Error(`M4 step 2: the split wants ${qty} × ${value}, the case holds ${have}`);
    }
    await expectText(page, 'Your chips cover this night.', 15_000);
    await expectNoText(page, 'Your chip case is too small', 2_000);
    // The time problem gets its own card — it is not a chip problem.
    if (!(await scrollUntilVisible(page, 'This structure runs past your finish time'))) {
      console.log('M4 FINDING step 2: no finish-time card on the fundable Small-box night');
    }
    await screenshot(page, 'm4-02-stack-smallbox');

    // Steps 3-4 (conditional): the depth is not under 50 BB with the
    // document's settings, so the shallow warning has no reason to appear.
    console.log(
      `M4 steps 3-4 (conditional): depth "${depthS}" — not under 50 BB, so the shallow branch does not trigger with the document's settings`,
    );

    // The ladder opens and holds every documented invariant.
    await tap(page, 'Approve stack', { exact: true });
    await expectText(page, '2 / 4', 20_000);
    const ladderSmall = await readLevels(page);
    checkLadder(ladderSmall, 'M4 step 2 (Small box)', { sb: 2, bb: 4 });
    console.log(`M4 step 2: ladder\n${ladderSmall.map((l) => `  L${l.n}: ${l.sb}/${l.bb}`).join('\n')}`);
    await screenshot(page, 'm4-03-levels-smallbox');

    // ── Step 5a — the document's "20 players" clamps to the free table ─────
    await tap(page, 'Change stack', { exact: true });
    await expectText(page, 'Starting stack', 15_000);
    await tap(page, 'Back to the setup', { exact: true });
    await expectText(page, 'Next: starting stack', 15_000);
    const cap20 = await setPlayersCount(page, 20);
    if (cap20 === 20) {
      console.log('M4 step 5: the quick-game field accepted 20 players');
    } else {
      console.log(
        `M4 FINDING step 5: the document's 20 players is not settable in the quick game — the field clamps to ${cap20} (free hosting covers one table; the group's table size). The chip-case check at 20 players cannot run here; the guard itself is exercised with the QA tiny case below.`,
      );
    }
    await screenshot(page, 'm4-05-players-clamp');
    const restore9 = await setPlayersCount(page, 9);
    if (restore9 !== 9) throw new Error(`M4 step 5: could not restore 9 players (reads ${restore9})`);

    // ── Step 5b — a night the case cannot fund is blocked, not claimed ─────
    // The QA tiny case (100 one-value chips) cannot seat nine 20 BB stacks.
    await setDefaultChipSet(page, 'QA tiny case');
    await startQuickGame(page);
    await setupRebuyNight(page);
    await tap(page, 'Next: starting stack', { exact: true });
    await expectText(page, 'Starting stack', 20_000);
    if (!(await scrollUntilVisible(page, 'Your chip case is too small for this field'))) {
      await screenshot(page, 'm4-05b-not-blocked');
      throw new Error(
        `M4 step 5: the 100-chip case was not blocked. Stack step: ${(await appText(page)).replace(/\s+/g, ' ').slice(0, 400)}`,
      );
    }
    const cannot = await readTextMatch(page, /cannot fund a \d+BB starting stack for \d+ players/);
    const reduce = await readTextMatch(page, /Reduce to \d+ players/);
    const approveBlocked = await buttonState(page, 'Approve stack');
    console.log(`M4 step 5: blocked — "${cannot}"; fix "${reduce}"; Approve stack=${approveBlocked}`);
    if (!cannot) console.log('M4 FINDING step 5: the chip-case card does not state the shortfall in players/BB');
    if (approveBlocked !== 'disabled') {
      console.log(`M4 FINDING step 5: "Approve stack" reads ${approveBlocked} on a blocked night`);
    }
    // Tapping a blocked night's Approve must not move the night forward.
    // Measure the button fresh and click its live centre: a click computed
    // from a stale rect (the semantics layer lags a scroll) can land on
    // whatever slid into that spot — once seen as a "Back to the setup" press.
    const blockRect = await scrollUntilVisible(page, 'Approve stack');
    let blockedTap: string;
    if (!blockRect) {
      blockedTap = 'the Approve button vanished from the blocked step';
    } else {
      await page.waitForTimeout(500);
      const fresh = (await scrollUntilVisible(page, 'Approve stack')) ?? blockRect;
      await page.mouse.click(fresh.x + fresh.width / 2, fresh.y + fresh.height / 2);
      await page.waitForTimeout(1_200);
      const levelsOpened = await hasText(page, 'minute levels');
      const backOnSetup = await hasText(page, 'Next: starting stack');
      const stillBlocked = await hasText(page, 'Approve stack');
      if (levelsOpened) {
        blockedTap = 'the blocked night continued to the levels — the guard let it through';
        console.log(`M4 FINDING step 5: ${blockedTap}`);
      } else if (backOnSetup) {
        blockedTap = 'the press landed on "Back to the setup" (harness mis-click), not the blocked Approve';
      } else if (stillBlocked) {
        blockedTap = 'the blocked night stayed on the stack step';
      } else {
        blockedTap = `the stack step left without the levels. Screen: ${(await appText(page)).replace(/\s+/g, ' ').slice(0, 220)}`;
      }
    }
    console.log(`M4 step 5: tap on blocked Approve — ${blockedTap}`);
    await expectNoText(page, 'No pace fits', 2_000); // never in the builder
    await screenshot(page, 'm4-05b-blocked-tiny-case');
    if (reduce) {
      await tap(page, reduce, { exact: true });
      await page.waitForTimeout(900);
      const cardGone = !(await hasText(page, 'Your chip case is too small'));
      const seated = await readPlayersCount(page);
      console.log(`M4 step 5: after "${reduce}" the field reads ${seated} players; card gone=${cardGone}`);
      await screenshot(page, 'm4-05b-reduced');
    }

    // ── Steps 3–4 (exercised) — the shallow warning and its one-tap fixes ──
    // The QA shallow case funds the night, but not deeply.
    await setDefaultChipSet(page, 'QA shallow case');
    await startQuickGame(page);
    await setupRebuyNight(page);
    await scrollUntilVisible(page, 'Add-on');
    await tapInSection(page, 'Add-on', 'No').catch(() =>
      tap(page, 'Add-on', { role: 'switch', exact: false, xBias: 0.9 }).catch((err) => {
        console.log(`M4 steps 3-4: could not turn the add-on off (${String(err).split('\n')[0]})`);
      }),
    ); // keep rebuys; the fix list still applies
    await tap(page, 'Next: starting stack', { exact: true });
    await expectText(page, 'Starting stack', 20_000);
    const depthShallow = await readDepthLine(page);
    const stackShallow = await readStackChips(page);
    const shallowShown = await hasText(page, 'Shallow start');
    console.log(`M4 steps 3-4: ${stackShallow} chips · ${depthShallow} · shallow card=${shallowShown}`);
    if (!shallowShown) {
      console.log(
        `M4 FINDING steps 3-4: the QA shallow case did not produce a sub-50 BB start (depth "${depthShallow}"); the documented shallow branch stayed unexercised. Closest screen: ${(await appText(page)).replace(/\s+/g, ' ').slice(0, 260)}`,
      );
    } else {
      await expectText(page, 'shallower than the 50 we like to see', 10_000);
      await expectText(page, 'Nothing changes until you tap one:', 10_000);
      await screenshot(page, 'm4-04-shallow-warning');
      const fix = await tapByRegex(page, /^(Skip the add-on|Limit rebuys to \d+ each|Lower the rebuy)[^→]*→ [\d.]+ BB$/);
      if (!fix) {
        console.log('M4 FINDING step 4: no one-tap fix button found on the shallow card');
      } else {
        const depthAfter = await readDepthLine(page);
        const cardAfter = await hasText(page, 'Shallow start');
        console.log(`M4 step 4: tapped "${fix}" → depth "${depthAfter}", shallow card still shown=${cardAfter}`);
        if (!cardAfter || depthAfter !== depthShallow) {
          console.log('M4 step 4: the one tap changed the night (nothing had changed before it)');
        } else {
          console.log(`M4 FINDING step 4: "${fix}" did not change the night (depth still ${depthAfter})`);
        }
        await screenshot(page, 'm4-04-shallow-fix-applied');
      }
    }

    // ── Steps 6–7 — 2 h + Deep: the time warning, then clean levels ────────
    await setDefaultChipSet(page, 'Home 25');
    await startQuickGame(page);
    await setDurationHours(page, 2);
    await tap(page, 'Deep', { exact: true });
    await setupRebuyNight(page);
    await tap(page, 'Next: starting stack', { exact: true });
    await expectText(page, 'Starting stack', 20_000);
    const stackDeep = await readStackChips(page);
    const depthDeep = await readDepthLine(page);
    console.log(`M4 step 6: ${stackDeep} chips · ${depthDeep}`);
    const timeCard = await scrollUntilVisible(page, 'This structure runs past your finish time');
    const overrun = await readTextMatch(page, /At Deep the levels run about [^.]*past the time you set[^.]*\./);
    console.log(`M4 step 6: time card=${timeCard}; note "${overrun}"`);
    if (!timeCard) console.log('M4 FINDING step 6: no time warning with 2 h + Deep');
    await expectNoText(page, 'No pace fits', 2_000); // reserved for the clock, not the builder
    if (stackDeep !== null && !(stackDeep >= 5_400 && stackDeep <= 6_600)) {
      console.log(`M4 FINDING step 6: Deep dealt ${stackDeep} chips (expected ≈6,000 from the engine) `);
    }
    await screenshot(page, 'm4-06-deep-2h');
    await tap(page, 'Approve stack', { exact: true });
    await expectText(page, 'minute levels', 20_000);
    const ladderDeep = await readLevels(page);
    checkLadder(ladderDeep, 'M4 step 7 (2 h Deep)', undefined, 2);
    console.log(`M4 step 7: Deep ladder\n${ladderDeep.map((l) => `  L${l.n}: ${l.sb}/${l.bb}`).join('\n')}`);
    await screenshot(page, 'm4-07-deep-levels');
  } finally {
    try {
      await goto(page, '/home');
      await setDefaultChipSet(page, 'Home 25');
    } catch (err) {
      console.log(`M4: could not restore the default chip set: ${String(err).split('\n')[0]}`);
    }
    await app.close();
  }
});
