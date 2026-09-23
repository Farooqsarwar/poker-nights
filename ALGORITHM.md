# Poker Night — Algorithm & Flow

What the engine does, in order, with the actual formulas. Everything below is
implemented and test-covered (596 tests).

---

## 1. Inputs

| Input | Source | Default if unset |
|---|---|---|
| Players | host | — |
| Duration (hours) | host | — |
| Buy-in | host | — |
| Chip set (colour, value, quantity) | host's own inventory | — |
| Level length | host | derived: ≤3 h → 10 min, ≤5 h → 15 min, else 20 min |
| Rebuys / re-entry / add-on on-off | host | — |
| Expected rebuys / re-entries / add-ons | host | engine rates |
| Rebuy / re-entry / add-on chip amounts | host | = starting stack |
| Antes on-off, first ante level, ante style | host | off, big-blind ante |
| Breaks (count, length, position) | host | position auto |
| Organizer % | host | 0 |
| Payout curve | host | Standard |

Every host input is nullable. Null means "engine default", so a tournament
created before an input existed regenerates byte-identically.

---

## 2. Structure generation — `TournamentEngine.generate()`

**Step 1 — Level count.**
```
scheduledBreakMins = Σ break lengths
playingMinutes     = max(60, hours × 60 − scheduledBreakMins)
plannedLevels      = max(6, ceil(playingMinutes / levelLength))
numLevels          = plannedLevels + 4          ← 4 spare levels as overtime insurance
```
Break time sits *inside* the target duration, not on top of it.
The 4 spare levels are generated but excluded from every estimate.

**Step 2 — Target starting depth (big blinds).**
```
targetBBDepth = clamp(40, 220,
                  125 + 28 × (hours − 3.5) − 2.5 × max(0, players − 8))
```
Longer night → deeper. Bigger field → shallower (more chips, longer night for
the same schedule). The result selects a style band that the solver must land
inside:

| Style | Band (BB) |
|---|---|
| Turbo | 40–70 |
| Fast | 55–90 |
| Standard | 70–140 |
| Deep | 100–220 |

There is **no** hard-coded starting stack and no universal 50–100 BB rule.

**Step 3 — Joint stack + opening-blind solve.**
Stack and opening blind are solved *together*, not in sequence. Every
small-blind/big-blind pair the host's real denominations can actually post is
evaluated against the largest stack the inventory can supply for that pair; the
pair landing closest to `targetBBDepth` inside the band wins. Candidates that
cannot make change for the small blind are rejected in favour of ones that can.

**Step 4 — Chip plan (scored enumeration).**
For the winning stack, enumerate practical per-colour combinations and score
them on:
- exactness (the counts must total the stack precisely),
- early-blind payability (every player can post SB and BB from level 1),
- stack aesthetics (round, countable piles),
- excessive chip count (≤ 25 chips of any single colour — one chip-tray row).

The same builder produces the rebuy and add-on chip plans.

**Step 5 — Blind curve.**
```
expectedTotalChips = stack × players
                   + rebuyStack × expectedRebuys
                   + max(0, reEntryStack − stack) × expectedReEntries
                   + addOnStack  × expectedAddOns

targetFinalBB = expectedTotalChips / (2 × 15)     ← heads-up starts ≈15 BB average
growthFactor  = (targetFinalBB / openingBB) ^ (1 / max(1, plannedLevels − 1))
rawBB(i)      = openingBB × growthFactor^i
```
A re-entry only adds the *surplus* over a starting stack, because it replaces a
stack already counted. The exponent uses `plannedLevels`, not `numLevels`, so
the spare tail keeps rising at the same rate instead of flattening the curve.

Each `rawBB(i)` is then snapped to the nearest entry on the blind ladder that
the chips can physically pay, forced strictly increasing. For very large fields
the ladder extends in +200/+400 steps past its printed end.

**Step 6 — Antes** (from the host's first ante level onward):
- Big-blind ante (default): `ante = bb`, one per table.
- Individual ante: `ante = snapToPracticalBlind(bb / 9)`, floored at the
  smallest chip in play.

**Step 7 — Rebuy close optimisation.** If the host did not pin it, the close
level is moved to the level where the stack depth, ante start, add-on
availability and break positions line up. If the host chose it, their choice
stands.

**Step 8 — Break placement.** Explicit positions are honoured first. Automatic
breaks anchor on the rebuy close (or the midpoint if rebuys are off) and later
ones spread across the remaining levels rather than stacking beside it.

**Step 9 — Colour-up schedule.** A denomination is played out once
`bb ≥ 20 × chipValue`. Each instruction names the exact exchange
("Level 7: exchange 20 × 25 Blue for 5 × 100 Black"). Remainders round **up**
in the player's favour — no formal chip race.

**Step 10 — Prize pool** (see §3).

**Step 11 — Finish estimate.**
```
expectedFinishMins = Σ durations of plannedLevels + 15 + scheduledBreakMins
```
The 15 is the end-of-rebuy settlement pause — real elapsed time with no clock
of its own. This is summed from what was actually generated, so it can disagree
with the requested duration and warn, rather than restating the target.

**Output:** starting stack, chip plan, rebuy/add-on stacks and plans, full
level list, planned level count, breaks, colour-up instructions, prize
schedule, finish estimate, plain-language style note, warnings.

---

## 3. Payouts

```
grossEligible   = buyIn × players
                + rebuyCost  × expectedRebuys
                + buyIn      × expectedReEntries
                + addOnCost  × expectedAddOns          ← KO bounty never enters
organizerAmount = grossEligible × organizerPct / 100, snapped to the nearest
                  multiple of 10 that keeps the pool a clean multiple of 10
prizePool       = grossEligible − organizerAmount − residue
```
The sub-10 residue is carried *out* of the pool and reported separately — it is
not an organizer cut and is never labelled as one.

**Paid places**: engine recommendation from field size vs pool size; the host
may override (1–10), and is offered the neighbouring shapes with the cost to
first place shown.

**Curve** (host-selectable, Standard is the default and is unchanged from the
reference schedule):

| Shape | Weights |
|---|---|
| Standard | 2: 73/27 · 3: 57/30/13 · 4: 56/30/10/4 · 5+: `e^(−0.7i)` normalised |
| Top heavy | `0.50^i` normalised |
| Flat | `0.90^i` normalised |

Every amount is a multiple of 10, never ends in 5, descends, and the places
total the pool exactly. A last place paying less than the buy-in is flagged to
the host (shown, not blocked).

**Live recalculation.** At rebuy close the prize pool is recomputed from the
*actual* confirmed players, rebuys, re-entries and add-ons. Before that point
players see only the pool total, never the split.

---

## 4. ICM (chop settlement)

Malmuth–Harville. A player's equity is the sum over every finishing position of
P(finishing there) × that position's prize; P(first) is the chip share, P(second)
is the chance someone else wins and then you win what remains, and so on.

Exact recursion up to **9 players**; above that it degrades to a proportional
split and says so on screen. Whole-unit payouts are produced by flooring and
handing the shortfall to the largest remainders, so the settlement totals the
pool exactly.

---

## 5. Integrity — structure verification

There is no server. Instead **every device** rebuilds the structure from the
stored settings and compares it to the stored structure, flagging any
difference in starting stack, level length, blind levels or breaks. The
organizer's cut is deliberately excluded (it is private and affects no blind).
Hand-edited levels carry a visible marker so the host sees which rows are
theirs before recalculating.

Consequence: **every generation input must be persisted.** Adding one without
storing it would make honest custom structures fail their own audit.

---

## 6. Application flow

```
draft ─► published ─► checkin ─► ready ─► running ⇄ paused
                                             │        │
                                             ├──► onBreak (scheduled, self-ending)
                                             ├──► rebuypause (rebuy close settlement)
                                             ├──► finaltable
                                             └──► completed
any state ─► cancelled
```

**Host**
1. **Create** — name, date, players, duration, buy-in, chip set, rebuy /
   re-entry / add-on / ante / KO options, breaks, organizer %.
2. **Structure review** — two tabs.
   - *Parameters*: every generation input, editable, with Reset. Expected
     rebuys/re-entries/add-ons and their chip amounts, level length, paid
     places, payout curve.
   - *Blind structure*: the schedule with running clock, per-level length,
     break rows, ante start, rebuy-close marker, BB depth and the solved blind
     growth factor (read-only).
   Regenerates live on every change. Premium hosts can hand-edit levels.
3. **Invite** — link / QR; guests join without an account.
4. **Check-in** — approve arrivals; late joins stay actionable while the clock
   runs.
5. **Run** — clock, level advance, breaks, rebuys/add-ons, eliminations,
   seating, chat, announcements. Money-bubble banner fires when
   `remaining = paid + 1`.
6. **Rebuy close** — settlement screen: confirm actual rebuys and add-ons; the
   prize pool and split are fixed here.
7. **Final table** — seat draw, ICM/chop support.
8. **Complete** — finishing order, prizes, results written to history.

**Player**
Join by link → check in → live view (clock, blinds, stack, players remaining,
prize pool total, chat) → elimination position → result in history.

**Public tools — no account required**
- Blind structure generator (players, hours, level length, chip box, start
  time, antes) → full schedule with wall-clock times and breaks.
- Payout calculator → the engine's own options.
- ICM calculator → equity vs chip share, signed difference, whole-unit chop.
- Tournament clock.

---

## 7. Key constants

| Constant | Value | Why |
|---|---|---|
| Spare levels | 4 | Overtime insurance; excluded from estimates |
| Settlement pause | 15 min | Real elapsed time at rebuy close |
| Heads-up average depth | 15 BB | Calibrates the final blind target |
| Max chips per colour per player | 25 | One chip-tray row |
| Level length bounds | 3–60 min | Presets 10/15/20; any value allowed |
| Target depth bounds | 40–220 BB | Spans Turbo to Deep |
| Exact ICM ceiling | 9 players | A final table; above it, proportional |
| Payout rounding | multiple of 10, never ends in 5 | Payable in real chips/notes |
