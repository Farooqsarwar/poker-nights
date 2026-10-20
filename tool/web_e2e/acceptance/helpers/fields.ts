import type { Page } from '@playwright/test';

/**
 * Text fields that have no accessible name.
 *
 * AppTextField paints its label as its own text node and forwards only the
 * *placeholder* to the input, so fields declared with a label alone (the preset
 * form's Buy-in / rebuy / add-on costs, the builder's "More options" numbers)
 * come out with neither aria-label nor placeholder — `typeInto` cannot address
 * them by name. These helpers anchor on the label node and pick the input
 * sitting right under it, then drive that input through the DOM exactly like
 * `typeInto` does.
 *
 * Probed on the deployed build (2026-10-19): these proxy inputs read an empty
 * value until they take focus, so readers focus (or fall back to a click)
 * before reading.
 */

interface FieldHit {
  x: number;
  y: number;
  tag: string;
}

/** Tags the input under the `label` node and returns its centre + tag. */
async function pick(page: Page, label: string): Promise<FieldHit | null> {
  return await page.evaluate(({ label }) => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    document.querySelectorAll('[data-e2e-field]').forEach((el) => el.removeAttribute('data-e2e-field'));

    let anchor: { left: number; top: number } | null = null;
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const t = norm((el as HTMLElement).innerText);
      const a = norm(el.getAttribute('aria-label'));
      if (t !== label && a !== label) continue;
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width <= 0 || r.height <= 0) continue;
      anchor = { left: r.left, top: r.top };
      break;
    }
    if (!anchor) return null;

    let best: (FieldHit & { d: number }) | null = null;
    let id = 0;
    for (const el of Array.from(document.querySelectorAll('input, textarea'))) {
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width <= 0 || r.height <= 0) continue;
      const cy = r.top + r.height / 2;
      // The field's box starts under its label; an AppTextField label sits
      // above the box, an InputDecoration label floats inside its top edge.
      const d = cy - anchor.top;
      if (d < 2 || d > 130) continue;
      if (Math.abs(r.left - anchor.left) > 60) continue;
      if (best && d >= best.d) continue;
      const tag = `e2e-field-${Date.now()}-${id++}`;
      el.setAttribute('data-e2e-field', tag);
      best = { x: r.left + r.width / 2, y: cy, tag, d };
    }
    return best ? { x: best.x, y: best.y, tag: best.tag } : null;
  }, { label });
}

/**
 * Reads the input under `label` ("30"), or null when no field can be found.
 * Focuses first — the proxy input is empty until it does — and re-reads once
 * after a click when focus alone left it empty.
 */
export async function readFieldNearLabel(page: Page, label: string): Promise<string | null> {
  const hit = await pick(page, label);
  if (!hit) {
    console.log(`fields: no input under "${label}"`);
    return null;
  }
  const input = page.locator(`[data-e2e-field="${hit.tag}"]`);
  await input.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
  await page.waitForTimeout(250);
  let value = (await input.inputValue({ timeout: 3_000 }).catch(() => '')).trim();
  if (value === '') {
    // A click focuses the field the way a person's tap does; Flutter then
    // writes the field's text into the proxy input.
    const again = await pick(page, label);
    if (again) {
      await page.mouse.click(again.x, again.y);
      await page.waitForTimeout(350);
      value = (
        await page
          .locator(`[data-e2e-field="${again.tag}"]`)
          .inputValue({ timeout: 3_000 })
          .catch(() => '')
      ).trim();
    }
  }
  return value;
}

/**
 * Types `value` into the input under `label` and returns what the proxy reads
 * afterwards. Never throws on a read-back mismatch — the app's own value (e.g.
 * the preset card's "BUY-IN 30" tag) is the source of truth; the read-back is
 * logged so a missed edit is visible in the run output.
 */
export async function typeIntoFieldNearLabel(page: Page, label: string, value: string): Promise<string> {
  const hit = await pick(page, label);
  if (!hit) throw new Error(`fields: no input under "${label}"`);
  const input = page.locator(`[data-e2e-field="${hit.tag}"]`);

  const attempt = async (): Promise<string> => {
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.insertText(value);
    await page.waitForTimeout(220);
    return (await input.inputValue({ timeout: 2_000 }).catch(() => '')).trim();
  };

  // Focus through the DOM — clicking by coordinates can land on whatever moved
  // into a stale rect (see typeInto in auth.ts).
  await input.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
  await page.waitForTimeout(150);
  let got = await attempt();

  if (got !== value) {
    // Fallback: click the field on a rect measured here and now, then retype.
    const again = await pick(page, label);
    if (again) {
      await page.mouse.click(again.x, again.y);
      await page.waitForTimeout(250);
      got = await attempt();
    }
  }
  if (got !== value) {
    console.log(
      `fields: "${label}" proxy reads "${got}" after typing "${value}" — verify the value where the app shows it`,
    );
  }
  return got;
}
