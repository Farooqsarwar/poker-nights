import { chromium, type BrowserContext, type Page } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

/**
 * Flutter-web semantics bridge.
 *
 * The deployed app paints into <canvas>, so there is no ordinary DOM to
 * query. Flutter does, however, mirror its widget tree into an accessibility
 * ("semantics") DOM of <flt-semantics> elements once accessibility is
 * enabled — every label, button, toggle and text field appears there with
 * text content and ARIA roles. This module turns that tree into a small
 * app-driving API: tap by exact label, assert text, type into fields.
 *
 * Facts verified against the live site (see probe/probe.spec.ts output):
 *  - `flt-semantics-placeholder` (aria-label "Enable accessibility") switches
 *    the tree on when clicked.
 *  - Buttons are `flt-semantics[role="button"]`; their label is element text
 *    (a nested <span>), NOT aria-label.
 *  - Container nodes also carry all descendant text, so a search must pick
 *    the deepest/smallest element with an exact text match, never a
 *    substring of a container.
 */

export const BASE_URL = process.env.E2E_BASE_URL ?? 'https://poker-night-tools.web.app';

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const AUTH_DIR = path.join(ROOT, '.auth');
const SCREENS_DIR = path.join(ROOT, '.reports', 'screens');

export interface AppSession {
  context: BrowserContext;
  page: Page;
  profile: string;
  close(): Promise<void>;
}

export interface LaunchOptions {
  headless?: boolean;
  url?: string;
}

/**
 * Opens the app with a persistent browser profile. Persistent profiles are
 * deliberately used instead of storageState: Firebase persists its session in
 * IndexedDB, which only a real profile carries across runs. `${profile}`
 * therefore *is* the signed-in account.
 */
export async function launchApp(profile: string, opts: LaunchOptions = {}): Promise<AppSession> {
  const userDataDir = path.join(AUTH_DIR, profile);
  fs.mkdirSync(userDataDir, { recursive: true });

  const isHeaded =
    opts.headless === false ||
    process.env.HEADED === 'true' ||
    process.argv.includes('--headed');

  const context = await chromium.launchPersistentContext(userDataDir, {
    headless: !isHeaded,
    slowMo: process.env.SLOWMO ? parseInt(process.env.SLOWMO, 10) : undefined,
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
    permissions: [],
    baseURL: BASE_URL,
  });

  const page = context.pages()[0] ?? (await context.newPage());
  page.setDefaultTimeout(30_000);

  if (isHeaded) {
    await page.addInitScript(() => {
      window.addEventListener('click', (e) => {
        const dot = document.createElement('div');
        dot.style.position = 'fixed';
        dot.style.left = `${e.clientX - 16}px`;
        dot.style.top = `${e.clientY - 16}px`;
        dot.style.width = '32px';
        dot.style.height = '32px';
        dot.style.borderRadius = '50%';
        dot.style.backgroundColor = 'rgba(255, 0, 50, 0.65)';
        dot.style.border = '2px solid white';
        dot.style.boxShadow = '0 0 12px rgba(255, 0, 0, 0.9)';
        dot.style.pointerEvents = 'none';
        dot.style.zIndex = '9999999';
        dot.style.transition = 'all 0.35s ease-out';
        document.body.appendChild(dot);
        requestAnimationFrame(() => {
          dot.style.transform = 'scale(2.2)';
          dot.style.opacity = '0';
        });
        setTimeout(() => dot.remove(), 400);
      }, true);
    });
  }

  await page.goto(opts.url ?? '/', { waitUntil: 'domcontentloaded' });
  await enableSemantics(page);

  return {
    context,
    page,
    profile,
    close: () => context.close(),
  };
}

/** Turns Flutter's accessibility tree on (idempotent). */
export async function enableSemantics(page: Page): Promise<void> {
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });

  await page
    .waitForFunction(() => document.querySelectorAll('flt-semantics').length > 3, { timeout: 10_000 })
    .catch(async () => {
      const placeholder = page.locator('flt-semantics-placeholder');
      if ((await placeholder.count()) > 0) {
        try {
          await placeholder.first().click({ force: true, timeout: 5_000 });
        } catch {
          await page.evaluate(() => {
            const el = document.querySelector('flt-semantics-placeholder');
            if (el instanceof HTMLElement) el.click();
          });
        }
      }
    });

  await page.waitForFunction(() => document.querySelectorAll('flt-semantics').length > 3, { timeout: 30_000 });
}

/**
 * Full-page navigation that re-enables the semantics tree afterwards.
 * page.goto() replaces the document, and Flutter rebuilds its accessibility
 * DOM only when asked — forgetting this leaves every selector blind.
 * In-app navigation (tap()) keeps the tree and must NOT use this.
 */
export async function goto(page: Page, path: string): Promise<void> {
  let lastErr: unknown;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      await page.goto(path, { waitUntil: 'domcontentloaded' });
      await enableSemantics(page);
      return;
    } catch (e) {
      lastErr = e;
      if (attempt < 3) await page.waitForTimeout(1200 * attempt);
    }
  }
  throw lastErr;
}

interface Rect {
  x: number;
  y: number;
  width: number;
  height: number;
}

interface Candidate extends Rect {
  text: string;
  role: string | null;
  target: string; // temporary attribute set on the chosen element
}

/**
 * Finds the smallest element whose trimmed text — or accessibility label —
 * matches `text` (exactly, or containing it). Returns null when nothing
 * matches yet. Positive-area elements always win over zero-size ones so a
 * hidden duplicate node can never shadow the real target.
 */
async function locate(page: Page, text: string, role?: string, contains = false, nth = 0): Promise<Candidate | null> {
  return await page.evaluate(
    ({ text, role, contains, nth }) => {
      const norm = (s: string) => s.replace(/\s+/g, ' ').trim();
      const wanted = norm(text);

      const all = Array.from(document.querySelectorAll('flt-semantics'));
      const matches: Candidate[] = [];
      let targetId = 0;

      for (const el of all) {
        const elRole = el.getAttribute('role');
        if (role && elRole !== role) continue;
        if (!role && elRole === 'textbox') continue;
        const t = norm((el as HTMLElement).innerText ?? el.textContent ?? '');
        const label = norm(el.getAttribute('aria-label') ?? '');
        // Flutter merges a node's label with its child text, so a widget like
        // Semantics(label: 'Red', child: Text('Red')) yields "Red Red".
        const doubled = `${wanted} ${wanted}`;
        const hit = contains
          ? t.includes(wanted) || label.includes(wanted)
          : t === wanted || label === wanted || t === doubled || label === doubled;
        if (!hit) continue;
        const r = el.getBoundingClientRect();
        matches.push({
          x: r.x,
          y: r.y,
          width: r.width,
          height: r.height,
          text: t,
          role: elRole,
          target: `e2e-${Date.now()}-${targetId++}`,
        });
        // Tag now; only the winner keeps it.
        el.setAttribute('data-e2e-id', matches[matches.length - 1].target);
      }

      if (matches.length === 0) return null;
      const visible = matches.filter((m) => m.width > 0 && m.height > 0);
      const pool = visible.length > 0 ? visible : matches;
      pool.sort((a, b) => a.width * a.height - b.width * b.height);
      const best = pool[nth];
      if (!best) return null;
      for (const m of matches) {
        if (m.target === best.target) continue;
        const el = document.querySelector(`[data-e2e-id="${m.target}"]`);
        el?.removeAttribute('data-e2e-id');
      }
      return best;
    },
    { text, role, contains, nth },
  );
}

function inViewport(r: Rect, viewport: { width: number; height: number }): boolean {
  const cx = r.x + r.width / 2;
  const cy = r.y + r.height / 2;
  return cx >= 0 && cy >= 0 && cx <= viewport.width && cy <= viewport.height && r.width > 0 && r.height > 0;
}

/**
 * Scrolls the app until the matched element sits comfortably on screen —
 * clear of the top app bar and the bottom navigation strip, which overlays
 * scrollable content. Flutter canvas apps listen to wheel events, so
 * mouse.wheel is the reliable way to move content. Elements that cannot move
 * (the fixed nav items themselves) are accepted in place once two wheels in
 * a row leave them where they are.
 */
export async function scrollUntilVisible(
  page: Page,
  text: string,
  opts: { role?: string; contains?: boolean; nth?: number } = {},
): Promise<Candidate | null> {
  const viewport = page.viewportSize() ?? { width: 390, height: 844 };
  const TOP_MARGIN = 110; // app bar
  const BOTTOM_MARGIN = 150; // bottom nav + safety
  const debug = process.env.E2E_DEBUG === '1';
  let last: Candidate | null = null;
  let stable = 0;

  for (let attempt = 0; attempt < 40; attempt++) {
    const rect = await locate(page, text, opts.role, opts.contains, opts.nth ?? 0);
    if (debug) {
      console.log(
        `[scroll] "${text}" attempt=${attempt} ` +
          (rect
            ? `@${Math.round(rect.x)},${Math.round(rect.y)} ${Math.round(rect.width)}x${Math.round(rect.height)}`
            : 'not found'),
      );
    }
    if (!rect) {
      await wheel(page, 300);
      last = null;
      stable = 0;
      continue;
    }

    const offscreen = !inViewport(rect, viewport);
    const tooHigh = rect.y < TOP_MARGIN;
    const tooLow = rect.y + rect.height > viewport.height - BOTTOM_MARGIN;

    if (!offscreen && !tooHigh && !tooLow) {
      // Position is good — but Flutter animates wheel scrolling and dialogs
      // slide in, so only click once the rect has held still across a beat.
      // A click during the glide lands where the element no longer is.
      if (last && Math.abs(last.x - rect.x) < 2 && Math.abs(last.y - rect.y) < 2) {
        return rect;
      }
      last = rect;
      await page.waitForTimeout(180);
      continue;
    }

    let delta = 0;
    if (rect.y < 0) delta = Math.max(rect.y - 40, -600);
    else if (tooLow) delta = Math.min(rect.y + rect.height - (viewport.height - BOTTOM_MARGIN) + 24, 600);
    else if (tooHigh) delta = Math.max(Math.min(rect.y - TOP_MARGIN - 24, -60), -600);
    if (delta === 0) return rect;

    // A fixed element (e.g. bottom nav) never moves: accept it after two
    // still reads even though it is outside the comfort zone.
    if (last && Math.abs(last.y - rect.y) < 2 && Math.abs(last.x - rect.x) < 2) {
      stable += 1;
      if (stable >= 2) return rect;
    } else {
      stable = 0;
    }
    last = rect;

    await wheel(page, delta);
  }
  return last;
}

async function wheel(page: Page, delta: number): Promise<void> {
  if (process.env.E2E_DEBUG === '1') console.log(`[wheel] dy=${delta}`);
  const viewport = page.viewportSize() ?? { width: 390, height: 844 };
  await page.mouse.move(viewport.width / 2, viewport.height / 2);
  await page.mouse.wheel(0, delta);
  await page.waitForTimeout(160);
}

/** Taps the element whose text matches exactly (or contains, when exact=false). */
export async function tap(
  page: Page,
  text: string,
  opts: { role?: string; exact?: boolean; timeout?: number; nth?: number; xBias?: number } = {},
): Promise<void> {
  const timeout = opts.timeout ?? 30_000;
  const contains = opts.exact === false;
  const bias = opts.xBias ?? 0.5;
  const start = Date.now();

  let rect: Candidate | null = null;
  while (Date.now() - start < timeout) {
    rect = await scrollUntilVisible(page, text, { role: opts.role, contains, nth: opts.nth });
    if (rect) break;
    await page.waitForTimeout(200);
  }
  if (!rect) {
    const sample = await page
      .evaluate(() =>
        Array.from(document.querySelectorAll('flt-semantics'))
          .map((el) => ((el as HTMLElement).innerText ?? '').replace(/\s+/g, ' ').trim())
          .filter((t) => t.length > 0 && t.length < 60)
          .slice(0, 50)
          .join(' | '),
      )
      .catch(() => 'n/a');
    throw new Error(
      `tap: no element ${contains ? 'containing' : 'with exact text'} "${text}"${opts.role ? ` and role ${opts.role}` : ''} within ${timeout}ms. Texts seen: ${sample}`,
    );
  }

  const locator = page.locator(`[data-e2e-id="${rect.target}"]`);
  const debug = process.env.E2E_DEBUG === '1';
  if (debug) {
    console.log(
      `[tap] "${text}" -> @${Math.round(rect.x)},${Math.round(rect.y)} ${Math.round(rect.width)}x${Math.round(rect.height)} target=${rect.target}`,
    );
  }
  const cx = rect.x + rect.width * bias;
  const cy = rect.y + rect.height / 2;

  await page.evaluate(({ x, y }) => {
    const dot = document.createElement('div');
    dot.style.position = 'fixed';
    dot.style.left = `${x - 16}px`;
    dot.style.top = `${y - 16}px`;
    dot.style.width = '32px';
    dot.style.height = '32px';
    dot.style.borderRadius = '50%';
    dot.style.backgroundColor = 'rgba(255, 30, 60, 0.7)';
    dot.style.border = '2px solid white';
    dot.style.boxShadow = '0 0 14px rgba(255, 0, 0, 1)';
    dot.style.pointerEvents = 'none';
    dot.style.zIndex = '9999999';
    dot.style.transition = 'all 0.35s ease-out';
    document.body.appendChild(dot);
    requestAnimationFrame(() => {
      dot.style.transform = 'scale(2.4)';
      dot.style.opacity = '0';
    });
    setTimeout(() => dot.remove(), 400);
  }, { x: cx, y: cy }).catch(() => {});

  if (bias !== 0.5) {
    // Merged semantics nodes (e.g. a toggle row) are wider than the control
    // itself; xBias clicks nearer the real widget inside the node.
    if (debug) console.log(`[tap] biased click at ${Math.round(cx)},${Math.round(cy)}`);
    await page.mouse.click(cx, cy);
  } else {
    try {
      await locator.click({ force: true, timeout: 4_000 });
    } catch {
      if (debug) {
        console.log(`[tap] locator click failed; mouse.click at ${Math.round(cx)},${Math.round(cy)}`);
      }
      await page.mouse.click(cx, cy);
    }
  }
  await page.waitForTimeout(250); // let Flutter process the tap and repaint
}

/** True when an element with exactly this text exists (anywhere, any size). */
export async function hasText(page: Page, text: string): Promise<boolean> {
  const exact = await locate(page, text);
  if (exact) return true;
  // Fall back to contains for text broken across spans by the engine.
  return await page.evaluate(
    ({ text }) => {
      const norm = (s: string) => s.replace(/\s+/g, ' ').trim();
      const wanted = norm(text);
      return Array.from(document.querySelectorAll('flt-semantics')).some((el) => {
        const t = norm((el as HTMLElement).innerText ?? el.textContent ?? '');
        const label = norm(el.getAttribute('aria-label') ?? '');
        return t.includes(wanted) || label.includes(wanted);
      });
    },
    { text },
  );
}

/** Waits until the exact text is visible. Throws with a screenshot note otherwise. */
export async function expectText(page: Page, text: string, timeout = 20_000): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    if (await hasText(page, text)) return;
    await page.waitForTimeout(200);
  }
  throw new Error(`expectText: "${text}" never appeared (waited ${timeout}ms)`);
}

/** Waits until the exact text is gone. */
export async function expectNoText(page: Page, text: string, timeout = 20_000): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    if (!(await hasText(page, text))) return;
    await page.waitForTimeout(200);
  }
  throw new Error(`expectNoText: "${text}" is still present after ${timeout}ms`);
}

/** All visible text in the app, newline-joined (for regex assertions). */
export async function appText(page: Page): Promise<string> {
  return await page.evaluate(() => {
    const parts: string[] = [];
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      // Only leaf-ish nodes to avoid repeating container text.
      if (el.querySelector('flt-semantics')) continue;
      const t = (el as HTMLElement).innerText?.trim();
      if (t) parts.push(t);
    }
    return parts.join('\n');
  });
}

/** Reads the first semantics node whose aria-label matches `pattern`. */
export async function readNodeLabel(page: Page, pattern: RegExp): Promise<string | null> {
  return await page.evaluate(({ source }) => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    const re = new RegExp(source);
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const l = norm(el.getAttribute('aria-label'));
      if (re.test(l)) return l;
    }
    return null;
  }, { source: pattern.source });
}

/**
 * Reads the first snippet matching `pattern` anywhere in the tree — text or
 * aria-label. Some rows (e.g. the bonus estimate) merge their text into a
 * label rather than exposing it as innerText, so both are scanned.
 */
export async function readTextMatch(page: Page, pattern: RegExp): Promise<string | null> {
  return await page.evaluate(({ source }) => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    const re = new RegExp(source);
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const t = norm((el as HTMLElement).innerText);
      const inText = t.match(re);
      if (inText) return inText[0];
      const l = norm(el.getAttribute('aria-label'));
      const inLabel = l.match(re);
      if (inLabel) return inLabel[0];
    }
    return null;
  }, { source: pattern.source });
}

export async function screenshot(page: Page, label: string): Promise<string> {
  fs.mkdirSync(SCREENS_DIR, { recursive: true });
  const file = path.join(SCREENS_DIR, `${new Date().toISOString().replace(/[:.]/g, '-')}-${label}.png`);
  await page.screenshot({ path: file });
  return file;
}
