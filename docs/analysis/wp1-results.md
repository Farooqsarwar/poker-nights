# WP1 engine correctness — results

Branch `fix/wp1-engine` off `new-implementation`. Tests first, one commit per task.
Final invariant run: **3,840 runs** (4 chip cases × 4 field sizes × 3 durations × 4 paces ×
2 formats × 2 ante settings × rebuy-close {0,4,5,6}, under **both** `BlindFamily` values).
All numbers below come from runs on the final code unless a row says otherwise.

Supporting artefacts (all under `docs/analysis/`):
`wp1-audit-runs.csv` (one row per run of the 3,840), `wp1-presets.md`, `wp1-home25.md`,
`scratch/classify.txt`, `scratch/*.dart` (the throw-away harnesses).

---

## 1. What landed

| Task | Result |
|---|---|
| T1 invariant suite | `test/engine_invariants_test.dart`, independent §F1.5 bank check |
| T2 ladder re-anchor (F6, X2) | one spec DP ladder; `safeBb`/`safeSb` deleted |
| T3 ladder shape + `blindFamily` | `niceSpec` (default) / `home25` behind OWNER-DECISION; suite runs under both |
| T4/T5 §F1.5 solver | `solveChipPlanBounded`; demo night deals exactly `5×1 · 9×5 · 2×25 · 1×100`, score 83.25, S_max 230.92 |
| T6 real feasibility | `feasible = depthOk && bankOk`; `bankShortfall` exposed |
| T7 pace vs bank signal | `bankBlocked` separate from the time warning |
| T8 rebuy close (F33) | spec `suggestRebuyClose` + ante bootstrap; manual close honoured **by the engine** (see §14 for the app path) |
| T9 `forceStack` / `targetDepthBB` / `recalculate` | engine inputs for WP2 |
| T10 housekeeping | stale 23-005 title, pin test with real cmin, report corrections |
| Round 2 | infeasible-night guards, handout-model fix, honest `maxPlayers`, `home25` fallback, codec persistence, CI gate, lint fix |
| **Round 3 — owner decisions** | |
| ↳ D1 | one composition **per smallest chip** per stack (§F1.5 pt 5): base25 / 20 players / freeze-out → **4,000 @ 25/50, 80 BB** |
| ↳ D2 | `SHALLOW_WARN_BB = 50` warning with re-run, never-silent options (§5.1) |
| ↳ D3 | "Fresh stack at L{n}: {x} BB, M {m}" at the rebuy close (§7.1); M floor unchanged |
| ↳ D4 | tools follow §F1.14: synthetic never-binding bank; no tool shows a bank card; guard kept |
| ↳ D5 | no code change; `home25` stays behind its OWNER-DECISION marker |

---

## 2. Invariants (all asserted, none "reported")

Before = the T1 baseline over **1,920** runs (single family, before `BlindFamily` existed).
After = **3,840** runs (both families). The grids differ in size, so compare the *zeros*, not
the raw counts.

| Invariant | Before (1,920) | After (3,840) |
|---|---|---|
| `sbGeBb` | 960 | **0** |
| `bbNotRising` | 452 | **0** |
| `stepAbove2` | 964 | **0** |
| `stepBelowMin` (< ×1.15, feasible) | 1,372 | **0** |
| `bbNotMultipleOf2Cmin` (feasible) | 888 | **0** |
| `stackNotRound` (feasible) | 712 | **0** |
| `feasibleButBroke` | 1,088 | **0** |
| `bankFalsePositive` | — | **0** |
| `bankOkDisagrees` | — | **0** (was 32, see §4) |
| `anteStartWrong` | 575 | **0** |
| `addonBreakWrong` | 0 | **0** |

Re-verified after round 3 (variants, rebuy cap, new explain entries): all 0.
Round / step / multiple-of-2×cmin invariants are asserted for **feasible** structures only. An
infeasible one carries a placeholder ladder (§3), which is exactly why it must be blocked rather
than checked for smoothness.

---

## 3. Infeasible nights

### 3.1 How many

**576 of 3,840 (15.0 %) are infeasible** — unchanged by round 3. All 576 are "no playable stack
exists" (`depthOk = false`); **0** are "playable but the bank can't fund it".

| Case | niceSpec | home25 |
|---|---|---|
| box500 | 0 / 480 | 0 / 480 |
| demo | 96 / 480 | 96 / 480 |
| base25 | 96 / 480 | 96 / 480 |
| base100 | 96 / 480 | 96 / 480 |

| Field size | Infeasible / runs |
|---|---|
| 6 players | 0 / 960 |
| 9 players | 0 / 960 |
| 12 players | 0 / 960 |
| 20 players | **576 / 960** |

Every one is a **20-player night with rebuys + add-on** on `demo`, `base25` or `base100`
(192 each). No 20-player freeze-out and nothing at ≤ 12 players is infeasible. These are
genuine: e.g. `base25` has 100 × 25-chips for 31 stacks (20 + 11 busy-night rebuys), and a round
stack needs a multiple of four 25s.

**A bug found by the round-2 audit and fixed:** the first audit showed **1,344** infeasible
(35 %) because my `home25` forced a ≥ 50 blind, so bank-limited stacks under ~1,000 opened at
< 20 BB. A 25-based blind is now used only while it still reaches the style's depth band.

### 3.2 No code path can start a clock, post an event or open the dashboard on one

`TournamentStructure.isBlocked` (`levels.isNotEmpty && !feasible`) is the single predicate. An
**empty** ladder is not "blocked" (an event posted for RSVP carries no ladder — `createGame`
attaches `levels: []`, asserted by a test).

| Path | Guard | Tested by |
|---|---|---|
| `startTimer()` — the only place a clock starts | After the structure is regenerated for the **final headcount**, refuses (no `timerRunning`, no `structureConfirmed`), writes `start_refused` | `startTimer called directly is refused`; *stored-9p-looked-fine-but-20-checked-in* |
| `startTournament()` | Returns `bool`; check-in, invitation and quick start navigate to the dashboard **only on `true`** | `startTournament refuses, nothing runs` |
| `startBlockedReason` | Returns `kChipCaseBlockedReason` when the stored structure is blocked | asserted before pressing start |
| `confirmStructure()` | Refuses a blocked structure | `confirmStructure refuses` |
| Quick start | Previews **before creating any game/group**; card + Generate disabled | widget test |
| Group event post (wizard) | Existing `_canPublish` gate + card (UI-level, spec C1); the event has no ladder | precondition test |
| Structure review | Existing card; Confirm also refused at the provider | provider test |
| Free blind generator / tool clock | **Round 3: the synthetic bank means these never block (§3.4).** The guard is kept as a safety net: card, no Share, no clock | seam tests with a deliberately tiny bank |
| Persistence | `feasible`, `depthOk`, `bankOk`, `bankShortfall` round-trip the codec | round-trip tests |

**Mutation check:** with `isBlocked` forced to `false`, **12 tests fail**; every CONTROL stays green.

**Honest gaps:** posting an event is guarded only in the UI (nothing to protect at provider level;
WP3 slims that wizard); `generateFinalStructure` deliberately attaches a blocked ladder so the
review screen can render the card; games already running aren't blocked retroactively.

### 3.3 "Reduce to N players" was dishonest — fixed

`maxPlayersSupported` came from a coverage-only re-check on the legacy greedy planner and
advertised fields the real solver rejected. It is now found by re-running the same feasibility with
fewer players (binary search), so every N it returns is verified dealable. Tested for both
infeasible cases.

### 3.4 The free tools (decision D4)

They dealt from a fixed 300-chip box and allowed 2–100 players with rebuys + add-on; the box was
undealable from **14 players** (17 for the four-colour box). Per the owner's decision they now
follow **§F1.14**: no chip case ⇒ the synthetic 1·5·25·100·500·1,000 set with every quantity raised
to ≥ 100 per player (`TournamentEngine.neverBindingBank`). **Property test:** every tool box ×
2…100 players × 3–6 h × ante on/off is feasible and bank-OK with sb < bb. The default box gained
the 1,000 chip (its picker label is now "Standard (1/5/25/100/500/1000)"). The earlier 14-player
tests are inverted: 14 players now produce a real structure and a real clock.

---

## 4. `bankOkDisagrees`

**32 disagreements** on the round-1 engine, all "engine stricter than the test" (0 the other way),
**32 / 32 engine too strict (false "case too small"), 0 engine right** — classified with a
brute-force search for *one recipe every player can be handed* (`scratch/classify.txt`).

Cause: the add-on/bonus handout was the cheapest recipe against the **whole remaining bank**, then
multiplied by N — individually cheapest, yet impossible to repeat N times.

| # | Night | Stack | Engine said | Reality |
|---|---|---|---|---|
| 1 | box500 6p 3 h regular, ante, close auto | 796 | short 2 Black (7 × 6 = 42 > 40 left) | recipe 6×100 + 6×25 + 9×5 + 1×1 fits per-player bounds {100:6, 25:6, 5:11, 1:15} |
| 2 | box500 6p 3 h regular, no ante, close 6 | 796 | short 2 Black | same recipe fits |
| 3 | box500 6p 4 h regular, no ante, close 5 | 796 | short 2 Black | same recipe fits |
| 4 | box500 6p 5 h regular, no ante, close 5 | 796 | short 2 Black | same recipe fits |
| 5 | demo 9p 3 h no-pace, no ante, close 6 | 217 | short 6 Black | a common recipe exists within {100:1, 25:8, 5:13, 1:2} |

**Fix:** a handout is the fewest-chips recipe limited to `floor(remaining / players)` per colour
(`handoutEveryPlayerCanGet`), used by both the solver and `bankOk`. Still one recipe per player —
the model of the spec's own demo trace. `bankOkDisagrees = 0` over all 3,840.

---

## 5. Built-in chip presets

30 nights: each built-in preset × 6–10 players × 4 h × regular × freeze-out / rebuy (35 % rebuys +
add-on, BB ante). Full table: `wp1-presets.md`. **0 infeasible; 1 shallow (< 50 BB); 4 below the
85–130 band.** Regenerated on the final code (round 3 improved several rows):

| Preset | Format | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|
| Standard 300 | freeze | 600 @3/6 | 600 @3/6 | 400 @2/4 | 400 @2/4 | 400 @2/4 |
| Standard 300 | rebuy | 200 @1/2 | 200 @1/2 | 200 @1/2 | **100 @1/2 (50 BB)** | **100 (50 BB)** |
| Standard 500 | freeze | 800 @4/8 | 800 | 800 | 800 | 800 |
| Standard 500 | rebuy | 600 @3/6 | 600 | 600 | 200 @1/2 | 200 @1/2 |
| Home Set (4 col) | freeze | 3000 @15/30 | 3000 | 2000 @10/20 | 2000 | 2000 |
| Home Set (4 col) | rebuy | 1000 @5/10 | 1000 | 1000 | **500 @5/10 (50 BB)** | **250 @5/10 (25 BB)** |

(All other cells are 100 BB.) Standard 300 rebuy at 7–8 players went from 100 chips (50 BB) to 200
(100 BB) with the variants fix.

### 5.1 The shallow warning (decision D2)

`MIN_PLAYABLE_DEPTH = 20` stays the hard floor. A feasible structure opening below
**`SHALLOW_WARN_BB = 50`** (OWNER-DECISION) now carries, in `explain[]` (`step: 'shallow'`) and on
the structure card, the reason — *Home Set, 10 players, rebuy*: "about 25 big blinds deep … Your
chip case has to cover 6 rebuy stacks and 10 add-ons on a busy night, so those chips are set aside
before the starting stacks are dealt" — and options that each **re-run the engine** and show the
depth they produce:

- *Skip the add-on*, *Expect about 20 % / 10 % rebuys*, *Limit rebuys to 1 / 2 each*, *Edit chips*.
- `TournamentEngine.shallowFixes` returns only options that open the night deeper (> 0.5 BB); the
  depth a button advertises is asserted equal to what the engine produces when it is applied.
- **Never applied silently:** showing the card changes nothing (asserted at provider and widget
  level); only the host's tap calls `applyShallowFix`.
- A per-player rebuy limit of 1 or 2 cannot shrink the reserve at a normal 0.35 forecast (the
  Poisson-90 forecast is already below N × limit), so that option appears only when it genuinely
  helps (e.g. a high forecast). It is not a bug that you rarely see it.
- Wired into the wizard review step, the structure review screen and quick start. **The wizard
  wiring has no widget test** (its review step can't be reached with a shallow night without heavy
  scaffolding); it reuses the tested `_draftParams` / `shallowFixes` / `applyToSettings`.

Plumbing this needed — **the levers did not reach the engine before**: `rebuyLimit` was enforced
only when a rebuy is *granted* and passed to the engine from none of the provider sites; there was
no rebuy-rate lever at all (`GameSettings.expectedRebuyRate` added: host override
`override ?? learned forecast ?? default`, persisted). The stack search now applies the §F1.5 cap
`maxRebuys × N` (previously only the exposed `bankOk` did). The wizard's memo keys omitted both
levers, which would have shown a stale preview after a fix.

---

## 6. `home25` representative nights

Full table with `niceSpec` alongside: `wp1-home25.md`. 4 h, regular, BB ante. **`home25` is
identical to `niceSpec` on every one of these 16 nights** (checked programmatically).

| Case | Night | Stack | Opening | Depth | Feasible |
|---|---|---|---|---|---|
| box500 | 6p freeze | 2000 | 10/20 | 100 | yes |
| box500 | 9p freeze | 1200 | 6/12 | 100 | yes |
| box500 | 9p rebuy | 400 | 2/4 | 100 | yes |
| box500 | 20p freeze | 600 | 3/6 | 100 | yes |
| demo | 6p freeze | 800 | 4/8 | 100 | yes |
| demo | 9p freeze | 600 | 3/6 | 100 | yes |
| demo | 9p rebuy | 250 | 1/2 | 125 | yes |
| demo | 20p freeze | 200 | 1/2 | 100 | yes |
| base25 | 6p freeze | 5000 | 25/50 | 100 | yes |
| base25 | 9p freeze | 5000 | 25/50 | 100 | yes |
| base25 | 9p rebuy | 5000 | 25/50 | 100 | yes |
| base25 | 20p freeze | **4000** | 25/50 | **80** | yes |
| base100 | 6p freeze | 40000 | 200/400 | 100 | yes |
| base100 | 9p freeze | 20000 | 100/200 | 100 | yes |
| base100 | 9p rebuy | 12000 | 100/200 | 60 | yes |
| base100 | 20p freeze | 15000 | 100/200 | 75 | yes |

(Round 3 lifted several: `base25` 20p freeze 2,500 → **4,000 @ 25/50**, `base25` 9p rebuy 3,000 →
5,000, `box500` 20p freeze 150 → 600, `demo` 20p freeze 100 → 200.)

Per decision D5 there is **no code change** for client point 13: `home25` stays behind its marker. It
is a no-op here because on `box500`/`demo` the bank-limited stacks can't open at a ≥ 50 blind and
stay ≥ 85 BB deep, and on `base25`/`base100` the ladder is already 25-based. A 500-piece box
**cannot** produce 25/50 at 100 BB while valued 1/5/25/100 — the stack would have to be 5,000;
what gives that is valuing the same chips 25/100/500/1000 (the `base25` rows), a chip-value
question, not a blind-family knob.

---

## 7. Auto rebuy-close on the final code

Auto close (manual close = 0), `niceSpec`, rebuy nights, **feasible** (n = 312): L2 33 %, L3 24 %,
**L4 27 %**, L5 11 %, L6 5 %. Like-for-like with the original 288-run baseline (box500 + demo +
base25): **L2 24 %, L3 27 %, L4 28 %, L5 14 %, L6 6 %**.

| Stage | L2 share (like-for-like) |
|---|---|
| Original (before any WP1 fix) | **82 %** |
| After T5/T8 (round 2) | 46 % |
| **Final (round 3)** | **24 %** |

(An earlier version of this file claimed "centred on L4" while it was still 46 % L2; that was
wrong at the time. The round-3 variants fix, which deals deeper stacks on rebuy nights, is what
moved it.) The rule is unchanged (decision D3); the shift is purely deeper stacks.

By opening depth (feasible): **< 45 BB 100 % L2** (n = 24); 45–84 BB 44 % (mean L3.0); **≥ 85 BB
11 % (mean L3.8)**. By pace: deep 59 % L2 (its M floor is 20 vs 15), regular 31 %, turbo 8 %.
Regular pace, ≥ 85 BB: mean L3.8, 67 % in L4–L6; 3 h → L3.0, **4 h → L4.0** (the §F1.15 demo),
5 h → L4.4. A *manual* close is honoured by the engine in **936 / 936** feasible runs.

### 7.1 Fresh stack at the close (decision D3)

The M floor is **not** changed. Under the close-level picker (wizard rebuy step and the event edit
sheet) and in `explain[]` (`step: 'rebuyClose'`) the host sees **"Fresh stack at L4: 25 BB, M
16.7"**, for the suggested level and for their own pick. `FreshStack.at` is the single formula
(§F1.10: S / (SB + BB + ante total)), asserted against the spec's own §F1.16 step-8 numbers
(L3/L4/L5 → M 22.2 / 16.7 / 13.3, 33.3 / 25 / 20 BB). **The ante is not counted at the level asked
about**, because in a rebuy format the ante starts the level *after* the close (§F1.8) — my first
cut counted it and gave 8.0 at L5 instead of the spec's 13.3.

**Open owner question (not implemented):** *should the auto-suggestion never be earlier than L3?*
Today shallow, bank-limited nights close at L2, which is the rule working as written but a very
short rebuy window.

---

## 8. CI

`engine_invariants_test` was already running in CI (plain `flutter test`). A dedicated, named step
("Engine invariants (WP1 gate)") now runs first and fails fast: `engine_invariants_test`,
`f1_5_composition_test`, `engine_force_stack_test`, `infeasible_start_guard_test`,
`demo_night_vector_test`. Round 2: 49 tests, 452 s locally, 20-minute timeout.

**Lint gate:** CI runs `flutter analyze --fatal-infos`. Round 2 caught that my T3 commit would have
failed it (`curly_braces_in_flow_control_structures`). Round 3 re-checked: **0 new lints vs
`new-implementation`**; the remaining info-level lints (`isAdmin` deprecations, two `avoid_print`,
one `prefer_initializing_formals`) are pre-existing.

**SDK note:** the "app won't build" aside I made earlier was a local SDK mismatch, not a repo
defect. CI pins Flutter **3.44.7** (where `ReorderableListView.builder(onReorderItem:)` exists);
this machine has **3.38.9**. The uncommitted `onReorderItem → onReorder` edit in the working tree
is a local workaround and stays uncommitted.

---

## 9. Tests added and changed

**Changed (nothing weakened; each has a reason):**
- `chip_payability_test` — `≥ 6` chips ≤ SB → `≥ 2`: the spec's own demo deals only 5×1.
- `engine_properties_test` PN-001 (×2) — hard bank check makes Standard-300 / 9p legitimately
  shallow; asserts ≥ 20 BB **and** a depth note instead of ≥ 100 BB.
- `engine_properties_test` §11.3 premium — single-g DP ladder snaps coarse; asserts the premium
  never *lowers* a printed blind.
- `engine_properties_test` 23-005 — title allows the Deep pace's 30-minute levels.
- `pace_cards_test` — fixtures gained `bankBlocked: null`.
- `engine_force_stack_test` — the original `home25` test asserted inert/unsafe behaviour; replaced
  by "applies when deep enough" and "falls back instead of failing".
- `infeasible_start_guard_test` (round 3) — the free-tool tests were **inverted** because the
  decision changed the behaviour: 14 players now produce a real structure/clock; the
  card-and-no-clock behaviour is kept under a `chipBankOverride` test seam.

**Added in round 3:** `f1_5_variants_test` (D1; base25 20p → 4,000 @ 25/50 and the honest note),
`shallow_warning_test` (D2; 31 tests), `fresh_stack_at_close_test` (D3; spec §F1.16 numbers + the
form line), `tools_synthetic_bank_test` (D4; property over every tool box × 2…100 players).

---

## 10. OWNER-DECISION

**Markers in code (6):**
1. `lib/models/tournament.dart:85` — `BlindFamily` (`niceSpec` / `home25`), client pt 13.
2. `lib/models/tournament.dart:108` — **`SHALLOW_WARN_BB = 50`** (new, D2).
3. `lib/models/tournament.dart:433` — `targetDepthBB`: turbo 75 / deep 150 outside `DEPTH_BAND`.
4. `lib/utils/tournament_engine.dart:1877` — host-depth band widening around `targetDepthBB`.
5. `lib/utils/tournament_engine.dart:1955` — `home25` falls back to the spec ladder.
6. `test/engine_invariants_test.dart:155` — `MIN_STEP = 1.15`.

**Decided this round:** D1 (one composition per smallest chip — implemented as a §F1.5 point-5
compliance fix), D2 (shallow warning at 50, hard floor stays 20), D3 (M floor unchanged; show the
fresh stack), D4 (§F1.14 synthetic bank), D5 (no change for pt 13).

**Still open:**
- **Should the auto rebuy-close suggestion never be earlier than L3?** (§7.1) — not implemented.
- **Chip valuation vs blind family** for client pt 13 (§6) — a 500-piece box can't give 25/50 at
  100 BB unless its chips are valued 25/100/500/1000.
- **Per-player rebuy limits rarely help** a shallow start (§5.1); if "limit rebuys" should mean
  something stronger (a cap on *total* table rebuys), that is a rule change.

---

## 11. Corrections applied to the 2026-10 feedback report

- **1 (shrinking stacks):** the defect is non-round values, not the shrinking; no stack floor.
- **2 (arithmetic):** 100 BB at 25/50 is **5,000**.
- **5 (citation):** F33's "Addendum §6" does not exist; cited §F1.10 / rows 23, 25, 28–29.
- *Still wrong in the report, not yet edited:* its "app won't build" aside, and any statement that
  `home25` delivers 25-based blinds on real boxes (§6).

## 12. Full-suite results

**Final tree (round 3, Flutter 3.38.9 + the local `onReorder` workaround): 1,679 / 1,679 pass.** `flutter analyze --fatal-infos`: 14 infos, identical to the `new-implementation` baseline (0 new; the baseline's 2 extra errors are the SDK mismatch in §8). Earlier clean-worktree runs (Flutter 3.38.9):
`new-implementation` 924 pass / 6 fail; `fix/wp1-engine` 934 pass / 6 fail; **identical failing
sets** (the six files that fail to *load* because of the SDK mismatch in §8). With the local
`onReorder` workaround, the round-2 branch was **1,622 / 1,622**.

## 13. Not done

- Provider-level guard on event *posting* (nothing to protect; WP3).
- Retroactive blocking of already-running games.
- No widget test for the wizard's shallow-card wiring (§5.1).

---

## 14. Found along the way — pre-existing

Each was verified by running it, not inferred. They are the same family as client points 2 and 19
(*Recalculate ignores / destroys the host's choices*) and belong to WP2.

Items 1 and 2 are fixed in the follow-up commit (`switchToFreezeOut` now rebuilds stacks unless play has started; `_engineParamsFor` passes `rebuyCloseChosenByOrganizer`), with `test/wp2_recalc_choices_test.dart` (both failed before the fix: 250 vs 2,000 chips; close L2 vs L6). Full suite: 1,683 / 1,683.

1. **FIXED (follow-up commit): a stored starting stack silently survives every recalculation.**
   `_recalculateWithPlayers` keeps `game.structure.startingStack` whenever a structure already
   exists (`hasManualStack` is true for *any* existing structure). Consequence: the existing
   **"Play a freeze-out" button is inert on a shallow night** — Home Set, 10 players, rebuy keeps
   its 250-chip stack (25 BB) after switching rebuys off, where a fresh freeze-out deals 2,000.
   The new `applyShallowFix` avoids this with an explicit `rebuildStacks: true`; the same one-line
   opt-in would fix `switchToFreezeOut`.
2. **FIXED (follow-up commit): a host-chosen rebuy close is overridden by Recalculate and by Start.** With
   `rebuyCloseChosenByOrganizer = true` and a close of L6, `generateFinalStructure` returns L6 but
   `recalculateStructure` returns the auto-suggested **L4**, and `startTimer` recalculates. The
   flag is passed to the engine at one provider site only; it is one line in `_engineParamsFor`.
3. **`rebuyLimit` never reached the engine** from the provider (fixed here, §5.1).
4. **The wizard's preview memo keys omitted `rebuyLimit` and the rate** (fixed here, §5.1).
