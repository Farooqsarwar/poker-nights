import type { Page } from '@playwright/test';
import { expectText, hasText, scrollUntilVisible, tap } from './flutter';
import { openSettings } from './nav';

/**
 * Structure-builder automation shared by the acceptance specs: the quick
 * game, the event's "Create structure" builder, and the free tools all embed
 * `lib/widgets/structure_builder.dart`.
 *
 * Probed facts this module leans on (deployed build, 2026-10-19):
 *   - The Players value renders as a semantics node whose text is exactly
 *     "N players"; its label node changes shape after an edit
 *     ("Players 8" → "Increase Players 9"), so the *text* node is the stable
 *     handle. Tapping it opens the "Enter number" dialog.
 *   - The quick game passes `maxPlayers: _cap(app)` (a free host: the group's
 *     one-table size, 9 by default), so a typed 20 clamps to 9.
 *   - The stack field is a DOM input; focusing it through the DOM (never by
 *     coordinates — the semantics rects lag) and committing with Enter uses
 *     the same path a host's keyboard does.
 *   - Level rows expose "L{n}" and "{sb} / {bb} · {mins} min" as text nodes.
 */

/** The Settings "Default Chip Set" row's badge; picks `name`. Idempotent. */
export async function setDefaultChipSet(page: Page, name: string): Promise<void> {
  await openSettings(page);
  const badge = name.toUpperCase();
  if (await hasText(page, badge)) {
    console.log(`builder: default chip set already ${name}`);
    return;
  }
  for (const current of [
    'HOME 25',
    'SMALL BOX',
    'STANDARD SET',
    'QA TINY CASE',
    'QA SHALLOW CASE',
    'QA UNNUMBERED',
  ]) {
    if (await hasText(page, current)) {
      await tap(page, current, { exact: false });
      break;
    }
  }
  await expectText(page, 'Default Chip Set', 20_000);
  await page.waitForTimeout(1_000);
  await tap(page, name, { exact: false });
  await expectText(page, badge, 20_000);
  console.log(`builder: default chip set → ${name}`);
}

export interface CountRow {
  x: number;
  y: number;
  w: number;
  h: number;
  n: number;
}

/** The Players value node (text exactly "N players"). */
export async function readPlayersRow(page: Page): Promise<CountRow | null> {
  return await page.evaluate(() => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const m = /^(\d+) players$/.exec(norm((el as HTMLElement).innerText));
      if (!m) continue;
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width > 0 && r.height > 0) {
        return { x: r.x, y: r.y, w: r.width, h: r.height, n: parseInt(m[1], 10) };
      }
    }
    return null;
  });
}

export async function readPlayersCount(page: Page): Promise<number | null> {
  return (await readPlayersRow(page))?.n ?? null;
}

/**
 * Sets the Players count through the "Enter number" dialog. Returns what the
 * row reads afterwards — which is the app's clamp, not necessarily `value`.
 */
export async function setPlayersCount(page: Page, value: number): Promise<number | null> {
  const row = await readPlayersRow(page);
  if (!row) throw new Error('builder: no Players value node on screen');
  await page.mouse.click(row.x + row.w / 2, row.y + row.h / 2);
  await expectText(page, 'Enter number', 20_000);
  await page.waitForTimeout(400); // dialog settle + autofocus
  const field = page.locator('input, textarea').last();
  await field.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
  await page.waitForTimeout(120);
  await page.keyboard.press('Control+A');
  await page.keyboard.insertText(String(value));
  await page.waitForTimeout(250);
  const got = (await field.inputValue({ timeout: 3_000 }).catch(() => '')).trim();
  if (got !== String(value)) {
    throw new Error(`builder: players dialog field shows "${got}" after typing ${value}`);
  }
  await tap(page, 'Apply');
  await page.waitForTimeout(600);
  return readPlayersCount(page);
}

/**
 * Clicks `option` inside the section headed by `section` (e.g. Ante → Individual).
 * The stepper/segmented nodes carry only their own words ("Yes", "Individual"),
 * so the section's label node is the anchor and geometry picks the match.
 */
export async function tapInSection(page: Page, section: string, option: string): Promise<void> {
  const hit = await page.evaluate(
    ({ section, option }) => {
      const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
      const nodes = Array.from(document.querySelectorAll('flt-semantics')).map((el) => ({
        t: norm((el as HTMLElement).innerText),
        a: norm(el.getAttribute('aria-label')),
        r: (el as HTMLElement).getBoundingClientRect(),
      }));
      const opts = nodes.filter(
        (n) => (n.t === option || n.a === option) && n.r.width >= 8 && n.r.height >= 1,
      );
      // The section label may be its own node or merged into a container that
      // still starts with the label ("Ante Yes No Big blind Individual").
      const anchors = nodes.filter(
        (n) => (n.t === section || n.t.startsWith(`${section} `)) && n.r.width > 0,
      );
      let best: { cx: number; cy: number; d: number } | null = null;
      for (const o of opts) {
        for (const a of anchors) {
          const d = o.r.y + o.r.height / 2 - a.r.y;
          if (d < -40 || d > 420) continue;
          if (!best || Math.abs(d) < Math.abs(best.d)) {
            best = { cx: o.r.x + o.r.width / 2, cy: o.r.y + o.r.height / 2, d };
          }
        }
      }
      if (!best && opts.length === 1 && anchors.length === 0) {
        // No usable section label — a single unambiguous option will do.
        const o = opts[0];
        best = { cx: o.r.x + o.r.width / 2, cy: o.r.y + o.r.height / 2, d: -1 };
      }
      return best;
    },
    { section, option },
  );
  if (!hit) throw new Error(`builder: no "${option}" within the "${section}" section`);
  await page.mouse.click(hit.cx, hit.cy);
  await page.waitForTimeout(350);
}

/** The "How long" value on screen ("4h" / "4h 30m"), or null when not painted. */
export async function readDurationHours(page: Page): Promise<string | null> {
  return await page.evaluate(() => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      const t = norm((el as HTMLElement).innerText ?? el.textContent ?? '');
      const label = norm(el.getAttribute('aria-label') ?? '');
      const m = t.match(/^(\d+)h(?: 30m)?$/) ?? label.match(/^(\d+)h(?: 30m)?$/);
      if (!m) continue;
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width > 0 && r.height > 0) return m[0];
    }
    return null;
  });
}

/**
 * Walks the "How long" control until the duration reads exactly `target`
 * hours (the displays are "3h" / "4h 30m").
 */
export async function setDurationHours(page: Page, target: number): Promise<string> {
  await scrollUntilVisible(page, 'How long');
  for (let i = 0; i < 10; i++) {
    let text = await readDurationHours(page);
    if (!text) {
      await scrollUntilVisible(page, 'How long');
      text = await readDurationHours(page);
    }
    if (!text) throw new Error('builder: no duration value on screen');
    const hours = parseInt(text, 10) + (text.includes('30m') ? 0.5 : 0);
    if (hours === target) return text;
    await tap(page, hours < target ? 'Longer' : 'Shorter', { role: 'button', exact: true });
    await page.waitForTimeout(350);
  }
  throw new Error(`builder: could not reach ${target}h`);
}

/**
 * The stack step's big number ("4,000 chips") as an integer. Polls: the stack
 * card paints after the solver finishes, so a single read can beat it.
 *
 * The whole card is ONE merged semantics node —
 *   "Starting stack\n5,000 chips\n100 big blinds deep · opening 25/50\n…"
 * — so the number is searched *within* the node text, never as the whole of it.
 */
export async function readStackChips(page: Page): Promise<number | null> {
  for (let i = 0; i < 24; i++) {
    const text = await page.evaluate(() => {
      const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
      let best: string | null = null;
      for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
        const m = /(\d[\d,]*) chips(?: |$)/.exec(norm((el as HTMLElement).innerText));
        if (!m) continue;
        const r = (el as HTMLElement).getBoundingClientRect();
        if (r.width > 0 && r.height > 0 && (best === null || m[1].length < best.length)) best = m[1];
      }
      return best;
    });
    if (text) return Number(text.replace(/[^\d]/g, ''));
    await page.waitForTimeout(600);
  }
  return null;
}

/**
 * The depth line ("100 big blinds deep · opening 25/50"), found inside the
 * merged stack card. Polls like the stack read.
 */
export async function readDepthLine(page: Page): Promise<string | null> {
  for (let i = 0; i < 24; i++) {
    const text = await page.evaluate(() => {
      const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
      for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
        const m = /(\d+) big blinds deep(?: · opening \d+\/\d+)?/.exec(
          norm((el as HTMLElement).innerText),
        );
        if (m) {
          const r = (el as HTMLElement).getBoundingClientRect();
          if (r.width > 0) return m[0];
        }
      }
      return null;
    });
    if (text) return text;
    await page.waitForTimeout(600);
  }
  return null;
}

/**
 * The per-player chip split ("4 × 25 · 4 × 100 · …"), found inside the merged
 * stack card after its "Per player" label. Polls like the stack read.
 */
export async function readChipPlan(page: Page): Promise<string | null> {
  for (let i = 0; i < 24; i++) {
    const text = await page.evaluate(() => {
      const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
      for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
        const m = /Per player ((?:[\d,]+ × [\d,]+)(?: · [\d,]+ × [\d,]+)+)/.exec(
          norm((el as HTMLElement).innerText),
        );
        if (m) {
          const r = (el as HTMLElement).getBoundingClientRect();
          if (r.width > 0) return m[1];
        }
      }
      return null;
    });
    if (text) return text;
    await page.waitForTimeout(600);
  }
  return null;
}

/**
 * Sets the stack via its text field: DOM focus (never a coordinate click),
 * whole-string insert, Enter — the same commit path `onSubmitted` uses.
 */
export async function setStackField(page: Page, value: number): Promise<number | null> {
  const before = await readStackChips(page);
  const attempt = async () => {
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.insertText(String(value));
    await page.waitForTimeout(200);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(700);
    return await readStackChips(page);
  };
  const box = page.locator('input, textarea').last();
  if ((await box.count()) > 0) {
    await box.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
    await page.waitForTimeout(200);
    const now = await attempt();
    if (now !== before) return now;
  }
  // Fallback: the field sits directly above its "Steps of 25" helper text.
  const anchor = await page.evaluate(() => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      if (norm((el as HTMLElement).innerText) !== 'Steps of 25') continue;
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width > 0) return { x: r.x + r.width / 2, y: r.y - 26 };
    }
    return null;
  });
  if (anchor) {
    await page.mouse.click(anchor.x, anchor.y);
    await page.waitForTimeout(250);
    const now = await attempt();
    if (now !== before) return now;
  }
  return await readStackChips(page);
}

/** "enabled" | "disabled" | "gone" for a button found by its exact text. */
export async function buttonState(page: Page, label: string): Promise<string> {
  return await page.evaluate((text) => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
      if (norm((el as HTMLElement).innerText) !== text) continue;
      const r = (el as HTMLElement).getBoundingClientRect();
      if (r.width <= 0) continue;
      return el.getAttribute('aria-disabled') === 'true' ? 'disabled' : 'enabled';
    }
    return 'gone';
  }, label);
}

export interface Level {
  n: number;
  sb: number;
  bb: number;
  text: string;
}

/** Every level row on the structure step, in level order. Polls until rows paint. */
export async function readLevels(page: Page): Promise<Level[]> {
  for (let i = 0; i < 24; i++) {
    const levels = await page.evaluate(() => {
      const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
      const found = new Map<number, { n: number; sb: number; bb: number; text: string }>();
      let pending: number | null = null;
      for (const el of Array.from(document.querySelectorAll('flt-semantics'))) {
        const t = norm((el as HTMLElement).innerText);
        if (!t || t.length > 90) continue;
        const r = (el as HTMLElement).getBoundingClientRect();
        if (r.width <= 0) continue;
        const ln = /^L(\d+)$/.exec(t);
        if (ln) {
          pending = parseInt(ln[1], 10);
          continue;
        }
        const pair = /^([\d,]+) \/ ([\d,]+)(?: · ante [\d,]+)? · \d+ min$/.exec(t);
        if (pair && pending !== null) {
          found.set(pending, {
            n: pending,
            sb: Number(pair[1].replace(/,/g, '')),
            bb: Number(pair[2].replace(/,/g, '')),
            text: t,
          });
          pending = null;
          continue;
        }
        const merged = /^L(\d+)\b[^\n]{0,40}?([\d,]+) \/ ([\d,]+)/.exec(t);
        if (merged) {
          const n = parseInt(merged[1], 10);
          if (!found.has(n)) {
            found.set(n, {
              n,
              sb: Number(merged[2].replace(/,/g, '')),
              bb: Number(merged[3].replace(/,/g, '')),
              text: t,
            });
          }
        }
      }
      return Array.from(found.values()).sort((a, b) => a.n - b.n);
    });
    if (levels.length) return levels;
    await page.waitForTimeout(600);
  }
  return [];
}

/**
 * The document's ladder bar: SB < BB on every row, blinds always rise, and
 * no step is bigger than ×2. `openSb`/`openBb` pin the documented opening.
 */
export function checkLadder(
  levels: Level[],
  where: string,
  opening?: { sb: number; bb: number },
  minLevels = 6,
): void {
  if (levels.length < minLevels) throw new Error(`${where}: only ${levels.length} levels parsed`);
  if (opening) {
    const first = levels[0];
    if (first.sb !== opening.sb || first.bb !== opening.bb) {
      throw new Error(`${where}: opens ${first.sb}/${first.bb}, expected ${opening.sb}/${opening.bb}`);
    }
  }
  for (let i = 0; i < levels.length; i++) {
    const l = levels[i];
    if (!(l.sb < l.bb)) throw new Error(`${where}: L${l.n} has SB ${l.sb} not below BB ${l.bb}`);
    if (i === 0) continue;
    const prev = levels[i - 1];
    if (!(l.bb > prev.bb)) {
      throw new Error(`${where}: L${l.n} BB ${l.bb} does not rise above L${prev.n} BB ${prev.bb}`);
    }
    const ratio = l.bb / prev.bb;
    if (ratio > 2.0 + 1e-9) {
      throw new Error(`${where}: L${l.n} steps ×${ratio.toFixed(2)} from L${prev.n}`);
    }
  }
}
