# WP1 engine correctness — results

Branch `fix/wp1-engine` off `new-implementation`. Tests-first; one commit per task.
Invariant harness: `test/engine_invariants_test.dart` (1,920 runs = 4 fields incl. a
100-chip case × 4 players × 3 durations × 4 paces × 2 formats × 2 ante × close {0,4,5,6}).

## Before/after counts per invariant

| Invariant | Before (T1 baseline) | After |
|---|---|---|
| `sbGeBb` (SB ≥ BB on a level) | 960 | _tbd_ |
| `bbNotMultipleOf2Cmin` | 888 | _tbd_ |
| `bbNotRising` | 452 | _tbd_ |
| `stepAbove2` (> ×2.0) | 964 | _tbd_ |
| `stepBelowMin` (< ×1.15) | 1372 | _tbd_ |
| `stackNotRound` (not × roundUnit) | 712 | _tbd_ |
| `feasibleButBroke` (feasible but bank short) | 1088 | _tbd_ |
| `bankFalseNoNote` | 0 | _tbd_ |
| `anteStartWrong` (≠ close+1) | 575 | _tbd_ |
| `addonBreakWrong` | 0 | _tbd_ |

## Before/after for representative nights

| Night | Before | After |
|---|---|---|
| base25 9p 4h regular freeze | stack 25,000, open 900/250 (SB>BB), L1→L2 ×7.2 | _tbd_ |
| base25 20p 4h regular freeze | stack 8,000, open 700/175, depth 45.7 | _tbd_ |
| box500 9p freeze | stack 1,200, open 6/12, 100 BB | _tbd_ |
| box500 9p rebuy | stack 396, open 2/4 (shrunk by bank reserve — see correction 1) | _tbd_ |
| demo (§F1.15) | 200, 1/2, close L4, breaks L4/L9, C 4,700, K 27, ~00:20 | _tbd_ |
| base100 9p 4h regular | _tbd_ | _tbd_ |

## Auto rebuy-close distribution

- **Before:** L2 in 235/288 (82 %) of rebuy runs; cause (T8) found in
  `optimiseRebuyCloseLevel` — the `minChipValue * 4 > bb` guard
  (`tournament_engine.dart:1129-1136`) fires on the small *early* blinds
  (L1 bb < 4×cmin), collapsing `viable` to 1, so `result` clamps to L2. The spec's
  `freshM ≥ Mmin` rule (`suggestRebuyClose`, §F1.10) is the correct replacement.
- **After:** _tbd_

## Existing tests changed

- _tbd_

## OWNER-DECISION markers left in code

- _tbd_

## Corrections applied to the report (2026-10 feedback report)

- **Correction 1 (shrinking stacks partly correct):** _tbd — update §8.6 to say the
  defect is non-round values, not the shrinking; add the "case supports up to X per
  player" explain sentence; do not add a stack floor the case cannot fund._
- **Correction 2 (arithmetic):** 100 BB at 25/50 is a **5,000** stack, not 3,000;
  base25 9p 4h regular freeze → ~5,000 at 25/50 (bank allows 45,000 ≤ 252,500).
- **Correction 5 (F33 citation):** verify/replace "Addendum §6".

## Not done / blocked

- _tbd_
