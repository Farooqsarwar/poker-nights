import type { Page } from '@playwright/test';
import { expectText, goto, hasText, tap } from './flutter';

/**
 * In-app navigation for signed-in screens.
 *
 * Deep-linking a browser URL straight to a pushed screen (e.g. /chip-sets)
 * loses a boot-timing race against the splash screen, which navigates to Home
 * on completion — so the automation walks through the app the same way a
 * person does: Home → bottom-nav "More" → Settings, and so on. This is also
 * what the acceptance document describes ("From Home, tap …").
 */

/** Lands on the signed-in Home screen (reliable deep link — splash agrees). */
export async function openHome(page: Page): Promise<void> {
  await goto(page, '/home');
  await expectText(page, 'Welcome back', 30_000);
}

/** Home → "More" (bottom nav) → Settings. */
export async function openSettings(page: Page): Promise<void> {
  await openHome(page);
  await tap(page, 'More');
  await page.waitForTimeout(900);
  await tap(page, 'Settings', { exact: false });
  await expectText(page, 'Account and group preferences', 30_000);
}

/**
 * The current screen's back control → Home, *without* reloading the page.
 *
 * The app persists presets to Firestore without awaiting the write, so a
 * reload straight after a save can read a state from before the write landed;
 * back-navigation keeps the app's in-memory truth. Screens built on PageHeader
 * label the control "Back"; AppBackButton-only screens ("Game presets") fall
 * back to its default "Go back". `tap` scrolls the page until the control is
 * actually on screen first — the header scrolls away with the content, so a
 * raw DOM click can land on empty canvas.
 */
export async function goHomeInApp(page: Page): Promise<void> {
  let failure = '';
  for (const label of ['Back', 'Go back']) {
    try {
      await tap(page, label, { exact: true, timeout: 10_000 });
    } catch (e) {
      failure = e instanceof Error ? e.message : String(e);
      continue;
    }
    for (let i = 0; i < 25; i++) {
      if (await hasText(page, 'Welcome back')) return;
      await page.waitForTimeout(400);
    }
    failure = `"${label}" did not lead to Home`;
  }
  throw new Error(`goHomeInApp: no usable back control (${failure.slice(0, 160)})`);
}

/** Settings → Chip sets (verified by its "+ New" action). */
export async function openChipSets(page: Page): Promise<void> {
  await openSettings(page);
  await tap(page, 'Chip sets', { exact: false });
  await expectText(page, '+ New', 30_000);
}

/**
 * Switches the current group to the canonical "Test Club" via the
 * current-group chip's switcher sheet.
 *
 * DECISION: the setup used to create a duplicate on every rerun, so several
 * groups are named "Test Club" — the chip's name alone cannot tell them apart,
 * and trusting it once mis-posted a group event into a one-member duplicate.
 * The canonical club is the only two-member one (QA Host + QA Player): the
 * switcher sheet lists it as "Test Club 2 members" while the rest read
 * "Test Club 1 member". The sheet is opened every time; the tile decides.
 */
export async function selectTestClub(page: Page): Promise<void> {
  if (!(await hasText(page, 'Switch group'))) await openHome(page);
  await tap(page, 'Switch group', { exact: false });
  await page.waitForTimeout(1_000);
  try {
    await tap(page, 'Test Club 2 members', { exact: false, timeout: 10_000 });
  } catch {
    // No shared club visible (fresh state): the first Test Club will do.
    await tap(page, 'Test Club', { exact: false });
  }
  await expectText(page, 'Switch group, Test Club', 30_000);
  if (!(await hasText(page, 'Welcome back'))) {
    await tap(page, 'Home', { exact: true, timeout: 10_000 });
    await expectText(page, 'Welcome back', 30_000);
  }
}

/** Opens the switcher sheet and taps the tile whose text contains `name`. */
export async function selectGroup(page: Page, name: string): Promise<void> {
  if (!(await hasText(page, 'Switch group'))) await openHome(page);
  await tap(page, 'Switch group', { exact: false });
  await page.waitForTimeout(1_000);
  await tap(page, name, { exact: false });
  await expectText(page, `Switch group, ${name}`, 30_000);
}
