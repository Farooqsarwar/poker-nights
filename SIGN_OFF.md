# Sign-off record

Acceptance evidence per phase of `IMPLEMENTATION_PLAN.md`, against the
*Poker Night — Perfect Developer Specification*, 10 September 2026.

> An earlier `SIGN_OFF.md` existed in a previous working tree and is not in git
> history. This file restarts the record from Phase 1. The six outstanding
> client-signature items it tracked (PN-005, PN-006/036, PN-027, PN-033, PN-034,
> PN-051) were raised against the **superseded** PDFs; PN-051 is closed (scored
> chip enumeration, commit `42b92fcf`) and PN-035 is closed by §2 of the new
> specification, which makes native iOS and Android current requirements.

---

## Phase 1 — Foundation fixes

**Branch:** `phase/1-foundation-fixes`
**Spec:** §7, §14, §18, §24, §29, §32
**Date:** 12 September 2026

### Step 1.1 — Organizer cost (§7, §18, §32)

| Requirement | Evidence |
|---|---|
| Default 10% | `create_tournament_screen.dart` — controller seeded `'10'` |
| Range 0–20% | `kOrganizerPctMax = 20`, validation reads `_orgPctCeiling` |
| `+/-` stepper, not typed | `CountStepper` replaces `AppTextField` in create **and** edit |
| Wording *"Percentage retained for equipment, drinks & snacks"* | Both forms, verbatim |
| Private, never shown to players | Unchanged — `services/projections.dart` |
| Never called "rake" | `test/activity_log_test.dart` asserts no user-facing occurrence |
| §18 worked example: gross 165 → 15 / 150 | `test/payout_rules_test.dart` |

**Compatibility.** The 10% default is a *form* default only. Stored
`organizerPct` values are untouched, so a game created before this change still
reads back the percentage it was created with. A game or preset carrying a
legacy figure above 20% keeps it — `_orgPctCeiling` raises the stepper's maximum
to the loaded value, so an existing number can be reduced but never silently
rewritten. Covered by *"a legacy percentage above the new 20% cap still
computes"*.

`CashGame.rakePct` remains in the model as a serialization field, documented as
unused and never surfaced. Removing it would violate §2.1 (additive-only
schema).

### Step 1.2 — No currency symbols (§7, §24) — no change required

Audited 12 September. No `€`, `£` or `¥` anywhere in `lib/`. The `$` matches are
Dart record accessors (`ctx.$1`) and doc comments in `utils/money_utils.dart`.

### Step 1.3 — Icon family (§24) — **deferred to Phase 10**

Choosing an icon family is design-system work. §31: *"Do not polish screens while
the underlying tournament state and permission model is unstable."* Doing it now
means doing it twice. `Group.icon` unchanged.

### Step 1.4 — Navigation says "Groups" (§3)

`widgets/nav_drawer.dart` — the sidebar section heading is now `GROUPS`
unconditionally, rather than `CURRENT GROUP` / `GROUP`.

The `Group` model, its routes and singular usages (*"New group"*, *"Group
name"*) are unchanged — those refer to one group and are correct English. §3's
requirement is that navigation acknowledges plurality, which the section heading
now does.

### Step 1.5 — Activity log completeness (§14, §29)

**Five live operational actions had no record at all.**

| §14 action | Before | After |
|---|---|---|
| Rebuy / re-entry | none | `'rebuy'` |
| Add-on | none | `'addon'` |
| Elimination | announcement only | `'elimination'` |
| Late player | announcement only | `'late_player'` |
| Generate seat | announcement only | `'seating'` |
| Check-in | already logged | unchanged |
| Structure edit, speed change, settlement, cancel, publish, final table | already logged | unchanged |

Rebuy and add-on are the serious two: money entered the game and the prize pool
moved with nothing written down. An announcement is **not** a log entry —
announcements are ephemeral, and §29 requires the action be reconstructable
afterwards.

Locked by `test/activity_log_test.dart`, which brace-matches each method body
and asserts it calls `addAuditRecord`. Source-level by design: driving these
through the real provider needs Firebase, auth and a live game, and a mocked
behavioural test would not catch the actual regression — somebody adding a
*new* live action and forgetting the record.

### Gate

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | 37 issues, 0 errors — **unchanged from baseline** |
| `flutter test` | **104 passing, 0 failing** (baseline 94 + 10 new) |
| `flutter build web --release` | **succeeds** — only pre-existing third-party wasm warnings |
| Schema changes | none — no migration, no compatibility risk |
| Feature flag | not required; no new capability, only corrected defaults |

### Not done in this phase

- Table balance and colour-up were not in the audited method list. Both are
  §14 actions and need the same check — carried into Phase 5.
- §7's organizer-cost **ON/OFF toggle** is represented by 0%, not a separate
  switch. Functionally equivalent; flag to the client if they want the explicit
  control.

### Rollback

`git revert` the branch. No schema change, so no data cleanup.

---

## Phase 5 — Structure integrity

**Branch:** `phase/5-structure-integrity`
**Spec:** §6, §7, §11, §29, §32
**Date:** 12 September 2026

### Step 5.1 — Manual future edits are marked and protected (§11, §29)

> *"Manual future edits need visible markers and cannot be silently
> overwritten by Recalculate."*

Recalculate rebuilt the whole ladder, so a host who hand-tuned level 9 lost it
the next time anything regenerated — with no warning, and no way to tell it had
happened.

| Requirement | Evidence |
|---|---|
| Marker exists | `BlindLevel.manuallyEdited`, defaults `false` |
| Set on human edits | `applyFutureLevels` marks everything the structure editor returns |
| **Visible** marker | Pencil icon beside the level number in the blind schedule, tooltip *"Edited by hand"* |
| Not silently overwritten | `recalculateStructure({keepManualLevels = true})` — **keeping is the default** |
| Host is asked | Recalculate dialog counts the edits and offers *Keep* / *Replace* / *Cancel*; with none it is unchanged |
| Outcome recorded | `'structure_recalculate'` audit entry names how many were kept and how many dropped |

**Compatibility.** Additive and defaults to `false`, which is not merely a safe
default but factually correct: every level written before the marker existed
*was* engine output. Re-application is by level **number**, so an edit whose
level no longer exists after a rebuild is dropped rather than appended
somewhere it was never meant to be — and the audit entry says so.

### Step 5.2 — One rebuy / re-entry toggle (§7, §32)

> *"Rebuy/re-entry: Single ON/OFF."* · *"Rebuy/re-entry is one toggle."*

They were two independent switches, so a host could enable rebuys and never
notice re-entry was a separate decision.

- The Off / Limited / Unlimited control is now the single toggle, titled
  **"Rebuys & re-entry"**
- The standalone *Re-entry* switch is gone from both forms
- `reEntry` **remains a stored field** — it still gates its own live action
  (`app_provider_players.dart`) and still feeds the engine's expected-chip
  projection. It simply no longer has a control of its own (§2.1)

**The asymmetry is deliberate.** In the creation wizard the pair moves
together. In the *edit* form, switching the pair **off** clears re-entry, but
switching it **on** does *not* retroactively enable re-entry on a game created
without it — that would change the engine's chip projection and unlock a live
action the host never agreed to (§2.3). Such a game shows a line saying its
setting is being kept as-is.

### Step 5.3 — Locked headcount (§6)

§6 names four distinct concepts. Three existed; **Locked** did not.

| Concept | Source |
|---|---|
| Confirmed | `GameSettings.players` |
| Expected | `expectedPlayersOverride` (built earlier) |
| **Locked** | `lockedExpectedPlayers` — **new** |
| Actual checked-in | `confirmedCount` — still what the start CTA uses |

- `lockExpectedPlayers([count])` freezes the current planning figure
- `unlockExpectedPlayers()` releases it
- `plannedHeadcount(game)` resolves the precedence: **Locked → override → RSVP-derived**
- `lockedHeadcountDrift(game)` reports how far RSVPs have moved from the lock,
  so §6's *"late RSVP changes do not silently reshuffle the locked
  preparation"* holds — drift surfaces, it does not act
- Both `generateFinalStructure` and `recalculateStructure` honour the
  precedence, still floored at whoever has actually checked in

Unlocking needs its own `clearLockedExpectedPlayers` flag, because `null` in
`copyWith` means *leave alone* — without it a host could never release a lock.
Asserted.

### Gate

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | 37 issues, 0 errors — unchanged from baseline |
| `flutter test` | **113 passing, 0 failing** (Phase 1 left it at 104) |
| New tests | `test/structure_integrity_test.dart` — 9 passing |
| Schema | additive only; old documents load as unedited / unlocked, both asserted |

Lock/unlock is surfaced on the check-in screen as a head-count panel: what the
night is being prepared for, a Lock / Unlock action, the drift notice when
RSVPs move after a lock, and a reminder that the start CTA uses actual
checked-in rather than the prepared figure.

### Not done in this phase

- Table balance and colour-up still need the §14 activity-log check carried
  over from Phase 1.
- The lock panel has no widget test. It is presentational over an API that is
  unit-tested; worth a golden if the design settles.

### Rollback

`git revert` the branch. The two new fields would remain in existing
documents and are ignored by the reverted code.
