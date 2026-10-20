import type { Page } from '@playwright/test';
import { appText, expectNoText, expectText, hasText, tap } from './flutter';
import { typeInto } from './auth';
import { openChipSets } from './nav';

/**
 * Chip-set automation for Settings → Chip sets, whose editor is
 * lib/screens/shell/edit_chip_set_screen.dart on the app side.
 *
 * Verified structure of the editor (see file header for flow):
 *   - "Set name"            AppTextField (placeholder "e.g. My Tournament Set")
 *   - "+ Add denomination"  adds one chip and immediately opens the palette
 *                           dialog: swatches are labelled with their colour
 *                           name (White, Red, Green, Black, Blue, Yellow,
 *                           Pink, Purple, Orange, Grey) and the confirm button
 *                           is "Add chip".
 *   - per row: "Value" text field, plus a CountStepper with semantics label
 *     "<Colour> chip quantity". Tapping the stepper's number opens an
 *     "Enter number" dialog whose field is autofocused with the text
 *     selected — type the number and press "Apply".
 *   - "Save" commits and returns to the list.
 */

export interface ChipSpec {
  color: string;
  value: number;
  quantity: number;
}

/** The document's "Home 25" set: Red 25×100, Green 100×100, Black 500×80, Purple 1,000×50, Blue 5,000×30. */
export const HOME_25: ChipSpec[] = [
  { color: 'Red', value: 25, quantity: 100 },
  { color: 'Green', value: 100, quantity: 100 },
  { color: 'Black', value: 500, quantity: 80 },
  { color: 'Purple', value: 1000, quantity: 50 },
  { color: 'Blue', value: 5000, quantity: 30 },
];

/** The document's "Small box" set: White 1×150, Red 5×150, Green 25×100, Black 100×100. */
export const SMALL_BOX: ChipSpec[] = [
  { color: 'White', value: 1, quantity: 150 },
  { color: 'Red', value: 5, quantity: 150 },
  { color: 'Green', value: 25, quantity: 100 },
  { color: 'Black', value: 100, quantity: 100 },
];

/**
 * Ensures a saved chip set with this exact name exists. Creation is only
 * attempted when the list doesn't already show the name, so re-runs are safe.
 */
export async function ensureChipSet(page: Page, name: string, chips: ChipSpec[]): Promise<void> {
  await openChipSets(page);
  if (await hasText(page, name)) return;

  await tap(page, '+ New');
  await expectText(page, 'New Chip Set', 30_000);
  await typeInto(page, 'e.g. My Tournament Set', name, { fallbackNth: 0 });

  for (let i = 0; i < chips.length; i++) {
    const chip = chips[i];

    await tap(page, '+ Add denomination');
    await expectText(page, 'Pick a color for your chip', 20_000);
    // Swatches carry their colour name as text/aria-label; no role filter.
    // The tap engine waits for the dialog to settle before clicking — these
    // swatches are 39×46 and a mid-animation click misses them.
    await tap(page, chip.color);
    await tap(page, 'Add chip');

    // The new row must carry the chosen colour; a missed swatch leaves the
    // default White and poisons the rest of the set (wrong stepper labels).
    // Wait out the dialog's exit animation first so the swatch text can't
    // satisfy the assertion.
    await expectNoText(page, 'Pick a color for your chip', 10_000);
    await expectText(page, chip.color, 10_000);

    // Printed value — the row's own "Value" field (row order = add order).
    await typeInto(page, 'Value', String(chip.value), { nth: i });

    await setQuantityStepper(page, chip.color, chip.quantity);
  }

  await tap(page, 'Save');
  await expectText(page, name, 30_000);
  const total = chips.reduce((sum, c) => sum + c.quantity, 0);
  await expectText(page, `${chips.length} denominations · ${total} total chips`, 20_000);
}

/**
 * Sets a row's physical quantity via its CountStepper: tapping the number
 * opens an "Enter number" dialog whose field is autofocused and selected.
 * While a Flutter modal is up, background inputs leave the semantics tree, so
 * the dialog's field is the only input; type straight into it.
 */
async function setQuantityStepper(page: Page, color: string, value: number): Promise<void> {
  await tap(page, `${color} chip quantity`, { exact: false });
  await expectText(page, 'Enter number', 20_000);
  await page.waitForTimeout(400); // dialog settle + autofocus

  // While a Flutter modal is up, background inputs leave the semantics tree,
  // so the dialog's field is the only input. Focus it directly (never click
  // by coordinates — see typeInto) and type the number in one event.
  const field = page.locator('input, textarea').last();
  await field.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
  await page.waitForTimeout(120);
  await page.keyboard.press('Control+A');
  await page.keyboard.insertText(String(value));
  await page.waitForTimeout(250);
  const got = (await field.inputValue({ timeout: 3_000 }).catch(() => '')).trim();
  if (got !== String(value)) {
    throw new Error(`quantity dialog for ${color}: field shows "${got}" after typing ${value}`);
  }
  await tap(page, 'Apply');
  await page.waitForTimeout(300);
}

/** Verifies the list shows the set with the expected denomination summary. */
export async function expectChipSetSummary(page: Page, name: string, chips: ChipSpec[]): Promise<void> {
  await openChipSets(page);
  const total = chips.reduce((sum, c) => sum + c.quantity, 0);
  await expectText(page, name, 30_000);
  await expectText(page, `${chips.length} denominations · ${total} total chips`, 20_000);
  const text = await appText(page);
  if (!text.includes(name)) throw new Error(`chip set "${name}" not in list`);
}

/**
 * Sets an inline CountStepper (the ICM calculator's "Prize pool" and
 * "Player N stack" rows, the chip editor's quantity rows) to a new value.
 *
 * Targeted by the number currently shown: those rows put the same words in a
 * plain label text node AND in the stepper's semantics label, so tapping by
 * name can hit the dead label — but the number itself is a proper role=button
 * node (probed) and tapping it opens the "Enter number" dialog.
 */
export async function setCountStepper(
  page: Page,
  currentValue: string | number,
  value: string | number,
): Promise<void> {
  await tap(page, String(currentValue), { exact: true });
  await expectText(page, 'Enter number', 20_000);
  await page.waitForTimeout(400); // dialog settle + autofocus

  // While a Flutter modal is up, background inputs leave the semantics tree,
  // so the dialog's field is the only input.
  const field = page.locator('input, textarea').last();
  await field.evaluate((el) => (el as HTMLElement).focus()).catch(() => {});
  await page.waitForTimeout(120);
  await page.keyboard.press('Control+A');
  await page.keyboard.insertText(String(value));
  await page.waitForTimeout(250);
  const got = (await field.inputValue({ timeout: 3_000 }).catch(() => '')).trim();
  if (got !== String(value)) {
    throw new Error(`stepper ${currentValue}→${value}: field shows "${got}" after typing`);
  }
  await tap(page, 'Apply');
  await page.waitForTimeout(300);
}
