import { defineConfig, devices } from '@playwright/test';

/**
 * Poker Night — web acceptance automation.
 *
 * Drives the DEPLOYED Flutter web app (canvas-rendered) through its
 * accessibility/semantics DOM. Flutter paints to <canvas>, so ordinary DOM
 * selectors see nothing; the app is instead located via the `flt-semantics`
 * element tree that Flutter builds once accessibility is enabled.
 *
 * These tests run against PRODUCTION (https://poker-night-tools.web.app) and
 * a production Firebase backend. They are serial by design: one worker, one
 * scenario at a time, so the shared QA accounts never race each other.
 */
export default defineConfig({
  testDir: '.',
  testMatch: ['**/acceptance/**/*.spec.ts', '**/probe/**/*.spec.ts'],
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: 0,
  timeout: 8 * 60 * 1000,
  expect: { timeout: 15 * 1000 },
  outputDir: '.reports/test-results',
  reporter: [
    ['list'],
    ['html', { outputFolder: '.reports/html', open: 'never' }],
  ],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'https://poker-night-tools.web.app',
    // The manual cases specify a phone at ~390 x 844 unless a step says otherwise.
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
    // Never let a browser permission prompt (notifications, etc.) hang a run.
    permissions: [],
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'off',
    actionTimeout: 20 * 1000,
    navigationTimeout: 90 * 1000,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], viewport: { width: 390, height: 844 } },
    },
    {
      // Uses the machine's installed Chrome instead of the bundled Chromium.
      // Useful if Firebase App Check ever refuses the bundled build.
      name: 'chrome',
      use: {
        ...devices['Desktop Chrome'],
        channel: 'chrome',
        viewport: { width: 390, height: 844 },
      },
    },
  ],
});
