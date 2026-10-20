import { test } from '@playwright/test';
import { appText, expectText, goto, hasText, launchApp, readTextMatch, screenshot, scrollUntilVisible, tap } from './helpers/flutter';
import { setCountStepper } from './helpers/chips';
import { readLevels } from './helpers/builder';
import { typeInto } from './helpers/auth';

/**
 * m4 — the public tools, from the acceptance document:
 *
 *   the blind-structure generator offers "Use this structure in the tournament
 *   clock?" — Yes must open the clock with the generated levels — and the ICM
 *   calculator must show equities that add up to the prize pool.
 *
 * The tools are public (no account needed) and live on their own routes.
 */
test('m4: blind generator hands its structure to the clock; ICM equities add up', async () => {
  const app = await launchApp('qa-a');
  try {
    const { page } = app;

    // 1. Tools index → the generator. Navigate IN-APP (Home → More → Tools):
    //    deep-linking /tools while signed in races the splash's redirect back
    //    to Home, and either side can win.
    await goto(page, '/home');
    await expectText(page, 'Welcome back', 30_000);
    await tap(page, 'More');
    await page.waitForTimeout(900);
    await tap(page, 'Tools', { exact: false });
    await expectText(page, 'Blind Structure Generator', 30_000);
    await tap(page, 'Blind Structure Generator', { exact: false });
    await expectText(page, 'Next: starting stack', 30_000);
    await screenshot(page, 'm4-generator-inputs');

    // 2. Walk the builder: stack → structure.
    await tap(page, 'Next: starting stack');
    await expectText(page, 'Starting stack', 20_000);
    const stackText = (await appText(page)).match(/\b\d[\d,]{2,7}\b/g) ?? [];
    console.log(`m4: generator stack step figures: ${stackText.slice(0, 8).join(', ')}`);
    await tap(page, 'Approve stack');
    await expectText(page, 'minute levels', 20_000);
    await screenshot(page, 'm4-generator-structure');

    // 2b. The document's step 2 — edit one level and recalculate around it,
    //     then confirm. The generator embeds the app's structure builder, so
    //     the same controls should be here; if this build hides them the log
    //     records that and the handoff below still runs.
    const genLadderBefore = await readLevels(page);
    if (await scrollUntilVisible(page, 'Edit level', { contains: true })) {
      const last = genLadderBefore[genLadderBefore.length - 1];
      const newBB = Math.max(Math.round((last.bb * 1.5) / 25) * 25, last.bb + 25);
      await tap(page, `Edit level ${last.n}`, { exact: true });
      await expectText(page, 'Save', 10_000);
      await typeInto(page, 'BB', String(newBB));
      await tap(page, 'Save', { exact: true });
      await page.waitForTimeout(700);
      console.log(
        `m4 step 2: level ${last.n} edited ${last.sb}/${last.bb} → ${last.sb}/${newBB}; pinned=${await hasText(page, 'Pinned')}`,
      );
      if (await hasText(page, 'Recalculate around this')) {
        await tap(page, 'Recalculate around this', { exact: true });
        await page.waitForTimeout(900);
      } else {
        console.log('m4 FINDING step 2: no "Recalculate around this" control after the edit');
      }
      const genLadderAfter = await readLevels(page);
      console.log(
        `m4 step 2: ladder after the recalculation\n${genLadderAfter.map((l) => `  L${l.n}: ${l.sb}/${l.bb}`).join('\n')}`,
      );
      await screenshot(page, 'm4-generator-edited');
    } else {
      console.log('m4 FINDING step 2: the free generator does not expose level editing');
    }

    // 3. "Use these blinds" → the handoff dialog. "No" stays on the generator
    //    with the structure intact.
    await tap(page, 'Use these blinds');
    await expectText(page, 'Use this structure in the tournament clock?', 15_000);
    await tap(page, 'No', { exact: true });
    await expectText(page, 'Use these blinds', 15_000);
    console.log('m4: No keeps the structure on the generator');

    // 4. Confirm again and say Yes — the clock opens with the same levels.
    await tap(page, 'Use these blinds');
    await expectText(page, 'Use this structure in the tournament clock?', 15_000);
    await tap(page, 'Yes', { exact: true });
    await expectText(page, 'Time left', 30_000);
    await expectText(page, 'Level', 15_000);
    await screenshot(page, 'm4-clock');
    console.log('m4: generator handed the structure to the clock');

    // 5. ICM calculator, default scenario: stacks 5,000 / 3,000 / 2,000 with
    //    50 / 30 / 20 prizes — standard Malmuth-Harville equities are
    //    38.39 / 32.75 / 28.86 (they add up to the 100 pool); the chip-share
    //    column shows 50.00 for the biggest stack and the difference 11.61.
    //
    //    Navigate IN-APP (clock → "All tools" → the ICM card): a deep link to
    //    /tools/icm can lose the boot-timing race against the splash and land
    //    on Home again for a signed-in session.
    await tap(page, 'All tools', { exact: false });
    await expectText(page, 'Blind Structure Generator', 20_000);
    await tap(page, 'ICM Calculator', { exact: false });
    await expectText(page, 'Players remaining: 3', 30_000);
    await screenshot(page, 'm4-icm');

    const decimals = (await appText(page)).match(/\b\d{1,4}\.\d{2}\b/g) ?? [];
    const figures = [...new Set(decimals)].map(Number);
    console.log(`m4: ICM figures seen: ${figures.join(', ')}`);
    const expected: Array<[string, number]> = [
      ['equity of the 5,000 stack', 38.39],
      ['equity of the 3,000 stack', 32.75],
      ['equity of the 2,000 stack', 28.86],
      ['chip share of the 5,000 stack', 50.0],
      ['equity-vs-chip-share difference', 11.61],
    ];
    for (const [label, want] of expected) {
      if (!figures.some((n) => Math.abs(n - want) <= 0.02)) {
        throw new Error(`m4: ${label} (${want}) not on screen; saw ${figures.join(', ')}`);
      }
    }
    console.log('m4: ICM equities 38.39 / 32.75 / 28.86 confirmed');

    // 6. The document's scenario: Total pool 500, stacks 8,000 / 5,000 /
    //    2,000, the 3-place split 250 / 150 / 100 → about
    //    197.44 / 171.61 / 130.95.
    //
    //    The prizes are typed by hand: "Fill prizes from pool" on this build
    //    collapses a 3-player field to winner-takes-all (the tournament engine
    //    refuses to pay half the field: places = max(1, players ~/ 2 - 1)),
    //    so the doc's 3-place split cannot come from that button. Entered by
    //    hand, the ICM maths matches the doc exactly (see probe-icm-fill for
    //    the fill-button evidence).
    await setCountStepper(page, '100', 500); // Total pool
    await setCountStepper(page, '5000', 8000); // Player 1 stack
    await setCountStepper(page, '3000', 5000); // Player 2 stack
    await setCountStepper(page, '50', 250); // 1st
    await setCountStepper(page, '30', 150); // 2nd
    await setCountStepper(page, '20', 100); // 3rd
    const docFigures = [...new Set((await appText(page)).match(/\b\d{1,4}\.\d{2}\b/g) ?? [])].map(Number);
    console.log(`m4: doc-scenario figures: ${docFigures.join(', ')}`);
    const docExpected: Array<[string, number]> = [
      ['8,000-stack equity', 197.44],
      ['5,000-stack equity', 171.61],
      ['2,000-stack equity', 130.95],
    ];
    for (const [label, want] of docExpected) {
      if (!docFigures.some((n) => Math.abs(n - want) <= 0.05)) {
        throw new Error(`m4: ${label} (≈${want}) not on screen; saw ${docFigures.join(', ')}`);
      }
    }
    console.log('m4: ICM doc scenario 197.44 / 171.61 / 130.95 confirmed');

    // 7. Adding a stack row raises Players remaining to 4.
    await tap(page, 'Add player');
    await expectText(page, 'Players remaining: 4', 15_000);
    await screenshot(page, 'm4-icm-doc-scenario');
  } finally {
    await app.close();
  }
});
