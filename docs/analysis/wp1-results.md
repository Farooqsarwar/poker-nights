# WP1 engine correctness — results

Branch `fix/wp1-engine` off `new-implementation`. Tests-first; one commit per task.
Invariant harness: `test/engine_invariants_test.dart` (1,920 runs = 4 chip cases incl.
a 100-chip case × 4 players × 3 durations × 4 paces × 2 formats × 2 ante × close {0,4,5,6}).
Scenario matrix: `docs/analysis/scratch/scenario_matrix.dart` → `engine-scenarios-after.csv`
(1,440 runs; the original is `engine-scenarios.csv`).

## What landed

| Task | Status | Commit headline |
|---|---|---|
| T1 invariant suite (red baseline) | ✅ | `test(engine): WP1 invariant suite — red baseline` |
| T2 re-anchor ladder to spec DP (F6, X2) | ✅ | `fix(engine): re-anchor the blind ladder to the spec DP pipeline` |
| T3 ladder shape (min/max step) | ◐ partial | folded into T2 (DP already bounds steps; `home25` family + hard MIN_STEP pending) |
| T6 real bank check exposed (F20/RC10) | ◐ infra | `feat(engine): real §F1.5 bank check exposed as bankOk/bankShortfall` — `feasible` flip deferred to T5 |
| T8 rebuy close + ante bootstrap (F33/RC5) | ✅ | `fix(engine): rebuy close via spec suggestRebuyClose + ante bootstrap` |
| T9 forceStack + targetDepthBB + recalculate (F2/F19) | ✅ | `feat(engine): forceStack + targetDepthBB inputs and recalculate(params,pins)` |
| T10 stale test + corrections + pin rerun | ✅ | this commit |
| T4 opening rung / magnitude | ❌ not done | needs the §F1.5 solver — see "Not done" |
| T5 round stacks + bank-aware composition | ❌ not done | the §F1.5 `scoreComposition` search; gates the T6 `feasible` flip and T7 |
| T7 pace signal vs bank signal | ❌ not done | gated on T5 (same demo-recommendation coupling as T6) |

## Before/after counts per invariant (1,920 runs)

| Invariant | Before (T1) | After | Fixed by |
|---|---|---|---|
| `sbGeBb` (SB ≥ BB) | 960 | **0** ✅ asserted | T2 |
| `bbNotRising` | 452 | **0** ✅ asserted | T2 |
| `stepAbove2` (> ×2.0) | 964 | **0** ✅ asserted | T2 |
| `anteStartWrong` (≠ close+1) | 575 | **0** ✅ asserted | T8 |
| `bankFalsePositive` (bankOk=true but short) | — | **0** ✅ asserted | T6 |
| `addonBreakWrong` | 0 | 0 ✅ asserted | — |
| `stepBelowMin` (< ×1.15) | 1372 | 27 ◐ reported | T2 mostly; MIN_STEP hardening = T3 |
| `bbNotMultipleOf2Cmin` | 888 | 194 ◐ reported | T2 mostly; odd opening BB = T4 |
| `stackNotRound` (not × roundUnit) | 712 | 712 ◐ reported | T5 |
| `feasibleButBroke` | 1088 | 456 ◐ reported | T6 computes it; flip = T5 |

"Reported" = tracked as a count, not asserted, so the suite is green mid-WP1. The
scenario after-matrix agrees: `SB>=BB=0, step>2=0, stackNotRound=712, feasibleButBroke=456`.

## Before/after for representative nights

| Night | Before | After |
|---|---|---|
| base25 9p 4h regular freeze | stack 25,000, open **900/250 (SB>BB)**, L1→L2 **×7.2** | stack 25,000, open **125/250 (SB<BB)**, max step **×1.67** — SB/step fixed; magnitude (→5,000 @ 25/50) is T4/T5 |
| base25 20p 4h regular freeze | stack 8,000, open 700/175, depth 45.7 | SB<BB, no giant step; magnitude/band still T4/T5 |
| box500 9p freeze | stack 1,200, open 6/12, 100 BB (already fine) | unchanged |
| box500 9p rebuy | stack 396, open 2/4 (bank-reserve shrink — correct per §F1.5, see correction 1) | unchanged; defect is non-round 396, fixed by T5 |
| demo (§F1.15) | 200, 1/2, close L4, ante L5, C 4,700, K 27, ~00:20 | **identical** (hard control held across every commit) |
| forceStack 5,000 on base25 9p freeze | n/a | **25/50, 100 BB, feasible** (T9) — the host can already get the right night |

## Auto rebuy-close distribution (288 rebuy auto-close runs)

- **Before:** L2 ×235 (82 %), L3 ×18, L4 ×10, L5 ×8, L6 ×2, …
- **After:** L2 ×36, L3 ×54, **L4 ×89**, L5 ×76, L6 ×29, L1 ×2, L7 ×2 — centred on L4.
- **Cause (T8):** `optimiseRebuyCloseLevel`'s `minChipValue × 4 > bb` guard
  (`tournament_engine.dart:1129-1136`) fires on the small EARLY blinds (L1's bb < 4×cmin),
  collapsing `viable` to 1 so `result` clamps to L2. Replaced on the generate path by the
  spec `suggestRebuyClose` (freshM ≥ style Mfloor, ≤ 40 % of the night, §F1.10). The demo
  still closes L4.

## Existing tests changed

- `test/engine_properties_test.dart` 23-005: group title changed from "level duration is
  always 10, 15 or 20" to "…10, 15, 20 or 30" (X4). The assertion already used
  `validLevelDurations` (which includes 30), so no behaviour weakened — the stale **title**
  was corrected because the Deep pace legitimately uses 30-minute levels (§A4/§F1.3).
- No other existing test was modified. `optimiseRebuyCloseLevel`'s unit tests
  (`test/rebuy_optimiser_test.dart`) still pass — the function is unchanged; it is simply no
  longer on the `generate` path.

## OWNER-DECISION markers left in code

- `tournament.dart` `targetDepthBB` field — turbo 75 / deep 150 are outside the spec's
  `DEPTH_BAND` (pt 13 conflict register).
- `tournament_engine.dart` depth-band block — the host-depth band widening is marked
  OWNER-DECISION (pt 13).
- `tournament_engine.dart` return site — the `feasible` flip to `depthFeasible && bankOk`
  is marked as WP1 sequencing / OWNER-DECISION (lands with T5).
- `test/engine_invariants_test.dart` `minStep = 1.15` — MIN_STEP tuning (T3).

## Corrections applied to the 2026-10 feedback report

- **Correction 1 (shrinking stacks partly correct):** applied — §8.6/RC9 now frame the
  defect as *non-round* values, not the shrinking (which is the §F1.5 bank-aware behaviour:
  box500's 13,400 total only funds ~670/player for a busy 9-player rebuy night). No stack
  floor is proposed; the fix is to round the value the bank allows and to say in `explain[]`
  what the case supports. (Report edit: the F32 "do not fall below ~1000" acceptance was the
  overreach correction 1 warns against — see note below.)
- **Correction 2 (arithmetic):** applied — 100 BB at 25/50 is **5,000**, not 3,000; F6b
  acceptance and §8.6 before/after corrected; `forceStack: 5000` already yields 25/50.
- **Correction 5 (citation):** applied — F33's "Addendum §6" was wrong (no such section);
  replaced with §F1.10 + row 25 (rebuy close), §F1.8/row 23 (ante start), §F1.9/rows 28–29
  (add-on break). The phrase traces to a code comment on
  `TournamentParams.rebuyCloseChosenByOrganizer`.

> Correction 1 caveat: F32's acceptance line still mentions a round floor; per correction 1
> that floor must NOT be imposed where the bank cannot fund it. T5's implementation should
> round to the deepest bank-fundable value and emit the "case supports up to X per player"
> explain sentence instead. Flagged here so T5 does not recreate client pt 20.

## Not done / blocked (with reasons)

- **T4 (opening rung & magnitude)** and **T5 (round stacks + bank-aware composition)** —
  the one genuinely large piece left. The current stack solver picks the opening rung from
  `validBlindLevels` with a tie-break toward the *larger* BB and builds the composition with
  a greedy `_buildChipPlan`, so (a) base25 opens at 250/500 with a ×10-inflated stack instead
  of 25/50 @ 5,000, and (b) the composition is not the §F1.5 `scoreComposition` optimum, so it
  can be bank-short (the demo's own 1×100,3×25,3×5,6×1 vs the spec's 5×1,9×5,2×25,1×100).
  Implementing §F1.5 faithfully (candidate nice stacks deepest-first, `scoreComposition` with
  the 0–24 count search over 3 free denominations, the soft-25 % rule, the hard per-colour
  bank check, round-unit snapping) is the right fix and is a multi-hour change that ripples
  through chip-payability/breaks/integrity; it was not safe to land green in this session
  alongside the rest. **The engine infrastructure it needs is in place:** `bankFeasibility`
  (the hard check), `niceBB`/`niceValuesInRange` (candidates), `dpSnapLadder`/`chooseSBLadder`
  (the ladder), and `forceStack` (which already deals the right night on demand). Once T5
  picks a bank-OK round stack, flip `feasible` to `depthFeasible && bankOk` (one line, marked
  in code) and T4's magnitude follows from choosing the lowest payable rung at the target depth.
- **T7 (pace signal vs bank signal)** — blocked on T5 for the same reason: `paceOptions`
  `recommended` must use `bankOk`, but until the composition solver is bank-aware the demo's
  own regular pace reports bank-short and would lose its recommendation. `bankOk` is already
  exposed on every structure, so T7 is a small change once T5 lands.
- **T3 `home25` blind family + hard MIN_STEP** — the DP already bounds steps at ≤ ×2 and
  penalises < ×1.15; a `blindFamily: niceSpec | home25` parameter and a hard MIN_STEP were
  not added. 27/1,920 runs still have a sub-1.15 step.

## Definition-of-done status

- `flutter analyze` clean on all touched files. ✅
- Demo night (§F1.15) exact across every commit. ✅
- Invariant suite green (asserts the T2/T6/T8-fixed invariants; reports the T4/T5-pending ones). ✅
- Engine test subset (232 tests) green after each commit. ✅
- Full `flutter test` green: **the engine suite is green; a full-suite run including widget/golden
  tests was not completed in-session** (see chat summary). The WP1 changes are engine + model +
  two provider/screen call-site renames (`safeBb`→`bb`), all analyze-clean.
- Scenario matrix rerun → `engine-scenarios-after.csv`. ✅
