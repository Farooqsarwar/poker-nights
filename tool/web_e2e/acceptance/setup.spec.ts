import { test, type Page } from '@playwright/test';
import { appText, expectText, goto, hasText, launchApp, screenshot, tap } from './helpers/flutter';
import { ensureAccount, loadState, resetProfileDir, saveState, typeInto, type AccountId } from './helpers/auth';
import { ensureChipSet, HOME_25, SMALL_BOX } from './helpers/chips';
import { openSettings } from './helpers/nav';

/**
 * One-time (idempotent) setup for the acceptance suite, mirroring the manual
 * test document's "Setup (once, before testing)" section:
 *
 *   Account A (host)  — a fresh QA account on production Firebase
 *   Account B (player) — a second QA account
 *   Group "Test Club"  — created by A, joined by B via its invite link
 *   Group "Office League" — A's second group (needed by case m2)
 *   Chip sets "Home 25" and "Small box" — exact chips from the document
 *   Currency — None
 *
 * Every step checks first and only creates what is missing, so reruns are
 * safe. Credentials are stored in .auth/accounts.json (gitignored) and the
 * signed-in session lives in the per-account browser profiles under .auth/.
 *
 * Run:   npm run setup
 * Fresh: $env:E2E_FRESH='1'; npm run setup   (new accounts, clean profiles)
 */

test.describe.configure({ mode: 'serial' });

const FRESH = process.env.E2E_FRESH === '1';

async function launchFor(id: AccountId) {
  const profile = id === 'A' ? 'qa-a' : 'qa-b';
  if (FRESH) resetProfileDir(profile);
  const app = await launchApp(profile);
  const { account, how } = await ensureAccount(app.page, id, { fresh: FRESH });
  console.log(`Account ${id}: ${how} — ${account.email}`);
  return app;
}

/** Ensures group `name` exists for A, creating it when the switcher and home don't show it. */
async function ensureGroup(page: Page, name: string): Promise<void> {
  await goto(page, '/home');
  await expectText(page, 'Welcome back', 30_000);
  if (await hasText(page, name)) return;

  // The home screen only shows the CURRENT group, so a group with this name
  // may still exist without being visible. Check the switcher sheet before
  // creating — creating another would fork the test data (six duplicate
  // "Test Club" groups were made before this check existed).
  if (!(await hasText(page, 'Create a group'))) {
    await tap(page, 'Switch group', { exact: false });
    await page.waitForTimeout(1_000);
    if (await hasText(page, name)) {
      await tap(page, name, { exact: false });
      await expectText(page, `Switch group, ${name}`, 30_000);
      return;
    }
    await tap(page, 'New group');
  } else {
    // Empty home: the button sits right there.
    await tap(page, 'Create a group');
  }
  await page.waitForTimeout(1_500);
  await typeInto(page, 'e.g. Friday Poker Club', name);
  await tap(page, 'Create group', { role: 'button' });

  const start = Date.now();
  while (Date.now() - start < 30_000) {
    if (await hasText(page, name)) return;
    await page.waitForTimeout(400);
  }
  throw new Error(`ensureGroup: "${name}" did not appear after creation`);
}

test('setup: A signed in, Test Club + Office League exist, invite code captured', async () => {
  const app = await launchFor('A');
  try {
    // Create "Office League" first, then "Test Club".
    await ensureGroup(app.page, 'Office League');
    await ensureGroup(app.page, 'Test Club');

    // Make Test Club the current group (the manual cases assume it) via the
    // current-group chip's switcher sheet. Selecting a group navigates to its
    // group screen.
    await tap(app.page, 'Switch group', { exact: false });
    await app.page.waitForTimeout(1_200);
    await tap(app.page, 'Test Club', { exact: false });
    await expectText(app.page, 'Switch group, Test Club', 30_000);

    // The group screen loads its data asynchronously ("Loading Test Club…"),
    // so poll until the group code renders. Format on screen:
    // "GROUP CODE :" followed by a 6-char code from the 31-char alphabet
    // (no I, L, O, 0, 1).
    const start = Date.now();
    let code: string | undefined;
    while (Date.now() - start < 45_000) {
      const text = await appText(app.page);
      code =
        text.match(/(?:GROUP|JOIN) CODE\s*:?\s*([A-HJ-NP-Z2-9]{6})/)?.[1] ??
        text.match(/\b[A-HJ-NP-Z2-9]{6}\b/)?.[0];
      if (code) break;
      await app.page.waitForTimeout(500);
    }
    if (!code) throw new Error('no join code found on the Test Club screen');
    saveState({ ...loadState(), testClubCode: code });
    console.log(`Test Club invite code: ${code}`);
    await screenshot(app.page, 'setup-a-test-club');
  } finally {
    await app.close();
  }
});

test('setup: A has the document chip sets, Home 25 default, currency None', async () => {
  const app = await launchFor('A');
  try {
    const { page } = app;
    // "Home 25": Red 25×100, Green 100×100, Black 500×80, Purple 1,000×50, Blue 5,000×30
    await ensureChipSet(page, 'Home 25', HOME_25);
    // "Small box": White 1×150, Red 5×150, Green 25×100, Black 100×100
    await ensureChipSet(page, 'Small box', SMALL_BOX);

    // Settings → Default chip set → "Home 25". Only the trailing badge is
    // tappable on that row (the title itself has no onTap in the app), so the
    // badge — "STANDARD SET" or the current default's uppercase name — is the
    // target. Idempotent: skip when "Home 25" is already the default.
    await openSettings(page);
    if (!(await hasText(page, 'HOME 25'))) {
      await tap(page, (await hasText(page, 'STANDARD SET')) ? 'STANDARD SET' : 'HOME 25', { exact: false });
      await expectText(page, 'Default Chip Set', 20_000);
      await tap(page, 'Home 25', { exact: false });
      await expectText(page, 'HOME 25', 20_000); // the settings row's trailing badge
    }

    // Settings → Currency → None. The button's semantics node merges the
    // label and its child text ("No currency symbol None"), so match loosely.
    await tap(page, 'No currency symbol', { exact: false });

    console.log('Chip sets ready: Home 25 (default), Small box; currency None');
    await screenshot(page, 'setup-a-chip-sets');
  } finally {
    await app.close();
  }
});

test('setup: B signed in and a member of Test Club', async () => {
  const app = await launchFor('B');
  try {
    const { page } = app;
    await goto(page, '/home');
    await expectText(page, 'Welcome back', 30_000);

    if (!(await hasText(page, 'Test Club'))) {
      const code = loadState().testClubCode;
      if (!code) throw new Error('missing Test Club invite code — account A setup must run first');
      await goto(page, `/join-group?code=${code}`);
      await expectText(page, 'Test Club', 30_000);
      await tap(page, 'Join group');
      const start = Date.now();
      let joined = false;
      while (Date.now() - start < 60_000) {
        if (page.url().includes('/home') && (await hasText(page, 'Test Club'))) {
          joined = true;
          break;
        }
        await page.waitForTimeout(500);
      }
      if (!joined) throw new Error('B did not land on Home as a Test Club member');
      console.log('B joined Test Club');
    } else {
      console.log('B is already a Test Club member');
    }
    await screenshot(page, 'setup-b-test-club');
  } finally {
    await app.close();
  }
});
