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
| T4/T5 §F1.5 solver | `solveChipPlanBounded`; demo night now deals exactly `5×1 · 9×5 · 2×25 · 1×100`, score 83.25, S_max 230.92 |
| T6 real feasibility | `feasible = depthOk && bankOk`; `bankShortfall` exposed |
| T7 pace vs bank signal | `bankBlocked` separate from the time warning |
| T8 rebuy close (F33) | spec `suggestRebuyClose` + ante bootstrap; manual close honoured |
| T9 `forceStack` / `targetDepthBB` / `recalculate` | engine inputs for WP2 |
| T10 housekeeping | stale 23-005 title, pin test with real cmin, report corrections |
| **Follow-up (this round)** | infeasible-night guards, handout model fix, honest `maxPlayers`, `home25` fallback, codec persistence, CI gate step, lint fix |

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

Round / step / multiple-of-2×cmin invariants are asserted for **feasible** structures only.
An infeasible one carries a placeholder ladder (see §3), which is exactly why it must be
blocked rather than checked for smoothness.

---

## 3. Infeasible nights (item 1)

### 3.1 How many

**576 of 3,840 (15.0 %) are infeasible.** All 576 are "no playable stack exists"
(`depthOk = false`); **0** are "playable but the bank can't fund it".

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

Every one is a **20-player night with rebuys + add-on** on the `demo`, `base25` or `base100`
case (96 = 3 durations × 4 paces × 2 ante × 4 close levels, in each of 3 cases × 2 families).
No 20-player freeze-out and nothing at ≤ 12 players is infeasible. These are genuine, not a bug:
e.g. `base25` has 100 × 25-chips for 31 stacks (20 + the 11 busy-night rebuys), and a round
stack needs a multiple of four 25s, so no nice stack with ≥ 2 of the smallest chip can be
dealt to everyone.

**A bug found by this audit and fixed:** the first audit showed **1,344** infeasible (35 %),
with `box500`/`demo` under `home25` almost entirely infeasible (408/480 and 456/480). Cause:
`home25` forced a ≥ 50 big blind, so any bank-limited stack under ~1,000 (box500 9p rebuy = 400)
opened at < 20 BB and was declared infeasible, where `niceSpec` dealt the same night at 100 BB.
That was a defect in my T3, not a real shortage (and its note, "supports up to 8 players", was
wrong). Fixed: a 25-based blind is used only while it still reaches the style's depth band,
otherwise that stack falls back to the spec's blinds. Test:
`home25 falls back to the spec ladder instead of making a night infeasible`.

### 3.2 No code path can start a clock, post an event or open the dashboard on one

`TournamentStructure.isBlocked` (`levels.isNotEmpty && !feasible`) is the single predicate.
An **empty** ladder is not "blocked" (an event posted for RSVP carries no ladder at all —
`createGame` attaches `levels: []`, asserted by a test).

| Path | Guard | Tested by |
|---|---|---|
| `startTimer()` — the only place a clock starts | After the structure is regenerated for the **final headcount**, refuses (no `timerRunning`, no `structureConfirmed`), writes a `start_refused` audit record | `startTimer called directly is refused`, and the *stored-9p-looked-fine-but-20-checked-in* case |
| `startTournament()` | Now returns `bool` (did the clock start). Check-in, invitation and quick start navigate to the dashboard **only on `true`**, otherwise stay and say why | `startTournament refuses, nothing runs` |
| `startBlockedReason` (start buttons, dashboard) | Returns `kChipCaseBlockedReason` when the stored structure is blocked | asserted before pressing start |
| `confirmStructure()` | Refuses a blocked structure (`structure_confirm_refused`) | `confirmStructure refuses` |
| Quick start | Previews the structure **before creating any game/group/guest sign-in**; shows `StructureFeasibilityCard` with Edit chips / Play a freeze-out / Reduce to N; Generate is disabled; `_start` re-checks defensively | widget test: card visible, button `onPressed == null`, `app.currentGame == null` |
| Group event post (wizard) | Existing `_canPublish` gate + card (UI-level, per spec C1). The posted event has no ladder (above) | precondition test |
| Structure review | Existing card; its Confirm now also refused at the provider | provider test |
| Free blind generator (E2) | Card instead of stats/schedule; **Share hidden** | widget tests |
| Free tool clock (E3) | `_build()` refuses to build segments; card shown; setup view stays | widget tests |
| Persistence | `feasible`, and now `depthOk` / `bankOk` / `bankShortfall`, round-trip the codec (they were being dropped) | round-trip tests |

**Mutation check:** with `isBlocked` forced to `false` (the old behaviour), **12 of the new
tests fail** (every "refuses", the quick-start widget test, both tool tests, the preconditions);
every CONTROL stays green. Restored.

**Honest gaps:**
- Posting an event is guarded only in the UI (the wizard), as the spec has it. There is nothing
  for a provider guard to protect, because the event carries no ladder; WP3 slims that wizard.
- `generateFinalStructure` deliberately *does* attach a blocked ladder — that is how the review
  screen gets the data to render the card. Nothing downstream will play it.
- A game that is **already running** when this ships is not retroactively blocked, and
  structures saved before `feasible` existed read as feasible (the codec's documented safe
  default).

### 3.3 "Reduce to N players" was dishonest — fixed

The card's button offers `maxPlayersSupported`. That number came from a leftover **coverage-only
re-check on the legacy greedy planner**, ignoring rebuys, add-ons and the nice-stack rule, so it
advertised fields the real solver then rejected (a host following the button landed on the same
card). It is now computed by re-running the *same* feasibility with fewer players (binary search,
because the tools allow 100 players), so every N it returns has been verified dealable. Tests:
`reducing to the advertised N is dealable` (both infeasible cases).

### 3.4 The free tools were the biggest hole

They deal from a fixed **300-chip box** and allow 2–100 players with rebuys + add-on. The box is
undealable from **14 players** (17 for the four-colour box), i.e. most of the stepper, and neither
tool looked at `feasible`: they presented a placeholder as a structure and could arm a clock on it.
I kept the tools' stated behaviour ("assumes the box most people have") and show the card instead,
rather than silently re-sizing the bank. (Spec F1.14 actually suggests a synthetic bank that
never binds; that would change every tool answer, so it is listed under owner decisions.)

---

## 4. `bankOkDisagrees` (item 2)

**32 disagreements** on the pre-fix engine, all "engine stricter than the test" (0 the other way,
so no false positives), all `home25` rows that were also depth-infeasible. Classified with a
brute-force search for *one recipe every player can be handed* (`scratch/classify.txt`):
**32 / 32 engine too strict (false "case too small"), 0 engine right.**

Cause: the add-on/bonus handout was the cheapest recipe against the **whole remaining bank**,
then multiplied by N. That recipe can be individually cheapest yet impossible to repeat N times,
so the engine reported a shortage when a slightly different recipe fit.

| # | Night | Stack | Engine said | Reality |
|---|---|---|---|---|
| 1 | box500 6p 3 h regular, ante, close auto | 796 | short 2 Black (7 Black × 6 = 42 > 40 left) | recipe 6×100 + 6×25 + 9×5 + 1×1 fits the per-player bounds {100:6, 25:6, 5:11, 1:15} |
| 2 | box500 6p 3 h regular, no ante, close 6 | 796 | short 2 Black | same recipe fits |
| 3 | box500 6p 4 h regular, no ante, close 5 | 796 | short 2 Black | same recipe fits |
| 4 | box500 6p 5 h regular, no ante, close 5 | 796 | short 2 Black | same recipe fits |
| 5 | demo 9p 3 h no-pace, no ante, close 6 | 217 | short 6 Black | a common recipe exists within {100:1, 25:8, 5:13, 1:2} |

Distinct stacks among the 32: **796 (24 rows)** and **217 (8 rows)**.

**Fix:** a handout is now the fewest-chips recipe limited to `floor(remaining / players)` per
colour (`handoutEveryPlayerCanGet`), used by both the solver and the exposed `bankOk` so they can
never disagree. Still one recipe per player — the same model the spec's own demo trace uses
(`add-on 250 = 2×100 + 2×25`), and the demo's numbers did not move. Regression tests in
`f1_5_composition_test.dart` (the 796 case, plus a genuine-shortage case returning `null`).
After the fix `bankOkDisagrees = 0` over all 3,840.

---

## 5. Built-in chip presets (item 3)

30 nights: every built-in preset × 6–10 players × 4 h × regular × freeze-out and rebuy
(35 % rebuys + add-on, BB ante). Full table: `wp1-presets.md`.
**0 infeasible. 6 feasible but below the 85–130 BB band** (each carries the depth note):

| Preset | Format | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|
| Standard 300 | freeze | 600 @3/6 | 600 @3/6 | 400 @2/4 | 400 @2/4 | 400 @2/4 |
| Standard 300 | rebuy | 200 @1/2 | **100 @1/2 (50 BB)** | **100 (50 BB)** | **100 (50 BB)** | **100 (50 BB)** |
| Standard 500 | freeze | 800 @4/8 | 800 | 800 | 800 | 800 |
| Standard 500 | rebuy | 600 @3/6 | 600 | 600 | 200 @1/2 | 200 @1/2 |
| Home Set (4 col) | freeze | 3000 @15/30 | 3000 | 2000 @10/20 | 2000 | 2000 |
| Home Set (4 col) | rebuy | 1000 @5/10 | 1000 | 1000 | **500 @5/10 (50 BB)** | **250 @5/10 (25 BB)** |

(All other cells are 100 BB.)

**Flag for the owner:** *Home Set, 10 players, rebuy* opens at **250 chips = 25 BB** — just above
the spec's 20 BB playable floor, and the rebuy close lands on L2. That is a typical home night and
it is effectively push-or-fold from level 1. It is correct per §F1.5 (the busy-night rebuy +
add-on reserve genuinely consumes the box) and the card says so, but whether 25 BB should be
presented as "playable" or warned about harder is a product call, not something I changed.
Also note the cliff on *Standard 500 rebuy*: 8 → 9 players drops 600 → 200 (nice-value
granularity on a bank-limited box).

---

## 6. `home25` representative nights (item 4)

Full table with `niceSpec` alongside: `wp1-home25.md`. 4 h, regular, BB ante.

| Case | Night | Stack | Opening | Depth | Feasible | Differs from niceSpec? |
|---|---|---|---|---|---|---|
| box500 | 6p freeze | 2000 | 10/20 | 100 | yes | no |
| box500 | 9p freeze | 1200 | 6/12 | 100 | yes | no |
| box500 | 9p rebuy | 400 | 2/4 | 100 | yes | no |
| box500 | 20p freeze | 150 | 1/2 | 75 | yes | no |
| demo | 6p freeze | 800 | 4/8 | 100 | yes | no |
| demo | 9p freeze | 600 | 3/6 | 100 | yes | no |
| demo | 9p rebuy | 150 | 1/2 | 75 | yes | no |
| demo | 20p freeze | 100 | 1/2 | 50 | yes | no |
| base25 | 6p freeze | 5000 | 25/50 | 100 | yes | no |
| base25 | 9p freeze | 5000 | 25/50 | 100 | yes | no |
| base25 | 9p rebuy | 3000 | 25/50 | 60 | yes | no |
| base25 | 20p freeze | 2500 | 25/50 | 50 | yes | no |
| base100 | 6p freeze | 40000 | 200/400 | 100 | yes | no |
| base100 | 9p freeze | 20000 | 100/200 | 100 | yes | no |
| base100 | 9p rebuy | 8000 | 100/200 | 40 | yes | no |
| base100 | 20p freeze | 15000 | 100/200 | 75 | yes | no |

**`home25` is a no-op on every one of these nights, and I should not have called it done
without showing this.** On `box500`/`demo` the bank-limited stacks (≤ 2,000) can't open at a ≥ 50
blind and stay ≥ 85 BB deep, so they correctly fall back to the spec ladder (the ladder is not
25-based: "2/4", "3/6"). On `base25`/`base100` the ladder is already 25-based. It only has an
effect with a deep stack on a fine-chip set (the unit test uses a 4,000-piece case, forced 6,000).

The practical consequence for client point 13 (blinds in multiples of 25): a 500-piece box
**cannot** produce 25/50 at 100 BB while its chips are valued 1/5/25/100 — the stack would have to
be 5,000. What gives 25/50 at 5,000 is *valuing the same chips differently* (25/100/500/1000, i.e.
the `base25` rows). That is a chip-value / unnumbered-chips question (client points 20–21), not a
blind-family knob.

---

## 7. Auto rebuy-close on the final code (item 5)

**Correction to my earlier claim.** The previous version of this file said the auto close was
"centred on L4 (L4 × 89)". That was measured *before* the T5 solver landed and is **stale**; on the
final code it is not.

Auto close (manual close = 0), `niceSpec`, rebuy nights:

| Population | Runs | L2 | L3 | L4 | L5 | L6 |
|---|---|---|---|---|---|---|
| All 4 cases | 384 | 52 % | 21 % | 15 % | 8 % | 4 % |
| Feasible only | 312 | 55 % | 18 % | 15 % | 8 % | 4 % |
| **Like-for-like with the original 288-run baseline** (box500+demo+base25) | 288 | **46 %** | 21 % | 18 % | 10 % | 5 % |

Original baseline (before any WP1 fix): **L2 in 82 %**. So the fix is real (82 % → 46 %) but L2
is still the single most common answer.

**Why** (feasible nights): it is driven by stack depth, not by the ladder.

| Opening depth | Runs | L2 share | Mean close |
|---|---|---|---|
| < 45 BB | 72 | **100 %** | L2.0 |
| 45–84 BB | 168 | 55 % | L2.8 |
| ≥ 85 BB | 72 | **11 %** | **L3.9** |

For real-depth nights it behaves as intended: regular pace, ≥ 85 BB, mean close **L3.8**
(67 % in L4–L6); by duration 3 h → L3.0, **4 h → L4.0** (matches the §F1.15 demo), 5 h → L4.5.
Two things pull the overall number to L2: (a) bank-limited shallow stacks, where a fresh stack
is already below the M floor by L3 (L2 is also the clamp floor I added so the window survives past
the opening level), and (b) **deep pace**, whose M floor is 20 vs 15, closes at L2 in 79 % of
nights. A *manual* close is honoured in **936 / 936** feasible runs.

So the client's "rebuys until L4–L6 with enough depth that people still rebuy" is achievable only
on nights where the chip case allows real depth. That is a chip-bank limit surfaced as a short
rebuy window, not a defect in the close rule — but it is what the client will see on a small box,
and it is listed under owner decisions.

---

## 8. CI (item 6)

`engine_invariants_test` was **already running in CI**: the workflow runs plain `flutter test`,
which includes everything under `test/`. I added a dedicated, named step ahead of it
("Engine invariants (WP1 gate)") so an engine regression is reported on its own and fails fast:

```
flutter test test/engine_invariants_test.dart test/f1_5_composition_test.dart
  test/engine_force_stack_test.dart test/infeasible_start_guard_test.dart
  test/demo_night_vector_test.dart
```

Ran that exact command locally: **49 tests, all pass, 452 s** (while sharing the machine with
other jobs); the step has a 20-minute timeout.

**Lint gate:** CI runs `flutter analyze --fatal-infos`. Comparing info/warning/error lints
(keyed by file + lint + message, not line) against `new-implementation` showed **my T3 commit had
introduced a `curly_braces_in_flow_control_structures` info in `engine_invariants_test.dart`, which
would have failed CI**. Fixed (plus two more the formatter exposed and two in a scratch file).
Current tree: **0 new lints vs the baseline.**

**Correction to what I told you before:** I said the app "won't build from the committed code".
That is a **local SDK mismatch**, not a repo defect. CI pins Flutter **3.44.7**, where
`ReorderableListView.builder(onReorderItem:)` exists; this machine has **3.38.9**, which doesn't.
The uncommitted `onReorderItem → onReorder` edit in the working tree is a local workaround and
should stay uncommitted. (The baseline's 2 analyzer *errors* disappear only because of it.)

---

## 9. Existing tests changed

Nothing was weakened to make it pass. Each change has a reason:

- `chip_payability_test` — `≥ 6` chips ≤ SB → `≥ 2`: the spec's own demo deals only 5×1.
- `engine_properties_test` PN-001 (×2) — the hard bank check makes Standard-300 / 9 players
  legitimately shallow; now asserts ≥ 20 BB **and** a depth note instead of ≥ 100 BB.
- `engine_properties_test` §11.3 premium — single-g DP ladder snaps coarse; now asserts the
  premium never *lowers* a printed blind.
- `engine_properties_test` 23-005 — title now allows the Deep pace's 30-minute levels.
- `pace_cards_test` — fixtures gained `bankBlocked: null`.
- `engine_force_stack_test` — the original `home25` test asserted behaviour the audit showed
  was inert/unsafe; replaced by two tests (applies when deep enough; falls back instead of
  failing).
- `engine_invariants_test` — braces/format only, no assertion change.

---

## 10. OWNER-DECISION

**Markers in code (5):**
1. `lib/models/tournament.dart:85` — `BlindFamily` (`niceSpec` / `home25`), client pt 13.
2. `lib/models/tournament.dart:426` — `targetDepthBB`: turbo 75 / deep 150 are outside the spec's `DEPTH_BAND`.
3. `lib/utils/tournament_engine.dart:1720` — host-depth band widening around `targetDepthBB`.
4. `lib/utils/tournament_engine.dart:1800` — `home25` falls back to the spec ladder when a 25-based blind can't reach the band.
5. `test/engine_invariants_test.dart:155` — `MIN_STEP = 1.15`.

**Decisions this audit surfaced (no code marker; nothing changed):**
- **One composition per stack (§F1.5 point 5).** For `base25`, 20 players, freeze-out a better
  night is dealable — 4,000 @ 25/50 (80 BB, `4×25+4×100+3×500+2×1000`) — but the solver picks 2,500
  (50 BB) because the best-scoring 4,000 composition has no 25s, which forces a 200 blind. The
  depth note then says the case "supports about 50 big blinds", which understates it. Evaluating
  one composition per (stack, smallest chip) would fix it but changes the spec's selection rule.
- **Is 25 BB "playable"?** Home Set, 10 players, rebuy opens at 25 BB (§5).
- **Short rebuy windows on small boxes** (§7): accept, or relax the M floor / pace-specific floors.
- **Free tools' bank:** keep the fixed 300-chip box + card (what I did), or the spec-F1.14
  synthetic never-binding bank (changes every tool answer).
- **Chip valuation vs blind family** for client pt 13 (§6).

---

## 11. Corrections applied to the 2026-10 feedback report

- **1 (shrinking stacks):** the defect is non-round values, not the shrinking; no stack floor.
- **2 (arithmetic):** 100 BB at 25/50 is **5,000**.
- **5 (citation):** F33's "Addendum §6" does not exist; cited §F1.10 / rows 23, 25, 28–29.
- *Still wrong in the report, not yet edited:* its "app won't build" aside, and any statement
  that `home25` delivers 25-based blinds on real boxes (§6).

## 12. Full-suite parity

Earlier clean-worktree runs (Flutter 3.38.9): `new-implementation` 924 pass / 6 fail;
`fix/wp1-engine` 934 pass / 6 fail; **identical failing sets** — the six files that fail to
*load* because of the SDK mismatch in §8. With the local `onReorder` workaround applied, the full
suite on the branch was **1,593 / 1,593**.

**Final code (after this follow-up round), same setup:** `flutter test` = **1,622 passed,
0 failed** (574 s). The +29 over 1,593 are the new tests (guards, handout model, codec round
trips). The baseline was *not* re-run with the workaround for this round, so "no regression" in
the six SDK-affected files rests on that single 1,622 / 0 run, as before.

## 13. Not done

- No PR opened, nothing pushed.
- Provider-level guard on event *posting* (nothing to protect; WP3).
- Retroactive blocking of already-running games.
- `findMaxPlayers` returns a verified-feasible N but, if feasibility were ever non-monotone in
  the field size, could understate the true maximum.
