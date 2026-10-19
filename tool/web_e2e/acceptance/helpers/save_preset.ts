import type { Page } from '@playwright/test';
import { appText, expectText, hasText, tap } from './flutter';
import { typeInto } from './auth';

/**
 * The builder's "Save as preset" dialog (offerSaveGamePreset): a name field,
 * a "Use as my default" toggle, and "Save preset".
 *
 * Probed facts (deployed build, 2026-10-19):
 *   - The name field is addressed by its placeholder "e.g. Friday deep stack".
 *   - AppToggle renders as a switch node; the label "Use as my default" may be
 *     the switch itself (then aria-checked reads) or a sibling text node.
 *   - Saving closes the dialog. A refusal (Free allowance) or a missing name
 *     keeps it open: "Free accounts can save up to 3 presets." / "Enter a name."
 */

type SaveOutcome = 'saved' | 'refused' | 'name-empty' | 'unknown';

/** The DOM state + centre of the toggle labelled `label`. */
export async function toggleState(
  page: Page,
  label: string,
): Promise<{ checked: boolean | null; x: number; y: number } | null> {
  return await page.evaluate(({ label }) => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    const all = Array.from(document.querySelectorAll('flt-semantics'));
    const state = (el: Element) => {
      const v = el.getAttribute('aria-checked') ?? el.getAttribute('aria-pressed');
      return v === null ? null : v === 'true';
    };
    // Flutter merges a labelled control's text into its own node, doubling the
    // label ("Use as my default Use as my default").
    const wanted = [label, `${label} ${label}`];
    for (const el of all) {
      const t = norm((el as HTMLElement).innerText);
      const a = norm(el.getAttribute('aria-label'));
      if (!wanted.includes(a) && !wanted.includes(t)) continue;
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width <= 0 || r.height <= 0) continue;
      const own = state(el);
      if (own !== null) return { checked: own, x: r.left + r.width / 2, y: r.top + r.height / 2 };
      // The label is its own node: find the switch on the same line, to its right.
      for (const sw of all) {
        const s = state(sw);
        if (s === null) continue;
        const sr = (sw as HTMLElement).getBoundingClientRect();
        const scy = sr.top + sr.height / 2;
        if (Math.abs(scy - (r.top + r.height / 2)) < 40 && sr.left >= r.left + r.width - 8) {
          return { checked: s, x: sr.left + sr.width / 2, y: scy };
        }
      }
      return { checked: null, x: r.left + r.width / 2, y: r.top + r.height / 2 };
    }
    return null;
  }, { label });
}

/** Turns the toggle labelled `label` on; returns the state read after the click. */
export async function setToggle(page: Page, label: string): Promise<boolean | null> {
  const before = await toggleState(page, label);
  if (!before) return null;
  if (before.checked === true) return true;
  await page.mouse.click(before.x, before.y); // known-off, or unreadable: one click
  await page.waitForTimeout(450);
  const after = await toggleState(page, label);
  if (after?.checked === true) return true;
  if (after?.checked === false) {
    // Second click only when the app says it is still off.
    await page.mouse.click(after.x, after.y);
    await page.waitForTimeout(450);
    return (await toggleState(page, label))?.checked ?? null;
  }
  return after?.checked ?? null;
}

/**
 * Fills the builder's "Save as preset" dialog and saves. Returns what the app
 * answered: "saved" (the dialog closed), "refused" (the Free allowance's
 * sentence is shown) or "name-empty" (the dialog said "Enter a name.").
 */
export async function savePresetDialog(
  page: Page,
  name: string,
  opts: { makeDefault?: boolean } = {},
): Promise<SaveOutcome> {
  await expectText(page, 'Preset name', 15_000);
  await typeInto(page, 'e.g. Friday deep stack', name);
  if (opts.makeDefault) {
    const madeDefault = await setToggle(page, 'Use as my default');
    console.log(`M5: "Use as my default" reads ${madeDefault} after ticking it`);
  }
  await tap(page, 'Save preset', { exact: true, timeout: 8_000 });
  await page.waitForTimeout(500);
  if (!(await hasText(page, 'Preset name'))) return 'saved';
  if (await hasText(page, 'Free accounts can save up to 3 presets.')) return 'refused';
  if (await hasText(page, 'Enter a name.')) return 'name-empty';
  const text = (await appText(page)).replace(/\s+/g, ' ');
  console.log(`M5: the save dialog stayed open — its text: ${text.slice(0, 220)}`);
  return 'unknown';
}
