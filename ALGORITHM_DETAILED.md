# Poker Night — Algorithm & Flow (detailed)

The long form of `ALGORITHM.md`. Every formula, constant, threshold and
tie-break below is read out of the shipped source, not paraphrased from a
design note. 596 automated tests cover it.

Read `ALGORITHM.md` first if you want the one-page version; this document
assumes it.

---

## Contents

1. [Inputs and the nullable-override rule](#1-inputs-and-the-nullable-override-rule)
2. [Structure generation, in execution order](#2-structure-generation-in-execution-order)
3. [The blind ladder](#3-the-blind-ladder)
4. [The chip plan solver](#4-the-chip-plan-solver)
5. [Antes](#5-antes)
6. [Rebuy close optimisation](#6-rebuy-close-optimisation)
7. [Break placement](#7-break-placement)
8. [Colour-up](#8-colour-up)
9. [Money: gross, organizer cut, prize pool](#9-money-gross-organizer-cut-prize-pool)
10. [Paid places and the payout curve](#10-paid-places-and-the-payout-curve)
11. [ICM](#11-icm)
12. [Live pace and the speed recommendation](#12-live-pace-and-the-speed-recommendation)
13. [Integrity — structure verification](#13-integrity--structure-verification)
14. [Free vs Premium](#14-free-vs-premium)
15. [Application flow](#15-application-flow)
16. [Constants reference](#16-constants-reference)

---

## 1. Inputs and the nullable-override rule

| Input | Type | Null means |
|---|---|---|
| Players | int | — (required) |
| Duration (hours) | double | — (required) |
| Buy-in | int | — (required) |
| Chip set | list of (colour, value, quantity) | — (required) |
| Level length (mins) | int? | derive from duration |
| Rebuys / re-entries / add-ons enabled | bool | — |
| Expected rebuys / re-entries / add-ons | int? | engine rate |
| Rebuy / re-entry / add-on chip amounts | int? | = starting stack |
| Antes enabled, first ante level, ante style | bool / int? / enum? | off / recommended |
| Breaks (count, length, position) | list | position auto |
| Rebuy close level | int? | optimise it |
| Organizer % | int | 0 |
| Paid places | int? | recommend from field + pool |
| Payout curve | enum | `standard` |

**Why every override is nullable.** `null` is not "zero" and not "unset pending
a default write" — it is a live instruction to the engine to compute the value
itself. This matters because of §13: every device regenerates the structure
from the stored settings and compares. If an input defaulted at *write* time,
a tournament created before that input existed would regenerate differently on
the next app version and be reported as tampering. With nullable overrides an
old tournament carries `null`, the engine derives exactly what it derived
before, and the audit passes.

**The corollary, and it is a hard rule:** *any new generation input must be
persisted on `GameSettings`, written by the codec, and passed into the
verification recomputation.* Adding one without all three makes honest custom
structures fail their own audit. This is why the industry-common "add-on is
1.5× the starting stack" default was rejected — it would have silently changed
the chip totals feeding the blind curve for every existing tournament.

The one deliberate exception is the payout curve. It sits *outside* the
Parameters card's Reset group, because resetting the blind curve should not
quietly undo a prize decision that has nothing to do with blinds.

---

## 2. Structure generation, in execution order

`TournamentEngine.generate(TournamentParams)`. The order matters — each step
consumes the previous one's output.

### 2.0 Guard

Duplicate chip values in the inventory are rejected up front. Two colours at
the same value make the colour-up schedule ambiguous and the payability scoring
meaningless.

### 2.1 Level length

```
levelLength = params.levelDurationMins
           ?? (hours <= 3 ? 10 : hours <= 5 ? 15 : 20)
```
Presets offered in the UI are `[10, 15, 20]`. Any integer in
`[kMinLevelDurationMins=3, kMaxLevelDurationMins=60]` is accepted — the presets
are a convenience, not a constraint.

### 2.2 Level count

```
scheduledBreakMins = Σ break lengths
playingMinutes     = max(60, hours × 60 − scheduledBreakMins)
plannedLevels      = max(6, ceil(playingMinutes / levelLength))
numLevels          = plannedLevels + _spareLevels        // _spareLevels = 4
```

Two decisions are encoded here:

- **Breaks sit inside the target duration.** A 4-hour night with two 10-minute
  breaks plays 220 minutes, not 240. The host asked for a 4-hour evening.
- **The 4 spare levels are overtime insurance.** They are generated so a slow
  field can never run off the end of the structure, and they are excluded from
  *every* estimate — finish time, pace, growth factor, rebuy-close ceiling.
  `effectivePlannedLevels` is the accessor that enforces this; it returns all
  levels when `plannedLevels <= 0 || plannedLevels > levels.length`, so a
  hand-edited structure degrades safely instead of truncating.

### 2.3 Target starting depth

```
targetBBDepth = clamp(kMinTargetBBDepth=40, kMaxTargetBBDepth=220,
                  125 + 28 × (hours − 3.5) − 2.5 × max(0, players − 8))
```

Longer night → deeper start (more levels to play through). Bigger field →
shallower start, because more entries means more chips in play and more hands
to eliminate the same fraction of the field on the same schedule. The `− 8`
offset makes a single full table the neutral case.

The result selects an admissible band via `admissibleDepthBand(target)`:

| Style | Band (BB) |
|---|---|
| Turbo | 40 – 70 |
| Fast | 55 – 90 |
| Standard | 70 – 140 |
| Deep | 100 – 220 |

The bands overlap deliberately — 65 BB is legitimately describable as either
turbo or fast, and the solver should not be forced to reject an otherwise
excellent chip plan over a one-BB boundary. Reporting the other way,
`TournamentStyle.fromBigBlinds(bb)` labels a *finished* structure: `< 60`
turbo, `< 75` fast, `<= 120` standard, else deep.

There is **no** hard-coded starting stack and no universal "50–100 BB" rule.
The stack is an output.

### 2.4 Joint stack + opening-blind solve

Stack and opening blind are solved *together*. Solving them in sequence (pick a
stack, then find a blind) produces stacks the chips cannot actually pay.

For every small-blind/big-blind pair on the ladder that the host's real
denominations can post, the solver computes the largest stack that inventory
can supply for that pair, scores the resulting `stack / bb` depth against
`targetBBDepth`, and requires the result to land inside the admissible band.

Tie-break: a candidate that can **make change** for the small blind beats one
that merely **covers** it. A player holding exactly one chip equal to the small
blind can post it but cannot call a raise without breaking the blind — that
table stops for change every orbit.

### 2.5 Chip plan → §4
### 2.6 Rebuy / re-entry / add-on stacks

Each defaults to the solved starting stack when the host left it null. The
recommended add-on, offered live rather than baked in, is:

```
recommendedAddOnStack = snapToPayableChips(
    clamp(startingStack ~/ 2, startingStack × 2,
          max(averageStack, currentBB × 25)))
```
— i.e. enough to matter at the current blind level, never more than double a
starting stack, never less than half.

### 2.7 Blind curve → §3
### 2.8 Antes → §5
### 2.9 Rebuy and add-on chip plans

Same solver as §4, run against the rebuy and add-on stack sizes.

### 2.10 Colour-up → §8
### 2.11 Gross, organizer cut, prizes → §9, §10
### 2.12 Finish estimate

```
expectedFinishMins = Σ durations of the PLANNED levels
                   + settlementBreakMins (15)
                   + scheduledBreakMins
```

The 15 minutes is the end-of-rebuy settlement pause — real elapsed time with no
clock of its own, distinct from any scheduled break. Because this is summed
from what was actually generated, it can legitimately disagree with the
requested duration, in which case a warning is emitted. It never just restates
the target back at the host.

### 2.13 Rebuy close optimisation → §6
### 2.14 Break placement → §7
### 2.15 Style narrative and warnings

A plain-language sentence ("Standard: ~92 BB deep, 20-minute levels") plus any
warnings raised along the way — inventory too thin, finish estimate off target,
a paid place below the buy-in, duplicate chip values.

### Output

Starting stack · chip plan · rebuy/re-entry/add-on stacks and their chip plans ·
full level list · planned level count · breaks · colour-up instructions · prize
schedule · expected finish · style note · warnings.

---

## 3. The blind ladder

### 3.1 Target final blind

```
expectedTotalChips = startingStack × players
                   + rebuyStack   × expectedRebuys
                   + max(0, reEntryStack − startingStack) × expectedReEntries
                   + addOnStack   × expectedAddOns

targetFinalBB = expectedTotalChips / (2 × targetHeadsUpAverageBB)   // 15
```

Two details:

- A **re-entry** contributes only its *surplus* over a starting stack. The
  player's original stack was already counted in `startingStack × players`; a
  re-entry replaces it rather than adding to it. A rebuy, by contrast, adds a
  whole stack.
- `targetHeadsUpAverageBB = 15` is the calibration point: the structure should
  arrive at heads-up with the two survivors averaging about 15 BB, which is the
  depth at which heads-up resolves in a reasonable number of hands instead of
  grinding.

### 3.2 Growth

```
growthFactor = (max(targetFinalBB, openingBB) / openingBB)
                 ^ (1 / max(1, plannedLevels − 1))
rawBB(i)     = openingBB × growthFactor^i
```

The exponent uses `plannedLevels`, **not** `numLevels`. Spreading the same
growth across the 4 spare levels would flatten the whole curve to buy insurance
that is usually unused; instead the spare tail keeps climbing at the same rate,
which is exactly what a tournament running long needs.

The structure review screen reports this factor back to the host as a measured
value — the geometric mean of first→last planned BB — rather than the stored
input, so a hand-edited ladder reports its true curve.

### 3.3 Snapping to real blinds

`rawBB(i)` is snapped to the nearest entry on `validBlindLevels` that the chips
can physically pay, then forced strictly increasing (a monotonic guard, then
nearest-raw tracking so the ladder does not drift after a forced bump).

`validBlindLevels` — 34 pairs:

```
5/10    10/20   20/40   20/50   25/50   50/100   75/150   100/200
150/300 200/400 250/500 300/600 400/800 500/1000 600/1200 700/1400
800/1600 900/1800 1000/2000 1100/2200 1200/2400 1300/2600 1400/2800
1500/3000 1600/3200 1700/3400 1800/3600 1900/3800 2000/4000 2200/4400
2400/4800 2600/5200 2800/5600 3000/6000
```

`20/50` is deliberately **not** a 2× pair. A small blind at 40–50% of the big
blind is standard practice, and 20/50 is the pair that a 5/25/100 chip set can
post cleanly where 25/50 cannot. The full list is filtered against the live
denominations before use, so every blind on the generated ladder is postable
with chips the host actually owns.

For very large fields the ladder extends past its printed end in +200
small-blind steps.

### 3.4 `snapToPracticalBlind`

Used wherever an arbitrary number has to become a real blind or ante. It takes
the magnitude (power of ten) and tries the prefixes:

```
1.0  1.5  2.0  2.5  3.0  4.0  5.0  6.0  8.0  10.0
```

A *standard* prefix (1, 2, 5, 10) wins over a closer non-standard one when
`diff <= minDiff × 1.5` — being 8% further from an arbitrary target is worth
far less than being a number players recognise. The result is floored at the
smallest chip in play so it can always be posted.

---

## 4. The chip plan solver

`_buildChipPlan` decides how many of each colour each player receives. This is
the part of the engine that most distinguishes a usable home game from a paper
exercise, so it is a scored search, not a greedy fill.

### 4.1 Caps

```
perPlayerDivisor = max(1.0, playerCount × reserveMultiplier)
caps[i]          = min(floor(quantity[i] / perPlayerDivisor), maxChipsPerPlayer)
```

`maxChipsPerPlayer = 25` — one chip-tray row, the practical limit of what a
player can stack and count without a second tray. It is configurable through
`TournamentParams`, validated to `[1, 100]`, and warns when it deviates from
the production default.

### 4.2 The reserve ladders

"Payability" is the measure being optimised. `payableCount` is how many of the
three lowest denominations satisfy `value <= smallBlind`; "change" chips are
those with `value < smallBlind`.

Rather than fill greedily, the solver enumerates *change reserves* for the
three lowest denominations:

```
lowest      [0, 4, 6, 8, 10, 12]
second      [0, 2, 4, 6, 8]
third       [0, 2, 4]
```

All-even by design: a stack that pays blinds in pairs counts down evenly, so a
player is never left holding one odd low chip. Each combination is filled
top-down from the caps and scored; the **all-zero reserve is itself a
candidate**, which guarantees the search can never score worse than plain
greedy.

*Performance note:* the first implementation carried these combinations in
maps and cost 1.4 s per `generate()` — visible lag on every keystroke in the
Parameters card, since the structure regenerates live. It now uses parallel
`List<int>` buffers.

### 4.3 `_scoreStack`

| Term | Rule | Weight |
|---|---|---|
| Exactness gate | counts must total the stack precisely | `−(10000 + abs(covered − target))` if not |
| Counting simplicity | count divisible by 10 / 5 / 2 | `+3 / +2 / +1`, capped at 15 |
| Early-blind payability | payable denominations | `+min(payable, 12) × 2.5` |
| | change denominations | `+min(change, 4) × 2.5` |
| | fewer than 6 payable | `−60` |
| | fewer than 2 change | `−60` |
| Stack aesthetics | 3–5 distinct colours | `+8` |
| | each singleton colour | `−1.5` |
| Excessive chip count | total above 22 | `−(total − 22) × 3` |
| | total below 12 | `−(12 − total) × 2` |

The exactness gate is deliberately an order of magnitude larger than every
other term combined: **any** stack that misses the target loses to **every**
stack that hits it. The two `−60` cliffs are similarly blunt — a stack that
cannot pay the blinds from level 1 is not a stack, however pretty its colour
distribution is.

The 22 / 12 band around the chip count is ergonomic: much above 22 and the
stack does not sit in one tidy pile, much below 12 and every pot forces change.

---

## 5. Antes

Applied from the host's first ante level onward: `useAnte = anteEnabled && i >= anteAfterLevel`.

| Style | Ante |
|---|---|
| Big-blind ante | `ante = bb` — one ante per table, posted by the big blind |
| Individual ante | `ante = max(minChip, snapToPracticalBlind(bb / 9))` |

The individual ante divides by 9 — `defaultTableSize` — so that the total anted
per orbit is roughly one big blind either way. The floor at the smallest chip
in play is what keeps it postable.

### `recommendAnte`

Returns a style *and a plain-language reason*, never a bare enum:

| Condition | Recommendation | Reason given |
|---|---|---|
| `hours < 3.5 && players <= 6` | **off** | a short shorthanded game does not need the extra pressure |
| `players <= 6` | **individual** | with one short table the big-blind ante falls on the same player too often |
| otherwise | **big-blind ante** | one ante per hand, nothing to collect, no dead chips |

---

## 6. Rebuy close optimisation

If the host pinned the close level, their choice is returned untouched. If not,
seven inputs are applied **in this order**:

1. **Depth.** `viable` = the last level where `startingStack / bb >= 20`
   (`_rebuyWorthwhileBB`). Past that a rebuy buys a stack too short to play,
   so selling one is taking money for nothing.
2. **Chips.** If `minChipValue × 4 > bb`, the smallest denomination can no
   longer make meaningful change at the current blind; `viable = max(1, i)`.
3. **Antes.** `viable = min(viable, anteAfterLevel + 1)` — the rebuy period
   should close about when antes start, because antes are the point the
   tournament changes character.
4. **Time ceiling fraction.** `0.55`, or `0.60` at ≥18 players, or `0.65` at
   ≥40. Bigger fields need longer to reach a stable count, so they get a
   proportionally later close.
5. **Ceiling.** `ceiling = max(2, floor(plannedLevels × fraction))`, also
   bounded by `floor(hours × 60 × fraction / levelLength)` — so an unusual
   level length cannot push the close past the wall-clock intent.
6. **Breaks.** `ceiling = min(ceiling, max(2, plannedLevels − 1))`.
7. **Clamp, then add-on.** `result = viable.clamp(2, ceiling)`; then
   `if (addOnAvailable && result > 2) result -= 1`.

Step 7's order is the subtle one. The add-on reduction is applied **after** the
clamp, not before. Applying it first lets the clamp put the level straight
back, silently cancelling it; applying it after guarantees that when an add-on
is on offer, the rebuy period genuinely ends one level earlier — which is the
whole point, since the add-on break is where the field settles.

---

## 7. Break placement

Capped at `kMaxScheduledBreaks = 3`.

1. **Explicit positions first.** Host-chosen break levels are honoured and
   clamped to `[1, plannedLevels − 1]`.
2. **Automatic breaks anchor on the rebuy close** — or on
   `round(plannedLevels / 2)` when rebuys are off. That is the natural pause:
   settle rebuys, colour up, redraw seats.
3. **Later automatic breaks spread**, at
   `round(anchor + (plannedLevels − anchor) × i / autos.length)`, nudged off
   any level already taken.

The spread rule exists because anchoring every automatic break on the same
event stacked two of them a level apart, giving a long unbroken run at the end
of the night — exactly where players want the break.

---

## 8. Colour-up

A denomination is played out at the first level where

```
bb >= chipValue × 20
```

i.e. once the smallest chip is worth less than a twentieth of a big blind it is
no longer doing any work and is costing table time.

```
newCount = ceil(count × chipValue / nextChipValue)
```

Remainders round **up**, in the player's favour. There is no formal chip race —
that requires a dealer, a deck and a stopped clock, which a home game does not
have. Giving the fractional chip to the player costs the tournament a rounding
error and saves it fifteen minutes.

Each instruction names the exact exchange, e.g.
*"Level 7: exchange 20 × 25 Blue for 5 × 100 Black."*

---

## 9. Money: gross, organizer cut, prize pool

```
grossEligible = buyIn      × players
              + rebuyCost  × expectedRebuys
              + buyIn      × expectedReEntries
              + addOnCost  × expectedAddOns
```

A knockout bounty **never** enters the gross. It is paid peer to peer at the
table and is not the organizer's to allocate.

### Organizer cut

```
target = (gross × pct + 50) ~/ 100
```

Two candidates are then constructed that carry the correct units digit mod 10
and bracket the target; the closer wins, ties break toward the smaller. The
constraint is that the *remaining pool* must stay a clean multiple of 10, so
the cut cannot be a naive percentage.

Worked example from the specification: gross 165 at 10% → organizer 15, net
150.

### Residue

```
roundingRemainder = prizePool % roundingUnit
prizePool         = grossEligible − organizerAmount − roundingRemainder
```

The sub-10 residue is carried **out** of the pool and reported as its own
figure. It is not an organizer cut and is never labelled as one — at a 0%
organizer setting the organizer amount is exactly 0 and the residue is shown
separately. The reconciliation `paid + organizerAmount + roundingRemainder ==
gross` is asserted by test for every case in the suite.

### Live recalculation

At rebuy close the pool is recomputed from the **actual** confirmed players,
rebuys, re-entries and add-ons, replacing the expectations used at generation
time. Before that point players see only the pool total, never the split — the
split is not final and showing a provisional one invites arguments.

---

## 10. Paid places and the payout curve

### `_paidPlacesFor`

```
places = 1
if players >= 6  → 2
if players >= 10 → 3
if players >= 18 → 4

if pool < 100 && places > 2 → 2
if pool < 400 && places > 3 → 3

places = min(places, pool ~/ 10)
if places < 1 → (pool > 0 ? 1 : 0)
```

Field size sets the ambition; pool size caps it. A 20-player freeroll-adjacent
game with a £60 pool pays two, not four, because a fourth place of £10 is not a
prize. The final `pool ~/ 10` clamp enforces the multiple-of-10 rule from
below: you cannot pay more places than there are tens in the pool.

The host may override to any value 1–10, and is shown the neighbouring shapes
with the cost to first place, so the trade-off is explicit.

### Curves

| Shape | Weights |
|---|---|
| **Standard** (default) | 2: 73/27 · 3: 57/30/13 · 4: 56/30/10/4 · 5+: `e^(−0.7i)` normalised |
| Top heavy | `0.50^i` normalised |
| Flat | `0.90^i` normalised |

### `_referencePayouts`

For `shape == standard` **and** `forcePaidPlaces == null` **and**
`reference.length == paidPlaces`, a hand-tuned lookup grid is used verbatim
instead of the weights, covering pools from 50 to 700 in steps of 10:

```
 50 [40,10]        60 [40,20]        70 [50,20]        80 [50,30]
 90 [60,30]       100 [60,30,10]    110 [70,30,10]    120 [70,40,10]
130 [80,40,10]    140 [80,40,20]    150 [90,40,20]    160 [90,50,20]
170 [100,50,20]   180 [110,50,20]   190 [110,60,20]   200 [110,60,30]
210 [120,60,30]   220 [130,60,30]   230 [130,70,30]   240 [140,70,30]
250 [140,80,30]   260 [150,80,30]   270 [150,80,40]   280 [160,80,40]
290 [160,90,40]   …                                   700 …
```

The gate on `shape == standard` is essential: without it, a host choosing
top-heavy or flat would silently get the standard grid back. And the gate keeps
`standard` byte-identical to what shipped before the selector existed, which is
what protects §13 — a dedicated test asserts default and explicit-`standard`
produce identical amounts for 2–6 places.

### The six guarantees

Every produced amount:

| # | Guarantee |
|---|---|
| 14-022 | is a multiple of 10 |
| 14-023 | never ends in 5 |
| 14-024 | the places sum to the pool **exactly** (absolute, not approximate) |
| 14-025 | place 1 is the largest |
| 14-026 | amounts are monotonically non-increasing |
| — | no paid place pays 0 |

**Method.** Places 2..N are weighted and rounded to multiples of 10; place 1
takes the remainder, which makes 14-024 exact by construction rather than by
correction. If place 1 then lands on a digit of 5, 5 is transferred to or from
an adjacent place — a transfer, not a rounding, so the sum is preserved and
monotonicity is re-checked.

A last paid place below the buy-in is **flagged to the host, not blocked**: it
is a legitimate structure (some hosts want a wide min-cash), it just should not
be an accident. The warning names the place, the amount, the buy-in, and the
two ways out — pay fewer places, or use a flatter curve.

---

## 11. ICM

Malmuth–Harville. A player's equity is the sum over every finishing position of
`P(finishing there) × that position's prize`. `P(first)` is the player's chip
share; `P(second)` is the probability someone else wins and then this player
wins what remains of the chips; and so on recursively.

- **Exact recursion up to `maxExactPlayers = 9`** — a final table, which is the
  only place anybody actually needs ICM. The recursion is factorial in the
  player count, so above 9 it degrades to a proportional (chip-share) split and
  says so on screen rather than hanging or silently lying.
- **`roundPreservingTotal`**: floor every equity, compute
  `shortfall = total − Σfloors`, sort indices by descending fractional
  remainder, hand +1 to the largest remainders. A negative shortfall removes
  from the smallest remainders, with an iteration guard. This mirrors the
  payout engine's own rule, so a chop settlement and a scheduled payout round
  the same way — and the settlement totals the pool exactly.

The public ICM tool shows equity against chip share with a signed difference
column, plus the whole-unit chop.

---

## 12. Live pace and the speed recommendation

Every level boundary, the engine estimates finish drift:

```
remainingLevelsMins = Σ durations of future PLANNED levels
                    + remainder of the level in progress

elapsedFraction = clamp(0, 1, elapsedMins / targetMins)
expectedNow     = max(2, startingField × (1 − elapsedFraction))
paceFactor      = clamp(0.5, 2.0, actualRemaining / expectedNow)

drift = round(remainingLevelsMins × paceFactor − (targetMins − elapsedMins))
```

Two corrections are baked in and worth stating, because both shipped as bugs:

- **Only planned levels count.** Counting the 4-level spare tail made a fresh
  3.5 h / 15-minute event report about +45 minutes of drift at level 1 with a
  full field and nobody eliminated — past the threshold, so "Speed Up" was
  recommended from the first boundary of every tournament. A permanent nag
  trains the host to ignore the control.
- **The pace factor runs actual-over-expected.** It used to divide the starting
  field by the current one, which grows without bound as players bust; at a
  three-handed final table of a ten-player game it clamped to 2.0 and
  recommended speeding up a game about to finish early. More players left than
  the schedule expects now means slow progress (speed up); fewer means fast
  progress (slow down).
- **The remainder of the current level is work still to do.** Omitting it
  understated the estimate by up to a full level.

```
drift >  20 min → SpeedRecommendation.speedUp
drift < −20 min → SpeedRecommendation.slowDown
otherwise       → none
```

It is a **recommendation**. It never auto-mutates the structure, and it is
cleared on next level, previous level and restart.

---

## 13. Integrity — structure verification

There is no authority adjudicating the structure. Instead **every device**
independently rebuilds the structure from the stored `GameSettings` and
compares it to the stored structure, reporting any difference in:

- starting stack
- level duration
- blind levels (small, big, ante, per level)
- breaks (position and length)

The organizer's cut is deliberately excluded — the recomputation is built with
`organizerPct: 0`. The cut is private to the host and affects only the prize
split, never a blind; including it would leak the figure into an audit that
every player's device runs.

Hand-edited levels carry a visible marker, so a host who edits the ladder sees
exactly which rows are theirs before recalculating.

**The consequence is §1's hard rule.** Every generation input must be
persisted, or honest custom structures fail their own audit.

---

## 14. Free vs Premium

| Capability | Free | Premium |
|---|---|---|
| Hosting | up to `freeMaxActivePlayers = 9` active players | unlimited |
| Hand-edit the blind structure | no | yes |
| Choose the payout curve | no | yes |
| Build custom chip sets | no | yes |
| Everything else — clock, rebuys, ICM, chat, history, public tools | yes | yes |

The entitlement gate is evaluated on the device. Payments run through a mock
service; this is a functional demo of the tier boundary, not a billing
integration.

---

## 15. Application flow

### Status state machine

```
draft ─► published ─► checkin ─► ready ─► running ⇄ paused
                                             │        │
                                             ├──► onBreak      (scheduled, self-ending)
                                             ├──► rebuypause   (rebuy close settlement)
                                             ├──► finaltable
                                             └──► completed
any state ─► cancelled
```

`onBreak` was appended to the end of the stored enum so existing persisted
indices do not shift.

### Host journey

1. **Create** — name, date, players, duration, buy-in, chip set, rebuy /
   re-entry / add-on / ante / knockout options, breaks, organizer %.
2. **Structure review** — two tabs.
   - *Parameters*: every generation input, editable, each with Reset.
     Expected rebuys / re-entries / add-ons and their chip amounts, level
     length, paid places, payout curve. Regenerates live on every change.
   - *Blind structure*: the schedule with a running elapsed clock, per-level
     length, inline break rows, ante start, rebuy-close marker, BB depth, and
     the measured blind growth factor. The 4 spare levels stay visible here —
     a host approving a structure should see the whole thing.
   Premium hosts can hand-edit levels; edits are marked (§13).
3. **Invite** — link or QR. Guests join without an account.
4. **Check-in** — approve arrivals. Late joins stay actionable while the clock
   runs.
5. **Run** — clock, level advance, breaks, rebuys and add-ons, eliminations,
   seating, chat, announcements, speed recommendation (§12). A money-bubble
   banner fires when `remaining == paidPlaces + 1` and switches to a
   bubble-burst banner at `remaining == paidPlaces`. Both are derived from live
   counts — no extra persisted state, no codec change.
6. **Rebuy close** — settlement screen: confirm actual rebuys and add-ons. The
   prize pool and split are fixed here (§9).
7. **Final table** — seat draw, ICM / chop support (§11).
8. **Complete** — finishing order, prizes, results written to history.

### Player journey

Join by link → check in → live view (clock, current and next blinds, own stack,
players remaining, prize pool total, chat) → elimination position → result in
history.

### Public tools — no account required

- **Blind structure generator** — players, hours, level length, chip box, start
  time, antes → the full schedule with wall-clock times, break rows and a
  "finishes around" estimate. The starting stack is deliberately *not* an input:
  it is solved (§2.4), and offering a box for it would be offering a control
  that does not exist.
- **Payout calculator** — pool, places, curve; the engine's own options.
- **ICM calculator** — equity vs chip share, signed difference, whole-unit chop.
- **Tournament clock.**

---

## 16. Constants reference

| Constant | Value | Why |
|---|---|---|
| `_spareLevels` | 4 | Overtime insurance; excluded from every estimate |
| `settlementBreakMins` | 15 | Real elapsed time at rebuy close, no clock of its own |
| `targetHeadsUpAverageBB` | 15 | Calibrates the final blind target |
| `maxChipsPerPlayer` | 25 | One chip-tray row (configurable, validated 1–100) |
| `defaultTableSize` | 9 | Divisor for the individual ante |
| `kMinLevelDurationMins` / `kMaxLevelDurationMins` | 3 / 60 | Presets 10/15/20; any value in range allowed |
| `validLevelDurations` | 10, 15, 20 | UI presets only, not a constraint |
| `kMinTargetBBDepth` / `kMaxTargetBBDepth` | 40 / 220 | Spans Turbo to Deep |
| `_rebuyWorthwhileBB` | 20 | Below this a rebuy buys an unplayable stack |
| `kMaxScheduledBreaks` | 3 | Upper bound on scheduled breaks |
| `Icm.maxExactPlayers` | 9 | A final table; above it, proportional |
| `valueLadder` | 5, 25, 100, 500, 1000, 5000 | Canonical denominations |
| `freeMaxActivePlayers` | 9 | One table on the free tier |
| Payout rounding | multiple of 10, never ends in 5 | Payable in real chips and notes |
| Speed-recommendation threshold | ±20 min | Below this, the drift is noise |
