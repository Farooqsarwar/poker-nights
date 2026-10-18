import { test } from '@playwright/test';
import { appText, expectText, launchApp } from '../acceptance/helpers/flutter';
import { ensureAccount } from '../acceptance/helpers/auth';

/**
 * Probe 10: can we activate Flutter widgets by dispatching a DOM click on
 * their semantics node — no coordinates, no scrolling?
 */
async function jsClick(page: import('@playwright/test').Page, text: string, contains: boolean) {
  const info = await page.evaluate(
    ({ text, contains }) => {
      const norm = (s: string) => s.replace(/\s+/g, ' ').trim();
      const wanted = norm(text);
      let best: HTMLElement | null = null;
      let bestArea = Number.POSITIVE_INFINITY;
      for (const el of Array.from(document.querySelectorAll('flt-semantics')) as HTMLElement[]) {
        const t = norm(el.innerText ?? '');
        const label = norm(el.getAttribute('aria-label') ?? '');
        const doubled = `${wanted} ${wanted}`;
        const hit = contains
          ? t.includes(wanted) || label.includes(wanted)
          : t === wanted || label === wanted || t === doubled || label === doubled;
        if (!hit) continue;
        const r = el.getBoundingClientRect();
        const area = r.width > 0 && r.height > 0 ? r.width * r.height : Number.MAX_SAFE_INTEGER;
        if (area < bestArea) {
          bestArea = area;
          best = el;
        }
      }
      if (!best) return null;
      const r = best.getBoundingClientRect();
      const info = {
        role: best.getAttribute('role'),
        text: norm(best.innerText ?? '').slice(0, 50),
        y: Math.round(r.y),
      };
      best.click();
      return info;
    },
    { text, contains },
  );
  return info;
}

test('probe: DOM click on semantics nodes', async () => {
  const app = await launchApp('qa-a');
  const { page } = app;
  try {
    await ensureAccount(page, 'A');
    await expectText(page, 'Welcome back', 30_000);

    // 1. Bottom-nav "More".
    console.log(`More: ${JSON.stringify(await jsClick(page, 'More', false))}`);
    await page.waitForTimeout(1_200);
    console.log(`  text now: ${(await appText(page)).replace(/\s+/g, ' ').slice(0, 120)}`);

    // 2. "Settings" entry in the sheet.
    console.log(`Settings: ${JSON.stringify(await jsClick(page, 'Settings', true))}`);
    await page.waitForTimeout(1_200);
    const t2 = await appText(page);
    console.log(`  settings reached: ${t2.includes('Account and group preferences')}`);

    // 3. "Chip sets" row — below the fold, no scrolling allowed.
    console.log(`Chip sets: ${JSON.stringify(await jsClick(page, 'Chip sets', true))}`);
    await page.waitForTimeout(1_200);
    console.log(`  chip sets reached: ${(await appText(page)).includes('+ New')}`);

    // 4. "+ New" button.
    console.log(`+ New: ${JSON.stringify(await jsClick(page, '+ New', false))}`);
    await page.waitForTimeout(1_500);
    console.log(`  editor reached: ${(await appText(page)).includes('New Chip Set')}`);

    // 5. Back to Settings link from the editor, then the "Default chip set" row.
    console.log(`Back: ${JSON.stringify(await jsClick(page, 'Back', false))}`);
    await page.waitForTimeout(1_200);
    console.log(`  back reached: ${(await appText(page)).includes('+ New')}`);
    console.log(`Default chip set: ${JSON.stringify(await jsClick(page, 'Default chip set', true))}`);
    await page.waitForTimeout(1_200);
    const t5 = await appText(page);
    console.log(`  sheet reached: ${t5.includes('Default Chip Set')}`);

    // 6. Pick "Home 25" in the sheet (it should list cached sets).
    console.log(`Home 25: ${JSON.stringify(await jsClick(page, 'Home 25', false))}`);
    await page.waitForTimeout(1_200);
    const t6 = await appText(page);
    console.log(`  badge HOME 25: ${t6.includes('HOME 25')}`);
  } finally {
    await app.close();
  }
});
