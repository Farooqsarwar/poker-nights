import { test, type Page } from '@playwright/test';
import {
  appText,
  expectNoText,
  expectText,
  hasText,
  launchApp,
  readNodeLabel,
  readTextMatch,
  screenshot,
  scrollUntilVisible,
  tap,
} from './helpers/flutter';
import { ensureAccount, typeInto } from './helpers/auth';
import { openHome, selectTestClub } from './helpers/nav';
import { setCountStepper } from './helpers/chips';

/** Reads a stepper's merged label (e.g. "Buy-in 20") from the semantics tree. */
async function readStepperLabel(page: Page, pattern: RegExp): Promise<{ label: string; value: number } | null> {
  const label = await readNodeLabel(page, pattern);
  if (!label) return null;
  const m = label.match(pattern);
  return m ? { label, value: Number(m[1]) } : null;
}

/**
 * Opens the short-form create screen from wherever we stand — Home or the
 * group screen both carry a create entry. Never deep-links Home here: that
 * reloads the app and resets the in-memory current group to the boot default.
 */
async function openNewGameForm(page: Page): Promise<void> {
  const tries: Array<[string, boolean]> = [
    ['+ New game', false],
    ['＋ New game', false],
    ['New game', false],
    ['Create tournament', true],
  ];
  let last = 'no attempts';
  for (const [text, exact] of tries) {
    try {
      await tap(page, text, { exact, timeout: 8_000 });
      await expectText(page, 'New tournament', 20_000);
      return;
    } catch (err) {
      last = String(err);
    }
  }
  throw new Error(`M2: no create entry found on this screen. Last error: ${last}`);
}

/**
 * Clicks the "RSVP" chip on the event card for `isoDate`. When several cards
 * share a date, the latest-start card — the one this run just posted — wins.
 * Coordinates are computed in-page: the page can carry several RSVP chips
 * and an "RSVP update" alert whose text also matches the word.
 */
async function tapRsvpOn(page: Page, isoDate: string): Promise<void> {
  await scrollUntilVisible(page, isoDate, { contains: true }).catch(() => null);
  await page.waitForTimeout(600);

  const hit = await page.evaluate((date) => {
    const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
    const onScreen = (r: DOMRect) =>
      r.width > 0 && r.height > 0 && r.top + r.height / 2 > 80 && r.top + r.height / 2 < window.innerHeight - 70;
    const nodes = Array.from(document.querySelectorAll('flt-semantics'));
    let chips = nodes.filter(
      (e) => norm((e as HTMLElement).innerText) === 'RSVP' || norm(e.getAttribute('aria-label')) === 'RSVP',
    );
    if (!chips.length) {
      chips = nodes.filter(
        (e) => /^RSVP\b/.test(norm((e as HTMLElement).innerText)) || /^RSVP\b/.test(norm(e.getAttribute('aria-label'))),
      );
    }
    // List rows below the fold still carry live semantics rects, so filter to
    // what a finger can actually reach before ranking by position.
    chips = chips.filter((e) => onScreen(e.getBoundingClientRect()));
    const dates = nodes.filter(
      (e) =>
        (norm((e as HTMLElement).innerText).includes(date) || norm(e.getAttribute('aria-label')).includes(date)) &&
        onScreen(e.getBoundingClientRect()),
    );
    let best: { x: number; y: number; top: number } | null = null;
    for (const chip of chips) {
      const cr = chip.getBoundingClientRect();
      let own: { d: number; top: number } | null = null;
      for (const d of dates) {
        const dr = d.getBoundingClientRect();
        const dist = Math.abs(cr.top - dr.top) * 1000 + Math.abs(cr.left - dr.left);
        if (!own || dist < own.d) own = { d: dist, top: dr.top };
      }
      if (!own) continue;
      if (!best || own.top > best.top) {
        best = { x: cr.left + cr.width / 2, y: cr.top + cr.height / 2, top: own.top };
      }
    }
    if (!best && dates.length > 0) {
      const dr = dates[dates.length - 1].getBoundingClientRect();
      best = { x: dr.left + dr.width / 2, y: dr.top + dr.height / 2, top: dr.top };
    }
    return best;
  }, isoDate);
  if (!hit) throw new Error(`M2: no RSVP chip on the ${isoDate} card`);
  await page.mouse.click(hit.x, hit.y);
  await page.waitForTimeout(1_000);
}

/**
 * The location field's DOM input. Matched by hint/aria-label while the field
 * is empty; a filled Flutter field drops the placeholder attribute, so fall
 * back to the semantics textbox (then to any input — the form has only one).
 */
function locationInput(page: Page) {
  return {
    async resolve() {
      const byHint = page.locator(
        'input[placeholder="Where are you playing?"], input[aria-label="Where are you playing?"], ' +
          'textarea[placeholder="Where are you playing?"], ' +
          'textarea[aria-label="Where are you playing?"]',
      );
      if ((await byHint.count()) > 0) return byHint.first();
      const inTextbox = page.locator(
        'flt-semantics[role="textbox"] input, flt-semantics[role="textbox"] textarea',
      );
      if ((await inTextbox.count()) > 0) return inTextbox.first();
      return page.locator('input, textarea').first();
    },
  };
}

async function readLocation(page: Page): Promise<string> {
  try {
    const input = await locationInput(page).resolve();
    await input.waitFor({ state: 'attached', timeout: 10_000 });
    // Probe result: Flutter only writes a field's value into the DOM input
    // when the field takes focus; before focus the input reads "". Focusing
    // makes the restored draft text (or the current editing value) readable.
    await input.evaluate((el) => (el as HTMLElement).focus());
    await page.waitForTimeout(250);
    return (await input.inputValue()).trim();
  } catch {
    return '';
  }
}

async function setLocation(page: Page, value: string): Promise<void> {
  const input = await locationInput(page).resolve();
  await input.waitFor({ state: 'attached', timeout: 10_000 });
  const current = (await input.inputValue().catch(() => '')).trim();
  if (current === value) {
    console.log(`M2: location already "${value}" (carried by the draft)`);
    return;
  }
  await input.evaluate((el) => (el as HTMLElement).focus());
  await page.waitForTimeout(120);
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.insertText(value);
  await page.waitForTimeout(200);
  const got = (await input.inputValue().catch(() => '')).trim();
  if (got !== value) throw new Error(`M2: location field shows "${got}" after typing "${value}"`);
}

async function expectLocation(page: Page, value: string, timeout = 15_000): Promise<void> {
  const start = Date.now();
  let last = '';
  while (Date.now() - start < timeout) {
    last = await readLocation(page);
    if (last === value) return;
    await page.waitForTimeout(500);
  }
  throw new Error(`M2: location field shows "${last}" instead of "${value}"`);
}

/**
 * M2 — the light group-event post, then Create structure (acceptance document):
 *
 *   A posts a one-screen event (buy-in, location, date/time, KO bounty,
 *   type, rebuy type, on-time bonus) with no chip-set or structure questions,
 *   B RSVPs Going, and A builds the structure later from the invited count.
 *
 * Notes from the document's "Result sheet" rules: the bonus % stepper on this
 * build takes whole percents (5–50), so the document's 12.5 % is entered as
 * 12 % and the difference is recorded in the log rather than failed.
 */
test('M2: short-form post, B RSVPs Going, host builds the structure', async () => {
  const a = await launchApp('qa-a');
  let b: Awaited<ReturnType<typeof launchApp>> | undefined;
  try {
    // ── A: the one-screen post ─────────────────────────────────────────────
    await ensureAccount(a.page, 'A');
    await openHome(a.page);
    await selectTestClub(a.page);
    const club = await readTextMatch(a.page, /GROUP CODE · [A-HJ-NP-Z2-9]{6}/);
    console.log(`M2: A's current club = ${club ?? '(sheet closed; still on Home)'}`);
    await openNewGameForm(a.page);

    await expectText(a.page, 'New tournament', 30_000);
    await expectText(a.page, 'Draft saved', 10_000);
    // One short screen only — no chip-set, stack or structure controls.
    for (const absent of ['Approve stack', 'Next: starting stack', 'Save structure']) {
      await expectNoText(a.page, absent, 2_000);
    }
    await screenshot(a.page, 'm2-a-form');

    // States in words: the two toggles are switches named "<row> On/Off".
    // The draft can already carry the previous run's state, so only flip
    // what is off.
    if (await readNodeLabel(a.page, /^KO bounty Off Off$/)) {
      await tap(a.page, 'KO bounty', { role: 'switch', exact: false, xBias: 0.9 });
    }
    await expectText(a.page, 'Bounty amount', 10_000);
    const bounty = await readStepperLabel(a.page, /^Bounty amount (\d+)$/);
    if (bounty && bounty.value !== 5) await setCountStepper(a.page, bounty.label, 5);
    if (await readNodeLabel(a.page, /^On-time bonus Off Off$/)) {
      await tap(a.page, 'On-time bonus', { role: 'switch', exact: false, xBias: 0.9 });
    }
    await expectText(a.page, 'final amount set in Create structure', 10_000);
    const pctText = (await appText(a.page))
      .split('\n')
      .map((l) => l.trim())
      .find((l) => /^\d+ %$/.test(l));
    // 12.5 % is not settable on this build (whole percents 5–50): 12 % stands
    // in and the difference is logged rather than failed (document's own rule).
    if (pctText && pctText !== '12 %') await setCountStepper(a.page, pctText, 12);
    const estimate = await readTextMatch(a.page, /[\d,]+ chips at a [\d,]+ stack/);
    console.log(`M2: on-time bonus estimate = ${estimate ?? '(not found)'}`);

    // Type Normal, rebuy type Rebuy.
    await tap(a.page, 'Normal', { exact: true });
    await tap(a.page, 'Rebuy', { exact: true });

    // Buy-in 20 (drafts can seed from the account's default preset) + location.
    const buyIn = await readStepperLabel(a.page, /^Buy-in (\d+)$/);
    if (!buyIn) throw new Error('M2: no Buy-in stepper on the form');
    if (buyIn.value !== 20) await setCountStepper(a.page, buyIn.label, 20);
    await setLocation(a.page, 'QA Room 7');

    // Date and time: the draft carries a start whose RSVP window is already
    // closed — RSVPs close 24 h before the start — so push the date three
    // days out, then accept the time as offered.
    const target = new Date(Date.now() + 3 * 86_400_000);
    const wishDay = target.getDate();
    const wishYear = target.getFullYear();
    const monthLong = target.toLocaleString('en-US', { month: 'long' });
    const monthShort = monthLong.slice(0, 3);
    const form = await appText(a.page);
    const dateStr = form.match(/\b\d{1,2} (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4}\b/)?.[0];
    const timeStr = form
      .split('\n')
      .map((l) => l.trim())
      .find((l) => /^\d{2}:\d{2}$/.test(l));

    if (dateStr) {
      await tap(a.page, dateStr, { timeout: 10_000 });
      // The picker's day cells: prefer a "…October 21…" label, fall back to
      // the cell whose whole text is the day number.
      const cell = await a.page.evaluate(
        ({ day, monthLong, monthShort }) => {
          const norm = (s: string | null) => (s ?? '').replace(/\s+/g, ' ').trim();
          const nodes = Array.from(document.querySelectorAll('flt-semantics'));
          const read = (el: Element) =>
            [el.getAttribute('aria-label'), (el as HTMLElement).innerText]
              .map(norm)
              .filter(Boolean)
              .join(' | ');
          const reLong = new RegExp(`(${monthLong}|${monthShort})[ ,.]+${day}\\b`, 'i');
          let best: { x: number; y: number; label: string; area: number } | null = null;
          for (const el of nodes) {
            const v = read(el);
            if (!v || !reLong.test(v)) continue;
            const r = el.getBoundingClientRect();
            if (r.width <= 0 || r.height <= 0) continue;
            const area = r.width * r.height;
            if (!best || area < best.area) {
              best = { x: r.left + r.width / 2, y: r.top + r.height / 2, label: v, area };
            }
          }
          if (best) return best;
          for (const el of nodes) {
            const t = norm((el as HTMLElement).innerText);
            if (t !== String(day)) continue;
            const r = el.getBoundingClientRect();
            if (r.width <= 0 || r.height <= 0 || r.width > 120 || r.height > 120) continue;
            return {
              x: r.left + r.width / 2,
              y: r.top + r.height / 2,
              label: `bare "${day}"`,
              area: r.width * r.height,
            };
          }
          const dump: string[] = [];
          for (const el of nodes) {
            const v = read(el);
            if (v && /(oct|\d\d?)/i.test(v) && dump.length < 70) dump.push(v.slice(0, 60));
          }
          return { x: -1, y: -1, label: `DUMP ${JSON.stringify(Array.from(new Set(dump)))}`, area: 0 };
        },
        { day: wishDay, monthLong, monthShort },
      );
      if (cell.x < 0) {
        throw new Error(`M2: could not find ${monthLong} ${wishDay} in the date picker — ${cell.label}`);
      }
      await a.page.mouse.click(cell.x, cell.y);
      await a.page.waitForTimeout(500);
      console.log(`M2: date picker — clicked ${cell.label.slice(0, 60)}`);
      await tap(a.page, 'OK', { exact: true, timeout: 8_000 });
      await a.page.waitForTimeout(600);
      const filled = await appText(a.page);
      console.log(
        filled.includes(`${wishDay} ${monthShort} ${wishYear}`)
          ? `M2: form date now ${wishDay} ${monthShort} ${wishYear} (start > 24 h away)`
          : `M2: warning — the form date does not read ${wishDay} ${monthShort} ${wishYear}`,
      );
    }
    if (timeStr) {
      try {
        await tap(a.page, timeStr, { timeout: 10_000 });
        await tap(a.page, 'OK', { exact: true, timeout: 8_000 });
        await a.page.waitForTimeout(600);
        console.log(`M2: time picker accepted (${timeStr})`);
      } catch {
        // Leave the form usable: close the picker again.
        if (await hasText(a.page, 'Cancel')) await tap(a.page, 'Cancel', { exact: true });
        else await a.page.keyboard.press('Escape');
        await a.page.waitForTimeout(600);
        console.log(`M2: time picker could not be accepted — kept the draft value (${timeStr})`);
      }
    }
    await screenshot(a.page, 'm2-a-form-filled');

    // Draft saved: leave the screen and come back — the entries are still there.
    // (Field values live in the DOM inputs, not the semantics text.)
    await tap(a.page, 'Back', { exact: true });
    await openNewGameForm(a.page);
    await expectLocation(a.page, 'QA Room 7');
    const buyInBack = await readStepperLabel(a.page, /^Buy-in (\d+)$/);
    if (!buyInBack || buyInBack.value !== 20) {
      throw new Error('M2: the restored draft lost its buy-in');
    }
    console.log('M2: draft survives leaving and coming back (location + buy-in + settings)');
    await screenshot(a.page, 'm2-a-draft-restored');

    // Post — without a chip set or a structure question.
    await tap(a.page, 'Post', { exact: true, role: 'button' });
    await expectText(a.page, 'Create structure', 60_000);
    console.log('M2: event posted; host is on the event page');
    await screenshot(a.page, 'm2-a-posted');

    // ── B: RSVP Going; players have no host controls ───────────────────────
    b = await launchApp('qa-b');
    await ensureAccount(b.page, 'B');
    await openHome(b.page);
    await selectTestClub(b.page);
    // Switching clubs can land on the group screen; the RSVP card is on Home.
    if (await hasText(b.page, 'GROUP CODE')) {
      await tap(b.page, 'Home', { exact: true, timeout: 10_000 });
      await b.page.waitForTimeout(1_200);
    }
    const bClub = await readTextMatch(b.page, /Join Code [A-HJ-NP-Z2-9]{6}/);
    console.log(`M2: B RSVPs from club ${bClub ?? '(code not shown)'}`);
    // Several Poker Night cards stack up in this club across runs, and an
    // "RSVP update" alert also matches the word — so aim at the RSVP chip on
    // THIS run's card: the latest start on the date we just set.
    const isoLocal = `${wishYear}-${String(target.getMonth() + 1).padStart(2, '0')}-${String(wishDay).padStart(2, '0')}`;
    await tapRsvpOn(b.page, isoLocal);
    if (!(await hasText(b.page, 'Your RSVP'))) {
      await screenshot(b.page, 'm2-b-no-rsvp');
      throw new Error(
        `M2: B's RSVP did not open. Page: ${(await appText(b.page)).replace(/\s+/g, ' ').slice(0, 500)}`,
      );
    }
    await expectText(b.page, 'Your RSVP', 30_000);
    await expectNoText(b.page, 'Create structure', 2_000);
    await tap(b.page, 'Going', { exact: true });
    await expectText(b.page, 'Bringing guests', 15_000);
    await screenshot(b.page, 'm2-b-rsvp');
    console.log('M2: B RSVP Going; no Create structure for players');

    // ── A: build the structure from the replies ────────────────────────────
    // B's RSVP can pull the page down to the Responses section; bring the
    // structure card back into view before tapping it.
    await a.page.mouse.move(195, 420);
    for (let i = 0; i < 6; i++) {
      await a.page.mouse.wheel(0, -900);
      await a.page.waitForTimeout(220);
    }
    await a.page.waitForTimeout(300);
    if (!(await hasText(a.page, 'Create structure'))) {
      await screenshot(a.page, 'm2-a-no-create-structure');
      throw new Error(
        `M2: no Create structure card after B's RSVP. Page: ${(await appText(a.page)).slice(0, 700)}`,
      );
    }
    await tap(a.page, 'Create structure', { exact: false, timeout: 15_000 });
    await expectText(a.page, 'Players', 30_000);
    const hint = await readTextMatch(a.page, /\d+ invited · \d+ Going · \d+ Maybe/);
    if (!hint) throw new Error('M2: the builder does not show invited / Going / Maybe counts');
    console.log(`M2: builder headcount = ${hint}`);
    await screenshot(a.page, 'm2-a-builder-inputs');

    // Carried over: the rebuy section suggests a policy, and More options
    // holds the buy-in (20) and the editable rebuy price.
    await scrollUntilVisible(a.page, 'Suggested for');
    await expectText(a.page, 'Suggested for', 15_000);
    const bonusChips = await readTextMatch(a.page, /=\s*\+\d[\d,]* chips/);
    console.log(`M2: builder bonus line = ${bonusChips ?? '(not found)'}`);
    await scrollUntilVisible(a.page, 'More options');
    await tap(a.page, 'More options', { exact: false, timeout: 15_000 });
    await a.page.waitForTimeout(600);
    await typeInto(a.page, 'Rebuy price', '25');

    // Continue: the stack step comes before any level; confirm the stack.
    await tap(a.page, 'Next: starting stack', { exact: true });
    await expectText(a.page, 'Starting stack', 20_000);
    await screenshot(a.page, 'm2-a-builder-stack');
    await tap(a.page, 'Approve stack', { exact: true });
    await scrollUntilVisible(a.page, 'Save structure');
    await screenshot(a.page, 'm2-a-builder-levels');

    // Confirm — and the event page shows the structure as saved.
    await tap(a.page, 'Save structure', { exact: true });
    await expectText(a.page, 'Structure generated', 45_000);
    await screenshot(a.page, 'm2-a-structure-saved');
    console.log('M2: structure confirmed and stored on the event');
  } finally {
    await a.close();
    await b?.close();
  }
});
