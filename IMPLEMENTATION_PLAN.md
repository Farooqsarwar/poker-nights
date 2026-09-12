# Poker Night — Implementation Plan

**Target specification:** *Poker Night — Perfect Developer Specification*, 10 September 2026
**Baseline:** branch `farooq`, commit `42b92fcf`
**Plan written:** 11 September 2026

---

## 0. How to read this document

The 10 September specification replaces the three earlier PDFs. Everything through
§29 is marked APPROVED; §30 is explicitly *not* approved and must not be built
without a written instruction.

This plan sequences that specification into phases that can be delivered one at a
time **without breaking anything that already works**. That constraint is the
point of the document, so Section 2 (Safety Rules) is not optional preamble — it
is the part that keeps a live tournament from dying mid-game because of a deploy.

Each phase is written as:

- **Goal** — one sentence
- **Spec references** — so the client can audit it
- **Preconditions** — what must be true before starting
- **Schema changes** — with compatibility notes
- **Steps** — numbered, each independently committable
- **Tests to add** — written *before* the behaviour changes
- **Acceptance gate** — how we know it's done
- **Rollback** — how to undo it if it goes wrong

---

## 1. Current state — what already exists

Do not re-build or re-quote any of this.

| Capability | Spec § | Where |
|---|---|---|
| Expected-players `+/-` stepper, not a text field | §6 | `widgets/count_stepper.dart`, wired into create + edit |
| Target duration ladder 3h → 6h | §7 | `create_tournament_screen.dart:1062` |
| Chip inventory per colour/denomination/quantity, AI constrained to owned chips | §10, §25 | `utils/tournament_engine.dart` |
| Edit suggested stack with `+/-` per colour | §10 | `widgets/chip_set_editor.dart` |
| Full-schedule blind payability validation | §10 | `tournament_engine.dart`, `test/engine_properties_test.dart` |
| Level durations restricted to 10/15/20 | §11 | `widgets/structure_editor.dart` `kAllowedLevelDurations` |
| Speed Up / Slow Down with confirmation, future levels only | §13 | `app_provider_tournament.dart` `acceptSpeedRecommendation` |
| Completed levels immutable | §11, §29 | Enforced in `acceptSpeedRecommendation`, `adjustStructure` |
| KO bounty excluded from the prize pool | §18 | `tournament_engine.dart`, test `23-007` |
| Host-authoritative timer surviving network loss | §12 | `levelEndTime` + server-time calibration |
| Privacy projections at the write boundary | §23 | `services/projections.dart` |
| **Three-tier group role model** `member / coAdmin / admin` | §3 | `models/user.dart:31`, enforced in `firestore.rules` |
| Undo for mistaken live actions | §30 | `_pushUndo` |
| Host takeover / single-active-editor claim | §30 | `editorDeviceId`, `_forceClaimEditor` |
| Offline / reconnecting / synced indicators | §30 | `app_provider_cloud_sync.dart` |
| Explicit tournament phases (10 states) | §30 | `LiveGameStatus` |
| Explicit player statuses | §30 | `Player` flags |
| Deterministic engine + shortage warnings | §30 | `tournament_engine.dart` |
| Financial invariants reconcile to gross exactly | §30 | `test/payout_rules_test.dart` |

**Test baseline: 94 tests passing.** This number must never go down.

---

## 2. Safety rules — the contract that keeps the app working

These apply to **every** step in this plan. A step that violates one of these is
not done, regardless of whether it works on the developer's machine.

### 2.1 Schema is additive only

Firestore documents are read by clients we do not control — a player's phone
running last week's build, a TV in the corner that hasn't been refreshed in
three hours.

- **Never rename a field.** Add the new one, write both for one release, retire
  the old one a release later.
- **Never remove a field** that a shipped client reads.
- **Every new field is nullable or has a default in `fromMap`.** Pattern already
  used throughout `utils/model_codec.dart`:
  ```dart
  expectedPlayersOverride: (m['expectedPlayersOverride'] as num?)?.toInt(),
  addOnCloseLevel: (m['addOnCloseLevel'] as num?)?.toInt() ?? 6,
  ```
- **Round-trip test for every new field.** `toMap` → `fromMap` → equal, and
  `fromMap({})` → sane defaults.

### 2.2 Old clients must not be poisoned by new documents

A new field an old client ignores is safe. A new **state** an old client cannot
interpret is not.

The dangerous one in this plan is the `break` status (Phase 3). An old client
reading `status: "onbreak"` falls through its `switch` and may crash or show
nothing.

**Rule:** when adding an enum value that old clients will read, write a
compatible legacy value alongside it:

```dart
'status': 'onbreak',          // new clients
'statusLegacy': 'paused',     // old clients fall back to this
```

`_enumByName(..., fallback)` in `model_codec.dart` already degrades safely; verify
this for each new value rather than assuming.

### 2.3 Behaviour changes are versioned, never retroactive

**This is the single most important rule in the plan.**

§11 changes the starting-stack target from ~125 BB (current) to ~50–100 BB. If we
simply change the constant, **every existing published tournament silently gets a
different structure** the next time anything triggers a regenerate. A host who
prepared physical chip stacks on Friday finds different numbers on Saturday.

**Rule:** stamp the engine calibration onto the structure at generation time.

```dart
/// Which calibration produced this structure. Structures keep the rules they
/// were generated under, so a recalibration never rewrites a tournament the
/// host has already prepared for.
final int engineVersion;   // absent/0 = legacy 80-240 band, 1 = spec-2026-09
```

- New structures generate at the current version.
- `recalculateStructure` on an existing game keeps that game's version **unless
  the host explicitly opts in** ("Rebuild with the new chip model").
- Property tests run against **both** versions until the client confirms the old
  one can be retired.

The same pattern covers the organizer-percentage default change (§7) and the
rebuy/re-entry toggle merge (§7).

### 2.4 Everything new ships behind a flag

```dart
// lib/app/feature_flags.dart
abstract final class Features {
  static const breaks = bool.fromEnvironment('FEATURE_BREAKS');
  static const organizerRole = bool.fromEnvironment('FEATURE_ORGANIZER');
  static const multiPayout = bool.fromEnvironment('FEATURE_MULTI_PAYOUT');
  static const premium = bool.fromEnvironment('FEATURE_PREMIUM');
}
```

Ship dark → verify in production with a real group → enable. A flag that has been
on for two releases with no issues gets deleted along with the old path.

### 2.5 Test gate on every step

Before starting a step:
```bash
flutter analyze --no-pub        # must be ≤ 37 issues, 0 errors
flutter test                    # must be 94+ passing
```

Before committing a step, the same two commands, plus the new tests for that step.
**Write the test before the behaviour change** wherever the behaviour is
observable — that is what proves the change did what was intended rather than
something adjacent.

### 2.6 Firestore rules change before the client does

Rules are deployed separately from the app and take effect immediately for
everyone. Always:

1. Widen rules (permit old **and** new shapes)
2. Deploy rules, verify nothing broke
3. Ship the client that writes the new shape
4. Narrow rules to the new shape only, one release later

Never step 4 before step 3 has been in production for a full release.

### 2.7 One phase, one branch, one review

```
farooq                        ← integration
 └── phase/1-foundation-fixes
 └── phase/2-permissions
 └── phase/3-breaks
```

Each branch: green suite, `flutter build web --release` succeeds, manual smoke
test of the four critical paths below, then merge.

### 2.8 The four critical paths — smoke test before every merge

These are the paths where a regression costs the client a real evening:

1. **Create → publish → RSVP → check-in → generate structure → start**
2. **Live: rebuy → add-on → elimination → level change → colour-up**
3. **Two devices: host + player, check-in lands on the host** *(this has broken twice; always test it)*
4. **Guest joins by link, sees the live view, cannot see private financials**

---

## 3. Open decisions — blocking, must be answered before the phases they gate

| ID | Question | Spec | Blocks | Why it matters |
|---|---|---|---|---|
| **D1** | Confirm starting depth **50–100 BB** | §11 | Phase 4 | Reverses deliberate tuning (PN-001); changes every structure |
| **D2** | Premium: what is free, what is paid, group member limit | §4, §19 | Phase 8 | §4 says "TBD/configurable" — not buildable |
| **D3** | Does Premium need **billing**, or only feature gates? | §19 | Phase 8 | Payment integration roughly doubles that phase |
| **D4** | Are the **4 public tools** in launch scope? | §2 | Phase 9 | Close to a second product |
| **D5** | Confirm **Android** is paid scope | §2 | Phase 7 | Was in no prior contract |
| **D6** | Break placement when rebuys are OFF — what is the default? | §8 | Phase 3 | §8 only specifies the rebuys-ON recommendation |
| **D7** | Organizer assignment — can a **guest** be an organizer? | §3 | Phase 2 | Affects the permission matrix and the rules |

Phases 1, 5 and 6 are not blocked and can start immediately.

---

# PHASE 1 — Foundation fixes (unblocked, low risk)

**Goal:** land the small, unambiguous spec deltas that touch no architecture.

**Spec:** §7, §14, §24
**Size:** 3–5 days
**Depends on:** nothing

### Step 1.1 — Organizer cost default 0% → 10%

§7 and §18 both specify default 10%, wording *"Percentage retained for equipment,
drinks & snacks"*, and that it is **private** and **never called rake**.

| File | Change |
|---|---|
| `create_tournament_screen.dart:230` | `TextEditingController(text: '0')` → `'10'` |
| `create_tournament_screen.dart` | Replace the label with the exact spec wording |
| `invitation_screen.dart` | Same wording in the edit form |
| `models/live_game.dart` | Leave `organizerPct` as-is — **do not** change stored defaults |

**Compatibility:** this is a *form default*, not a stored default. Existing games
keep the percentage they were created with. Verify by loading a game created
before the change and confirming it still reads 0.

**Tests:** extend `payout_rules_test.dart` with the §18 worked example — gross 165
→ organizer 15 → net 150. *(Already passing; add it explicitly under the new
section number so the client can trace it.)*

**Grep for "rake"** across the whole repo, including comments and test names. §32
lists it as a term that must not drift.

### Step 1.2 — No currency symbols in the primary UI — ✅ **already clean**

§7 and §24. Audited 12 September: no `€`, `£` or `¥` anywhere in `lib/`. The
`$` matches are Dart record accessors (`ctx.$1`) and doc comments in
`utils/money_utils.dart`. **No change required.**

### Step 1.3 — ~~Replace emoji UI icons~~ → **moved to Phase 10**

§24: *"one coherent icon family; do not use generic emojis as UI icons."*

**Deferred, deliberately.** Choosing an icon family *is* design-system work, and
§31 says not to polish visuals while the state and permission model is unstable.
Doing it here means picking a set now and revisiting it during Phase 10 — the
same mistake §31 warns about. `Group.icon` (`models/group.dart:19`) stays as-is
until then.

When it is done, in Phase 10:

- Keep the `icon` field a `String` (§2.1 — additive only)
- Map known emoji values onto the new set so existing groups keep their identity
- Unknown values fall back to a default rather than rendering raw emoji

### Step 1.4 — Navigation says "Groups"

§3, §32. Label-only change. Do **not** rename the `Group` model or its routes —
the user-visible cost is zero and the diff risk is large.

```bash
grep -rn "'Group'" lib/ --include=*.dart
```

### Step 1.5 — Activity-log completeness audit

§14 and §29: *"every operational action timestamped."*

Enumerate every live action and confirm each calls `addAuditRecord`.

**Audit result (12 September) — five actions had no record at all:**

| Action | Was | Now |
|---|---|---|
| Rebuy / re-entry | ❌ nothing | `'rebuy'` |
| Add-on | ❌ nothing | `'addon'` |
| Elimination | ❌ announcement only | `'elimination'` |
| Late player | ❌ announcement only | `'late_player'` |
| Generate seat | ❌ announcement only | `'seating'` |
| Structure edit / speed / settle / cancel / publish / final table | ✅ | unchanged |

Rebuy and add-on were the serious ones: money entered the game and the prize
pool moved with nothing written down. An announcement is **not** a log entry —
announcements are ephemeral, and §29 requires the action be reconstructable.

Locked by `test/activity_log_test.dart`.

**Acceptance gate for Phase 1**

- [ ] 94+ tests green
- [ ] `flutter analyze` ≤ 37 issues, 0 errors
- [ ] A game created before the change still shows its original organizer %
- [ ] No `€`/`$` in `lib/`, no "rake" anywhere
- [ ] Every §14 action produces a timestamped record

**Rollback:** revert the branch. No schema change, so no data cleanup.

---

# PHASE 2 — Permission model (P0, the foundation)

**Goal:** multiple admins, tournament-scoped Organizer, owner transfer, invitation
approval.

**Spec:** §3, §26, §28, §32
**Size:** 8–12 days
**Depends on:** D7
**Blocks:** Phase 6 (design), and per §31 nothing visual should be polished until
this is stable.

### What already exists

`GroupRole { member, coAdmin, admin }` (`models/user.dart:31`), persisted as
`role` on membership rows and enforced in `firestore.rules`. This is most of the
multi-admin tier. What is missing is the **tournament-scoped** Organizer.

### Step 2.1 — Model the Organizer assignment

Organizer is **per tournament**, not per group (§3, §32). It therefore belongs on
the game, not the membership row.

```dart
// models/live_game.dart
/// User ids assigned operational control of THIS tournament (spec section 3).
/// Tournament-scoped by design: an organizer has no group-level rights and no
/// access to any other tournament's private data.
final List<String> organizerIds;   // defaults to const []
```

**Compatibility:** additive, defaults to empty. Old clients ignore it and behave
exactly as today (admin-only).

### Step 2.2 — One capability check, used everywhere

Today permission logic is scattered. Before adding a third role, centralise it,
or the §28 matrix cannot be verified.

```dart
// lib/services/permissions.dart
enum Capability {
  viewGroup, chatAndPolls, createEvent, rsvpOwnGuests,
  approveMembership, editGroupSettings, manageAdmins,
  runThisTournament, rebuyAddOnOps, seatingRebalance,
  viewPrivateFinancials, deleteGroup,
}

bool can(Capability c, {required AppUser user, required Group group, LiveGame? game});
```

Transcribe §28 into a table-driven test **first**:

```dart
// test/permission_matrix_test.dart
// Every cell of specification section 28, asserted explicitly.
```

Then refactor call sites to use `can(...)`. The test is what makes this
refactor safe.

### Step 2.3 — Group invitations with admin approval

§3: *"Any member can invite; invitation stays pending until Admin approval."*

New collection `groups/{gid}/invitations/{id}`:

| Field | Notes |
|---|---|
| `invitedEmailHash` | reuse the existing `emailIndexKey` sha256 pattern — never store a raw email |
| `invitedByUserId` | |
| `status` | `pending` / `approved` / `rejected` / `expired` |
| `createdAt`, `decidedAt`, `decidedByUserId` | §3 activity log |

Rules: a member may **create** a row with `status == 'pending'` only; only an
admin may transition it. This mirrors the existing C1-hardened membership-create
rule at `firestore.rules:270`.

### Step 2.4 — Owner transfer

§3. Transactional: demote the current owner to admin and promote the target in one
write, so the group can never end up with zero or two owners. Audit-log it.

### Step 2.5 — Rules + projections

- Extend `firestore.rules` for `organizerIds` and the invitations collection.
- Extend `services/projections.dart`: an organizer sees private financials **for
  their assigned game only** (§28), nothing for any other game.
- Follow §2.6 — widen, deploy, ship client, narrow.

**Tests to add**

- `permission_matrix_test.dart` — every cell of §28
- Organizer cannot read another tournament's private fields
- A member-created invitation cannot be self-approved
- Owner transfer is atomic; no state with 0 or 2 owners

**Acceptance gate**

- [ ] §28 matrix fully asserted, all green
- [ ] Rules deployed and verified before the client ships
- [ ] Critical path 4 (guest sees no private financials) still passes
- [ ] An old client with no knowledge of `organizerIds` behaves as admin-only

**Rollback:** flag `FEATURE_ORGANIZER` off. `organizerIds` stays in the documents
harmlessly; rules are permissive of its absence.

---

# PHASE 3 — Breaks (P0, approved, new)

**Goal:** scheduled breaks as a first-class part of the structure and the live
state machine.

**Spec:** §8 (approved, with its own acceptance gate), §27, §32
**Size:** 5–7 days
**Depends on:** D6

§8 is explicit that *"a break is a real scheduled state, not merely a manual
pause."* Today `LiveGameStatus.rebuypause` is a manual pause — it is **not** a
break and must not be reused for one.

### Step 3.1 — Model

```dart
// models/tournament.dart
/// A scheduled break (spec section 8). Distinct from a manual pause: it is
/// part of the generated structure and is counted in the target duration.
class ScheduledBreak {
  final int afterLevel;     // break runs after this level completes
  final int durationMins;   // 5 / 10 / 15 / 20, or custom
}
```

- `GameSettings.breaks` → `List<ScheduledBreak>`, defaults `const []` (= OFF)
- `TournamentStructure.breaks` → the resolved list actually generated

**Compatibility:** empty list means "no breaks", which is exactly today's
behaviour. Old documents deserialise to `[]`.

### Step 3.2 — Duration accounting

§8: *"target 4h = 3h40 playing + 20 min scheduled breaks."*

In `tournament_engine.dart`:

```dart
final breakMins = breaks.fold<int>(0, (a, b) => a + b.durationMins);
final playingMinutes = params.durationHours * 60 - breakMins;
```

`playingMinutes` already drives `plannedLevels` (`tournament_engine.dart:1013`),
so subtracting there propagates correctly through the pace model.

`expectedFinishMins` must include break time. **Careful:** `settlementBreakMins`
(currently 15) is a different thing — the post-rebuy settlement pause. Keep them
separate and name them distinctly, or the finish estimate double-counts.

### Step 3.3 — Default placement

§8: when rebuys/re-entry are enabled, default to immediately after the rebuy
period ends. With rebuys off — **D6**, ask the client. Suggested default until
answered: after the midpoint level, which is the common home-game convention.

### Step 3.4 — Live break state

```dart
enum LiveGameStatus { ..., onBreak, ... }
```

Per §2.2 this is the dangerous change. Add `onBreak` **at the end of the enum**
(index stability) and write a legacy-compatible value alongside it so old clients
see a paused game rather than an unknown state.

Behaviour:
- Level ends → if a break is scheduled after it, enter `onBreak`
- Timer counts down the break; TV and player views show `BREAK` + remaining
- Break ends → next level starts automatically
- Host may skip or extend; both audit-logged

### Step 3.5 — Setup UI

§8: ON/OFF · 1 or 2 breaks · placement preset (after L4/5/6/7/8 or custom) ·
duration preset (5/10/15/20 or custom). Reuse `CountStepper` for custom values.

**Tests to add** — `test/breaks_test.dart`

- OFF produces no break and today's exact structure *(regression guard)*
- ON with 1 break: playing time + break = target
- ON with 2 breaks: same
- Default placement follows the rebuy close level
- Custom placement and duration honoured
- `expectedFinishMins` includes break time and does not double-count settlement
- Break state transitions: level → break → next level
- An old-format document with no `breaks` field loads and behaves as OFF

**Acceptance gate** — §29's break-specific gate, verbatim

- [ ] OFF means no scheduled break
- [ ] ON supports 1 or 2 breaks
- [ ] Each break has placement and duration
- [ ] Presets plus custom values
- [ ] Default recommendation after the rebuy period
- [ ] AI includes break time in target duration
- [ ] Live system recognises break as a scheduled state

**Rollback:** `FEATURE_BREAKS` off → `breaks` is always `[]` → today's behaviour
exactly.

---

# PHASE 4 — Engine recalibration (P0, high blast radius)

**Goal:** move starting depth to §11's ~50–100 BB **without touching any existing
tournament**.

**Spec:** §11
**Size:** 2–3 days
**Depends on:** **D1** — do not start without a written answer

> **Raise D1 with the client first.** The current engine targets ~125 BB and
> enforces an 80–240 band (`tournament_engine.dart:1016, 1147`). That band was
> tuned deliberately under finding PN-001. §11 says 50–100 BB "not rigid", which
> sits entirely below it. Confirm this is intended before rebuilding it.

### Step 4.1 — Introduce `engineVersion` (do this first, on its own)

Per §2.3. Ship this step **alone**, verify nothing changes, then proceed.

```dart
// models/tournament.dart
/// Which calibration generated this structure. 0/absent = the pre-2026-09
/// 80-240 BB band; 1 = specification 2026-09 (50-100 BB).
final int engineVersion;
```

- `generate()` takes a version, defaults to current
- `recalculateStructure` reuses the game's stored version
- Codec defaults absent → `0`

**At this point nothing has changed behaviourally.** Confirm with a full suite run
before continuing.

### Step 4.2 — Add the v1 calibration alongside v0

Keep both paths. `targetBBDepth` and the band gate become version-dependent.

### Step 4.3 — Parameterise the property tests over both versions

`engine_properties_test.dart` currently asserts the 80–240 band. Parameterise it:
v0 asserts 80–240, v1 asserts 50–100. Both must pass. This is what proves the old
path is untouched.

### Step 4.4 — Default new structures to v1, offer opt-in upgrade

New tournaments generate at v1. Existing games keep v0 and show an explicit
*"Rebuild with the updated chip model"* action — never automatic.

**Acceptance gate**

- [ ] A game created before this phase produces a byte-identical structure
- [ ] New games land in 50–100 BB
- [ ] Property tests pass for **both** versions
- [ ] Chip payability holds at v1 (`chip_payability_test.dart` parameterised too)

**Rollback:** flip the default back to v0. Data is unaffected — every structure
carries its own version.

---

# PHASE 5 — Structure integrity (P0, unblocked)

**Goal:** manual edits survive; rebuy/re-entry becomes one toggle; the Locked
headcount concept.

**Spec:** §6, §7, §11, §29
**Size:** 4–6 days

### Step 5.1 — Manual future edits are marked and protected

§11 and §29: *"manual future edits need visible markers and cannot be silently
overwritten by Recalculate."* Today Recalculate overwrites them.

```dart
// models/tournament.dart
class BlindLevel {
  ...
  /// True when a human set this level's values. Recalculate must not silently
  /// discard it (spec sections 11 and 29).
  final bool manuallyEdited;   // default false
}
```

- `StructureEditor` marks edited levels
- UI badge on marked levels
- Recalculate detects them and **asks**: keep manual levels, or discard them?
  Never silent either way.

### Step 5.2 — Rebuy / re-entry as a single toggle

§7 and §32: *"Rebuy/re-entry is one toggle."* Today `rebuys` and `reEntry` are
separate booleans.

**Do not delete the fields.** Add the combined concept, derive both for
persistence, keep writing both for one release:

```dart
bool get rebuyOrReEntryEnabled => rebuys || reEntry;
```

UI collapses to one switch. Sub-options when ON: until level (default 6), max per
player (unlimited or number), price (defaults to buy-in, editable) — all per §7.

### Step 5.3 — Locked headcount

§6 defines four distinct concepts. Three exist; **Locked** is new.

| Concept | Status |
|---|---|
| Confirmed — raw RSVP count | exists |
| Expected — organizer estimate, `+/-` stepper | built (Phase 0 of the earlier work) |
| **Locked** — expected frozen for physical preparation | **new** |
| Actual checked-in — present and confirmed | exists |

```dart
/// The expected count frozen for physical chip preparation (spec section 6).
/// Late RSVP changes must not silently reshuffle a locked preparation.
final int? lockedExpectedPlayers;
```

- Lock/unlock action for admin and organizer
- Once locked, later RSVP changes do **not** alter the prepared structure; they
  surface as a notice instead
- Start CTA still uses actual checked-in: `"Start Tournament — 13 Players"` (§6)

**Tests:** `test/headcount_test.dart` — the §6 worked example (Confirmed 12,
Expected 15, Lock 15, 13 check in → CTA says 13) asserted end to end.

**Acceptance gate**

- [ ] Recalculate never silently discards a manual edit
- [ ] Marked levels visibly marked
- [ ] One rebuy/re-entry toggle; both legacy fields still written
- [ ] §6 worked example passes end to end

---

# PHASE 6 — AI payouts & voice (P1)

**Size:** 6–8 days · **Depends on:** Phase 2

### Step 6.1 — Multiple payout options

§18 and §25: *"AI generates multiple payout options, not only one"* — e.g. 3, 4
or 5 paid positions, each showing position, percentage and amount; the organizer
selects.

```dart
class PayoutOption {
  final int paidPlaces;
  final List<PrizeEntry> prizes;   // place, pct, amount
  final String rationale;          // section 30 "explainable AI" — cheap here
}
```

- Engine returns `List<PayoutOption>`; keep the existing single-result function as
  a wrapper over `options.first` so nothing breaks while the UI catches up
- Selection persisted on the game
- Rounding stays deterministic and clean (§18) — the existing rules already
  satisfy this

**Tests:** extend `payout_rules_test.dart` — every option totals exactly 100%,
every option reconciles to the net pool, options are distinct, amounts are clean.

### Step 6.2 — Voice reduced to level transitions

§17 is narrower than what we have. Current scope is **level transitions only**.

| Moment | Say |
|---|---|
| 1 minute remaining | *"1 minute remaining"*, then the next level's blinds |
| Level end | audible 5-4-3-2-1, then *"Start of level N — blinds X — duration Y minutes"* |

Explicitly **removed** (§17): start, rebuys-closed, final-table, winner, dealer.

- Tournament-level ON/OFF, admin/organizer only
- Mute and volume control
- Optional synced visual cue, **off by default**
- Driven by the same authoritative state transition as the timer — no drift

**Implementation note:** do not delete the other announcement call sites. Gate
them behind a per-event settings map so the client can re-enable individually
without another release. He has changed his mind on this once already.

> **Worth telling the client:** silencing "rebuys closing" and "add-ons
> available" has a real cost — a player who misses that window loses money. §17
> is unambiguous, so we will build it as written, but a per-event toggle costs us
> nothing and leaves the door open.

---

# PHASE 7 — Native iOS & Android (P0/P1)

**Size:** 10–16 days · **Depends on:** D5 · **Can run in parallel**

§2: *"Any earlier PWA-only assumption is obsolete."* This closes the long-standing
PN-035 contradiction. `android/` and `ios/` scaffolding exists and commit
`42b92fcf` reports mobile running, but store-ready is a different bar.

| Step | Work |
|---|---|
| 7.1 | Bundle ids, signing, provisioning, keystore |
| 7.2 | Push on both platforms (OneSignal already integrated for web) |
| 7.3 | **Background audio** — voice must survive a locked screen. This is very likely the real reason native was requested; verify it early, it is the highest-risk unknown |
| 7.4 | Wake-lock during a 4-hour tournament |
| 7.5 | Store listings, privacy declarations, review submission |
| 7.6 | Device matrix testing |

**Ask the client why** native is wanted. *"So it's in the App Store"* and *"the
voice stopped when I locked my phone"* are very different requirements with very
different priorities — and the second one is a genuine PWA limitation.

---

# PHASE 8 — Premium (P1/P2)

**Size:** 10–15 days without billing, 20–25 with · **Depends on:** D2, D3

§4, §19, §29. **Do not start without D2 and D3 answered.** §4 says the group
member limit is "TBD/configurable", which is not buildable.

- Entitlement model on the user or group
- **Server-enforced** (§19, §29) — client gates alone are not acceptance-passing
- Free: basic cash game, blinds, players, seating, session timer, buy-ins,
  cash-outs, basic history
- Premium: customization, multi-table, advanced seating, saved presets, expanded
  history, advanced controls
- Premium gating is **feature-level, not creation-level** (§19) — any signed-in
  user can create a cash game

---

# PHASE 9 — Public tools (P1/P2)

**Size:** 8–10 days · **Depends on:** D4

§2: Blind Structure Generator, Tournament Clock, ICM Calculator, Payout
Calculator. No account, each with its own URL. **No routes exist today.**

The engine already does most of the work for the generator and the payout
calculator — they are largely a public shell around existing logic. The ICM
calculator is genuinely new maths.

---

# PHASE 10 — Design system (P2 by §31, but large)

**Size:** 8–12 days · **Depends on:** Phase 2

§31 is explicit: *"Do not polish screens while the underlying tournament state and
permission model is unstable."* Doing this before Phase 2 means doing it twice.

§24 and §12:
- Shared tokens: colour, typography, spacing, shadows, radii
- **Horizontal, prominent timer** (§12) — currently vertical
- Bold `LEVEL N` above the countdown
- Green/amber/red depth indicator around AVG STACK
- Gold as an accent, not every border
- Red vertical-bar brand texture
- Centred content, sensible desktop max-widths
- Avoid low-contrast grey
- Ten named redesign targets in §24

---

# PHASE 11 — Polish & accessibility (P2)

**Size:** 4–6 days

- Soft shot clock / time bank, independent of the level timer (§12)
- Accessibility testing of critical screens, especially canvas-rendered ones
  (§23, §29)
- Screen-reader pass

---

## 4. Sequencing

```
D1 ─────────────────────────► Phase 4 (engine)
D5 ─────────────────────────► Phase 7 (native)      ── parallel, independent
D2,D3 ──────────────────────► Phase 8 (premium)
D4 ─────────────────────────► Phase 9 (tools)
D6 ─────────────────────────► Phase 3 (breaks)
D7 ─────────────────────────► Phase 2 (permissions)

Phase 1 (fixes)      ── start now, unblocked
Phase 5 (integrity)  ── start now, unblocked
Phase 2 (permissions) ──┬─► Phase 6 (payouts/voice)
                        └─► Phase 10 (design)  ← never before Phase 2
Phase 3 (breaks)     ── independent of Phase 2
Phase 4 (engine)     ── after Phase 3 (breaks change duration maths)
Phase 11 (polish)    ── after Phase 10
```

## 5. Effort summary

| Phase | Item | Days | Blocked by |
|---|---|---|---|
| 1 | Foundation fixes | 3–5 | — |
| 2 | Permission model | 8–12 | D7 |
| 3 | Breaks | 5–7 | D6 |
| 4 | Engine recalibration | 2–3 | **D1** |
| 5 | Structure integrity | 4–6 | — |
| 6 | AI payouts & voice | 6–8 | Phase 2 |
| 7 | Native iOS + Android | 10–16 | D5 |
| 8 | Premium | 10–15 | D2, D3 |
| 9 | Public tools | 8–10 | D4 |
| 10 | Design system | 8–12 | Phase 2 |
| 11 | Polish & accessibility | 4–6 | Phase 10 |
| | **Total** | **68–100** | |

Indicative developer-days, excluding client decision turnaround and store review.

## 6. Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| Engine recalibration changes prepared tournaments | Host turns up with the wrong chips | `engineVersion` (§2.3) — never retroactive |
| `onBreak` status crashes old clients | Live tournament breaks mid-game | Legacy status alongside (§2.2); fallback-tested |
| Permission refactor opens a data leak | Private financials exposed | §28 matrix test written **before** the refactor |
| Rules deployed ahead of client | Everyone locked out instantly | Widen → deploy → ship → narrow (§2.6) |
| Design pass before permissions | Redesign done twice | §31; Phase 10 gated on Phase 2 |
| Premium scope undefined | Unquotable, scope creep | D2/D3 blocking |
| iOS background audio doesn't work | The main reason for going native fails | Spike it in Phase 7 **first** |
| Check-in race regresses | Has already broken twice | Critical path 3 in every smoke test |

## 7. Per-phase definition of done

- [ ] Full suite green, count never below the previous phase
- [ ] `flutter analyze` — 0 errors, issues ≤ baseline
- [ ] `flutter build web --release` succeeds
- [ ] New tests written for the new behaviour
- [ ] All four critical paths smoke-tested manually
- [ ] Schema changes additive; old-document load tested
- [ ] Firestore rules deployed ahead of the client
- [ ] Feature flag present and default-off
- [ ] Spec section referenced in the code comments
- [ ] `SIGN_OFF.md` updated with the acceptance gate

---

## 8. Immediate next actions

1. **Send D1–D7 to the client.** Phases 2, 3, 4, 7, 8 and 9 are all gated on
   answers. D1 is the most urgent — it reverses deliberate work.
2. **Commit the 7 bug fixes** currently sitting uncommitted on `farooq`.
3. **Start Phase 1** — unblocked, low risk, visible progress while decisions land.
4. **Spike iOS background audio** — a half-day answer that may reshape Phase 7's
   priority entirely.
5. **Tell the client he already has 7 of his 21 §30 recommendations.** It is free
   credibility and may change what he approves.
