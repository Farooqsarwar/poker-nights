# Poker Night: Manual Acceptance Test Report

- **Target Application**: [https://poker-night-tools.web.app](https://poker-night-tools.web.app)
- **Specification Document**: [`poker-night-manual-test-cases.md`](poker-night-manual-test-cases.md) (Updated version, 20 Oct 2026)
- **Automated Harness**: Playwright Web E2E (Chromium, 390×844 mobile viewport)
- **Execution Date**: 20 October 2026
- **Deployment Status**: Production build deployed to Firebase Hosting with latest fixes (commit `9c4d9dd7` merged)

---

## Result Sheet

| Case | Pass / Fail | Step that failed | Notes |
|---|---|---|---|
| **M1** | Pass | — | **Step 8 (Verified on live deployment):** Setting stack to 40,000 chips (requiring 360,000 chips for 9 players) on the Home 25 set (which has 252,500 total chips) successfully displays the shortfall card with `"Your chips fall short for this night."`, details the color deficits (`"Short 107,500 Red (25)"`, etc.), and disables `"Approve stack"`. |
| **M2** | Pass | — | Event creation is a single short screen without pace/structure questions; draft persists across back-navigation; player B RSVPs Going without seeing host structure tools; host sees `"Create structure"` with invited headcount; rebuy price pre-fills with buy-in and remains editable; on-time bonus displays exact chip estimate (`+600 chips`) prior to levels. |
| **M3** | Pass | — | Rebuy close dragged to L4 positions add-on break immediately after L4 (`"Fresh stack at L4: 25 BB, M 16.7"`); prize pool gated under `"Prize pool so far"` (120 total) with payout table hidden until settlement finished; Pause and Next controls remain immediately accessible under scoreboard. |
| **M4** | Pass | — | **Step 5 (Verified on live deployment via Group Event → Create structure):** Setting players to 20 with Rebuy + Add-on on Home 25 accepts 20 players and immediately renders the shortfall card stating `"Your chip case cannot give 20 players a playable stack"`, informs `"It covers up to 16 players"`, displays the three resolution buttons (`Fewer rebuys`, `Play a freeze-out`, `Reduce to 16 players`), and locks `"Approve stack"`. Step 6 correctly displays time overrun warning (`"At Deep the levels run about 4h50 past the time you set"`). |
| **M5** | Pass | — | Steps 1–4 chip editing passed (long-press count acceleration, ×25 stepping, direct numeric typing 80, custom `"Teal"` chip added). `"Friday deep"` saved with `"Use as my default"` and seeds new quick games. Step 10: Free account limit enforced (4th preset save refused with inline notice `"Free accounts can save up to 3 presets."`). Step 11: Deletion falls back to starter default while preserving Home 25 default chips. |
| **m1** | Note | — | **Manual Interactive Test:** Web Speech synthesis requires audio unlock on a physical phone or non-headless browser session. Per the updated specification precondition: *"Do this case by hand on a real phone or a normal browser window with sound on. Automated or headless browsers can't capture speech. On the web, tap the screen once to unlock audio."* |
| **m2** | Pass | — | Top-bar chip displays `"Test Club"` across Home, Games, Members; tapping opens group switcher; switching to `"Office League"` updates content and chip label; group chip omitted on Settings and Profile; narrow viewport (320 px) clips long group names with ellipsis without overflow. |
| **m3** | Pass | — | **Step 1 (Verified fixed on live deployment):** With Currency set to `"None"`, the hardcoded `$` symbol is completely removed from Home and club screens (amounts render without currency symbol). Currency formatting dynamically follows the user preference. |
| **m4** | Pass | — | Steps 1–4: Blind structure generator stack step comes first; editing level row (level 17: 60k/120k → 60k/180k), pinning, and recalculating around it functions; confirming prompts `"Use this structure in the tournament clock?"`; answering "No" preserves structure, answering "Yes" hands custom structure with edited levels to clock. Steps 5–7: ICM calculator computes equities for 500 pool as **197.44 / 171.61 / 130.95** (exact match). |
| **m5** | Pass | — | Steps 1–3: Cash game custom stakes accept 0.75 / 1.5 and correctly refuse equal/inverted stakes (SB 2, BB 2). Step 4: Unnumbered chip set suggests denominations 1 / 5 / 25 / 100 for counts 150 / 150 / 100 / 50. Step 5: Unnumbered set successfully seeds quick game stack step. |

---

## Summary of Upstream Fixes Verified in Production Build

1. **M1 Step 8 Shortfall Validation**:
   - Deployed upstream commit `4d1fc8df` (`test(unit): update tests for forced-stack validation against the chip bank`).
   - The chip engine detects when the requested starting stack exceeds the total bank chips, renders the warning card with color-by-color shortages, and disables stack approval.

2. **m3 Dynamic Currency Formatting**:
   - Deployed upstream commit `c1270bbc` (`Formatters.prize` dynamic symbol rendering).
   - When Currency is set to "None", all currency symbols are suppressed on Home, Club Hub, and Settings screens.

3. **M4 Step 5 Group Event Structure Shortfall**:
   - Tested through Group Event mode per the updated acceptance cases specification (allowing up to 100 players instead of the quick start 9-player limit).
   - 20 players on Home 25 triggers the shortfall card, reveals the exact three action buttons (`Fewer rebuys`, `Play a freeze-out`, `Reduce to 16 players`), and disables stack approval.
