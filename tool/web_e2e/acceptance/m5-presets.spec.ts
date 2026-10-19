import { test, type Page } from '@playwright/test';
import {
  expectText,
  hasText,
  launchApp,
  screenshot,
  scrollUntilVisible,
  tap,
} from './helpers/flutter';
import { ensureAccount } from './helpers/auth';
import { goHomeInApp, openHome, openSettings } from './helpers/nav';
import { readDurationHours, setDurationHours } from './helpers/builder';
import { typeIntoFieldNearLabel } from './helpers/fields';
import { savePresetDialog } from './helpers/save_preset';
import {
  STARTER_PRESETS,
  deletePreset,
  ensureNoUserPresets,
  openPresets,
  presetCard,
  presetCards,
  scrollToCard,
  tapCardAction,
  usedPresetCount,
} from './helpers/presets';

/**
 * M5 — game presets, from the acceptance document:
 *
 *   5. Finish a builder and tap "Save as preset" — name it "Friday deep" and
 *      tick "Make default".
 *   6. Settings → Game presets: "Friday deep" is listed, marked default; the
 *      built-in starters are there and cannot be deleted.
 *   7. Opening it holds buy-in, type, pace, format, rebuys, add-on, ante,
 *      bonus, payouts, table size, stack and the chip set.
 *   8. Change buy-in to 30 and save.
 *   9. A new quick game starts from it (buy-in 30, its chip set).
 *  11. Delete "Friday deep" — the next game falls back to the starter default
 *      and keeps the saved default chip case.
 *
 * Machine proxies (noted in the report):
 *   - Step 5 runs the quick builder; its Buy-in lives in the collapsed "More
 *     options" tile. The preset is saved with the builder's chip case (Home
 *     25) and a duration of 4h — the value step 9 reads back (the starter
 *     default is 3h / buy-in 20).
 *   - Step 6's "cannot be deleted" is behavioural: tapping a built-in card's
 *     Delete must open no confirmation dialog (the app renders that Delete
 *     with onPressed: null).
 *   - Step 7's "Opening it holds …" is read off the card's own semantics
 *     label, which spells out every stored choice (buy-in, duration, format,
 *     pace, depth, rebuys, add-on, KO, ante, organiser costs, chip case) —
 *     plus the edit form's Buy-in field.
 *   - Navigation stays in-app (Back / drawer): the app writes presets to
 *     Firestore without awaiting, so a reload straight after a save can read
 *     a state from before the write landed.
 *
 * M5 steps 1–4 (the chip editor) run in m5-chip-editor.spec.ts; step 10 (the
 * Free allowance) is the second test here.
 */
test('M5: save "Friday deep" as default, edit it, start from it, delete it', async () => {
  test.setTimeout(30 * 60_000);
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');

    // Start from an empty library: the Free allowance counts "your own"
    // presets, and a leftover from an earlier run would make this test's save
    // (and step 10's refusal) read the wrong state.
    await openPresets(page);
    const cleaned = await ensureNoUserPresets(page);
    console.log(`M5 start: library cleaned (${cleaned} leftover preset(s)), used=${await usedPresetCount(page)}/3`);
    await goHomeInApp(page);

    // ── 5. Builder → Save as preset (name it, tick "Make default") ─────────
    await startQuickGame(page);
    const duration = await setDurationHours(page, 4);
    console.log(
      `M5 step 5: "How long" reads ${duration} (the starter default is 3h — the value step 9 must read back)`,
    );
    if (!(await scrollUntilVisible(page, 'Save as preset'))) {
      throw new Error('M5 step 5: no "Save as preset" button in the quick builder');
    }
    await tap(page, 'Save as preset', { exact: true, timeout: 10_000 });
    const outcome = await savePresetDialog(page, 'Friday deep', { makeDefault: true });
    if (outcome !== 'saved') {
      throw new Error(`M5 step 5: the app did not save "Friday deep" (outcome ${outcome})`);
    }
    console.log('M5 step 5: "Friday deep" saved with "Use as my default" ticked');
    await screenshot(page, 'm5-preset-saved');

    // ── 6–7. The library lists it, marked default, its choices held ────────
    await goHomeInApp(page);
    await openPresets(page);
    const card = await scrollToCard(page, 'Friday deep');
    if (!card) {
      throw new Error('M5 step 6: "Friday deep" is not in the Game presets library');
    }
    console.log(`M5 step 6: "Friday deep" is listed — default=${card.isDefault}`);
    if (!card.isDefault) {
      throw new Error('M5 step 6: "Friday deep" should be the default preset ("Use as my default" was ticked)');
    }
    for (const tag of [
      'BUY-IN 20',
      '4H',
      'FREEZE OUT',
      'REGULAR PACE',
      '100 BB DEEP',
      'NO REBUYS',
      'NO ADD-ON',
      'ANTE L6+',
      'HOME 25',
    ]) {
      if (!card.label.includes(tag)) {
        throw new Error(`M5 step 7: the card does not hold "${tag}" — it reads: ${card.label}`);
      }
    }
    console.log("M5 step 7: the card holds the builder's choices (buy-in 20 · 4h · freeze-out · regular pace · 100 BB · no rebuys/add-on · ante L6+ · Home 25 chips)");
    await screenshot(page, 'm5-presets-list');

    // Built-in starters: present, and their Delete is inert.
    for (const starter of STARTER_PRESETS) {
      if (!(await scrollToCard(page, starter))) {
        throw new Error(`M5 step 6: the built-in "${starter}" is missing from the library`);
      }
    }
    const guard = await deletePreset(page, 'Classic Freezeout', { confirm: false });
    console.log(
      `M5 step 6: built-in "Classic Freezeout" Delete → ${guard.outcome}` +
        `${guard.dialogText ? ` ("${guard.dialogText}")` : ''}; still listed=${Boolean(await presetCard(page, 'Classic Freezeout'))}`,
    );
    if (guard.outcome === 'cancelled') {
      throw new Error(
        `M5 FINDING step 6: a built-in starter opened the delete dialog ("${guard.dialogText ?? ''}") — the document says built-ins cannot be deleted`,
      );
    }
    if (!(await presetCard(page, 'Classic Freezeout'))) {
      throw new Error('M5 step 6: the built-in starter vanished after tapping its Delete control');
    }
    console.log('M5 step 6: the built-in starters are listed, and their Delete control does nothing');

    // ── 8. Edit it: buy-in 30 ─────────────────────────────────────────────
    let edited = await editPresetBuyIn(page, 'Friday deep', 30);
    if (!edited) {
      console.log('M5 step 8: the first Buy-in edit did not reach the card — retrying once');
      await page.keyboard.press('Escape');
      await page.waitForTimeout(700);
      edited = await editPresetBuyIn(page, 'Friday deep', 30);
    }
    if (!edited) {
      throw new Error('M5 step 8: editing "Friday deep" to buy-in 30 did not stick on the card');
    }
    console.log('M5 step 8: buy-in changed to 30 — the card reads BUY-IN 30');

    // ── 9. A new quick game starts from the default preset ────────────────
    await goHomeInApp(page);
    await startQuickGame(page);
    const seededDuration = await readDurationHours(page);
    const seededBuyIn = await readBuilderBuyIn(page);
    await scrollUntilVisible(page, 'Home 25', { contains: true });
    const chipsHeld = await hasText(page, 'Home 25');
    console.log(
      `M5 step 9: a new quick game reads duration=${seededDuration ?? 'unreadable'}, ` +
        `buy-in=${seededBuyIn ?? 'unreadable'}, chips=${chipsHeld ? 'Home 25' : '?'}`,
    );
    if (seededDuration !== '4h') {
      throw new Error(
        `M5 step 9: a new quick game should start from "Friday deep" (4h) but the builder reads "${seededDuration}"`,
      );
    }
    if (seededBuyIn !== null && seededBuyIn !== '30') {
      throw new Error(`M5 step 9: the new game should carry the edited buy-in 30 but its field reads "${seededBuyIn}"`);
    }
    if (seededBuyIn === null) {
      console.log('M5 step 9: the Buy-in field could not be read — the seeding proof is the 4h duration + Home 25');
    }
    if (!chipsHeld) {
      throw new Error("M5 step 9: the new game did not pick up the preset's chip set (Home 25)");
    }
    console.log('M5 step 9: the new quick game starts from "Friday deep"');

    // ── 11. Delete it; fall back; the chip case is kept ───────────────────
    await goHomeInApp(page);
    await openPresets(page);
    if (!(await scrollToCard(page, 'Friday deep'))) {
      throw new Error('M5 step 11: "Friday deep" disappeared before the delete step');
    }
    const removed = await deletePreset(page, 'Friday deep');
    if (removed.outcome !== 'deleted') {
      throw new Error(`M5 step 11: deleting "Friday deep" failed (${removed.outcome})`);
    }
    console.log(`M5 step 11: preset deleted — used=${await usedPresetCount(page)}/3`);
    await screenshot(page, 'm5-preset-deleted');

    await goHomeInApp(page);
    await startQuickGame(page);
    const fallbackDuration = await readDurationHours(page);
    const fallbackBuyIn = await readBuilderBuyIn(page);
    await scrollUntilVisible(page, 'Home 25', { contains: true });
    console.log(
      `M5 step 11: after the delete a new game reads duration=${fallbackDuration ?? 'unreadable'}, ` +
        `buy-in=${fallbackBuyIn ?? 'unreadable'}`,
    );
    if (fallbackDuration === '4h') {
      throw new Error('M5 step 11: the deleted preset still seeds new games (duration 4h)');
    }
    if (fallbackBuyIn === '30') {
      throw new Error('M5 step 11: the deleted preset still seeds new games (buy-in 30)');
    }
    if (!(await hasText(page, 'Home 25'))) {
      throw new Error('M5 step 11: the saved default chip case (Home 25) did not survive the delete');
    }
    console.log(
      `M5 step 11: the next game falls back to the starter default (${fallbackDuration ?? '?'}) and keeps Home 25`,
    );

    await openSettings(page);
    if (!(await hasText(page, 'HOME 25'))) {
      throw new Error('M5 step 11: Settings should still show the "Home 25" chip case as the default');
    }
    console.log('M5 step 11: Settings still shows HOME 25 as the default chip case');

    // Leave the library as we found it.
    await openPresets(page);
    await ensureNoUserPresets(page);
  } finally {
    await app.close();
  }
});

/**
 * M5 step 10 — the Free allowance, from the acceptance document:
 *
 *   "Create 3 more of your own presets. The 3rd saves, and the 4th asks you
 *    to upgrade (3 of your own on Free). Editing an existing preset doesn't
 *    count as a new one."
 *
 * Account A is a free account on this build, so the gate is live (the app
 * refuses inside the save dialog: "Free accounts can save up to 3 presets.").
 */
test('M5 step 10: three of your own on Free, the 4th refused, edits not counted', async () => {
  test.setTimeout(30 * 60_000);
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await openPresets(page);
    const cleaned = await ensureNoUserPresets(page);
    console.log(`M5 step 10 start: library cleaned (${cleaned} leftover preset(s)), used=${await usedPresetCount(page)}/3`);

    // ── The 3rd saves ─────────────────────────────────────────────────────
    for (const [index, name] of ['QA preset 1', 'QA preset 2', 'QA preset 3'].entries()) {
      await goHomeInApp(page);
      await startQuickGame(page);
      if (!(await scrollUntilVisible(page, 'Save as preset'))) {
        throw new Error(`M5 step 10: no "Save as preset" button while creating "${name}"`);
      }
      await tap(page, 'Save as preset', { exact: true, timeout: 10_000 });
      const outcome = await savePresetDialog(page, name);
      if (outcome !== 'saved') {
        throw new Error(`M5 step 10: "${name}" was not saved (outcome ${outcome})`);
      }
      await goHomeInApp(page);
      await openPresets(page);
      if (!(await scrollToCard(page, name))) {
        throw new Error(`M5 step 10: "${name}" was not saved (not in the library)`);
      }
      const used = await usedPresetCount(page);
      console.log(`M5 step 10: "${name}" saved — used=${used}/3`);
      if (used !== index + 1) {
        throw new Error(`M5 step 10: the library says ${used}/3 after ${index + 1} saved preset(s)`);
      }
    }
    await screenshot(page, 'm5-step10-three-saved');

    // ── The 4th is refused, naming the Free allowance ──────────────────────
    await goHomeInApp(page);
    await startQuickGame(page);
    if (!(await scrollUntilVisible(page, 'Save as preset'))) {
      throw new Error('M5 step 10: no "Save as preset" button for the 4th attempt');
    }
    await tap(page, 'Save as preset', { exact: true, timeout: 10_000 });
    const fourth = await savePresetDialog(page, 'QA preset 4');
    console.log(`M5 step 10: the 4th save outcome=${fourth}`);
    if (fourth !== 'refused') {
      throw new Error(`M5 FINDING step 10: the 4th save was not refused (outcome ${fourth})`);
    }
    console.log('M5 step 10: the 4th save is refused in-dialog: "Free accounts can save up to 3 presets." (a limit sentence, not an upgrade button — noted)');
    await screenshot(page, 'm5-step10-4th-refused');

    // Close the refused dialog (Escape, else its Close button — nothing saved).
    await page.keyboard.press('Escape');
    await page.waitForTimeout(600);
    if (await hasText(page, 'Preset name')) {
      await tap(page, 'Close Save as preset', { exact: false, timeout: 8_000 });
      await page.waitForTimeout(600);
    }
    if (await hasText(page, 'Preset name')) {
      await openHome(page); // last resort: a reload drops the dialog
    } else {
      await goHomeInApp(page);
    }
    await openPresets(page);
    const created = (await presetCards(page)).find((c) => c.name === 'QA preset 4');
    console.log(`M5 step 10: "QA preset 4" created=${Boolean(created)}; used=${await usedPresetCount(page)}/3`);
    if (created) {
      throw new Error('M5 step 10: the refused save still created "QA preset 4"');
    }

    // ── Editing an existing preset doesn't count as a new one ──────────────
    const edited = await editPresetBuyIn(page, 'QA preset 1', 31);
    console.log(`M5 step 10: editing "QA preset 1" saved while at the limit=${edited}`);
    if (!edited) {
      throw new Error('M5 step 10: editing an existing preset at the limit should not count as a new one');
    }
    const afterEdit = await usedPresetCount(page);
    console.log(`M5 step 10: after the edit used=${afterEdit}/3 (an edit must not consume a slot)`);
    if (afterEdit !== 3) {
      throw new Error(`M5 step 10: an edit consumed a new slot (used ${afterEdit}/3)`);
    }
    await screenshot(page, 'm5-step10-edit-not-counted');

    // ── Cleanup: delete the three ──────────────────────────────────────────
    const removed = await ensureNoUserPresets(page);
    console.log(`M5 step 10: cleaned up ${removed} test preset(s); used=${await usedPresetCount(page)}/3`);
  } finally {
    await app.close();
  }
});

/** Home → "Start a game now" → the builder's inputs step. */
async function startQuickGame(page: Page): Promise<void> {
  await tap(page, 'Start a game now', { exact: false, timeout: 40_000 });
  await expectText(page, 'Next: starting stack', 30_000);
}

/**
 * Opens a preset's edit form, types `value` into its Buy-in field and saves.
 * Returns whether the card shows `BUY-IN <value>` afterwards. The Buy-in is a
 * label-only AppTextField, addressed by the label node above it (helpers/fields).
 */
async function editPresetBuyIn(page: Page, name: string, value: number): Promise<boolean> {
  if (!(await hasText(page, 'Preset name'))) {
    if (!(await scrollToCard(page, name))) return false;
    if (!(await tapCardAction(page, name, 'Edit'))) return false;
    await expectText(page, 'Preset name', 15_000);
    await page.waitForTimeout(700);
  }
  const typed = await typeIntoFieldNearLabel(page, 'Buy-in', String(value));
  console.log(`M5: the edit form's Buy-in reads "${typed}" after typing ${value}`);
  await tap(page, 'Save preset', { exact: true, timeout: 8_000 });
  for (let i = 0; i < 15; i++) {
    const card = await presetCard(page, name);
    if (card?.label.includes(`BUY-IN ${value}`)) return true;
    await page.waitForTimeout(400);
  }
  return false;
}

/**
 * Opens the collapsed "More options" tile and reads the Buy-in field it
 * reveals. The field is addressed by its own aria-label (Flutter puts
 * `InputDecoration.labelText` on the input); the proxy input reads empty until
 * it takes focus, so focus (or click) first.
 */
async function readBuilderBuyIn(page: Page): Promise<string | null> {
  await scrollUntilVisible(page, 'More options');
  await tap(page, 'More options', { exact: false, timeout: 10_000 });
  await page.waitForTimeout(900);
  const input = page.locator('input[aria-label="Buy-in"], textarea[aria-label="Buy-in"]').first();
  if ((await input.count()) === 0) {
    console.log('M5: "More options" did not reveal a Buy-in field');
    return null;
  }
  await input.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
  await page.waitForTimeout(300);
  let value = (await input.inputValue({ timeout: 3_000 }).catch(() => '')).trim();
  if (value === '') {
    const box = await input.boundingBox();
    if (box) {
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
      await page.waitForTimeout(350);
      value = (await input.inputValue({ timeout: 3_000 }).catch(() => '')).trim();
    }
  }
  return value;
}
