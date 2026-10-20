import type { Page } from '@playwright/test';
import { expectText, hasText, tap } from './flutter';
import { openHome } from './nav';

/**
 * The Game presets library (drawer → "Presets") and its cards.
 *
 * Probed facts (deployed build, 2026-10-19), which decide this file's shape:
 *   - The drawer item is "Presets"; the screen's header is "Game presets".
 *   - The preset name is NOT a semantics node of its own. Flutter merges the
 *     whole card into one `role="button"` node whose aria-label is the card's
 *     text: the name on the first line, then the tags ("BUY-IN 20", "3H",
 *     "HOME 25", …) and the chip list. `hasText(name)` therefore matches, but
 *     `locate()`/`scrollUntilVisible()` (exact text) never do — every card
 *     lookup here goes through that merged label.
 *   - Inside the card, "Make default" / "Edit" / "Delete" are separate small
 *     nodes; they are matched by geometry (cards never overlap).
 *   - Built-in starters keep a Delete button with `onPressed: null`, so the
 *     control is exposed but does nothing; user presets' Delete opens a
 *     Material "Delete preset?" dialog whose content names the preset.
 *   - The header subtitle is the library's own counter: "… (N/3 used)".
 */

export const STARTER_PRESETS = ['Classic Freezeout', 'Sprint Turbo', 'Deep Stack', 'KO Bounty'];

export interface PresetAction {
  text: string;
  role: string;
  disabled: boolean;
  x: number;
  y: number;
}

export interface PresetCard {
  name: string;
  /** The merged card text, whitespace-collapsed (name · tags · chips). */
  label: string;
  /** The card shows the DEFAULT tag (it is the account's default preset). */
  isDefault: boolean;
  /** Screen rect — zero-sized while the card is not painted. */
  rect: { x: number; y: number; width: number; height: number };
  actions: PresetAction[];
}

/** Home → drawer → "Presets" → the "Game presets" screen. */
export async function openPresets(page: Page): Promise<void> {
  await tap(page, 'Open navigation menu', { exact: false, timeout: 15_000 });
  await page.waitForTimeout(900);
  await tap(page, 'Presets', { exact: true, timeout: 10_000 });
  await expectText(page, 'Game presets', 20_000);
}

/**
 * Every preset card the semantics tree exposes, in library order. Cards below
 * the fold are included (the list is a Column inside the page's scroll view),
 * with a zero-sized rect until they are painted.
 */
export async function presetCards(page: Page): Promise<PresetCard[]> {
  return await page.evaluate(() => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    const nodes = Array.from(document.querySelectorAll('flt-semantics'));
    const out: {
      name: string;
      label: string;
      isDefault: boolean;
      rect: { x: number; y: number; width: number; height: number };
      actions: { text: string; role: string; disabled: boolean; x: number; y: number }[];
    }[] = [];
    for (const el of nodes) {
      const raw = el.getAttribute('aria-label') ?? '';
      if (!/\nBUY-IN\b/.test(raw)) continue;
      if ((el.getAttribute('role') ?? '') !== 'button') continue;
      const name = (raw.split('\n')[0] ?? '').trim();
      if (!name) continue;
      const cr = el.getBoundingClientRect();
      const rect = { x: cr.left, y: cr.top, width: cr.width, height: cr.height };
      const actions: { text: string; role: string; disabled: boolean; x: number; y: number }[] = [];
      for (const a of nodes) {
        const t = norm((a as HTMLElement).innerText);
        if (t !== 'Edit' && t !== 'Delete' && t !== 'Make default') continue;
        const ar = a.getBoundingClientRect();
        if (ar.width <= 0 || ar.height <= 0) continue;
        const cx = ar.left + ar.width / 2;
        const cy = ar.top + ar.height / 2;
        if (cx < rect.x - 4 || cx > rect.x + rect.width + 4) continue;
        if (cy < rect.y - 4 || cy > rect.y + rect.height + 4) continue;
        const role = a.getAttribute('role') ?? '';
        actions.push({
          text: t,
          role,
          disabled: a.getAttribute('aria-disabled') === 'true' || role !== 'button',
          x: cx,
          y: cy,
        });
      }
      out.push({ name, label: norm(raw), isDefault: /\bDEFAULT\b/.test(raw), rect, actions });
    }
    return out;
  });
}

/** The first card called `name`, or null. */
export async function presetCard(page: Page, name: string): Promise<PresetCard | null> {
  const cards = await presetCards(page);
  return cards.find((c) => c.name === name) ?? null;
}

/** How many cards carry `name` (duplicates appear when saves were repeated). */
export async function presetCardCount(page: Page, name: string): Promise<number> {
  return (await presetCards(page)).filter((c) => c.name === name).length;
}

/**
 * The library's own counting oracle — the header subtitle
 * "Complete game preferences · 3 saved free (N/3 used)".
 */
export async function usedPresetCount(page: Page): Promise<number | null> {
  return await page.evaluate(() => {
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const t = (el as HTMLElement).innerText ?? '';
      const m = t.match(/\((\d+)\/3 used\)/);
      if (m) return Number(m[1]);
    }
    return null;
  });
}

async function wheel(page: Page, dy: number): Promise<void> {
  await page.mouse.move(195, 430);
  await page.mouse.wheel(0, dy);
  await page.waitForTimeout(320);
}

/**
 * Scrolls the library until the card's header row is comfortably on screen,
 * and returns the painted card (null when no card carries that name).
 */
export async function scrollToCard(page: Page, name: string, timeoutMs = 25_000): Promise<PresetCard | null> {
  const viewport = page.viewportSize() ?? { width: 390, height: 844 };
  const TOP = 100;
  const BOTTOM = 140;
  const start = Date.now();
  let last: PresetCard | null = null;
  while (Date.now() - start < timeoutMs) {
    const card = await presetCard(page, name);
    if (!card) return null;
    last = card;
    const painted = card.rect.width > 0 && card.rect.height > 0;
    if (painted && card.rect.y >= TOP && card.rect.y + 90 <= viewport.height - BOTTOM) return card;
    if (!painted || card.rect.y > viewport.height - BOTTOM) {
      await wheel(page, Math.min(520, Math.max(220, (painted ? card.rect.y : viewport.height) - 160)));
    } else if (card.rect.y < TOP) {
      await wheel(page, -420);
    } else {
      return card; // painted but its action row is in the top band: good enough
    }
  }
  return last;
}

/**
 * Clicks `action` ("Edit" / "Delete" / "Make default") on the card called
 * `name`. Returns false when the card exposes no such control, or when the
 * control is disabled and `allowDisabled` is not set. With `allowDisabled`
 * the click is still sent (to prove behaviourally that a disabled control
 * does nothing).
 */
export async function tapCardAction(
  page: Page,
  name: string,
  action: string,
  opts: { allowDisabled?: boolean } = {},
): Promise<boolean> {
  const card = await scrollToCard(page, name);
  if (!card) return false;
  const hit = card.actions.find((a) => a.text === action);
  if (!hit) return false;
  if (hit.disabled && !opts.allowDisabled) return false;
  await page.mouse.click(hit.x, hit.y);
  await page.waitForTimeout(650);
  return true;
}

/** True when the card called `name` carries the DEFAULT tag. */
export async function cardIsDefault(page: Page, name: string): Promise<boolean | null> {
  const card = await presetCard(page, name);
  return card ? card.isDefault : null;
}

/**
 * Clicks the "Delete preset?" dialog's confirm (never a card icon behind it).
 *
 * Anchored on the dialog's *content* text (`"<name>" will be removed…`): the
 * content names the preset, so a click that landed on a neighbouring card's
 * Delete is visible instead of silently deleting the wrong preset. The
 * confirm is the dialog's only node with the *text* "Delete" — the card icons
 * carry their label as an aria-label (or not at all).
 */
async function tapDeleteConfirm(page: Page, name: string): Promise<boolean> {
  const hit = await page.evaluate(
    ({ name }) => {
      const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
      const nodes = Array.from(document.querySelectorAll('flt-semantics'));
      let anchor: { top: number } | null = null;
      for (const el of nodes) {
        const t = norm((el as HTMLElement).innerText);
        if (!t.includes('will be removed') || (name && !t.includes(name))) continue;
        const r = (el as HTMLElement).getBoundingClientRect();
        if (r.width > 0 && r.height > 0) {
          anchor = { top: r.top };
          break;
        }
      }
      if (!anchor) {
        for (const el of nodes) {
          if (norm((el as HTMLElement).innerText) !== 'Delete preset?') continue;
          const r = (el as HTMLElement).getBoundingClientRect();
          if (r.width > 0 && r.height > 0) {
            anchor = { top: r.top };
            break;
          }
        }
      }
      if (!anchor) return null;
      let best: { x: number; y: number; d: number } | null = null;
      for (const el of nodes) {
        if (norm((el as HTMLElement).innerText) !== 'Delete') continue;
        const r = (el as HTMLElement).getBoundingClientRect();
        if (r.width <= 0 || r.height <= 0) continue;
        const d = r.top - anchor.top;
        if (d < -80 || d > 450) continue;
        if (!best || d < best.d) best = { x: r.left + r.width / 2, y: r.top + r.height / 2, d };
      }
      return best ? { x: best.x, y: best.y } : null;
    },
    { name },
  );
  if (!hit) return false;
  await page.mouse.click(hit.x, hit.y);
  await page.waitForTimeout(600);
  return true;
}

export type DeleteOutcome = 'no-control' | 'no-dialog' | 'cancelled' | 'deleted' | 'still-listed';

/**
 * Deletes the card called `name`: its Delete → "Delete preset?" → the dialog's
 * confirm. With `confirm: false` the dialog is only *observed* (and cancelled)
 * — used to prove a control opens nothing, without ever confirming.
 */
export async function deletePreset(
  page: Page,
  name: string,
  opts: { confirm?: boolean } = {},
): Promise<{ outcome: DeleteOutcome; dialogText: string | null }> {
  const before = await presetCardCount(page, name);
  if (before === 0) return { outcome: 'no-control', dialogText: null };
  if (!(await tapCardAction(page, name, 'Delete', { allowDisabled: true }))) {
    return { outcome: 'no-control', dialogText: null };
  }

  // The dialog is recognised by its content, which names this preset.
  let dialog = false;
  for (let i = 0; i < 12 && !dialog; i++) {
    dialog = await hasText(page, `"${name}" will be removed`);
    if (!dialog) await page.waitForTimeout(250);
  }
  if (!dialog) return { outcome: 'no-dialog', dialogText: null };

  const dialogText = (await page
    .evaluate(() => {
      const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
      for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
        const t = norm((el as HTMLElement).innerText);
        if (t.includes('will be removed')) return t;
      }
      return null;
    })
    .catch(() => null)) as string | null;

  if (opts.confirm === false) {
    await tap(page, 'Cancel', { exact: true, timeout: 8_000 });
    await page.waitForTimeout(600);
    return { outcome: 'cancelled', dialogText };
  }

  if (!(await tapDeleteConfirm(page, name))) {
    // Last resort: the text-only lookup (the anchored click found no anchor).
    await tap(page, 'Delete', { exact: true, timeout: 8_000 });
  }
  for (let i = 0; i < 20; i++) {
    if ((await presetCardCount(page, name)) < before) return { outcome: 'deleted', dialogText };
    await page.waitForTimeout(300);
  }
  return { outcome: 'still-listed', dialogText };
}

/**
 * Deletes every user-saved preset (built-ins stay), verifying across reloads
 * that the writes landed: the Free allowance (3 of your own) is only
 * predictable from a genuinely empty account. Returns how many were removed.
 */
export async function ensureNoUserPresets(page: Page): Promise<number> {
  let removed = 0;
  for (let round = 0; round < 4; round++) {
    const leftovers = (await presetCards(page)).filter((c) => !STARTER_PRESETS.includes(c.name));
    if (leftovers.length === 0) {
      const used = await usedPresetCount(page);
      if (used === null || used === 0) return removed;
      // The counter claims used slots but no card is exposed: reload and look again.
    }
    for (const card of leftovers) {
      const r = await deletePreset(page, card.name);
      if (r.outcome === 'deleted') removed += 1;
    }
    // A reload gives the backend write time to land, then re-reads the truth.
    await openHome(page);
    await openPresets(page);
  }
  const leftover = (await presetCards(page)).filter((c) => !STARTER_PRESETS.includes(c.name)).map((c) => c.name);
  if (leftover.length > 0) {
    throw new Error(`presets: leftover user preset(s) survived cleanup: ${leftover.join(', ')}`);
  }
  return removed;
}
