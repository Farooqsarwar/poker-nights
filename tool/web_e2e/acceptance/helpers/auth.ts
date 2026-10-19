import type { Page } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { goto, hasText, tap } from './flutter';

/**
 * QA accounts for the automated acceptance runs, created against the live
 * production Firebase on first use and reused afterwards (a persistent
 * browser profile per account keeps the signed-in session).
 *
 * Credentials live in .auth/accounts.json — gitignored, and deliberately
 * separate from the profiles in .auth/<name>/ so a profile can be rebuilt
 * from the credentials at any time.
 */

export interface Account {
  name: string;
  email: string;
  password: string;
}

export type AccountId = 'A' | 'B';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
export const STATE_FILE = path.join(ROOT, '.auth', 'state.json');

export interface E2eState {
  accounts?: Partial<Record<AccountId, Account>>;
  testClubCode?: string;
  officeLeagueCode?: string;
}

export function loadState(): E2eState {
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8')) as E2eState;
  } catch {
    return {};
  }
}

export function saveState(state: E2eState): void {
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

/** Deterministic-but-unique account identities for the two test roles. */
export function freshAccount(id: AccountId): Account {
  const stamp = Date.now().toString(36);
  const suffix = id === 'A' ? 'host' : 'player';
  return {
    name: id === 'A' ? 'QA Host' : 'QA Player',
    email: `qa.${suffix}.${stamp}@poker-night-e2e.test`,
    password: `Poker!Night${stamp}Z9`,
  };
}

/**
 * Types into the input Flutter created for a semantics field. Matches the
 * accessibility label OR the placeholder the app set (AppTextField renders its
 * label as separate text and passes the placeholder to the input).
 */
export async function typeInto(
  page: Page,
  labelOrPlaceholder: string,
  value: string,
  opts: { nth?: number; fallbackNth?: number; lenient?: boolean } = {},
): Promise<void> {
  const selector =
    `input[aria-label="${labelOrPlaceholder}"], textarea[aria-label="${labelOrPlaceholder}"], ` +
    `input[placeholder="${labelOrPlaceholder}"], textarea[placeholder="${labelOrPlaceholder}"]`;
  let locator = page.locator(selector);
  let index = opts.nth ?? 0;

  if ((await locator.count()) <= index && opts.fallbackNth !== undefined) {
    // Some Flutter TextFields expose neither aria-label nor placeholder;
    // fall back to positional access among all inputs on the screen.
    locator = page.locator('input, textarea');
    index = opts.fallbackNth;
  }
  if ((await locator.count()) <= index) {
    throw new Error(`typeInto: no field "${labelOrPlaceholder}" (nth ${index}) on screen`);
  }

  const input = locator.nth(index);
  await input.waitFor({ state: 'attached', timeout: 5_000 }).catch(() => {});

  // Focus the field directly through the DOM instead of clicking it. Clicking
  // is unreliable in this app: Flutter's semantics layer lags layout changes,
  // so a click computed from a stale rect can land on whatever moved into
  // that spot (one press meant for a Value field landed on the sticky
  // "+ Add denomination" button and re-opened the palette dialog). DOM focus
  // depends only on element identity, never on geometry.
  await input.evaluate((el) => (el as HTMLElement).focus());
  await page.waitForTimeout(120);
  const isFocused = await page.evaluate(
    ({ label }) => {
      const el = document.activeElement as HTMLElement | null;
      if (!el) return false;
      return el.getAttribute('aria-label') === label || el.getAttribute('placeholder') === label;
    },
    { label: labelOrPlaceholder },
  );
  if (!isFocused) {
    throw new Error(`typeInto: could not focus field "${labelOrPlaceholder}" (nth ${index})`);
  }

  // Clear anything already there, then send the whole string as ONE input
  // event. Typing key-by-key races Flutter's write-back on fields that
  // rebuild per keystroke (e.g. the chip editor's Value field), which
  // replaces the content after every character.
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.insertText(value);
  await page.waitForTimeout(150);
  const got = (await input.inputValue({ timeout: 3_000 }).catch(() => '')).trim();
  if (got !== value.trim()) {
    if (opts.lenient) {
      // Some Flutter fields draw the text on canvas and clear the a11y proxy
      // input the moment the framework takes the value (probed on the
      // player-name fields: the field visibly holds the text while its proxy
      // reads empty). Lenient callers verify the value where the app shows it
      // instead of trusting the proxy.
      console.log(
        `typeInto (lenient): proxy for "${labelOrPlaceholder}" reads "${got}" after typing "${value}"`,
      );
      return;
    }
    throw new Error(`typeInto: field "${labelOrPlaceholder}" shows "${got}" after typing "${value}"`);
  }
}

/** Ticks (or unticks) the nth Flutter checkbox and verifies the state flipped. */
export async function setCheckbox(page: Page, nth: number, checked = true): Promise<void> {
  const box = page.locator('flt-semantics[role="checkbox"]').nth(nth);
  if ((await box.count()) <= nth) throw new Error(`setCheckbox: no checkbox #${nth}`);
  const target = checked ? 'true' : 'false';
  if ((await box.getAttribute('aria-checked')) === target) return;
  await box.click({ force: true });
  await page.waitForTimeout(250);
  const after = await box.getAttribute('aria-checked');
  if (after !== target) throw new Error(`setCheckbox: checkbox #${nth} is ${after}, expected ${target}`);
}

/** Registers a brand-new account from /register and waits for Home. */
export async function registerAccount(page: Page, account: Account): Promise<void> {
  await goto(page, '/register');
  await page.waitForSelector('input[aria-label="Full Name"]', { timeout: 60_000 });
  await typeInto(page, 'Full Name', account.name);
  await typeInto(page, 'Email address', account.email);
  await typeInto(page, 'Password', account.password);
  await typeInto(page, 'Confirm Password', account.password);
  // Checkbox #0 is the required 18+/Terms consent. #1 (keep history) stays off.
  await setCheckbox(page, 0, true);
  await tap(page, 'Create Account', { role: 'button' });
  await waitForSignedInHome(page, 'registerAccount');
}

/** Waits for the signed-in Home screen ("Welcome back" only exists there). */
async function waitForSignedInHome(page: Page, who: string, timeout = 60_000): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    if (await hasText(page, 'Welcome back')) return;
    await page.waitForTimeout(500);
  }
  throw new Error(
    `${who}: never reached the signed-in Home screen — check for a form error (wrong password, email already in use, validation)`,
  );
}

/** Signs in an existing account from /login and waits for Home. */
export async function signIn(page: Page, account: Account): Promise<void> {
  await goto(page, '/login');
  await page.waitForSelector('input[aria-label="Email address"]', { timeout: 60_000 });
  await typeInto(page, 'Email address', account.email);
  await typeInto(page, 'Password', account.password);
  await tap(page, 'Sign In', { role: 'button' });
  await waitForSignedInHome(page, 'signIn', 45_000);
}

/** Deletes a browser profile, forcing a clean sign-in/registration next launch. */
export function resetProfileDir(profile: string): void {
  fs.rmSync(path.join(ROOT, '.auth', profile), { recursive: true, force: true });
}

/**
 * Guarantees the browser profile ends up signed in as account `id`.
 * Self-healing order: stored session → sign in with stored credentials →
 * register a brand-new account (the previous one is orphaned; harmless).
 */
export async function ensureAccount(
  page: Page,
  id: AccountId,
  opts: { fresh?: boolean } = {},
): Promise<{ account: Account; how: 'session' | 'signed-in' | 'registered' }> {
  let account = loadState().accounts?.[id];

  if (opts.fresh || !account) {
    account = freshAccount(id);
    saveState({ ...loadState(), accounts: { ...loadState().accounts, [id]: account } });
    await registerAccount(page, account);
    return { account, how: 'registered' };
  }

  // 1) Already signed in? A stored Firebase session keeps the person signed in.
  //    NB: a signed-out deep link to /home stays at /home but renders the
  //    sign-in interstitial, so the URL alone proves nothing. "Welcome back"
  //    is the top-bar greeting that exists only on the signed-in home.
  await goto(page, '/home');
  await page.waitForTimeout(4_000);
  if (await hasText(page, 'Welcome back')) {
    return { account, how: 'session' };
  }

  // 2) Sign in with the stored credentials.
  try {
    await signIn(page, account);
    return { account, how: 'signed-in' };
  } catch {
    // 3) The account is gone or the password changed — register a fresh one.
    const fresh = freshAccount(id);
    saveState({ ...loadState(), accounts: { ...loadState().accounts, [id]: fresh } });
    await registerAccount(page, fresh);
    return { account: fresh, how: 'registered' };
  }
}
