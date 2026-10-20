import { test } from '@playwright/test';
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
import { ensureAccount, typeInto } from './helpers/auth';
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
  setStackField,
} from './helpers/builder';
import { HOME_25 } from './helpers/chips';

/**
 * M1 — Quick game, every step of the acceptance document, run against the
 * deployed build (390×844, qa-a).
 *
 *   start the quick game → answer the setup (players 9, 4 h, Normal,
 *   Regular 20 min, ante Yes/BB, two names) → approve the ≈5,000 stack →
 *   push it to 4,000 and to 40,000 → back to ≈5,000 → edit level 6, pin it,
 *   recalculate around it → round trip → start the clock at 25/50.
 *
 * Where the document's expectation does not match what the deployed build
 * does, the run records `M1 FINDING …` lines with the exact screen text and
 * keeps going; the acceptance report carries those as step notes.
 */

/** "M:SS" → seconds. */
function secs(mmss: string): number {
  const m = mmss.match(/(\d{1,2}):(\d{2})/);
  return m ? Number(m[1]) * 60 + Number(m[2]) : NaN;
}

test('M1: quick game — every documented step', async () => {
  test.setTimeout(25 * 60_000);
  const app = await launchApp('qa-a');
  try {
    const { page } = app;
    await ensureAccount(page, 'A');
    await selectTestClub(page);
    await setDefaultChipSet(page, 'Home 25');
    await openHome(page);

    // ── Step 1 ───────────────────────────────────────────────────────────────
    // "Start a game now" opens the builder on its setup step, with no blind
    // levels yet.
    await tap(page, 'Start a game now', { exact: false, timeout: 40_000 });
    await expectText(page, 'Next: starting stack', 30_000);
    await expectNoText(page, 'minute levels', 3_000);
    await expectNoText(page, 'Approve stack', 1_500);
    console.log('M1 step 1: builder opens on its setup step; no levels yet');
    await screenshot(page, 'm1-01-inputs');

    // ── Step 2 ───────────────────────────────────────────────────────────────
    // Players 9, length 4 h, type Normal, pace Regular (20 min) — type and
    // pace are two separate questions, both on this first step.
    const players0 = await readPlayersCount(page);
    const players9 = await setPlayersCount(page, 9);
    console.log(`M1 step 2: players ${players0} → ${players9}`);
    if (players9 !== 9) throw new Error(`M1 step 2: players reads ${players9}, expected 9`);
    const hoursText = await setDurationHours(page, 4);
    console.log(`M1 step 2: duration reads ${hoursText}`);
    await expectText(page, 'Tournament type', 10_000);
    await expectText(page, 'Pace', 10_000);
    await expectText(page, 'Minutes per level', 10_000);
    await tap(page, 'Normal', { exact: true });
    await tap(page, '20 min', { exact: true });
    console.log('M1 step 2: Normal type + 20 min pace; both questions live in the first step');
    await screenshot(page, 'm1-02-inputs-configured');

    // ── Step 3 ───────────────────────────────────────────────────────────────
    // Ante Yes → a second choice appears (Big blind default, or Individual);
    // there is no "Recommended" button on the question.
    await expectText(page, 'Ante', 10_000);
    await expectText(page, 'Big blind', 10_000);
    await expectText(page, 'Individual', 10_000);
    await expectNoText(page, 'Recommended', 2_000);
    await tap(page, 'Individual', { exact: true });
    await tap(page, 'Big blind', { exact: true });
    console.log('M1 step 3: ante offers Big blind / Individual, no "Recommended"');
    await screenshot(page, 'm1-03-ante');

    // ── Step 4 ───────────────────────────────────────────────────────────────
    // Two names — Ali and Sara; the rest stay unnamed.
    await scrollUntilVisible(page, 'Add a name');
    await tap(page, 'Add a name', { exact: true });
    await typeInto(page, 'Player 1 name (e.g. Alex)', 'Ali', { lenient: true });
    await scrollUntilVisible(page, 'Add a name');
    await tap(page, 'Add a name', { exact: true });
    await typeInto(page, 'Player 2 name (e.g. Alex)', 'Sara', { lenient: true });
    // Flutter draws the field text and clears the a11y proxy input, so the
    // DOM read-back proves nothing — the screenshot carries the evidence, and
    // the live game is scanned for the names once the clock exists (step 13).
    const nameProbe = await page.evaluate(() =>
      Array.from(document.querySelectorAll('input[placeholder^="Player "]')).map((el) => {
        const parent = (el as HTMLElement).closest('flt-semantics, flt-semantics-container');
        return {
          value: (el as HTMLInputElement).value,
          parentText: (parent?.textContent ?? '').replace(/\s+/g, ' ').slice(0, 40),
        };
      }),
    );
    console.log(`M1 step 4: name-field probe = ${JSON.stringify(nameProbe)}`);
    await screenshot(page, 'm1-04-names');

    // ── Step 5 ───────────────────────────────────────────────────────────────
    // The stack step: ≈5,000 chips, about 100 BB at 25/50, a per-player split
    // that only uses chips the Home 25 case holds — and still no levels.
    await tap(page, 'Next: starting stack', { exact: true });
    await expectText(page, 'Starting stack', 20_000);
    const stack5k = await readStackChips(page);
    const depth5k = await readDepthLine(page);
    const plan5k = await readChipPlan(page);
    console.log(`M1 step 5: ${stack5k} chips · ${depth5k} · plan ${plan5k}`);
    if (stack5k === null || stack5k < 4_300 || stack5k > 5_700) {
      throw new Error(`M1 step 5: starting stack reads ${stack5k} (want 4,300–5,700)`);
    }
    if (!depth5k || !/^100 big blinds deep · opening 25\/50$/.test(depth5k)) {
      throw new Error(`M1 step 5: depth line reads "${depth5k}" (want 100 BB · opening 25/50)`);
    }
    if (!plan5k) throw new Error('M1 step 5: no per-player chip split on screen');
    const caseCounts = new Map(HOME_25.map((c) => [c.value, c.quantity]));
    for (const part of plan5k.split(' · ')) {
      const m = part.match(/^(\d+) × ([\d,]+)$/);
      if (!m) throw new Error(`M1 step 5: unparsed split part "${part}"`);
      const qty = Number(m[1]);
      const value = Number(m[2].replace(/,/g, ''));
      const have = caseCounts.get(value);
      if (have === undefined) {
        throw new Error(`M1 step 5: the split uses a ${value} chip the Home 25 case does not hold`);
      }
      if (qty > have) {
        throw new Error(`M1 step 5: the split wants ${qty} × ${value}, the case holds ${have}`);
      }
    }
    await expectNoText(page, 'minute levels', 3_000);
    console.log('M1 steps 5-6: stack ≈5,000 at 100 BB · opening 25/50 (SB < BB); still no levels listed');
    await screenshot(page, 'm1-05-stack');

    // ── Step 7 ───────────────────────────────────────────────────────────────
    // Stack 4,000 → the chips are dealt again, the depth drops to ≈80 BB.
    const after4k = await setStackField(page, 4000);
    const depth4k = await readDepthLine(page);
    const plan4k = await readChipPlan(page);
    console.log(`M1 step 7: ${after4k} chips · ${depth4k} · plan ${plan4k}`);
    if (after4k !== 4_000) throw new Error(`M1 step 7: stack reads ${after4k} after entering 4,000`);
    const depth4kBB = depth4k ? Number(depth4k.match(/^(\d+) big blinds/)?.[1]) : NaN;
    if (!(depth4kBB >= 76 && depth4kBB <= 84)) {
      throw new Error(`M1 step 7: depth reads "${depth4k}" (want ≈80 BB)`);
    }
    if (plan4k === plan5k) throw new Error('M1 step 7: the per-player split did not change with the stack');
    await screenshot(page, 'm1-07-stack-4000');

    // ── Step 8 ───────────────────────────────────────────────────────────────
    // Stack 40,000: the document expects a card naming the missing colour and
    // how many chips to add, and a blocked Continue. Record what is shown.
    await setStackField(page, 40000);
    await page.waitForTimeout(800);
    const text8 = (await appText(page)).replace(/\s+/g, ' ');
    const card8 =
      (await hasText(page, 'Your chip case is too small for this field')) ||
      (await hasText(page, 'Your chips fall short'));
    const shortLine8 = text8.match(/Your chips fall short[^.]*\./)?.[0] ?? null;
    const saysColour8 = /(short|missing|add|need|have)[^.]{0,90}(colour|color|25|100|500|1000|5000)/i.test(text8);
    const approve8 = await buttonState(page, 'Approve stack');
    console.log(`M1 step 8: caseCard=${card8} shortLine="${shortLine8}" colourLine=${saysColour8} approve=${approve8}`);
    if (!card8) console.log(`M1 FINDING step 8: no chip-case card at 40,000 chips. Screen: ${text8.slice(0, 320)}`);
    if (!saysColour8) console.log('M1 FINDING step 8: nothing names the missing colour and how many chips to add.');
    if (approve8 !== 'disabled') {
      console.log(`M1 FINDING step 8: "Approve stack" reads ${approve8} at 40,000 — the document says the night cannot continue until fixed.`);
    }
    await screenshot(page, 'm1-08-stack-40000');

    // ── Step 9 ───────────────────────────────────────────────────────────────
    // Back to ≈5,000 and approve: the level list opens; SB < BB everywhere, the
    // blinds always rise, and no step jumps by more than double.
    if (await hasText(page, 'Use the suggested stack')) {
      await tap(page, 'Use the suggested stack', { exact: true });
      await page.waitForTimeout(700);
    } else {
      await setStackField(page, 5000);
    }
    const back5k = await readStackChips(page);
    console.log(`M1 step 9: back to ${back5k} chips`);
    if (back5k === null || back5k < 4_300 || back5k > 5_700) {
      throw new Error(`M1 step 9: stack reads ${back5k} (want 4,300–5,700)`);
    }
    await tap(page, 'Approve stack', { exact: true });
    await expectText(page, 'minute levels', 20_000);
    const ladderA = await readLevels(page);
    checkLadder(ladderA, 'M1 step 9', { sb: 25, bb: 50 });
    console.log(`M1 step 9: ladder\n${ladderA.map((l) => `  L${l.n}: ${l.sb}/${l.bb} — ${l.text}`).join('\n')}`);
    await screenshot(page, 'm1-09-levels');

    // ── Step 10 ──────────────────────────────────────────────────────────────
    // Edit level 6: raise the BB, save — the row shows the new value with the
    // pin/calculator mark.
    const l5 = ladderA.find((l) => l.n === 5);
    const l6 = ladderA.find((l) => l.n === 6);
    if (!l5 || !l6) throw new Error('M1 step 10: levels 5 and 6 not parsed');
    let newBB = Math.min(Math.round((l6.bb * 1.5) / 25) * 25, Math.floor((2 * l5.bb) / 25) * 25);
    if (newBB <= l6.bb) newBB = l6.bb + 25;
    await scrollUntilVisible(page, 'Edit level 6');
    await tap(page, 'Edit level 6', { exact: true });
    await typeInto(page, 'BB', String(newBB));
    await tap(page, 'Save', { exact: true });
    await page.waitForTimeout(800);
    const ladderB = await readLevels(page);
    const l6b = ladderB.find((l) => l.n === 6);
    if (!l6b || l6b.bb !== newBB) {
      throw new Error(
        `M1 step 10: level 6 reads ${l6b?.bb}, expected ${newBB}. Screen: ${(await appText(page)).replace(/\s+/g, ' ').slice(0, 300)}`,
      );
    }
    await expectText(page, 'Pinned', 10_000);
    await expectText(page, 'Recalculate around this', 10_000);
    console.log(`M1 step 10: level 6 ${l6.sb}/${l6.bb} → ${l6b.sb}/${newBB}; pin mark shown`);
    await screenshot(page, 'm1-10-pinned-level-6');

    // ── Step 11 ──────────────────────────────────────────────────────────────
    // "Recalculate around this" on level 6: 1–5 stay the same, level 6 keeps
    // its value, and 7 and up move smoothly.
    await tap(page, 'Recalculate around this', { role: 'button' });
    await page.waitForTimeout(1_000);
    const ladderC = await readLevels(page);
    for (const n of [1, 2, 3, 4, 5]) {
      const a = ladderB.find((l) => l.n === n);
      const c = ladderC.find((l) => l.n === n);
      if (!a || !c || a.sb !== c.sb || a.bb !== c.bb) {
        throw new Error(`M1 step 11: level ${n} moved ${a?.sb}/${a?.bb} → ${c?.sb}/${c?.bb}`);
      }
    }
    const l6c = ladderC.find((l) => l.n === 6);
    if (!l6c || l6c.bb !== newBB) throw new Error('M1 step 11: level 6 lost its pinned value');
    const aboveChanged = ladderC
      .filter((l) => l.n > 6)
      .some((l) => {
        const b = ladderB.find((x) => x.n === l.n);
        return !b || b.sb !== l.sb || b.bb !== l.bb;
      });
    if (!aboveChanged) throw new Error('M1 step 11: nothing above level 6 changed after the recalculation');
    checkLadder(ladderC, 'M1 step 11');
    console.log(`M1 step 11: recalculated\n${ladderC.map((l) => `  L${l.n}: ${l.sb}/${l.bb}`).join('\n')}`);
    await screenshot(page, 'm1-11-recalculated');

    // ── Step 12 ──────────────────────────────────────────────────────────────
    // Round trip to the stack step and back: the ≈5,000 stack and the pinned
    // level 6 are both still there.
    await tap(page, 'Change stack', { exact: true });
    await expectText(page, 'Starting stack', 15_000);
    const still5k = await readStackChips(page);
    if (still5k === null || still5k < 4_300 || still5k > 5_700) {
      throw new Error(`M1 step 12: stack reads ${still5k} (want 4,300–5,700)`);
    }
    await tap(page, 'Approve stack', { exact: true });
    await expectText(page, 'minute levels', 15_000);
    const ladderD = await readLevels(page);
    if (JSON.stringify(ladderD) !== JSON.stringify(ladderC)) {
      throw new Error('M1 step 12: the ladder changed on the round trip');
    }
    await expectText(page, 'Pinned', 5_000);
    console.log('M1 step 12: the stack and the pinned level 6 survived the round trip');
    await screenshot(page, 'm1-12-round-trip');

    // ── Step 13 ──────────────────────────────────────────────────────────────
    // Confirm and start: the clock runs on level 1 at 25/50. Before starting,
    // stub the Web Speech API so the app's spoken announcements are captured
    // (flutter_tts speaks through window.speechSynthesis on the web — this is
    // the machine proxy for the document's "the voice says …" expectations).
    await page.evaluate(() => {
      const w = window as unknown as { __spoken?: string[]; __speakStubbed?: boolean; speechSynthesis?: SpeechSynthesis };
      w.__spoken = w.__spoken ?? [];
      try {
        const synth = w.speechSynthesis;
        if (synth && !w.__speakStubbed) {
          w.__speakStubbed = true;
          const orig = synth.speak.bind(synth);
          synth.speak = (u: SpeechSynthesisUtterance) => {
            try {
              w.__spoken!.push(String(u?.text ?? ''));
            } catch {
              /* capture only */
            }
            try {
              orig(u);
            } catch {
              /* keep the app's await chain alive */
            }
          };
        }
      } catch {
        /* no speechSynthesis in this context */
      }
    });
    await tap(page, 'Start the clock', { exact: false });
    for (let i = 0; i < 10; i++) {
      if (await hasText(page, 'End it and start')) {
        await tap(page, 'End it and start', { exact: false });
        await page.waitForTimeout(1_200);
        break;
      }
      await page.waitForTimeout(700);
    }
    // The host lands on the join-code hand-off ("Players and the TV. No
    // account, no app.") whose "Open the clock" button opens the live view.
    for (let i = 0; i < 10; i++) {
      if (await hasText(page, 'Open the clock')) {
        await tap(page, 'Open the clock', { exact: false });
        break;
      }
      if (await hasText(page, 'Level 1')) break;
      await page.waitForTimeout(700);
    }
    let clockSeen = false;
    const deadline = Date.now() + 150_000;
    while (Date.now() < deadline) {
      if (await hasText(page, 'Level 1')) {
        clockSeen = true;
        break;
      }
      await page.waitForTimeout(1_500);
    }
    if (clockSeen) {
      await expectText(page, '25 / 50', 15_000);
      const t1 = (await readTextMatch(page, /\b\d{1,2}:\d{2}\b/)) ?? '';
      await page.waitForTimeout(6_000);
      const t2 = (await readTextMatch(page, /\b\d{1,2}:\d{2}\b/)) ?? '';
      console.log(`M1 step 13: clock on level 1 (25/50); timer ${t1} → ${t2}`);
      if (!t1 || !t2 || !(secs(t2) < secs(t1))) {
        throw new Error(`M1 step 13: the timer is not running (${t1} → ${t2})`);
      }
      const spoken: string[] = await page.evaluate(
        () => (window as unknown as { __spoken?: string[] }).__spoken ?? [],
      );
      console.log(`M1 step 13 voice capture: ${JSON.stringify(spoken)}`);
      if (!spoken.some((s) => /Level 1|small blind/i.test(s))) {
        console.log('M1 FINDING step 13: no spoken level announcement was captured');
      }
      const clockText = await appText(page);
      console.log(
        `M1 step 13: step-4 names visible on the live screen = ${JSON.stringify(
          ['Ali', 'Sara'].filter((n) => clockText.includes(n)),
        )}`,
      );
      await screenshot(page, 'm1-13-clock-running');
    } else {
      console.log(
        `M1 FINDING step 13: the live clock did not open after Start the clock. Screen: ${(await appText(page)).replace(/\s+/g, ' ').slice(0, 300)}`,
      );
      await screenshot(page, 'm1-13-no-clock');
    }

    // Liveness, from a fresh boot on Home: the LIVE badge (the game is live).
    await goto(page, '/home');
    await expectText(page, 'LIVE', 90_000);
    console.log('M1 step 13: the game is live on Home (LIVE badge)');
    await screenshot(page, 'm1-home-live');
  } finally {
    await app.close();
  }
});
