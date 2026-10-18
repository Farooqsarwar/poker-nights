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
 * DECISION: more than one group can be named "Test Club" (the setup used to
 * create a duplicate on every rerun), so selection matters: the smallest-title
 * rule that tap() uses lands on the FIRST "Test Club" entry in the sheet — the
 * club with two members (A and B), whose invite code is kept in
 * .auth/state.json. Verified twice by probe as deterministic.
 */
export async function selectTestClub(page: Page): Promise<void> {
  if (await hasText(page, 'Switch group, Test Club')) return;
  await tap(page, 'Switch group', { exact: false });
  await page.waitForTimeout(1_000);
  await tap(page, 'Test Club', { exact: false });
  await expectText(page, 'Switch group, Test Club', 30_000);
}
