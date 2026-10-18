import { test } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

/**
 * One-off reconnaissance against the deployed app: load it, enable Flutter's
 * accessibility tree, and dump what the semantics DOM actually looks like.
 * Everything in acceptance/helpers is written from the facts this probe
 * prints — run it first whenever selectors start failing after a Flutter or
 * app upgrade.
 */

const OUT = path.join(import.meta.dirname, 'out');

test('probe: dump deployed app semantics DOM', async ({ page }) => {
  fs.mkdirSync(OUT, { recursive: true });

  const consoleLines: string[] = [];
  page.on('console', (msg) => consoleLines.push(`${msg.type()}: ${msg.text()}`));

  await page.goto('/', { waitUntil: 'domcontentloaded' });

  // Flutter mounts <flt-glass-pane> before painting anything.
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 60_000 });

  const placeholder = page.locator('flt-semantics-placeholder');
  const placeholderCount = await placeholder.count();
  let placeholderHtml: string | null = null;
  if (placeholderCount > 0) {
    placeholderHtml = await placeholder.first().evaluate((el) => el.outerHTML);
  }

  await page.screenshot({ path: path.join(OUT, '01-before-semantics.png') });

  // Enable accessibility: click the placeholder, or fall back to a DOM click.
  // This is what turns on the flt-semantics tree that all our selectors use.
  if (placeholderCount > 0) {
    try {
      await placeholder.first().click({ force: true, timeout: 5_000 });
    } catch {
      await page.evaluate(() => {
        const el = document.querySelector('flt-semantics-placeholder');
        if (el instanceof HTMLElement) el.click();
      });
    }
  }

  // Wait for the semantics tree to populate. The splash animation runs ~4 s
  // before the app lands on a real screen, so allow generous settle time.
  await page
    .waitForFunction(() => document.querySelectorAll('flt-semantics').length > 3, { timeout: 30_000 })
    .catch(() => {});
  await page.waitForTimeout(6_000);

  const nodes = await page.evaluate(() => {
    const out: Array<{
      tag: string;
      role: string | null;
      label: string | null;
      text: string | null;
      disabled: boolean;
      checked: string | null;
      tag2: string | null;
    }> = [];
    for (const el of Array.from(document.querySelectorAll('flt-semantics, flt-semantics-host *')).slice(0, 200)) {
      out.push({
        tag: el.tagName.toLowerCase(),
        role: el.getAttribute('role'),
        label: el.getAttribute('aria-label'),
        text: (el.textContent ?? '').trim().slice(0, 100) || null,
        disabled: el.hasAttribute('aria-disabled'),
        checked: el.getAttribute('aria-checked') ?? el.getAttribute('aria-pressed'),
        tag2: el.getAttribute('data-flutter-semantics-id') ?? null,
      });
    }
    return out;
  });

  const story = {
    url: page.url(),
    placeholderCount,
    placeholderHtml,
    semanticsCount: nodes.length,
    labelled: nodes.filter((n) => n.label),
    consoleTail: consoleLines.slice(-40),
  };

  fs.writeFileSync(path.join(OUT, 'semantics.json'), JSON.stringify({ story, nodes }, null, 2));
  await page.screenshot({ path: path.join(OUT, '02-after-semantics.png'), fullPage: false });

  // Show a readable digest in the test log.
  console.log('#semantics nodes:', nodes.length);
  console.log('#with labels:', nodes.filter((n) => n.label).length);
  for (const n of nodes.filter((x) => x.label).slice(0, 60)) {
    console.log(`  [${n.role ?? n.tag}${n.disabled ? ' disabled' : ''}] ${n.label}`);
  }
});
