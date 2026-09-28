# Poker Night — Build Plan

**v4.0 · 28 September 2026**
Supersedes BUILD_PLAN v3.1+A1+A2. Every claim in this plan was verified against the
codebase at `HEAD = 7f6f9622` before it was written; the evidence is cited inline.

**Sources and precedence**

| Source | Decides | Status |
| :--- | :--- | :--- |
| `App redesign project.pdf` (the board) | What a screen **looks like** | **Deleted at HEAD.** Recover: `git show a9cc4d3a:"App redesign .pdf"` |
| `Poker_Night_Build_Specification_v3.1.md` + Addenda 1 & 2 | What a screen **does**; the calibrated constants | Present, verified identical to `docs/` |
| `General_Poker_Tournament_Structuring_Framework.pdf` | The **methodology** for structure, and the two layers §F1 omits | New in this revision |
| `research/*.js`, `mockup/*` | The maths, 759 + 55 + 145 vectors | **Absent, never in git history.** See P0.2 |

**How the Framework and §F1 fit together.** They do not conflict. The Framework is the
general method; §F1 is one calibrated instantiation of it. The Framework says so itself
— "100 BB is a strong baseline, **not law**" (§17) and "**No source establishes one
universal multiplier sequence**; the exact curve must be calibrated" (§8). So:

- Where both speak, **§F1's numbers win** (they are owner decisions: `DEPTH_BAND`
  standard `[85,130]`, `K_BASE/K_ANTE` 20/27, `PACE` 15/20/30, `g` caps).
- The Framework supplies the **reasoning and the identities** every §F1 formula must
  satisfy — these become testable vectors that do not depend on the missing JS engines.
- The Framework adds **two layers §F1 does not have**: §13 time-control (compression
  schedule + hard ceiling) and §14 the calibration loop. These are additive. Both are
  **change requests** under Addendum 1's Scope rule and are gated on owner approval
  (§3 below).

**Framework → §F1 symbol map** (put this in a doc comment on the engine; the two
documents collide on the letter `L`):

| Framework | Meaning | §F1 / code |
| :--- | :--- | :--- |
| `X` | starting stack | `S`, `startingStack` |
| `B0` | opening big blind | `BB1 = niceBB(S / STYLE[style].D, cmin)` |
| `D0 = X/B0` | starting depth | `STYLE[style].D`, filtered by `DEPTH_BAND` |
| `N` | entrants | `players` |
| `r = R/N` | rebuy rate | `expectedRebuyRate` (default 0.35) |
| `A` | add-on multiple of X | `addOn.multiplier` (1.10–1.50, default 1.25) |
| `q = S/N` | add-on uptake | `addOn.takeUpRate` (default 0.7) |
| `C` | total chips in play | `meta.C` |
| **`L`** | **number of levels** | **`e`** — §F1 uses `L` for level *length* |
| `t` | level length | `PACE[pace].L` (15 / 20 / 30) |
| `T` | available minutes | `P = max(30, T − breaks − rebuyPause)` |

---

## 1. Constraints (unchanged, restated)

- **No Cloud Functions.** The ruleset is the enforcement layer. Everything on the
  critical path of a live night works without them. §9 lists what is actually lost.
- **No real payment.** Entitlement is device-local. `MockPaymentService` writes
  `'simulated': true` and never touches Firestore.
- **Consequence.** The Premium gate moves to the client (Phase 6). `firestore.rules`
  stops enforcing the seat cap, because it cannot read a device-local entitlement.

## 2. What the previous plan got wrong

Recorded so the same errors are not re-introduced.

| # | Previous plan said | Verified truth |
| :--- | :--- | :--- |
| 1 | P4.4: `players/*` is host-only | **Inverted.** Addendum 1 §2 row 4: co-hosts write `players/*`, `requests/*`, `rsvps/*` under those documents' own rule rows. Only `settings.*`, `hostUid`, `coHostUids` are host-only. Building it as written locks co-hosts out of busts, rebuys and check-ins — the exact D15 duties |
| 2 | P4.4 "narrow co-host rights" | There is **no co-host concept in `firestore.rules` at all**. Authority is `isGroupAdmin` (owner, or member `role == 'admin'`). This is *introduce*, not *narrow* |
| 3 | A1-4 assumes subcollections | `players` is an **array field on the game doc** (`firebase_repository.dart:1548`). `players/{playerId}` (`firestore.rules:660`) is a seat-cap index only. `requests` is **top-level** at `/requests/{gameId}/items/{reqId}` (`firestore.rules:886`). **There is no `rsvps` collection at all.** The addendum's carve-out has nowhere to live |
| 4 | P0.1 "rotate the OneSignal key" closes C2 | Rotation re-bakes a *new* key into `main.dart.js` on the next deploy. The plan's own gate would fail again immediately |
| 5 | P1.1 delete 2 palettes = §B1 conformance | §B1 opens "**Exactly one look**". Deleting 2 of 4 leaves a **two-option** Appearance picker (`settings_screen.dart:499`) |
| 6 | P1.5 "add the `redText` token" | Neither `redText` nor `redDanger` exists anywhere in `lib/`. §B1 line 275 requires every small red text in 186 files to change. The codebase already solves this differently, with derived getters (`destructiveText = lerp(destructive, white, 0.40)`) used in **175 places** |
| 7 | §0.1 "the Dart ports came from `research/*.js` — correct" | Unsupported; §0.3 of the same document says those files were never in the repo. Provenance is **unverifiable** |
| 8 | §10 milestone 1 gate = "vectors rebuilt from spec" | Addendum 1 milestone 1 is "all 759 + 55 vectors passing", **paid on acceptance**. Substituting the gate is a change request, not a plan detail |
| 9 | §2.1 of the conformance report: "the engine work is done" | **The structure engine is missing §F1.3 entirely.** See §4 below |
| 10 | P6.6 "every 47 current paths" | `router.dart` now declares **50** `GoRoute`s. Still zero path parameters |

## 3. Decisions — owner's answers, 28 September 2026

| # | Decision | **Answer** |
| :--- | :--- | :--- |
| **A** | **Hard ceiling** (Framework §13) | **Build it (P2.5).** Agreed change request |
| **B** | **Calibration loop** (Framework §14) | **Build it (P2.6).** Agreed change request |
| **C** | Milestone 1's acceptance gate; the 759 + 55 vectors cannot be run | **Try recovery first.** P0.2 is now a gating task, not a formality. Only if recovery fails does a substitute gate get agreed in writing |
| **D** | OneSignal key compiled into the public JS bundle | **Defer until a server exists.** Do not rotate, do not re-architect. Ship nothing new that uses the key. The current key stays exposed in the deployed bundle; that is an accepted, recorded risk |
| **E** | "Exactly one look" (§B1) | ~~Remove the Appearance picker entirely.~~ **Superseded the same day: the design scheme is frozen.** No colour, token or palette changes. New screens use the design scheme already in the codebase and the board. The §B1 gaps are inventoried in `PROVENANCE.md` §4.1 and revisited after the functional phases. **Note:** T141 cannot pass while frozen, so milestone 2's stated gate cannot be met — see `PROVENANCE.md` §4.1 |

### 3.1 The two change requests, recorded

A and B are **not in Build Specification v3.1**. They come from the General Poker
Tournament Structuring Framework, which the owner supplied on 28 September 2026 as the
authority for how the structure is created. Under Addendum 1's Scope rule they are
change requests: written down here, and agreed before work starts. Cost: **+2.5 days**
on Phase 2 (hard ceiling ~1 day, calibration loop ~1.5).

Neither overrides a §F1 constant. The hard ceiling sits *above* the ladder as a stopping
rule; the calibration loop sits *after* the night as a record. If §F1 and the Framework
ever appear to disagree on a number, §F1 wins — the Framework itself defers ("100 BB is a
strong baseline, not law"; "no source establishes one universal multiplier sequence").

---

## 4. The headline finding: §F1.3 is not implemented

`lib/utils/tournament_engine.dart:3066` says so in its own words:

> `// TODO(spec §F1.3 solveUniformLevels / paceOptions): not implemented.`
> `// This engine has no 'pace' input anywhere in [TournamentParams] at all —`
> `// it derives a per-game growth factor from duration/players continuously`
> `// instead (see 'growthFactor' in [generate]) — so there is no menu of`
> `// discrete pace options to fit or offer. Adding one is a real feature`
> `// (a new params field, new UI, a genuine alternate code path through`
> `// [generate]), not a bug fix, and is out of scope for this pass.`

§F1.3 is the mechanism that fits a night to its finish time. It is precisely what the
Framework's §6 ("Designing for a Fixed Finish Time") is about. **The single thing the
attached Framework document is most about is the thing the engine does not do.**

What *is* built and genuinely good: the DP blind-ladder snap, colour-up planning, ante
recommendation, Poisson-90th chip-bank sizing, rebuy-close suggestion, shootout, and
`structure_verification.dart`. That work stands. The gap is the solver above it.

**Verified divergences from §F1.1 / §F1.3:**

| Spec requires | `TournamentParams` (`lib/models/tournament.dart:156`) has |
| :--- | :--- |
| `startTime`, `endBy` | `durationHours` (a scalar) — a late start cannot shrink `T` |
| `pace` (turbo/regular/deep) | **absent** — pace is *inferred* from depth by `paceStyleFor` |
| `expectedRebuyRate` (0.35) | `bool rebuys` + `rebuyLimit` |
| `addOn {multiplier, takeUpRate}` | `bool addOn` + `addOnCost` |
| `earlyBonusPct` | **absent** |
| `forceStack` | **absent** |
| `C = S(N+R) + A·S·N·q + bonusPct·S·N` | missing the **`bonusPct·S·N`** term (`tournament_engine.dart:2115`) |
| Rebuy pause **10 min** (§F1.2) | `settlementBreakMins = 15` (`tournament_engine.dart:233`) |
| `explain[]` output | **absent** |

---

## 5. Phase 0 — Baseline and provenance (0.5 day)

- **P0.1 — Green the suite first.** `test/icm_test.dart:109` expects `0`; the engine
  correctly returns `100` (two zero stacks, one 100 prize → split the pool). **The test
  is stale, not the engine.** Change to `expect(sum(e), 100)`. Then run `flutter test`
  **to completion** and record the baseline. No later phase is measurable without this.
- **P0.2 — Recover the reference package (decision C: gating).** Look for
  `research/structure_engine.js`, `research/payouts_engine.js`, both test harnesses and
  `mockup/` in the previous repo, in backups, and on the designer's machine. Recover the
  board from git: `git show a9cc4d3a:"App redesign .pdf" > "App redesign project.pdf"`.
  - **If found:** milestone 1's original gate stands, the 759 + 55 vectors run, and
    §G5 row 22's provenance warning is finally discharged. Phase 2 and Phase 3 then
    port *against* the JS rather than against prose, which is a materially different
    (and safer) job — revisit their estimates at that point.
  - **If not found:** record the search in `PROVENANCE.md`, state plainly that the Dart
    ports' provenance is **unverifiable**, and take a substitute gate back to the owner
    **in writing** before Phase 2 ends.
- **P0.3 — OneSignal: deferred (decision D).** No rotation, no re-architecture. Record
  the exposure in `PROVENANCE.md`: the REST key is compiled into `build/web/main.dart.js`
  and is publicly readable; anyone reading the bundle can push to the whole subscriber
  base. **Ship nothing new that depends on the key**, so the blast radius does not grow.
  Revisit when the no-Cloud-Functions constraint lifts. Track with
  `Select-String -Path build\web\main.dart.js -Pattern 'os_v2_app_'` so the exposure
  stays visible rather than forgotten.

## 6. Phase 1 — **DONE, as re-scoped** (design frozen)

The design scheme was frozen part-way through this phase (decision E, §3). Phase 1 was
cut to the three items that do not touch the look. **P1.1, P1.2, P1.3, P1.4, P1.5 and
P1.8 were not done**; they are inventoried as known deviations in `PROVENANCE.md` §4.1.

Completed:

- **P1.6 — Hosting tour removed** (Addendum 2 correction 5). All 9 sites across 6 files:
  the `_showAppTour` field, the `showAppTour` / `setAppTour` accessors, the persisted
  preference and its load path, the Settings row, the `_AdminAppTourCard` dashboard card
  (113 lines) and the invitation screen's tutorial modal and its trigger.
- **P1.7 — Settings DATA section** (§F2 line 1208). Three rows: "Keep my game history to
  improve structures" (D9 consent, new `keepHistoryForStructures` flag, **defaults off**
  because §A4's sign-up checkbox is unchecked by default), "Export my data", "Delete
  account". Export is clipboard-based — the app ships no file-download or share
  dependency and a `data:` URL behaves differently per platform. The delete flow was
  **extracted** to `lib/widgets/delete_account_flow.dart` and is now shared with F1
  Profile, so there is one implementation rather than two; §F2's confirm sentence
  ("Your results stay in the groups' history as 'Former member'.") was added.
- **P1.9 — Privacy claim corrected** (D2). `support_screen.dart` said prize amounts were
  host-only; D2 says everyone sees pool and payouts. **The same false claim was also in
  `privacy_screen.dart`**, the privacy policy itself, which the original plan missed.
  Both fixed.

Styling throughout used existing tokens only.

<details>
<summary>Original Phase 1 scope, retained for when the design question reopens</summary>

- **P1.1 — One look (decision E: remove the picker).** Delete the Appearance picker
  (`settings_screen.dart:499`) and the `paletteId` preference. Remove `cosmicAi`,
  `darkOrange` and `crimsonGlass` from `ThemePalettes.all`; `red` is the only palette.
  Migration: existing users holding a stored `paletteId` fall through
  `ThemePalettes.forId`'s `orElse: () => red`, so no data migration is needed — but
  clear the stored preference so it does not linger.
- **P1.2 — §B1's 13 tokens become the single source of truth.** With one palette, the
  derived `*Text` getters no longer earn their keep: replace them with §B1's literals.
  `bg` `#0A0A0A` · `surface` `#141414` · `surface2` `#1C1C1C` · `border`
  `rgba(255,255,255,0.08)` · `borderStrong` `rgba(255,255,255,0.16)` · `red` `#D53032` ·
  `redText` `#F2555A` · `redDim` `rgba(213,48,50,0.16)` · `redDanger` `#B23430` ·
  `white` `#FFFFFF` · `muted` `#A6A6AA` · `muted2` `#939399` · `green` `#3FBF6B`.
  The 175 `*Text` call sites migrate to the literals. Do this **before** P1.3, so the
  `redText` audit lands on a settled token set rather than being done twice.
- **P1.3 — The `redText` audit.** §B1: *"wherever this document calls text below 24 px
  red or crimson — eyebrows, the LEVEL and ANTE labels, antes in tables, link rows,
  legal headings — it means `redText`, never `red`"*. ~78 candidate sites. `redDanger`
  stays **fill-only**.
- **P1.4 — F5 chip palette (A1-2).** Ten named colours: White, Red, Green, Black, Blue,
  **Yellow**, Pink, Purple, Orange, Grey. Yellow is legal **only** in a real-chip swatch.
- **P1.5 — Clear yellow from the app's own decorations.** `Colors.yellow[700]` in
  `coin_shuffle_animation.dart:18` and `coin_animation_widget.dart:128`.
- **P1.6 — Remove the hosting tour (A2-5).** 9 sites across 6 files: `app_provider.dart:823`,
  `app_provider_auth.dart:146-151`, `app_provider_notifications_settings.dart:170-181`,
  `settings_screen.dart:170`, `admin_dashboard_screen.dart:373,4234`,
  `invitation_screen.dart:102,137`. Includes the device-local `showAppTour` preference.
- **P1.7 — Settings DATA section (A2-6).** Exactly §F2 line 1208: "Keep my game history
  to improve structures" (D9 consent, with the per-group opt-out in B9) · Export my data
  · Delete account, confirm copy "Your results stay in the groups' history as 'Former
  member'." `Delete account` and `Sign out` use `redText`; the confirm button uses
  `redDanger` fill.
- **P1.8 — Replace the three emoji.** `profile_screen.dart:265` 🏆, `:275` 🔥, `:283` 💰,
  plus the badge strings at `:516, :530, :544`. `app_tag.dart` / `icon_tile.dart` are
  the compliant treatment.
- **P1.9 — Fix the privacy claim.** `support_screen.dart:40-41` says results are
  host-only; D2 says everyone sees pool and payouts.

**Gate:** T141 (no yellow pixel) and T102 (contrast) pass in CI.

</details>

## 7. Phase 2 — Structure engine: §F1 + the Framework (5–7 days) · *THE BIG ONE*

Sequenced before payouts because it changes `TournamentParams`, which the wizard,
Configure and quick-start screens all construct. Doing it after means touching those
call sites twice.

> **Design constraint (owner, 28 Sep 2026) — applies to every phase from here on.**
>
> **Layout and flow may change; theme and component styling may not.** Screens can be
> rearranged, rows and cards added or removed, and new screens built, as the documents'
> flows require — using the components and colours that already exist.
>
> So the new UI in this phase — the pace cards, the "nothing fits" warning card, the
> feasibility blocking card, the "Why?" disclosures, the compression-tail labels and the
> post-game calibration record — is laid out to match §F1.3, C1 step 4 and the board,
> and styled with the **existing** tokens (`AppColors.primary`, `card`, `borderSubtle`,
> `mutedForeground`, `destructiveText`, …) and the existing components (`AppButton`,
> `AppPage`, `AppTag`, `IconTile`, `_buildSettingRow`-style rows). Do **not** introduce
> `redText`, `redDim`, `redDanger`, `surface2` or any other §B1 token, do not retune a
> palette value, and do not restyle a button. Where the board
> (`App redesign project.pdf`) draws a screen, follow the board for its layout. The full
> frozen/actionable split is in `PROVENANCE.md` §4.

- **P2.1 — Bring `TournamentParams` up to §F1.1.** Add `startTime`, `endBy`,
  `targetDurationMinutes`, `pace`, `expectedRebuyRate`, `maxRebuys`,
  `addOn {enabled, multiplier, takeUpRate}`, `earlyBonusPct`, `forceStack`. Keep the
  existing fields as deprecated adapters so the 7 `generate` call sites migrate one at a
  time. Put the Framework symbol map in the class doc comment.
- **P2.2 — Fix the chip-supply equation.** Add the missing `bonusPct × S × N` term at
  `tournament_engine.dart:2115`. Correct `settlementBreakMins` 15 → 10 (§F1.2), or
  record why it differs. **Test the Framework's own identity:** with `bonus = 0` and
  `rebuy = X`, assert `C / X == N × (1 + r + A·q)` (Framework §4 and Appendix). This is
  a real vector that does not depend on the missing JS engines.
- **P2.3 — Implement `solveUniformLevels` (§F1.3).** Replaces the continuous growth
  derivation. `P = max(30, T − breaks.total − rebuyPause)` · `BB_end = C / K` (K = 27
  with any ante, else 20) · `BB1 = niceBB(S / STYLE[style].D, cmin)` ·
  `L = PACE[pace].L` · `eFit = max(2, floor(P / L))` ·
  `gFit = (BB_end / BB1)^(1/(eFit−1))` ·
  `fits = gFit ≤ gMax || levelsNeeded × L ≤ P + 5` ·
  `g = fits ? clamp(gFit, 1.2, gMax) : gMax` · `raw[i] = BB1 × g^i` for `i < e + 4`.
  When a pace does not fit, re-plan breaks via `planBreaks(e × L + rebuyPause)`.
  `meta.fits = fits && projectedEnd.minutes ≤ T + 5`.
  **Guard the `L` collision** — Framework `L` = level count, §F1 `L` = level length.
- **P2.4 — Implement `paceOptions` (§F1.3).** Runs the engine 3×. `recommended` = the
  **slowest of Deep, then Regular** that fits *and* whose bank is OK; **turbo is never
  recommended**. Neither fits → `warning` with the exact copy and three `choices`:
  later · noAddOn (only when an add-on is on) · turbo. **Nothing is applied silently**
  (§E17 row 20). Late-start refit keeps `endBy` and shrinks `T` (§E17 row 21); once
  running, no silent regeneration. Gate: T129, T130, T131, T132.
- **P2.5 — Time-control architecture (Framework §13). Approved change request.** All
  three layers, in the Framework's own terms:
  - *Target schedule* — the generated ladder. Exists after P2.3.
  - *Compression schedule* — `_spareLevels = 4` already publishes a tail past target
    (`tournament_engine.dart:228`), but silently, as overtime insurance. The Framework
    requires it **pre-announced**: label those levels in the level list and on the
    Scoreboard so host and players can see the compression before it is needed.
  - *Hard ceiling* — new. Reuse `PayoutsEngine.dealTrigger`'s existing `targetTime`
    trigger (built, unwired, and wired up in P3.6) so the ceiling **offers a settlement**
    rather than inventing a second mechanism. The Framework's test is that an
    uncontrolled extension becomes *impossible*, not merely discouraged: at the ceiling
    the host is given the ICM chop and cannot silently play on past it.
  - Depends on P3.6 for the trigger wiring. If Phase 3 slips, build P2.5's ceiling
    against `dealTrigger` directly and let P3.6 replace the call site.
- **P2.6 — Calibration loop (Framework §14). Approved change request.** Record per
  completed night: N · R · R/N · S alive at the add-on break · add-ons taken · C ·
  level at each time checkpoint · average live stack in BB (`C / (live × BB)`) ·
  **actual finish vs target**. Nothing is recorded today — no `finishedAt`, no take-up
  learning.
  - This is exactly the data §F1's own "last 8 games" rule (spec line 1721) needs:
    `takeUp = mean(addOnsTaken / playersAliveAtTheAddOnBreak)` over the last 8 games,
    clamped 0–100 %, default 70 % below 8 games. Implement that rule here too, now that
    it has a source. Note its stated boundary: it changes only the chips-in-play
    estimate C, **never** the chip-bank check, which assumes every player takes the
    add-on.
  - Surface as a post-game record. "Adjust one major variable at a time" (Framework §14)
    is **guidance shown to the host, not an auto-tune** — Framework §16 is explicit that
    no formula guarantees a finish minute, and silently retuning a structure from
    history would violate §E17 row 20's "nothing is applied silently".
- **P2.7 — Surface feasibility.** Persist `feasible` and `maxPlayersSupported` in
  `model_codec.dart`. Blocking card in C1 step 4 and Configure with the engine's
  sentence and three buttons (Edit chips · Fewer rebuys · Play a freeze-out); **Create**
  stays disabled (§F1.5 point 7, §E17 row 88). Turn `depthShortfallNote` into a
  "Reduce to 9 players" action.
- **P2.8 — Structure vectors.** Rebuild from what can be verified: the Framework's
  identities (P2.2), §F1.15's worked example and §F1.16's step-by-step trace, plus the
  existing property tests. **This is not the 759, and it is not milestone 1's gate**
  (decision C).
- **P2.9 — `explain[]` output.** §F1.1 requires `explain [{step, text, numbers}]`. It
  feeds Phase 3's "Why?" disclosures, so build it here.

## 8. Phase 3 — Payouts onto `PayoutsEngine` (3 days)

`PayoutsEngine` has **zero references outside its own file** — verified. The live app
runs a second, older path in `TournamentEngine`.

- **P3.1** — Rebuild the 55 payout vectors from §F2.12's traces.
- **P3.2** — `PayoutBridge.recalculate` wrapping `PayoutsEngine.payoutPlan`; must compute
  `roundingRemainder`.
- **P3.3** — Delete the shape picker; adopt the owner's shapes (52.5/32.5/15 and
  42.5/30/17.5/10).
- **P3.4** — Move the 5 call sites to the bridge.
- **P3.5** — Reimplement `payoutOptions` on the plan. Fixes §G5 #1 (`suggestPaid`).
- **P3.6** — Wire `dealTrigger` (targetTime → bubble → ITM → headsUp). Fixes §G5 #9, and
  is the mechanism P2.5's hard ceiling uses.
- **P3.7** — Delete the legacy maths. One implementation, not two. Fixes §G5 #8
  (`organiserFee` rounding).

## 9. Phase 4 — Addendum 2 automations (2 days)

- **P4.1** — Add-on window (A2-1). Closes when **Next** is pressed, **or** — if
  settlement step 2 is not done when the break ends — once every player from step 1 has
  taken or declined, shown as "Add-on window (overtime)". *Both* edges. Scrub
  `addOnOvertime` in `publicGameDocSafe()`.
- **P4.2** — Level-change announcement (A2-2): the live region uses **the same words the
  voice uses** ("Level four. Blinds five and ten, ante ten."), **never every second**.
- **P4.3** — Level-change pulse (A2-3): level label + new blinds, 2 × 300 ms, on every
  Scoreboard; reduce-motion → 3-second `redText` outline. Belongs to §E17 row 18.
- **P4.4** — "Fix the count" (A2-4): a **light sheet**, one stepper per colour, changing
  **tonight's game only**. Not the F5 editor. On later registration: "Save these chips
  as 'My chips'?"
- **P4.5** — "Why?" disclosures (§B4 rule 10, T138) on pace, starting depth, paid-places
  curve, chip-bank sizing and the organiser contribution — first sentence visible, the
  rest behind the link. Fed by P2.9's `explain[]`.
- **P4.6** — Un-gate the pace analysis. It is free (D4).

## 10. Phase 5 — Addendum 1 gaps (3–4 days)

- **P5.1** — `soloGames` path and the "Solo" history view for **any signed-in user** (A1-1).
- **P5.2** — Chip-set named-palette UI, save, and value suggestion.
- **P5.3** — Report → group-host push, **unconditional**, cannot be switched off (Apple
  1.2). Count badge on the B9 Reports row (A1-3).
- **P5.4 — Co-host rules, corrected (A1-4).** *Rewritten from the previous plan's
  inverted version.*
  - Introduce `isCoHost(gid)` — it does not exist today.
  - On the **game document**, co-hosts may change only `clock`, `control`, `ledger`.
    Host-only: `settings.*`, `hostUid`, `coHostUids`.
  - **Co-hosts must retain** bust, rebuy, check-in and pause (D15).
  - **The blocker:** `players` is an array field on the game doc, `requests` is
    top-level, `rsvps` does not exist. The addendum's "under those documents' own rule
    rows" has nowhere to live. Choose one, and cost it before starting:
    **(a)** a field-level rule permitting the `players` array but not `settings.*` —
    smaller, keeps the addendum's *intent*, deviates from its letter; or
    **(b)** migrate players into a real subcollection — matches the letter, touches the
    codec, the repository, the seat-cap index and offline recovery.
  - Emulator rules tests proving a co-host **can** bust and check in, and **cannot**
    change the structure, payouts or the organiser contribution.
- **P5.5** — Cash settle-up **Preview** (writes nothing) vs **End session & settle** (A1-5).
- **P5.6** — `groupPreviews/{gid}` for the `/invite/:code` preview (§E6).

## 11. Phase 6 — Premium without a server (2 days)

Note the current deadlock: `entitlements/{uid}` is `allow write: if false`
(`firestore.rules:1027`) while the seat cap requires `isPremiumUser()`
(`firestore.rules:631-667`). **Premium is ungrantable today** — a paying host is hard-capped
at 9. Phases 1–5 ship with that true; it is fixed here.

- **P6.1** — Device-local entitlement keyed to UID, cleared on sign-out. Keep
  `demoPremiumEnabled`.
- **P6.2** — Honest checkout: "Activate Premium (demo — no payment)". No fake card fields.
- **P6.3** — Client-only Premium gate; drop the server seat cap. Implement **D5's actual
  rule** — free stops at the *second table*, not at 9 heads (§E6 checks
  `settings.tables > 1`). The two coincide for a one-table game and diverge when
  `maxPerTable` is set above 9.
- **P6.4** — Host licence (D12) with placeholder pricing (O2: 3 plans, no trial).
- **P6.5** — Stop selling free features. Per D4, **ICM, one TV, unlimited tournaments,
  sync and full level editing are FREE**. `upgrade_screen.dart:62-81` currently sells ICM
  as paid, inverting D4's most explicit decision. `entitlements.dart:46-73` already has
  the correct wording.
- **P6.6** — Codec `_v` version gating; refuse authority over a newer `_v` (§E2 rule 1).
- **P6.7** — Analytics + Crashlytics.
- **P6.8** — Pre-launch: D13 lawyer sign-off, §A3 store readiness.

## 12. Phase 7 — Dynamic routes and missing screens (own branch, 1–3 weeks)

- **P7.1** — Size it: identify every `currentGame` reader.
- **P7.2** — Convert to builders (`/t/:id`, `/groups/:gid/…`, `/join/:code`, `/invite/:code`,
  `/g/:gameCode`, `/tv/:code`, `/chipsets/:id`). Keep legacy redirects.
- **P7.3** — `game_scope.dart` guard; then rewrite as prefix matching.
- **P7.4** — Build the missing screens. §C2 has **59** route rows; `router.dart` has
  **50** `GoRoute`s and **zero** path parameters. Missing: group settings · standings /
  seasons · import past results · group default chip set · group invite · per-tournament
  payouts · deal/chop · `/t/:id/me` · finish order · `/groups/new`. Agree the final list
  against §C2 before starting.
- **P7.5 — Non-regression gate.**
  - Not a single Firestore path changes.
  - All **50** current paths resolve.
  - Cold-start deep link into a live game from a fully terminated app.
  - Mid-game background / foreground / rotate / device switch does not reset the clock.
  - Offline recovery survives a parameterized route.
  - A full scripted night, diffed against `main`.

## 13. Phase 8 — Test and release debt (ongoing)

- Rules emulator suite (`rules-test/` currently holds only a `package.json`). The
  ruleset is the most subtle untested code in the repo.
- §G2.3 behavioural tests; goldens in CI; T141/T102 as a CI gate.
- ARB localisation (after routes settle).
- Co-host read-only levels view (M7).
- Clear stale references to superseded documents ("§11.4", "§24", "v11") so future
  audits are cheap.
- Rename `admin_dashboard_screen.dart`. **Keep the wire value `'admin'`** — the rules
  depend on it.

---

## 14. Sequence

| Phase | What | Days | Ships? |
| :--- | :--- | :--- | :--- |
| 0 | Baseline, provenance, OneSignal | 0.5–1 | — |
| 1 | Design system | 2–3 | **yes** |
| 2 | **Structure: §F1.3 + Framework §13/§14** | 7.5–9.5 | yes |
| 3 | Payouts onto `PayoutsEngine` | 3 | yes |
| 4 | Addendum 2 automations | 2 | yes |
| 5 | Addendum 1 gaps + co-host rules | 3–4 | yes |
| 6 | Premium, entitlement, `_v` | 2 | yes |
| 7 | Dynamic routes (own branch) | 1–3 wk | gated |
| 8 | Test and release debt | ongoing | — |

Phase 1 runs in parallel with Phase 2 — they share no files.

## 15. Milestone mapping (Addendum 1 §1)

| §A3 milestone | Phases | Acceptance gate |
| :--- | :--- | :--- |
| 1 Engines ported, vectors | 0.2, 2, 3 | **P0.2 decides this.** Files recovered → the original 759 + 55 gate stands. Not recovered → a substitute gate goes to the owner in writing before Phase 2 ends |
| 2 Design system + shell | 1, 6.6 | T141 / T102 clean |
| 3 A real night runs | 2, 3, 4 | clock → levels → players → payouts |
| 4 Groups, check-in, Configure | 2.7, 5.1, 5.2 | T18–T20, T25, T57 |
| 5 Seating, deals, results | 3.6, 4.3, 5.5 | T62, T82, T87, T99 |
| 6 Sync, offline, TV, player live | 5.4, 7 | T84, T85; co-host rule tests |
| 7 Cash game, tools, settings | 5.5, 6.4, 6.5 | T87, T33 |
| 8 Premium, readiness | 6 | D13 lawyer sign-off |

## 16. Open decisions (§G3) — built with their "build meanwhile" answer

O1 one codebase, locale-ready · O2 placeholder pricing, 3 plans, no trial · O3 500-piece
box · O4 no currency symbol · O5 voice on at level change only · O6 gesture-initiated TV
sound · O7 suggest seat rebalance · O8 bounty on by default · O9 flat per elimination ·
O10 engine picks the starting stack · O11 europe-west1 · O12 skip weekend reminders.

## 17. What no Cloud Functions actually costs

Functionality: almost nothing. Security margin: four named places, all documented in
`firestore.rules` itself.

- **Push fan-out** — outbox mirrors into each device's inbox on open.
- **Scheduled reminders** — missing; a client timer covers a single-host night.
- **`joinGroup(code)`** — the secret is the code, not the gid.
- **Receipt validation** — moot, no payment.
- **Chat word filter** — a real loss; needs a server.
- **Per-member projections** — `memberViews` is declared and closed. Privacy is by
  omission (`publicGameDocSafe`), not per-role projection. The one user-visible casualty.
- **AI structure generation** — client-side, with `structure_verification.dart`
  re-deriving on device.
- **Seat cap** — becomes client-only in Phase 6. A modified client can host unlimited
  players. Accepted for a private home-poker product.

Narrowing co-host rights (P5.4) is a rules change, so the deployment ends up **more**
secure than today.
