# Web acceptance automation

Click-through acceptance tests for the DEPLOYED Flutter web app
(https://poker-night-tools.web.app) on production Firebase. Flutter paints to
a canvas, so the tests drive the app through its accessibility/semantics DOM
(`flt-semantics`) the way a screen reader would — real clicks on real widgets,
real text in real fields.

## Run it

    npm install
    npx playwright install chromium   # once per machine
    npm run setup                     # one-time: accounts, groups, chip sets
    npm test                          # all acceptance cases

`npm run report` opens the last HTML report; failing runs keep screenshots and
traces under `.reports/test-results/`.

## What runs

- `acceptance/setup.spec.ts` — prepares shared state: two QA accounts (A host,
  B player), the "Test Club" group (invite code in `.auth/state.json`), the
  "Home 25" and "Small box" chip sets, currency None. Idempotent; reruns
  reuse everything unless `E2E_FRESH=1` (new accounts, clean profiles).
- `acceptance/m1-quick-game.spec.ts` — M1 from the acceptance document: quick
  game from Home, starting stack ≈5,000 at 25/50, level edit + recalculate,
  start; proves the clock is running via the LIVE badge after a fresh boot.
- `acceptance/m4-tools.spec.ts` — m4: the blind-structure generator hands its
  levels to the tournament clock ("Use these blinds" → Yes), and the ICM
  calculator shows the standard equities for the default scenario.
- `probe/*.spec.ts` — small one-off specs used to learn the app's semantics
  while building the harness; not part of the acceptance results.

## How it works

- Phone viewport 390×844, one worker, serial: the QA accounts are shared.
- Accounts and their browser profiles live in `.auth/` (gitignored); Firebase
  sessions persist in the profiles, so reruns stay signed in.
- The current group is not persisted across browser restarts, so tests select
  "Test Club" explicitly through the group switcher (`selectTestClub`).
- The app's `showAppModal` dialogs (e.g. "Your game is live") are NOT in the
  accessibility tree — only the screen behind them is; tests must not depend
  on their text (see M1's header for the workaround).

## Pointers

- `E2E_BASE_URL` overrides the target (e.g. a Firebase preview channel).
- `E2E_DEBUG=1` logs every tap/scroll with coordinates.
- `.reports/parse-trace.mjs` turns a failing run's `trace.zip` into an action
  log for debugging.
