# Poker Night — Build Spec v3.1 Conformance Report

**Date:** 2026-09-28
**Spec audited:** `Poker_Night_Build_Specification_v3.1.md` (3,061 lines, 2026-09-27)
**Codebase:** `HEAD = 8a371c1d` ("Merge Phase 2: align structure/blind engine with Build Spec v3.1 §F1")
**Deployment:** `https://poker-night-tools.web.app` (rules + hosting)

**Stated priorities for this assessment:** functionality first; no Cloud Functions required; dummy/test-mode payments accepted. Where those two constraints conflict with the spec, the verdict below is written from the functionality-first position, and the spec deviation is called out as a known, accepted gap rather than a defect.

---

## 1. Executive summary

The app is a **working tournament manager**, not a mock. The parts that carry a live poker night are genuinely built and genuinely correct: the structure engine, the clock, seating, rebuys, ICM, check-in, the guest flow, projections, and a Firestore ruleset that is far more careful than most production apps ship.

Three things are worth stating plainly before the detail:

1. **Not using Cloud Functions does not break the product.** Every one of the six functions the spec names has a working client-side + rules-based substitute in this codebase. The cost is a specific, enumerable list of security and reliability caveats (§6), not a loss of functionality. The single genuinely user-visible casualty is per-role private projections (`memberViews`).
2. **Dummy payments are fine for what they are doing.** `MockPaymentService` grants a **device-local** entitlement and never writes to Firestore, so it cannot unlock anything server-side. It is correctly self-labelled as simulated. It is a UI gate, not a security gate, and the code says so.
3. **The largest real defects are not backend-shaped.** They are: no dynamic routes (so most of the spec's deep links 404 into a generic error page), an exposed OneSignal credential in a deployed script, a shipped alternative colour theme that breaks the "no gold/amber" owner rule, emoji still live in the profile achievements, and one stale failing test.

**Verdict:** the code is ahead of the spec in security design and behind it in navigation depth and design-system discipline.

---

## 2. What is implemented and working

### 2.1 Structure and blind engine — implemented, and the strongest part of the codebase

| Area | Status | Evidence |
|---|---|---|
| Structure generation | Implemented, heavily tested | `lib/utils/tournament_engine.dart:1706` `TournamentEngine.generate`; ~20 test files (`breaks_test`, `pace_model_test`, `engine_properties_test`, `chip_payability_test`, `ante_recommendation_test`, `payout_rules_test`, `payout_options_test`) |
| Pace model (Turbo 15 / Regular 20 / Deep 30) | Implemented | `TournamentEngine.paceStyleFor`, `admissibleDepthBand` — `test/pace_model_test.dart` |
| Hard 85–130 BB starting depth (2026-09-25 decision) | Implemented | `TournamentEngine.kMinPlayableDepthBB` asserted in `engine_properties_test.dart:345` |
| Add-on break placement after rebuys close (D1) | Implemented | `TournamentEngine.settlementBreakMins` — `test/breaks_test.dart:320` |
| Chip bank sized on Poisson 90th percentile of rebuys | Implemented | `TournamentEngine.poissonQuantile90` — matches the spec's documented demo calculation |
| `suggestRebuyClose` | Implemented, matches spec | Verified against the spec's worked example |
| Shootout (Stage A multi-table → final table) | Implemented | `TournamentEngine.generateShootout` — `engine_properties_test.dart:529` |
| Independent ante recommendation (D7) | Implemented | `TournamentEngine.recommendAnte` — `test/ante_recommendation_test.dart` |
| Structure verification on device | Implemented | `lib/utils/structure_verification.dart`, surfaced by `lib/widgets/structure_audit_banner.dart` |

`TournamentEngine` is used everywhere it should be. The engine work is done.

### 2.2 ICM — implemented and correct

`lib/utils/icm.dart` is a frontier-DP implementation of Malmuth–Harville with a seeded Monte-Carlo fallback above `maxStates`, which is the architecture the spec §F2.5 asks for. It handles zero-stack (busted) players by pushing them to the bottom places and splitting the remainder — the spec's stated rule. Busted-all-live-zero splits the pool equally, which is the only defensible answer and is documented in the code.

Used by `lib/screens/public/tools_screen.dart` (the public ICM calculator) and the tournament screens. One test is stale (see §5.1); the engine itself is right.

### 2.3 Payouts engine — implemented but **not wired into the app**

`lib/utils/payouts_engine.dart` is a large, spec-faithful implementation: `payoutPlan` (ps15 curve, owner shapes 52.5/32.5/15 and 42.5/30/17.5/10, min cash 1.5× buy-in, cash-unit rounding), `organiserFee` (rounds down, fixing the mock's `Math.round` bug from §G5 #8), `roundDeal`, `dealTrigger` (all four types, priority-ordered), `seasonPoints` / `seasonTable` (10 × √(players ÷ finish)), `settleUp` (exact fewest transfers), `leaveForWinner`, `compareDeals`.

**The problem: `PayoutsEngine` has zero references outside its own file.** A repo-wide search for `PayoutsEngine` returns only its own definition and its own doc comments. The live product uses a *second*, older payout path in `TournamentEngine` (`recalculatePrizes`, `payoutOptions`, `roundingUnitFor` — all exercised by `test/payout_rules_test.dart`).

So there are two payout implementations and only the legacy one is running. This is the single largest piece of dead work in the repository.

### 2.4 Rules security — implemented well beyond what the spec's own rules file asks

`firestore.rules` (1,032 lines) is genuinely strong. Notable properties, all verified in the file:

- **Money cannot be created by tampering.** `organizerPctSafe` (0–20%), `prizePoolReconciles` (pool + organizer + remainder == gross), `grossWithinField` (gross ≤ buyIn × heads × 10), `structureShapeSafe` (stack/level/level-count/paid-places sanity bands). `firestore.rules:204-343`
- **A member cannot forge their own seat.** `memberPlayersSafe` rejects `confirmed`, `eliminated`, `hasAddOn`, `rebuys`, `reEntries`, `knockouts` on self-create, and restricts self-updates to `rsvp`/`checkedIn`. `firestore.rules:81-112`
- **Private data genuinely cannot leak.** The public game doc must *omit* `organizerPct`, `prizes`, `organizerAmount`, and must carry an empty audit timeline and request queue — enforced server-side, not just scrubbed client-side (`publicGameDocSafe`, `firestore.rules:175-186`). The admin sidecar is separately value-checked (`privateGameDocSafe`, `firestore.rules:367-395`).
- **Public projections are field-checked**, and prize amounts are forced to an **empty list** with a scalar count alongside, because rules cannot iterate a list (`publicProjectionsSafe`, `firestore.rules:847-867`).
- **Join codes cannot be enumerated** (`allow get: if true; allow list: if false`), and minting a code requires authority over the referenced group (`firestore.rules:760-773`).
- **Email index is hashed and non-enumerable** (`emailIndex/{sha256}`), closing the account-existence oracle. `firestore.rules:795-815`
- **Server-time calibration is per-caller and pinned to `request.time`**, so no client can poison the shared clock offset that drives `levelEndTime`. `firestore.rules:987-993`
- **Premium is read from a document no client can write** — `entitlements/{uid}` is `allow write: if false`, and the free seat cap (`meta/playerCount`) is checked *in the rules* against `isPremiumUser()`. `firestore.rules:62-67`, `631-667`, `1025-1028`

This is a better security posture than the spec's own §E6 table describes, achieved without a single Cloud Function.

### 2.5 The rest of the working product

Also implemented and functional: the multi-screen guest flow (`guest_flow_screen.dart`, 5 states, with a real closed-registration gate), RSVP + waitlist, check-in with pending/confirmed separation, TDA balancing suggestions (`app_provider_players.dart:1567-1613`), rebuy settlement, final-table seat redraw, complete-tournament finish order, cash game with exact fewest-transfers settle-up (`lib/utils/cash_settlement.dart`), TV projection, QR scanning, OneSignal push, offline recovery, audio-master/authority election, a 9-player free seat cap enforced in rules, chip sets, presets, statistics, and ~39 test files with golden probes.

---

## 3. What is not implemented, ranked by how much it matters functionally

### 3.1 Critical — real user impact

**C1. No dynamic routes. Every spec deep link that carries an id is missing.**

`lib/app/router.dart` declares 47 `GoRoute`s, and **not one contains a path parameter**. All `RoutePaths` are static strings (`lib/app/route_paths.dart`). The spec's route table (§C2) is built on parameters:

| Spec route | Status in app |
|---|---|
| `/join/:code` | ✗ — app has `/join?code=…` only |
| `/invite/:code` | ✗ — no group invite preview screen at all |
| `/g/:gameCode` | ✗ — `/guest-flow` takes no code in the path |
| `/tv/:code` | ✗ — `/tv-mode` is unpaired |
| `/t/:id` and 11 siblings | ✗ — the whole `/t/*` family uses a session-global `currentGame` instead |
| `/groups/:gid/settings` | ✗ — no route |
| `/groups/:gid/standings` | ✗ — no route |
| `/groups/:gid/import` | ✗ — no route |
| `/groups/:gid/chips` | ✗ — no route |
| `/groups/:gid/invite` | ✗ — no route |
| `/groups/new` | ✗ — no route |
| `/chipsets/:id` | ✗ — `state.extra` instead of a path param |
| `/start` | ✗ — app uses `/` |
| `/forgot` | ✗ — app uses `/forgot-password` |

**Functional consequence:** the app is fundamentally a *single-current-game* app. A member who is in two groups, or who follows a link to a specific game while another game is loaded, cannot be routed to it — the router has no way to express "this game" and `currentGame` silently decides instead. Links are un-shareable, browser back/forward is not addressable per game, and the spec's deep-linkability requirement (§C3 steps 4, 8, 9) cannot be satisfied. It also means the existing `/game/FP2608` rewrite (`router.dart:153-156`) is the only deep link that works at all, and it depends on `currentGame` being correct.

This is the biggest gap in the report and it is a **structure** problem, not a server problem.

**C2. A live REST credential is embedded in the deployed build path.**

`deploy.ps1:5` holds a plaintext OneSignal REST API key, and line 23 passes it as `--dart-define=ONESIGNAL_REST_API_KEY=…`. Dart defines are **compiled into the JavaScript bundle** — the key is in `build/web/main.dart.js`, which is served publicly. `lib/services/onesignal_sender.dart:36` uses it directly as an HTTP `Key`/`Basic` header.

Blast radius is bounded (send-messages-only scope, one app) but it is a real, publicly readable credential that can be used to send arbitrary push notifications to this app's entire subscriber base. The file is gitignored (`.gitignore:92`) and the header comment acknowledges the risk, but ignoring a file in git does nothing about a key in a public bundle.

**Fix:** rotate the key now, and move send-to-user behind a trusted relay. The client only needs to *request* a send, not hold the key.

**C3. Only one of the four colour palettes is spec-legal, and all four ship.**

The spec is absolute (§B1, §B4.9, D 2026-09-26, T141): black + crimson + white, no gold, yellow or amber anywhere. `ThemePalettes.all` exposes four palettes to users via Settings → Appearance (`lib/screens/shell/settings_screen.dart:276`, `lib/theme/theme_palette.dart:177-182`):

- `red` — `#D53032` on `#0A0A0A`. **Compliant**, and it is the default (`defaultId = 'red'`).
- `crimsonGlass` — compliant.
- `cosmicAi` — blue `#3B82F6` + purple `#8B5CF6` + cyan. Not the spec palette.
- `darkOrange` — **`primary: 0xFFFF6D00`, `icon: 0xFFFFAB40`, `iconMuted: 0xFFFFCC80`, `ring: 0xFFFF6D00`.** These are orange/amber. The spec names amber as a named violation twice, and T141 fails a test on any yellow pixel.

The gold-accent removal work in commit `69b64fb3` was thorough and correct *within* each palette — there are many deliberate "no gold" comments — but the `darkOrange` palette reintroduces the banned hue family wholesale, and it is user-selectable. Two genuine yellow/amber pixels also survive outside the palette: `Colors.yellow[700]` in `lib/widgets/coin_shuffle_animation.dart:18` and `lib/widgets/coin_animation_widget.dart:128`.

**Fix:** delete `darkOrange` and `cosmicAi` from `ThemePalettes.all`, keep the codes but unlist them, and replace the two `Colors.yellow[700]` chip fills with palette-driven values.

**C4. Emoji are still in the product.**

§B4 rule 1 is "No emoji anywhere — not as icons, not in copy". §A5 #6 says the board's emoji achievement chips must be rebuilt with icons from the app's icon set. `lib/screens/shell/profile_screen.dart` still ships three of them:

- `profile_screen.dart:266` `emoji: '🏆'` (FIRST WIN)
- `profile_screen.dart:276` `emoji: '🔥'` (3 IN A ROW)
- `profile_screen.dart:284` `emoji: '💰'` ($1K NIGHT)
- and in the earned-badges copy at `:516`, `:530`, `:544`

`lib/widgets/app_tag.dart` and `icon_tile.dart` exist precisely to be the non-emoji replacement, and the app uses them everywhere else. These three call sites were missed.

### 3.2 High — spec gaps that affect correctness of a live night

**H1. The reference engines and mock are absent, so the spec's own verification gate cannot be run.** `research/structure_engine.js`, `research/payouts_engine.js`, both harnesses and all of `mockup/` are not in the repo. The spec makes the JS engines authoritative ("never re-derive math") and specifies 759 structure vectors and 55 payout vectors with SHA-256 baselines. **None of that can be checked.** The Dart engines may well be correct — §2.1 shows real care — but correctness is *asserted*, not *proven*, and the spec's mock-gap #22 specifically warns against porting from the stale in-mock engines, which is exactly the provenance risk that cannot be ruled out without the files. This is the largest *verification* gap in the project.

**H2. The demo-night vector cannot be executed.** `TournamentParams` has no pace/date inputs and the early-bonus term is absent from the chip-bank calculation `C`, so the spec's worked example is not reproducible through the public API. Either the engine is behind the spec or the model is behind the engine; either way the spec's own worked example is not a regression test today.

**H3. `PayoutsEngine` is dead code.** See §2.3. Everything the spec §F2 asks for exists but nothing calls it. Either wire it and retire `TournamentEngine.recalculatePrizes`/`payoutOptions`, or delete it. Right now the app is shipping the *old* payout rules while the repository contains the new ones — including the `organiserFee` rounding fix from §G5 #8 and the §G5 #1 `suggestPaid` replacement.

**H4. `dealTrigger` is not called.** §G5 #9 names this as a known mock defect to fix, and `payouts_engine.dart:575` implements it correctly. There is no call site. The bubble/deal cards exist; the trigger logic that decides *when to offer* a deal does not run.

**H5. Feasibility fields are computed and discarded.** `feasible` and `maxPlayersSupported` are set on the structure result but are not read by any caller and not persisted by `lib/utils/model_codec.dart:221-257`. So the app cannot tell a host "this will finish at 1:40 a.m." — the single most valuable output of the structure engine.

**H6. `suggestPaid` in the live path.** §G5 #1 says Configure's paid-places suggestion uses a legacy rule and must be replaced by `payoutPlan`. Because H3, it is.

**H7. Support copy contradicts decision D2.** D2: *everyone* sees the prize pool and payouts; only the organiser contribution is hidden. `lib/screens/public/support_screen.dart:40-41` says the opposite — "Prize amounts and the full results table are only shown to the tournament host. Players see their position without anyone else's payouts." This is the exact board copy that §A5 #5 says to replace. It is a factual product-claim error in public copy.

**H8. Upgrade screen sells the wrong Premium.** D4 and §A5 #4 are specific: ICM, one TV, unlimited tournaments, sync, full level editing are **free**; Premium is 2+ tables, seasons & points, TV layouts & more displays, Progressive/Mystery bounties, unlimited templates, graphs & export. `lib/screens/premium/upgrade_screen.dart:62-81` still sells the board's superseded list — "Unlimited tournaments & players", "TV mode & big-screen clock", **"ICM deals & advanced payouts"**, "Cloud sync across devices" — and marks ICM as a paid item, which inverts D4's most explicit monetization decision. `lib/services/entitlements.dart:46-73` documents the correct boundary correctly; only the screen is stale. The comparison table also has no Host-licence row (§A5 #18, D12), and `payment_service.dart:45-59` defines only two plans.

**H9. Missing screens that the spec marks as required.** No group settings screen, no group standings/seasons screen, no import-past-results screen, no group default-chip-set screen, no group invite sheet as a route, no per-tournament payouts screen, no per-tournament deal/chop screen, no per-player check-in-states screen (`/t/:id/me`), no finish-order screen as distinct from complete-tournament, no `groups/new`. Several are reachable by another name (check-in exists as a host screen; complete-tournament covers finish order; cash-game covers both cash routes) but the spec's screen-per-concern separation is not there.

**H10. No "Why?" affordance anywhere.** §B4 rule 10 and T138 require long explanations behind a "Why?" link with the first sentence visible. A search for `'Why'` / `Why?` across `lib/` returns nothing. Inputs and toggles are on screen (that half is satisfied) but nothing is collapsed behind a disclosure.

**H11. Analytics, Crashlytics and localisation are absent.** `pubspec.yaml` has no `firebase_analytics`, no `firebase_crashlytics`. No `.arb` files, no `AppLocalizations` — every string is inline English, so §E1's "all strings in ARB files from day one" is not met. This is launch-blocking for the EU consent flow §E1 describes but **not** functionally blocking for a live night.

**H12. `memberViews` is declared, closed, and never written.** `firestore.rules:587-590` is `allow write: if false` with a comment saying it would need a Cloud Function. The consequence is that all members read the same member-readable game document and privacy is enforced by *omission* (`publicGameDocSafe`) rather than by *per-role projection*. This works and is safe; it just means per-role views (e.g. a co-host seeing a different document than a member) do not exist.

**H13. No codec versioning.** §E2 rule 1 requires every document to carry `_v` and a client to refuse authority over a newer `_v`. A search for a codec version field finds nothing. The single-codec, one-wire-format discipline **is** implemented and used by both Firestore and the local recovery store — that part is right — but the versioning contract is missing, so a future breaking field change has no migration story.

**H14. Free-tier enforcement is a 9-player cap, not a 2-table rule.** The spec's D5 says free stops at the *second table* (10+ players at 9 per table), and §E6 wants `settings.tables > 1` checked against the entitlement. What exists is `meta/playerCount ≤ 9` in the rules plus `Entitlements.canHost` in the UI. For a one-table home game these coincide exactly, so the practical effect is right. The divergence only appears if a host sets `maxPerTable` to 10+ on one table, which the group settings stepper allows (6–12). Minor.

**H15. `groupPreviews/{gid}` is not in the rules.** Spec §E6 lists it as a collection readable by anyone holding the group code, written by Functions only. The app has no invite-preview screen and no such collection — the `/invite/:code` half of C1.

### 3.3 Medium — worth fixing, no live-night impact

- **M1. `pubspec.yaml` references `cupertino_icons` in a comment but does not depend on it** — the Flutter template dependency was removed without updating the comment. Harmless, but it is a stale claim in the manifest.
- **M2. wasm builds are blocked** by `flutter_secure_storage_web` and `localstore` (they use `dart:html` / `dart:js_util`). JS is the deployment target, so this is informational.
- **M3. Rules tests are stubbed.** `rules-test/` contains only a `package.json` — no test files, no emulator suite. A ruleset this subtle (14 helper functions, `getAfter` pairings, the 10-`let` deploy limit) with zero automated rule tests is the highest-risk untested surface in the repo.
- **M4. Screens carry spec references to superseded documents.** Many files cite "§11.4", "§24", "19-019", "specification v11" — from documents v3.1 explicitly supersedes. Not a defect, but it makes the codebase hard to audit against the current spec.
- **M5. `admin_dashboard_screen.dart` filename.** The *UI* was correctly renamed to Host/Co-host in commit `69b64fb3` and the wire value stays `'admin'` (which is correct — the rules depend on it). The filename is the only remaining trace. §A6 says never write "admin" *in the app*; a filename is not in the app, so this is cosmetic.
- **M6. `CoinShuffleAnimation` / `CoinAnimationWidget`** are the two widgets still using `Colors.yellow[700]` (see C3).
- **M7. No `/t/:id/levels` route distinct from the structure review screen** — §C2 lists a host level editor and a co-host view-only variant of the same route. The app has one review screen with no co-host read-only mode.

---

## 4. Can it be implemented without Cloud Functions? (the constraint you set)

Yes, for the large majority. Here is the honest split.

### 4.1 What is already done without Cloud Functions

| Spec requirement (Function) | Current substitute | Verdict |
|---|---|---|
| AI structure generation server-side | Client-side pure engine + `structure_verification.dart` re-derives and compares on device | **Workable.** The spec wanted it server-side to stop a tampered client inventing a structure; instead the rules refuse absurd structures and every device re-derives. Weaker, but functional. |
| Push fan-out | Each member device mirrors the group outbox into its own inbox; OneSignal called from the client | **Workable, with a caveat.** See §5.2. |
| Per-game scheduled reminders | Not implemented at all | **Unaffected** — this is a missing feature, not a Functions casualty. |
| Code reservation | `joinCodes/{code}` created by the authority with a `getAfter`/existence check | **Workable.** `firestore.rules:767-771` requires authority over the target group, which is the real requirement. |
| Receipt validation | **Dummy payment — deliberately local-only** | **Fine for now.** `MockPaymentService` writes to `localstore`, not Firestore, so a purchased tier is *never* server-visible and *cannot* unlock a rules-enforced limit. |
| Account deletion | Client batches delete of own docs | **Workable.** `deleteAccount` clears notifications and results; the rules were explicitly opened for this (see the comments at `firestore.rules:444-450` and `473-478`). |
| Season recompute | `PayoutsEngine.seasonTable` is pure | **Workable** — it's pure maths, no server needed. Currently unreachable because H3. |
| `joinGroup(code)` callable | Membership row created client-side, gated on `viaCode == groups/{gid}.joinCode` | **Workable, weaker.** See §5.1. |
| `resolveJoinCode` callable | `joinCodes/{code}` with `get: if true, list: if false` | **Workable.** A known code resolves publicly by design (QR/invite links must work pre-sign-in); enumeration is closed. |
| Per-role private projections (`memberViews`) | Closed (`write: if false`) | **The one real casualty.** See §6. |

### 4.2 What genuinely cannot be replaced by rules alone, and what it costs

1. **Code secrecy.** The spec says *no client reads* `codes/{CODE}` — only the Function resolves it. The rules open a single-doc GET. A determined caller with one known code learns its `gid` and, if the caller is signed in, can then attempt the self-join check. Practical impact: low (they needed the code already). Spec deviation: real.
2. **Notification fan-out integrity.** Without a server, any member device can create a group notification. Mitigated by payload shape validation, title/body length caps and a 1.5 s rate limit (`firestore.rules:736-749`, `951-963`). A hostile member can still annoy the group on a loop; they cannot impersonate the host, read financial data, or reach outside the group.
3. **Entitlement authority.** `entitlements/{uid}` is `write: if false`, so Premium can only be granted by hand in the console. That is *more* secure than a webhook that trusts a receipt, and it is the right trade at this scale — but it means self-serve purchase genuinely cannot ship without a server. The code already says this (`payment_service.dart:136-137`).
4. **The `playerCount` counter can be walked down.** Documented honestly in the rules themselves (`firestore.rules:619-630`): a client that decrements the counter across many writes can make room for a tenth free seat. Requires a continuous lie to hold; every honest save rewrites it from the real field. Self-acknowledged, self-mitigated.
5. **Member projections.** No per-role documents exist, so "co-host view" and "member view" are the same document. Not a leak — a missing feature.

**Bottom line: no Cloud Functions costs you security margin, not functionality.** The only user-visible loss is per-role private views. The security margin is concentrated in four named places, all documented in the rules file itself.

---

## 5. What to fix, in order

### Fix now (before anything ships or is shared)

**5.1 Rotate the OneSignal key and stop shipping it to the browser.** (C2)
Generate a new key in OneSignal, and change the app so the client never holds a send credential: have the client write a `pushRequests/{id}` document and a trusted relay perform the send. If that is too much for now, at minimum regenerate the key and treat the current one as burned.

**5.2 Delete the non-compliant palettes and the two yellow pixels.** (C3)
Remove `darkOrange` and `cosmicAi` from `ThemePalettes.all` (`lib/theme/theme_palette.dart:177-182`). The constants can stay for reference; they must not be selectable or reachable. Replace `Colors.yellow[700]` at `lib/widgets/coin_shuffle_animation.dart:18` and `lib/widgets/coin_animation_widget.dart:128`. This is what makes T141 passable.

**5.3 Replace the three emoji with icons.** (C4)
`profile_screen.dart:266, 276, 284` and the earned-badge strings at `:516, :530, :544`. `app_tag.dart` / `icon_tile.dart` already provide the compliant treatment.

**5.4 Fix the stale ICM test.** (§5.1 below) — one line, and it stops a red test from masking a real one.

**5.5 Correct the support-screen privacy claim.** (H7) `support_screen.dart:40-41`. D2 is unambiguous and the app implements it; the public copy says the opposite. This is a correctness-of-claim issue, not a style issue.

### Fix next (spec conformance, high value)

**5.6 Rewire payouts onto `PayoutsEngine`.** (H3, H6, H4)
Replace `TournamentEngine.recalculatePrizes` / `payoutOptions` / `roundingUnitFor` call sites with `PayoutsEngine.payoutPlan` / `organiserFee` / `dealTrigger` / `roundDeal`. This is where §G5 #1, #8 and #9 all get fixed at once, and it is the highest-value single change in this report. Then delete the legacy path so there is one implementation.

**5.7 Surface the feasibility result.** (H5) Read `feasible` / `maxPlayersSupported` in the configure and review screens and show the "this finishes at 1:40 a.m." warning the spec asks for. Small change, large user value, and it is the whole point of the engine.

**5.8 Rewrite the upgrade screen to D4.** (H8) Replace the four superseded bullets with the real Premium list, add the Host-licence plan, and stop selling ICM as paid. `entitlements.dart:46-73` already has the correct wording to copy.

**5.9 Recover the reference engines.** (H1) Find `research/*.js` and `mockup/` — from the previous repo, a backup, or the designer's machine. Without them the spec's own verification gate cannot be run and 814 vectors stay unchecked. This is a **provenance** problem, not a coding problem, and it is the one gap that can silently invalidate everything in §2.1.

**5.10 Add "Why?" disclosures.** (H10) Needed on pace, starting depth, paid-places curve, chip-bank sizing and the organiser contribution — the five places the spec explicitly lists.

### Fix when there is time

- **5.11 Dynamic routes.** (C1) The largest single piece of work: introduce path parameters, replace the `currentGame` session-global with route-derived state, and add the missing screens for group settings, standings, import, invite preview, payouts, deal and player check-in. This is what makes the app multi-group and link-shareable. It is also the change most likely to introduce regressions, so it wants its own branch.
- **5.12 Rules tests.** (M3) Turn `rules-test/package.json` into a real emulator suite. The ruleset is the most subtle untested code in the repo.
- **5.13 Codec versioning.** (H13) Add `_v`, and the refuse-newer-authority rule.
- **5.14 Analytics + Crashlytics + ARB.** (H11) Launch-blocking for EU consent, not for a live night.
- **5.15 Co-host read-only level editor.** (M7)

---

## 6. The failing test, stated precisely

`flutter test test/icm_test.dart` → 1 failure of 18.

```
test/icm_test.dart:107  group('edge cases do not explode')  every stack is zero
  Expected: <0>
    Actual: <100.0>
```

**The engine is right and the test is stale.** With two zero stacks and one prize of 100, there is no chip total to weigh anyone's chance by, so the only defensible answer is to split the pool — 50/50, totalling 100. `icm.dart` documents this exact case: *"Nobody has live chips: split every paid place equally — there is no stack to weigh anybody's chance by."*

The test was written against an older engine that returned zeros for a degenerate input — which is arguably worse, because it tells a host the pot is worth nothing when the money is still on the table.

**Fix:** `test/icm_test.dart:109` → `expect(sum(e), 100);` (or assert `[50.0, 50.0]` to pin the even split). Change the test, not the engine.

Note: the full `flutter test` suite was not completed in this pass — it was interrupted. Only `icm_test.dart` was run to completion, and its other 17 tests pass.

---

## 7. Quick reference

| Question | Answer |
|---|---|
| Is the structure/blind engine real? | Yes — the most complete part of the codebase. |
| Is ICM real? | Yes — DP + seeded Monte-Carlo, correct degenerate handling. |
| Is the payouts engine real? | Yes, but **dead code**. The legacy path is what ships. |
| Are the Firestore rules good? | Genuinely good — better than the spec's own rules table. |
| Do deep links work? | No. No route has a parameter. This is the critical gap. |
| Does no-Cloud-Functions hurt functionality? | No. It costs security margin in 4 named places, and per-role private projections. |
| Are dummy payments safe? | Yes — device-local only, cannot unlock anything server-side, correctly labelled. |
| Can Premium actually be granted? | Only by hand in the Firebase console. Self-serve needs a server. |
| Are the colours compliant? | Only 2 of 4 palettes. One ships amber; two yellow pixels remain. |
| Are there emoji? | Yes — 3 in profile achievements. |
| Is the reference-engine verification possible? | No — `research/*.js` and `mockup/` are absent. |
| Is the test suite green? | `icm_test.dart` has 1 stale failure. Full suite not verified this pass. |
