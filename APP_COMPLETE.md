# Poker Night — Complete Application Reference

**Every subsystem, every algorithm, every formula. One document.**

Engine version `2.1.0` · 160 Dart files · ~69,000 lines

---

## Contents

**Part I — The application**
1. [What the application is](#1-what-the-application-is)
2. [Architecture](#2-architecture)
3. [The domain model](#3-the-domain-model)
4. [Data storage and schema](#4-data-storage-and-schema)
5. [Identity, sessions and the route guard](#5-identity-sessions-and-the-route-guard)
6. [Permissions and projections](#6-permissions-and-projections)
7. [Groups, join codes and invitations](#7-groups-join-codes-and-invitations)
8. [The tournament lifecycle](#8-the-tournament-lifecycle)

**Part II — The tournament engine**
9. [Engine inputs and the override rule](#9-engine-inputs-and-the-override-rule)
10. [Generation, step by step](#10-generation-step-by-step)
11. [The blind ladder](#11-the-blind-ladder)
12. [The chip plan solver](#12-the-chip-plan-solver)
13. [Antes](#13-antes)
14. [The rebuy window](#14-the-rebuy-window)
15. [Breaks](#15-breaks)
16. [Colour-up](#16-colour-up)

**Part III — Money**
17. [Cents, and why](#17-cents-and-why)
18. [The prize pool and the organizer cut](#18-the-prize-pool-and-the-organizer-cut)
19. [Paid places](#19-paid-places)
20. [The payout split](#20-the-payout-split)
21. [Payout options](#21-payout-options)
22. [ICM](#22-icm)
23. [Payments](#23-payments)

**Part IV — Running the night**
24. [The live clock](#24-the-live-clock)
25. [Players: RSVP, check-in, guests, rebuys, eliminations](#25-players-rsvp-check-in-guests-rebuys-eliminations)
26. [Seating and table balancing](#26-seating-and-table-balancing)
27. [Live intelligence: pace, speed, extensions](#27-live-intelligence-pace-speed-extensions)
28. [The cash game module](#28-the-cash-game-module)

**Part V — Everything around it**
29. [Chat, polls and notifications](#29-chat-polls-and-notifications)
30. [Voice announcements and the Audio Master](#30-voice-announcements-and-the-audio-master)
31. [TV and public display](#31-tv-and-public-display)
32. [Sync, authority, undo and recovery](#32-sync-authority-undo-and-recovery)
33. [Integrity and verification](#33-integrity-and-verification)
34. [Statistics and history](#34-statistics-and-history)
35. [Free and Premium](#35-free-and-premium)
36. [Input safety and formatting](#36-input-safety-and-formatting)

**Part VI — Reference**
37. [Complete constants reference](#37-complete-constants-reference)
38. [Documented deviations and judgement calls](#38-documented-deviations-and-judgement-calls)
39. [Boundaries — what the app does not claim to do](#39-boundaries--what-the-app-does-not-claim-to-do)

---
---

# PART I — THE APPLICATION

---

## 1. What the application is

Poker Night runs a home-game poker night end to end: a private group of
regulars, a scheduled tournament, an automatically designed blind structure and
chip plan, a synchronised clock every device in the room shares, live
rebuy and elimination tracking, an automatically reconciled prize pool, and a
recorded result that feeds each player's lifetime statistics. It also runs cash
sessions, and a set of public calculators that need no account.

Three audiences, one app:

- **The host** designs and runs the night — the only role that can change
  anything about a live game.
- **The players** join by code or invite, RSVP, check in, watch the clock,
  request rebuys, see the payout table, chat.
- **The room** — a TV or a laptop — shows a read-only board with no private
  financials on it.

Everything a host does is derived rather than typed wherever it can be. The
host enters *the night they want* — buy-in, how many people, how long it should
run, the chips they own — and the app produces the structure, the chip plan, the
payouts and the schedule. Every derived value remains overridable, and an
override is remembered forever.

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  SCREENS  (Flutter widgets)                                      │
│  public · shell · tournament · premium                           │
└──────────────────────────┬───────────────────────────────────────┘
                           │  reads state, calls intents
┌──────────────────────────▼───────────────────────────────────────┐
│  AppProvider  (ChangeNotifier — the single application state)    │
│  split by domain into `part` mixins:                             │
│   auth · groups · game · players · tournament · timer            │
│   social · notifications+settings · payments · codes+cash        │
│   cloud_sync · user_data                                         │
└───────┬──────────────────────────────────┬───────────────────────┘
        │                                  │
┌───────▼────────────────┐      ┌──────────▼──────────────────────┐
│  PURE LOGIC (no I/O)   │      │  SERVICES (I/O, platform)       │
│  tournament_engine     │      │  firebase_repository            │
│  icm · cash_settlement │      │  push · onesignal_sender        │
│  clock_sequence        │      │  voice · tab_leader             │
│  structure_verification│      │  recovery · payment             │
│  money_utils·formatters│      │  browser_notifications          │
│  permissions·projections│     │  tv_display_settings            │
└────────────────────────┘      └─────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│  MODELS + CODEC   live_game · game · tournament · group ·        │
│  user · cash_game · payment · notification · chip · shot_clock   │
│  model_codec.dart — ONE wire format for cloud AND local          │
└──────────────────────────────────────────────────────────────────┘
```

**Three rules the architecture enforces:**

1. **One wire format.** `model_codec.dart` serialises every model. The cloud
   repository and the device-local recovery store both call it, so a crash
   recovery snapshot and a cloud document are the same shape byte for byte.
   There is no second serialiser that can drift.

2. **Pure logic is pure.** The engine, ICM, settlement and verification take
   values and return values. No clock, no network, no randomness inside them —
   which is why the same inputs always reproduce the same structure, and why
   every device can independently recompute the host's work and check it.

3. **One state object.** All mutable application state lives on `AppProvider`.
   Screens never hold domain state. This is what makes the undo stack, the
   authority model and the single-writer guarantee possible at all.

---

## 3. The domain model

```
AppUser ──┬── memberOf ──> Group ──┬── members: GroupMember[]  (member|coAdmin|admin)
          │                        ├── games:   LiveGame[]
          │                        ├── chat:    ChatMessage[]
          │                        ├── polls:   Poll[]
          │                        ├── notifications
          │                        ├── joinCode (6 chars)
          │                        └── tableSettings (maxPerTable, randomizeByDefault)
          │
          ├── stats: UserStats (played, wins, podium, avgFinish, knockouts)
          ├── results: GameResult[]   (own private copy, per game)
          ├── chipSets · presets
          └── entitlement (device-local tier)

LiveGame ──┬── settings: GameSettings   (every input + every override)
           ├── structure: TournamentStructure (levels[], breaks[], chip plans)
           ├── players: Player[]
           ├── guestSlots: GuestSlot[]
           ├── payments: PaymentRecord[]
           ├── prizePool · organizerAmount · roundingRemainder · prizes
           ├── auditHistory: AuditRecord[]
           ├── changeLog
           ├── chat: ChatMessage[]  (+ per-game chat subcollection)
           ├── clock: currentLevel · levelEndTime · status · shotClock
           └── control: revision · lastIdempotencyKey · editorDeviceId ·
                        editorClaimedAt · audioMasterDeviceId · organizerIds
```

### Effective-value getters

Models never expose a raw field where a derived one is correct:

```dart
effectiveOrganizerPct      = organizerPct.clamp(0, 20)
effectiveExpectedRebuys    = expectedRebuysOverride    ?? round(players × 0.35)
effectiveExpectedReEntries = expectedReEntriesOverride ?? round(players × 0.20)
effectiveExpectedAddOns    = expectedAddOnsOverride    ?? round(players × 0.65)
rsvpDeadline               = scheduledStart − 1 hour
```

---

## 4. Data storage and schema

### Cloud (Firestore)

```
users/{uid}
  ├─ results/{gameId}          own finish record — feeds lifetime stats
  ├─ chipSets/{id}
  ├─ presets/{id}
  ├─ notifications/{id}
  └─ entitlements/{id}
groups/{gid}
  ├─ members/{uid}
  ├─ games/{gameId}
  │     ├─ chat/{msgId}        per-game chat (members append directly)
  │     ├─ players/{...}
  │     ├─ requests/{...}      check-in / rebuy requests
  │     ├─ meta/undoStack
  │     └─ meta/privateData
  ├─ chat/{msgId}
  ├─ polls/{id}
  ├─ notifications/{id}        outbox, mirrored into member inboxes
  └─ pendingInvites/{id}
publicGames/{gameId}           sanitized projections: player · guest · tv
joinCodes/{CODE}               → { gid, gameId?, kind: group|game|tv }
cashSessions/{id}
emailIndex/{...}               email → uid lookup
rate_limits/{key}              e.g. chat-{uid}
```

**Why `publicGames` is a separate collection.** A TV or a guest must never be
able to read the raw game document — it holds the organizer's cut, every
player's rebuy count, the payment ledger and the audit trail. Rather than
hiding fields at read time, the host writes a *pre-stripped* copy (§6).
Security rules can then verify the stripped copy structurally — for example
that `prizes.size() == 0` — instead of trusting a filter.

### Device-local

| Store | Contents | Why local |
|---|---|---|
| Recovery | Active game + cash session, `lastSavedAt` | *"Restore active tournament — last saved 21:43"* after a crash or refresh |
| Guest session | `{gameId, name, inviterId, slot}` | A guest with no account keeps the same approved seat across a refresh |
| TV display settings | Text scale, panels, rotate seconds | The 55-inch screen and the host's phone need different settings |
| Preferences | Voice, app tour, theme | Per device by nature |
| Entitlement | Premium tier | Simulated — see §35 |

All of them use the same `model_codec.dart` serialisation as the cloud.

---

## 5. Identity, sessions and the route guard

| Identity | Account | Sees | Can do |
|---|---|---|---|
| **Signed-in member** | yes | group, games, own results | RSVP, chat, vote, request rebuy |
| **Guest session** | no | one game, guest projection | claim a slot, request check-in |
| **Anonymous visitor** | no | public tools, TV board | calculate, watch |

### The route guard algorithm

`GoRouter`'s `redirect` runs this sequence on every navigation:

```
1.  /game/{CODE}         → rewrite to /join?code=CODE
2.  /group?tab=X         → rewrite to the dedicated route (/chat, /members, …)
3.  if !authReady        → save deep link (once), hold everything at /splash
4.  if adminPath && !isAdmin
                         → /invitation if a game is loaded, else /home
5.  if member on /invitation && game.status.isActiveLive
                         → /player-live            (auto-follow the host)
6.  if admin on /structure-review && game.status.isActiveLive
                         → /admin-dashboard        (no back-nav mid-game)
7.  if !authed && !guestAllowed && !publicPath
                         → /login?next=<encoded original>
8.  if pendingDeepLink   → consume it (public targets resolve for everyone;
                            protected targets route through login first)
9.  if authed && on splash/login/register/forgot
                         → ?next= if present, else /home
```

**The refresh throttle.** `AppProvider` notifies once per second from the clock
and again on every Firestore delivery — roughly fifteen streams. Feeding all of
that to the router re-ran the guard constantly, and a single-frame blip in
`isAdmin` or `currentGame` (while a group bundle re-subscribed) bounced the user
out of the screen they were mid-flow on. So `_RouterRefresh` collapses the
provider's notifications to a seven-value snapshot and only fires when one
changes:

```dart
[authReady, isAuthenticated, hasGuestSession, isAdmin,
 currentGame?.id, currentGame?.status, currentGroup.id]
```

Every tick, every stack edit, every chat message is invisible to routing.

### Route map

```
PUBLIC     /splash · / · /login · /register · /forgot-password
           /tv-mode · /guest-flow · /join · /join-group
           /privacy · /terms · /support
TOOLS      /tools · /tools/blind-structure · /tools/clock
           /tools/icm · /tools/payouts
SHELL      /home · /group · /chat · /members · /polls
           /notifications · /history
TOURNAMENT /create-tournament · /structure-review · /invitation
           /check-in · /admin-dashboard · /player-live
           /rebuy-settlement · /final-table · /complete-tournament
           /result-podium
CASH       /cash-game · /cash-game-live
ACCOUNT    /profile · /settings · /stats · /chip-sets · /edit-chip-set
           /presets · /upgrade · /checkout
```

Each public tool has its own URL because it is meant to be found and linked
individually — somebody searching for an ICM calculator should land on the ICM
calculator, not on a hub they then have to navigate.

---

## 6. Permissions and projections

Two independent mechanisms, and both are needed.

### 6.1 Permissions — *may this person do this?*

```dart
enum Actor      { guest, member, organizer, admin }
enum Capability { …13 capabilities… }

Actor  Permissions.actorFor({user, group, game, isGuestSession})
bool   Permissions.can(capability, actor, {isAssignedGame})
```

The actor is resolved **per game**, not per account. The same person can be
admin of Tuesday's game and an ordinary member of Friday's.

The matrix is a constant table with exactly **one conditional cell**:

```
viewPrivateFinancials → organizer → only on a game they are assigned to
```

Everything else is a flat yes/no. A conditional permission that spreads becomes
impossible to reason about; keeping the exception to one cell is deliberate.

**Decision D7: a guest can never be an organizer.** An organizer handles money
and sees private financials. Somebody with no account, no verified identity and
a session that evaporates on browser-clear is not that person.

### 6.2 Projections — *what bytes does this person receive?*

```dart
projectionFor(game, role, viewerId)   // admin | player | guest | tv
```

Permissions decide what a UI offers. Projections decide what ever leaves the
host's device. The second is what actually protects anything — hiding a widget
does not hide a field in a document.

| Field | admin | player | guest | tv |
|---|---|---|---|---|
| `organizerPct` | actual | **0** | **0** | **0** |
| `forcePaidPlaces` | actual | **null** | **null** | **null** |
| `prizes` | full list | **[]** | **[]** | **[]** |
| `paidPlaces` | actual | scalar only | scalar only | scalar only |
| per-player rebuys / re-entries / add-ons / knockouts | actual | **0** | **0** | **0** |
| `payments` | full ledger | **[]** | **[]** | **[]** |
| `auditHistory` | full | **[]** | **[]** | **[]** |
| `chat` | full | full | **[]** | **[]** |

`prizes` is emptied to a **list** rather than nulled specifically so a security
rule can assert `prizes.size() == 0`. A null would be indistinguishable from an
absent field.

`paidPlaces` survives as a bare number because the room legitimately needs to
know *"three places pay"* without knowing what those places are worth.

---

## 7. Groups, join codes and invitations

### Code generation math

```dart
const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';   // 31 characters
// I, L, O, 0, 1 removed — unreadable aloud and across a room
6 characters drawn from Random.secure()
→ 31⁶ = 887,503,681 possible codes
```

This used to be an LCG seeded from `DateTime.now().millisecondsSinceEpoch`.
Three problems, all fixed:

- every code was reproducible offline from an approximate creation time;
- `publicCode` and `tvCode` were consecutive draws from one process-wide
  stream, so holding either one revealed the other;
- `seed % 31` was modulo-biased across the alphabet.

Document ids use the same cryptographic source:

```dart
secureId(prefix) = '<prefix>-' + 22 chars from [a-zA-Z0-9]
→ 62²² ≈ 2.7 × 10³⁹
```

replacing `<prefix>-<epoch_ms>`, which spanned only a few million values for a
given evening — guessable in minutes.

### Code resolution

One input box accepts anything a person might paste; `extractJoinCode`
normalises all of it:

```
raw code        FRIDAY7
invite link     https://…/join-group?code=FRIDAY7
game link       https://…/game/FP2608
join link       https://…/join/FP2608
QR payload      (any of the above)
    ↓
parse as URI → ?code= param, else last path segment
else contains 'code=' → split on it
else contains '/'     → last segment, strip ?query and #fragment
    ↓
uppercase, strip everything outside [A-Z0-9]
```

`resolveJoinCode` then classifies the code **without joining or subscribing to
anything**, so the unified join screen can route before committing:

```
joinCodes/{CODE} → { gid, gameId?, kind }

no gameId      → group code → group join flow
kind == 'tv'   → TV code    → read-only board
otherwise      → game code  → player / guest flow
```

**Rate limit: 10 lookups per minute per device**, sliding window. This is what
makes 31⁶ meaningful — brute-forcing the space at 10/min takes about 169 years.

```dart
_codeLookupTimes.removeWhere((t) => now.difference(t) > 1 minute);
if (_codeLookupTimes.length >= 10) return rateLimited;
```

### Subscription after resolution

```
kind == 'game' AND this device is game authority
    → subscribe the RAW game document (admins only)
otherwise
    → subscribe publicGames/{gameId}, read the matching projection key:
        tv    → 'tv'
        game  → 'player'
        group → 'guest'
```

A guest, a member on a shared link and a TV never touch the raw document.

---

## 8. The tournament lifecycle

```
                    ┌─────────┐
                    │  draft  │  created, structure not yet confirmed
                    └────┬────┘
                         │ host reviews / edits / confirms structure
                    ┌────▼────────┐
                    │  scheduled  │  invitations out, RSVPs open
                    └────┬────────┘   (RSVP deadline = start − 1 h)
                         │ check-in opens, players confirmed
                    ┌────▼────────┐
         ┌─────────>│   running   │<────────┐
         │          └──┬───┬───┬──┘         │
         │             │   │   │            │
    ┌────┴─────┐  ┌────▼┐ ┌▼───────┐  ┌─────┴──────┐
    │  paused  │  │ on  │ │ rebuy  │  │ finaltable │
    │          │  │break│ │ pause  │  │            │
    └──────────┘  └─────┘ └────────┘  └─────┬──────┘
                                            │ finish order recorded
                                       ┌────▼──────┐    ┌───────────┐
                                       │ completed │    │ cancelled │
                                       └───────────┘    └───────────┘
```

`LiveGameStatus`: `draft, scheduled, running, paused, rebuypause, finaltable,
completed, cancelled, onBreak`.

> **`onBreak` is appended LAST in the enum and must stay there.** Several rules
> compare `status.index` ordinally. Inserting a value in the middle silently
> changes what "past the rebuy pause" means on every game already stored.

### Derived state — the ordinal comparisons

```dart
bool get rebuysClosed {
  if (!settings.rebuys)                return true;
  if (settlementConfirmed)             return true;
  if (status == rebuypause)            return false;  // explicitly open
  if (status.index > rebuypause.index) return true;   // moved past it
  return currentLevel > settings.rebuysCloseLevel;
}

bool get registrationClosed =>
    status.index >= rebuypause.index ||
    (settings.rebuysCloseLevel > 0 && currentLevel > settings.rebuysCloseLevel);

bool get stacksLocked => running || paused || rebuypause || finaltable;
bool get isActiveLive => running | paused | rebuypause | finaltable | onBreak;
bool get isUpcoming   => draft | scheduled;
```

`stacksLocked` stops a host retroactively editing starting stacks once chips are
in play — which would invalidate every average-stack and pace figure already
announced.

---
---

# PART II — THE TOURNAMENT ENGINE

---

## 9. Engine inputs and the override rule

### What goes in

```
buyIn · startingStack · targetDurationMins · levelDurationMins
expectedPlayers · rebuys? · rebuyCost · addOns? · addOnCost
chipSet (denominations + quantities owned)
rebuysCloseLevel · breaks · organizerPct · payoutShape
+ every generation override (each nullable)
```

### The nullable-override pattern

Every generation input on `GameSettings` is nullable (`T?`).

```
null  →  the engine computes this value
value →  the host decided this value; the engine must honour it
```

One convention, three guarantees:

- A tournament created before a new input existed still has `null` there, so it
  regenerates **identically** to the day it was made.
- The UI can always show "auto" versus "you set this" without a second flag.
- Verification (§33) can recompute from the same inputs and get the same answer.

> **Rule for future work:** any new generation input must be (a) persisted on
> `GameSettings`, (b) added to `model_codec.dart`, **and** (c) passed into
> `StructureVerification`'s recomputation. Miss (c) and every honest custom
> structure gets reported as tampering.

### Chip presets shipped

| Preset | Denominations (value × quantity) |
|---|---|
| Standard 300 | 1×100 · 5×100 · 25×50 · 100×30 · 500×20 |
| Standard 500 | 1×150 · 5×150 · 25×100 · 100×60 · 500×40 |
| Home Set (4 colour) | 5×100 · 25×80 · 100×60 · 500×30 |

**Unnumbered chips.** Home sets often have no printed values. The host orders
their colours most-available to least-available and the engine assigns:

```dart
valueLadder = [5, 25, 100, 500, 1000, 5000]
// beyond the ladder: valueLadder.last × 10^(i − ladder.length + 1)
```

It starts at **5, not 1** — deliberately. The most-available colour should map
to the denomination expected to be used most, not automatically to the absolute
lowest value.

---

## 10. Generation, step by step

The order is load-bearing: each step consumes the previous step's output.

```
 0.  DUPLICATE-CHIP GUARD
     two colours sharing one value → DuplicateChipValueException
     (the solver indexes by value; duplicates make its caps meaningless)

 1.  LEVEL LENGTH
     the host's choice wins; otherwise bucket by duration:
        ≤ 3 h → 10 min      ≤ 5 h → 15 min      > 5 h → 20 min
     bounds: 3 ≤ levelDurationMins ≤ 60

 2.  TOTAL CHIPS IN PLAY
     entries = expectedPlayers
             + effectiveExpectedRebuys + effectiveExpectedReEntries
     totalChips = entries × startingStack  (+ add-on chips if enabled)

 3.  TARGET FINAL BIG BLIND
     targetFinalBB = totalChips / (2 × targetHeadsUpAverageBB)
                   = totalChips / 30
     i.e. heads-up play should begin with the average stack around 15 BB

 4.  LEVEL COUNT
     playedLevels = ceil(targetDurationMins / levelDurationMins)
     generated    = playedLevels + _spareLevels (4)
     the 4 spares are headroom so a slow field never plays off the end;
     they are EXCLUDED from the finish estimate

 5.  GROWTH EXPONENT + LADDER          → §11
 6.  SMALL BLINDS                      → §11
 7.  CHIP PLAN SOLVE                   → §12
 8.  ANTES                             → §13
 9.  REBUY CLOSE OPTIMISATION          → §14
10.  BREAK PLACEMENT                   → §15
11.  COLOUR-UP SCHEDULE                → §16
12.  MONEY: pool, organizer cut        → §18
13.  PAID PLACES + PAYOUT CURVE        → §19–20
14.  STYLE CLASSIFICATION + NARRATIVE  → below
15.  WARNINGS
```

### Duration model

```
totalMins = playedLevels × levelDurationMins
          + Σ break durations
          + settlementBreakMins (15) if rebuys are enabled
```

The 15-minute settlement pause has no clock of its own but it is real elapsed
time, so it counts in the duration model. Leaving it out made every estimate
optimistic by a quarter of an hour on exactly the nights that ran long.

### Style classification

```dart
TournamentStyle.fromBigBlinds(openingBBDepth):
    < 60   → turbo
    < 75   → fast
    ≤ 120  → standard
    else   → deep
```

Each carries a `purpose` string, so the review screen explains what kind of
night this structure produces rather than only showing numbers.

### The admissible depth band

A **universal** minimum depth was wrong: it lengthened short events that were
meant to be short. What replaces it is a band derived from the depth *this*
tournament targets, so the constraint follows the event:

```dart
admissibleDepthBand(target) = switch (TournamentStyle.fromBigBlinds(target)) {
  turbo    => (min:  40, max:  70),
  fast     => (min:  55, max:  90),
  standard => (min:  70, max: 140),
  deep     => (min: 100, max: 220),
};
// hard outer bounds: kMinTargetBBDepth = 40, kMaxTargetBBDepth = 220
```

**The measured failure this prevents:** Standard 300, 9 players, 4 hours targets
~136 BB. When any low depth was legal, the solver took a 65 BB stack that was
down to 16 BB by level three. A band that tracks the target rules that out
structurally — that event lands in Deep and cannot take 65, while a genuinely
short crowded night lands in Turbo and may. A universal floor could not tell
those two apart.

### The style narrative

The engine explains an unusual depth in plain language rather than only naming
it:

```
"Turbo — 52 big blinds to start, fast and decisive.
 Your chips could not fund a deeper start, so the structure opens
 shorter than usual."
```

Naming the style is half of it; saying *why it is not the default* is the half
that actually helps.

---

## 11. The blind ladder

The ladder is a **geometric progression snapped to a practical alphabet**.

```
g   = (targetFinalBB / openingBB)^(1 / (n − 1))      growth per level
BBᵢ = snapToPracticalBlind(openingBB × gⁱ)
SBᵢ = snapped, at 40–50% of BBᵢ
```

The small blind is explicitly **not assumed to be half the big blind**. 20/50 is
a permitted, real pair; forcing SB = BB/2 would forbid it.

### The practical blind table

34 pairs, extended downward from 25/50 so small chip sets have somewhere to
start:

```
5/10    10/20   20/40   20/50   25/50   50/100  75/150  100/200
150/300 200/400 250/500 300/600 400/800 500/1000
600/1200  700/1400  800/1600  900/1800  1000/2000
1100/2200 1200/2400 1300/2600 1400/2800 1500/3000
1600/3200 1700/3400 1800/3600 1900/3800 2000/4000
2200/4400 2400/4800 2600/5200 2800/5600 3000/6000
```

Entries are filtered against the **live denominations** at generation time, so
every blind in the final ladder is actually postable with the chips the host
owns.

### `snapToPracticalBlind`

```dart
minChip = smallest chip value in the set (fallback 1)
if (raw <= minChip) return minChip;

magnitude = largest power of 10 with raw / magnitude >= 10

standardPrefixes = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0]

// baseline: nearest multiple of the smallest chip
best    = round(raw / minChip) × minChip
minDiff = |best − raw|

for each prefix:
    candidate = round(prefix × magnitude)
    skip if candidate < minChip  OR  candidate % minChip != 0
    diff = |candidate − raw|
    if (diff <= minDiff × 1.5) {          ← THE PREFERENCE RULE
        minDiff = diff
        best    = candidate
    }

return max(best, minChip)
```

**The `× 1.5` tolerance is the whole point.** A standard prefix wins even when
it is up to 50% further from the raw target than the arithmetic nearest. This is
why the ladder reads 20 → 50 → 100 rather than the mathematically closer
20 → 40 → 80. Real tournaments jump 20/50, and a structure that *looks* wrong is
not trusted even when it is right.

Two hard constraints survive the preference: a candidate must be at least the
smallest chip, and must be an exact multiple of it. A blind nobody can physically
post is not a blind.

---

## 12. The chip plan solver

Given the denominations and quantities the host owns, build one player's
starting stack so that the stack is exactly right, every early bet is payable
without making change, and nobody starts with an unmanageable pile.

### Why not greedy

Greedy top-down was the previous implementation, and it produced the failure the
client reported from a real game: **a stack of seven high-value chips and
nothing small enough to post the small blind with.** Filling from the top is
locally optimal for chip *count* and pessimal for *payability*.

Adding a single fixed "change seed" in front of the greedy pass only moved the
problem — the seed ate the per-colour headroom the final top-up needed, exact
coverage was lost, and the solver fell back to absurd stacks (measured: **1 BB**).

### What runs now — scored enumeration

The only real degree of freedom is **how much change to reserve before
filling**. So the search walks a ladder of reserve sizes across the three
lowest blind-payable denominations, completes each candidate top-down, and
scores the finished stacks.

```dart
perPlayerDivisor = max(1.0, playerCount × reserveMultiplier)
caps[i] = min( floor(quantity[i] / perPlayerDivisor), maxChipsPerPlayer )
```

> The `max(1.0, …)` guard is not cosmetic. A zero head-count — the estimate an
> admin triggers the instant check-in opens, before anyone has checked in — made
> `quantity / 0` evaluate to `Infinity`, and `Infinity.floor()` **throws**,
> crashing the tap instead of producing a plan.

```dart
// how many of the LOWEST denominations can pay the small blind
payableCount = count of the 3 lowest values that are <= smallBlind

// reserve ladders, coarsest first — EVEN NUMBERS ONLY:
//   a stack that pays blinds in pairs is easier to count down than
//   one holding sevens
ladder0 = [0, 4, 6, 8, 10, 12]
ladder1 = [0, 2, 4, 6, 8]
ladder2 = [0, 2, 4]

for r0 in ladder0, r1 in ladder1, r2 in ladder2:
    fill  → _fillStack(...)
    score → _scoreStack(...)
    keep the best
```

**The all-zero reserve is one of the candidates**, so this can never do worse
than the plain greedy fill it replaces — and the "rebuild without the seed"
fallback the old code needed is gone with it.

With no blind context (`smallBlind == 0`) there is nothing to be payable *for*,
so the search collapses to a single unseeded fill.

### `_fillStack` — completing one candidate

```
1.  lay down the requested reserve across the lowest `payableCount`
    denominations, each bounded by its cap and by what is affordable
2.  fill the rest TOP-DOWN, each bounded by remaining headroom
3.  TOP UP from the smallest denomination so the declared value is EXACT:
        extra = ceil(remaining / values[0]), bounded by headroom
return targetStack − remaining
```

### `_scoreStack` — the objective function

Exactness is **not a term, it is a gate**:

```dart
if (covered != targetStack)
    score -= 10000 + |covered − targetStack|
```

Ordered so "closer" still beats "further" among failures, and **any failure
loses to any exact stack.** Every downstream figure — the prize pool, the average
stack, the colour-up — is computed from the declared value, so missing the
target outranks every aesthetic consideration there is.

| Term | Formula | Rationale |
|---|---|---|
| blind payability | `+ min(payable, 12) × 2.5` | chips at or below the SB can post it |
| change | `+ min(change, 4) × 2.5` | chips strictly below the SB can make change |
| payability floor | `− 60 if payable < 6` | the "seven blue chips" complaint lives here |
| change floor | `− 60 if change < 2` | scored, not filtered — a hopeless inventory still yields its best stack rather than nothing |
| counting simplicity | `+3` per colour with count %10, `+2` %5, `+1` even; capped at `+15` | counts on 5s and 10s are read at a glance across a table |
| pyramid shape | `+8 if 3 ≤ colours ≤ 5` | a stack should look like a pyramid |
| singletons | `− 1.5` each | the classic "why do I have exactly one of these" |
| too many chips | `− (total − 22) × 3.0 if total > 22` | slow to count, slow to colour up |
| too few chips | `− (12 − total) × 2.0 if total < 12` | the unplayable brick the client was handed |

### `maxChipsPerPlayer = 25`

A standard casino chip tray row holds 25 chips. Keeping each colour to one row
makes distribution, counting and colour-up exchanges fast and error-free.
Validated to `[1, 100]` at generation time; a non-default value trips an assert
so it cannot be changed by accident.

### Performance

> The stack solver calls `_buildChipPlan` **thousands of times** while walking
> candidate depths. The inner loop therefore works on parallel `List<int>`
> buffers allocated once per call rather than on maps of colour names. The first
> cut of this enumeration did the latter and took **1.4 seconds per
> `generate()`** — a visible freeze on every settings save. Only the winning
> candidate is ever turned into `ChipPlanEntry` objects.

### Chip plans at a live level

A rebuy at level 9 must not be handed out in level-1 chips.

```dart
chipPlanAtLevel({stack, chips, currentBB, playersRemaining}):
    obsoleteBelow = currentBB ~/ 10
    usable = chips where value >= obsoleteBelow
    if (usable.isEmpty) usable = chips     // never strip the set bare
    plan = _buildChipPlan(stack, usable, …, smallBlind: currentBB ~/ 2)
    if (plan total < stack)
        plan = _buildChipPlan(stack, FULL set, …)   // exactness wins
```

Anything below a tenth of the big blind is skipped unless it is needed to make
the total exact. A rebuy stack always equals the starting stack in **value**;
only its composition changes.

### Recommended add-on stack

The host enters only the **price** (defaulting to the buy-in); the engine
recommends the chip **amount** — the inverse of how it originally shipped.

```dart
avg    = totalChipsInPlay / playersRemaining
target = max(avg, currentBB × 25)
target = min(target, startingStack × 2)     // never dwarf the table
target = max(target, startingStack / 2)     // always worth taking
return round(target / smallestChip) × smallestChip
```

---

## 13. Antes

The real trade-off is **operational, not theoretical**. A big-blind ante is one
payment per hand from one player: fast, and nobody has to be chased. An
individual ante is a chip from everyone every hand — fairer in principle, slower
in practice, and the slowness compounds with the number of players.

```dart
recommendAnte({players, durationHours}):

  durationHours < 3.5 && players <= 6
      → NO ANTE, style bigBlind
        "A short game with a small field does not need antes —
         the blinds create the pressure on their own."

  players <= 6
      → ANTE, style INDIVIDUAL
        "Short-handed, so an individual ante is quick to collect
         and spreads the cost evenly."

  otherwise
      → ANTE, style BIG BLIND
        "One payment per hand from the big blind — faster at a full
         table than collecting from everybody."
```

The individual-ante candidate is sized as `bigBlind / defaultTableSize (9)`.

> This option existed in the UI but always resolved to Big Blind Ante — it was a
> third label for the same choice. It now recommends something.

---

## 14. The rebuy window

A fixed rule such as *"rebuys always end after two hours"* is explicitly
forbidden. The cutoff optimises against the **shape of the structure**, not the
clock: rebuys should close while the field is still deep enough that buying back
in is worth the money. Once the average stack is short, a rebuy buys a player a
few orbits and nothing more.

**The organizer's explicit choice is returned untouched.** Only the UI default
is optimised.

```dart
optimiseRebuyCloseLevel({requested, organizerChose, levelBlinds,
    startingStack, plannedLevels, players, durationHours, levelDurationMins,
    anteEnabled, anteAfterLevel, breaks, addOnAvailable, minChipValue})

if (organizerChose) return requested;          // authoritative
```

Seven inputs, consumed in this order:

```
① BLINDS + STARTING STACK
   viable = last level i where startingStack / BBᵢ >= 20
   (_rebuyWorthwhileBB = 20)

② CHIPS
   for each level up to `viable`:
       if (minChipValue × 4 > BBᵢ) { viable = max(1, i); break; }
   once the smallest chip in the box is a meaningful fraction of the BB,
   the rebuy stack can no longer be built cleanly

③ ANTES
   if (anteEnabled) viable = min(viable, anteAfterLevel + 1)
   antes drain every stack every hand, so the same chips buy less time

④ PLAYERS  → the ceiling fraction
   players >= 40 → 0.65
   players >= 18 → 0.60
   otherwise     → 0.55
   a bigger field takes longer to reduce

⑤ LEVEL LENGTH + DURATION
   ceiling = max(2, floor(plannedLevels × ceilingFraction))
   maxWindowMins = durationHours × 60 × ceilingFraction
   levelsThatFit = floor(maxWindowMins / levelDurationMins)
   if (levelsThatFit >= 2) ceiling = min(ceiling, levelsThatFit)
   expressed in LEVELS, sanity-checked against the SHARE of the night —
   a proportion of whatever was asked for, never a fixed number of minutes

⑥ BREAKS
   if (breaks.isNotEmpty) ceiling = min(ceiling, max(2, plannedLevels − 1))
   default break placement hangs off this cutoff, and a cutoff with no level
   after it would place a break at the very end — which is not a break

   result = viable.clamp(2, ceiling)

⑦ ADD-ON
   if (addOnAvailable && result > 2) result -= 1
```

> **⑦ is applied AFTER the clamp, deliberately.** Reducing `viable` first does
> nothing whenever the blinds alone would allow a later cutoff than the ceiling
> permits — which is the common case. The reduction vanished into the clamp and
> the add-on had no effect at all.

---

## 15. Breaks

```dart
kBreakDurationPresets = [5, 10, 15, 20] minutes
kMaxScheduledBreaks   = 3
```

```
1.  EXPLICIT PLACEMENTS FIRST
    each requested break with afterLevel > 0 is clamped to [1, plannedLevels−1]
    and reserves that level, so an automatic break can never steal a level the
    organizer already chose

2.  ANCHOR for automatic breaks
    anchor = rebuysEnabled && rebuysCloseLevel > 0
                 ? rebuysCloseLevel                 ← the natural pause point
                 : round(plannedLevels / 2)
    clamped to [1, plannedLevels − 1]

3.  SPREAD
    break 0 takes the anchor
    break i takes  round(anchor + (plannedLevels − anchor) × i / autos.length)
    so later breaks spread through the remaining levels rather than stacking
    beside the first

4.  COLLISION NUDGE
    while the level is taken, step +1 (and back −1 at the last legal level),
    guarded against looping

5.  sort by afterLevel
```

The rebuy close is the anchor because it is when the field settles — the moment
people are already standing up, counting chips and settling rebuys.

---

## 16. Colour-up

A denomination is retired when it can no longer pay a blind:

```
retire chip when   bb >= chipValue × 20
new count          = ceil(oldCount × oldValue / newValue)
```

**`ceil`, never `round`** — rounding down takes chips off a player.

There is **no chip race**. The room is nine people, not a casino floor; a race
costs more time and goodwill than the fractional chips are worth.

---
---

# PART III — MONEY

---

## 17. Cents, and why

```dart
toCents(dollars)      = (dollars × 100).round()
toDollars(cents)      = cents / 100.0
percentOf(cents, pct) = (cents × pct + 50) ~/ 100     // integer round half-up
splitEvenly(total, n) = base + (i < remainder ? 1 : 0)
```

All domain arithmetic is in **integer cents**. Doubles were off by a penny
roughly a third of the time — invisible in a bank statement, fatal at a table
where somebody counts the notes.

`percentOf` uses `(x × pct + 50) ~/ 100`: round-half-up with no floating point
anywhere in the path. `splitEvenly` guarantees the parts sum to the total
exactly by pushing the remainder into the first parts.

Doubles survive at exactly two boundaries: the Firestore write path for legacy
cash-game fields, and display.

---

## 18. The prize pool and the organizer cut

### Gross eligible

```dart
grossEligible = confirmedCount × buyIn
              + totalRebuys    × effectiveRebuyCost
              + totalReEntries × buyIn              // a re-entry buys a fresh entry
              + totalAddOns    × effectiveAddOnCost // only if add-ons enabled
```

**KO bounty is excluded.** It is a separate field, never part of `buyIn`, and
never part of the prize pool.

Computed from **actual** confirmed players and actual rebuy / re-entry / add-on
counts — never from the expected rates. Those (0.35 / 0.20 / 0.65) drive
*structure design* only; they never touch real money.

### The organizer cut — bracketed candidates

The requirement is that the remaining prize pool is a clean multiple of 10, so
every payout can be a multiple of 10 and never end in 5.

```dart
targetOrganizer = (grossEligible × organizerPct + 50) ~/ 100   // round half-up
mod             = grossEligible % 10

// two candidates carrying the correct units digit, BRACKETING the target
baseUnits     = targetOrganizer − mod
floorCandidate = floor(baseUnits / 10) × 10 + mod
ceilCandidate  = floorCandidate + 10

organizerAmount = the candidate nearest targetOrganizer,
                  ties broken toward the SMALLER value
                  (rejecting any candidate < 0 or > grossEligible)
```

> `best` is nullable on purpose. It used to be seeded at 0, and that seed was
> then treated as "unset" — so whenever 0 was the nearest valid amount the loop
> still took the upper candidate: **gross 100 at 1% retained 10 against a target
> of 1.** The rule is the nearest amount, ties broken downward, preferring to
> retain less.

```dart
effectiveOrganizerPct = organizerPct.clamp(0, 20)   // maxOrganizerPct = 20
```

### The rounding remainder

```dart
prizePool         = max(0, grossEligible − organizerAmount)
roundingRemainder = prizePool % 10
prizePool        -= roundingRemainder
```

A pool that is not a multiple of 10 cannot split into payouts that are all
multiples of 10. With a **0% organizer cut — the documented default, i.e. the
common case** — an 11 × 15 game produced 105/40/20, and 105 ends in 5.

The residue is carried **out** of the pool and reported separately as
`roundingRemainder`. It is **not** an organizer cut and is never labelled as
one.

```dart
roundingUnitFor(buyIn) => 10;    // always 10, regardless of buy-in size
```

This used to drop to 1 for sub-10 buy-ins "so sums stay exact", which permitted
amounts like 27. Exactness is now preserved by the remainder instead.

### Live recomputation

`_updatePrizePool` patches only four fields — `prizePool`, `organizerAmount`,
`roundingRemainder`, `prizes`. Nothing else on the document is touched, so a
concurrent edit to an unrelated field is never clobbered.

---

## 19. Paid places

Depends on **both** the field size and the pool size.

```dart
_paidPlacesFor(prizePool, players):

  // ① base tier from unique player count
  places = 1
  if (players >= 6)  places = 2
  if (players >= 10) places = 3
  if (players >= 18) places = 4

  // ② clamp to the reference payout style — small pools do not spread
  if (prizePool < 100 && places > 2) places = 2
  if (prizePool < 400 && places > 3) places = 3

  // ③ never promise more places than can each clear the 10 minimum
  maxByPool = prizePool ~/ 10
  if (places > maxByPool) places = maxByPool
  if (places < 1) places = prizePool > 0 ? 1 : 0
```

③ is what prevents a "paid" place ever landing on 0.

### Documented deviation: three places start at 10 players, not 8

Where the place **count** agrees, the split matches the reference table exactly
— **0 deviations across all 67 reference pools.** The counts themselves differ
for one reason, and 184 of 396 tested field × pool combinations differ on that
basis alone.

**The justification.** The target is *around 15–25% of unique players, subject
to a meaningful lowest prize.*

- Three places out of 8 is **37.5%** of the field — well above the band — and at
  typical home buy-ins the third prize lands at or near the 10 minimum, which is
  **less than the buy-in**: it pays a player less than they staked.
- Two places out of 8 is **25%**, at the top of the band, and keeps every paid
  place meaningful.
- Three places start at 10 players, where **30%** is closer to the band and the
  pool can carry a real third prize.

This is a calibration choice, not a defect. To match the reference table
exactly, change `players >= 10` to `players >= 8` — nothing else needs to move.

---

## 20. The payout split

### The six guarantees

| # | Guarantee |
|---|---|
| 1 | Every award is a multiple of 10 |
| 2 | No award ends in 5 |
| 3 | **The awards sum EXACTLY to the prize pool — absolute** |
| 4 | Place 1 is the largest |
| 5 | Amounts are monotonic non-increasing down the places |
| 6 | No paid place pays 0 |

### The reference schedule

A 67-row grid from pool 50 to 700 in steps of 10, used **verbatim** whenever the
computed place count matches:

```
 50: [40, 10]              100: [60, 30, 10]         200: [110, 60, 30]
 60: [40, 20]              110: [70, 30, 10]         300: [170, 90, 40]
 70: [50, 20]              150: [90, 40, 20]         400: [220, 120, 40, 20]
 80: [50, 30]              160: [90, 50, 20]         500: [280, 150, 50, 20]
 90: [60, 30]              170: [100, 50, 20]        600: [330, 180, 70, 20]
                                                     700: [390, 210, 80, 20]
                                   (…67 rows in all, every 10 from 50 to 700)
```

```dart
reference = (shape == standard) ? _referencePayouts[prizePool] : null;
if (forcePaidPlaces == null && reference != null &&
    reference.length == paidPlaces) {
  return reference;    // used verbatim
}
```

**The reference applies only to the standard shape.** It *is* the standard shape
written out longhand — so a host who asked for a different curve must not be
handed it, which would silently ignore their choice. A forced place count also
bypasses it, for the same reason.

### The weighted fallback

For pools outside the 50–700 grid, non-standard shapes, forced place counts, or
fields too small to unlock all places:

```dart
weightsFor(n):
  // non-standard shape → plain geometric curve
  if (shape != standard)
      raw = [ratio⁰, ratio¹, ratio², …]  normalised to 1

  // standard shape, tuned tables
  n == 2 → [0.73, 0.27]
  n == 3 → [0.57, 0.30, 0.13]
  n == 4 → [0.56, 0.30, 0.10, 0.04]
  n >= 5 → weightᵢ = e^(−0.7 × i), normalised
```

```dart
PayoutShape.topHeavy.ratio       = 0.65
PayoutShape.flat.ratio           = 0.50
PayoutShape.winnerTakeMost.ratio = 0.90
```

> The `default` branch used to return a **four**-element list for every `n > 4`,
> so `weights[i]` read past the end and threw a `RangeError` for 5+ paid places
> — reachable straight from the shipped 1–10 dropdown.

### The allocation loop

```
while (paidPlaces >= 2):

  ① floor every LOWER place (2..N) to a multiple of 10:
        amt = floor(weightᵢ × prizePool / 10) × 10
        if (amt < 10) amt = 10                    ← per-place minimum

  ② place 1 absorbs the EXACT remainder:
        amounts[0] = prizePool − Σ(lower places)
     this is what makes guarantee 3 absolute

  ③ fix a stray 5 digit on place 1 by transferring 5 to/from place 2,
     preserving the sum and the ordering:
        if (amounts[0] % 10 == 5):
            amounts[1] >= 15  →  [0] += 5, [1] -= 5
            amounts[0] >= 15  →  [0] -= 5, [1] += 5

  ④ VALIDATE all six guarantees
     if any fails → paidPlaces--, retry from ①

  return prizes
```

```
fell all the way through → [Prize(place: 1, amount: prizePool)]
```

Dropping a place and retrying, rather than fudging an amount, is what keeps the
guarantees absolute: the engine would rather pay two places properly than three
places badly.

**The documented tradeoff.** The caller normally hands in a pool already snapped
to a multiple of 10 (§18), so every place comes out clean. Should the pool ever
carry a units digit, **sum-exactness wins**: places 2..N stay multiples of 10 and
the stray units land on place 1, which then cannot be a multiple of 10. In that
production-unreachable case the multiple-of-10 and no-5 rules bend for place 1
alone; the sum stays exact.

---

## 21. Payout options

The engine's own recommendation comes first and is the default. Around it sit
the neighbouring shapes, so a host who wants to pay one more or one fewer place
can see exactly what that costs the winner *before* deciding.

```dart
candidates = {default, default−1, default+1, default+2}
             .where(n >= 1 && n <= 5 && n <= players)
             .sorted()
```

Each candidate is dropped if:

- the split could not actually produce that many places;
- any place pays ≤ 0;
- **three or more places share the same lowest award.**

> The third filter is measured, not theoretical: rounding to clean amounts left
> **90/30/10/10/10 from a 150 pool** — which pays nobody anything worth
> collecting and is not a real alternative to offer.

Each surviving option carries a plain-language rationale:

```
places == recommended → "Recommended for this field and pool"
places == 1           → "Winner takes all"
places <  recommended → "Top-heavy — bigger first prize"
places >  recommended → "Flatter — more players get paid"
```

---

## 22. ICM

The Independent Chip Model answers the only question a chop argument is actually
about: **what is my stack worth in money right now?** Chips are not money — half
the chips is not half the pool, because you can still bust.

```
E(player i) = Σ over finishing positions p:  P(i finishes p) × payout(p)

P(i finishes 1st) = stackᵢ / Σ stacks
P(i finishes 2nd) = Σ over j≠i: P(j 1st) × stackᵢ / (Σ stacks − stackⱼ)
… recursively
```

```dart
_accumulate(place, probability, taken):
    if (place >= payouts.length || probability <= 0) return;   ← prune
    remaining = Σ stacks of untaken players
    for each untaken player i with stack > 0:
        p = probability × stacksᵢ / remaining
        equity[i] += p × payouts[place]
        taken[i] = true
        _accumulate(place + 1, p, taken)
        taken[i] = false
```

Two prunes: the recursion **stops once every prize is allocated** — positions
below the money contribute nothing, so enumerating them is work for no answer —
and any branch whose probability reaches zero is abandoned.

### The exactness ceiling

```dart
maxExactPlayers = 9
```

The recursion is exact and **factorial** in the field size. Nine is the
realistic ceiling and the only place anybody actually needs ICM. Above it, the
model falls back to a proportional chip-share split:

```dart
equityᵢ = totalPool × stackᵢ / Σ stacks
```

Deliberately crude, deliberately labelled, and applied only where nobody is
settling a chop anyway. **A 45-second wait to settle a deal is worse than a
rounding error nobody can perceive.**

Two shortcuts before any of this: an empty field or empty payout list returns
zeros, and one prize with one live player returns that prize directly — no model
needed.

### Rounding equities

```dart
roundPreservingTotal(equities, total):
    floor everything
    shortfall = total − Σ floors
    order = indices sorted by DESCENDING fractional remainder
    give the shortfall to the largest remainders, one at a time
```

Rounding each equity independently loses or invents money — three players at
33.4 each round to 33 and a unit vanishes. Same deterministic
largest-remainder rule the payout engine uses.

---

## 23. Payments

> **Payments are simulated.** The flow, ledger, idempotency, audit trail and
> reconciliation are all real and complete. No money moves.

```dart
amountFor(purpose) = switch (purpose) {
  buyIn   => settings.buyIn,
  rebuy   => settings.effectiveRebuyCost,
  reEntry => settings.buyIn,            // a re-entry buys a fresh entry
  addOn   => settings.effectiveAddOnCost,
};
```

**The amount is read from the tournament's own settings, never from the payer.**
There is no amount for a client to send, so there is no amount to tamper with.

### Idempotency

```dart
existing = payments.firstWhereOrNull((p) => p.idempotencyKey == key);
if (existing != null) return existing;     // replay — no second row
```

This is what makes a double-tap, or a retried request after a dropped
connection, safe. Without it the prize pool double-counts.

### Singular purposes

A player cannot buy in twice or take a second add-on; both are rejected before a
record is written. **Rebuys are excluded from that rule deliberately** — a player
may rebuy repeatedly, and the limit on that is `rebuyLimit`, enforced where the
rebuy is granted.

### Outcomes

```dart
if (outcome.countsTowardPool) _updatePrizePool();
```

**Only `PaymentStatus.paid` reaches the pool.** Failed and cancelled attempts are
recorded and otherwise inert — they appear in the audit trail, they explain why
a player is not confirmed, and they move no money.

Every payment writes an audit record naming the purpose, the outcome, the player
and the amount.

### Reconciliation

The prize pool and the payment ledger are computed from different things and are
**meant to be able to differ**:

- the **pool** counts what is *in play* — confirmed players, rebuys taken,
  add-ons taken;
- the **ledger** counts what has been *recorded as paid*.

A player sitting at the table who has not yet paid is a real and common state.
Showing the host the gap is the point; forcing the two to agree would hide it.

---
---

# PART IV — RUNNING THE NIGHT

---

## 24. The live clock

### 24.1 Server-time calibration

Every device has a different idea of what time it is. Phones drift, laptops
sleep, browsers throttle background tabs. A countdown stored as "seconds
remaining" diverges within minutes.

So the clock stores **`levelEndTime`, an absolute timestamp**, and every device
derives its own remaining seconds from it. That only works if every device
agrees on *now*:

```
1.  write  FieldValue.serverTimestamp()        ← record local time t₀
2.  read it back                               ← record local time t₁
3.  localReference   = (t₀ + t₁) / 2           ← midpoint absorbs round-trip
4.  _serverTimeOffset = serverTimestamp − localReference
5.  _serverNow        = DateTime.now() + _serverTimeOffset
```

The midpoint assumes the request and the response took roughly the same time,
which is true enough that the residual error is milliseconds. **Re-calibrated
every 10 minutes**, so long sessions do not drift.

```dart
currentSecondsRemaining([offset]) =
    levelEndTime.difference(now + offset).inSeconds
```

### 24.2 The tick

A single **1-second** periodic timer drives the whole clock. It does not
decrement anything — it recomputes from `levelEndTime` each time. A missed tick,
a throttled tab or a sleeping laptop therefore **self-corrects on the next tick**
instead of accumulating error.

### 24.3 The clock sequence

Breaks are **first-class segments**, not a flag on the preceding level. A clock
that treats a break as an attribute of a level ends up with a boolean and two
countdowns fighting over the same variable.

```dart
ClockSegment.level(level)
ClockSegment.breakAfter(afterLevel:, breakDurationMins:)

seconds => (level?.durationMins ?? breakDurationMins) × 60
label   => isBreak ? 'Break' : 'Level ${level.level}'
```

`ClockSequence.build(structure)` flattens the structure into the order the clock
actually plays it, so **"what comes next" becomes an index, not a branch**:

```dart
// planned levels: 0 or > available means "play all of them"
plannedLevels = (n <= 0 || n > levels.length) ? levels : levels.take(n)

for each level:
    emit the level
    emit any break whose afterLevel matches and whose duration > 0

// a trailing break is dropped — a break with nothing after it is not a
// break, it is the end
while (segments.isNotEmpty && segments.last.isBreak) segments.removeLast();
```

The end of the list is the end of the tournament. A clock that loops back to
level one because nobody told it to stop is worse than one that simply stops.

```dart
levelAt(segments, i)        // during a break, the level it FOLLOWS
nextLevelAfter(segments, i) // the next level to be played
```

Both are provided rather than having the clock guess: during a break the blinds
that matter are the ones about to start, but the level that just finished is
what everybody remembers playing.

### 24.4 Level rollover

```
nextLevel():
  ├─ a scheduled break follows this level?  → status = onBreak
  ├─ this level is rebuysCloseLevel?        → status = rebuypause
  ├─ past the last planned level?           → pendingLevelExtension (§27)
  │                                            THE CLOCK HOLDS
  └─ otherwise                              → advance · announce ·
                                               push undo · bump revision
```

Plus `pauseTimer` / `resumeTimer`, `previousLevel`, `restartLevel`, `endBreak`,
`startShotClock` / `clearShotClock`.

`startTimer` calls `recalculateStructure()` first, sets `structureConfirmed`,
and sets `startedAt ??= _serverNow`.

### 24.5 Non-authority devices

A device that is not the game authority rolls the level over **display-only**:

```dart
_rollOverLevelForViewer()
  // no announcement · no notification · no undo push · no revision bump
```

The viewer's clock reaches zero and flips so the display stays live and correct.
The *authoritative* rollover — the one that writes, announces and increments the
revision — happens once, on the authority device. Without this split, nine
devices would each announce the same level change and each write a competing
revision.

### 24.6 Announcements

`_announceLevelMark` produces:

- a **one-minute warning** naming the *next* level's blinds — the useful moment
  is before the change, not after it;
- a **5-4-3-2-1 countdown**, one number per second, spoken but **silent in the
  feed** — five lines of "3" in the chat history is noise.

### 24.7 The shot clock

```dart
presets = [30, 60, 90] seconds,  default 30
isUrgentAt(s) => s <= 10
```

It is **soft**: it never folds a hand. It is a social instrument for the host to
point at, not a rule the app enforces. A timer that folded a player's aces
because their phone lagged would end the night.

---

## 25. Players: RSVP, check-in, guests, rebuys, eliminations

### 25.1 RSVP

```dart
enum Rsvp { going, maybe, cant, goingPlus1, goingPlus2, goingPlus3, goingPlus4 }

bool get isGoing    => going || goingPlus1..4
int  get guestCount => 0 | 1 | 2 | 3 | 4
```

`goingPlusN` is one value, not two fields, because "am I coming" and "how many
am I bringing" are answered in the same breath — and a split invites the
inconsistent state where somebody brings two guests but is not attending.

**Deadline:** `scheduledStart − 1 hour`. Late enough to be useful, early enough
that the host can still plan chips and tables.

**Own-RSVP overlay.** A member's own RSVP is applied as a local overlay on top of
whatever the server last sent. Without it, tapping "Going" visibly reverts for
the half-second before the write round-trips — and on a slow connection, looks
like it failed.

Members write via a **dot-path patch** that touches only their own entry, which
is what lets fifteen people RSVP simultaneously without overwriting each other.

### 25.2 Guest slots

```dart
enum GuestSlotStatus {
  unclaimed,          // the inviting member reserved a seat, nobody in it
  reserved,           // a named guest holds it
  checkInRequested,   // the guest is at the door
  checkedIn,          // the host approved them
  cancelled,
}
```

Slots sync to the RSVP count: raising `goingPlus2` to `goingPlus3` creates a
slot; lowering it removes one. Excess slots are reconciled in a defined order —
**unclaimed slots are removed first**, so lowering a count never evicts a guest
who has already arrived and been approved.

A guest's session lives on the guest's own device
(`{gameId, name, inviterId, slot}`) so a refresh returns them to the *same
approved seat* rather than making them queue again.

### 25.3 Check-in re-assertion

If a member's own check-in is missing from an incoming snapshot — because a
concurrent write from the host clobbered it — `_maybeReassertOwnCheckIn`
re-applies it and persists a targeted dot-path patch. The member does not have
to notice or retry.

### 25.4 Rebuys, re-entries, add-ons

Live chip plans are recomputed at the **current** level (§12), not the starting
level. Handing a player the starting-stack denominations when the 25s have been
coloured up gives them a stack they cannot bet.

Every rebuy, re-entry and add-on immediately triggers `_updatePrizePool`, so the
prize table on every screen in the room updates at once.

### 25.5 Elimination

```dart
eliminatePlayer(id, {knockedOutBy}):
    eliminationPos = active.length          // BEFORE removing them
    knockedOutBy?.knockouts += 1
    if (remaining <= 9 && multiTableEvent && !finalTableRedrawCompleted)
        status = finaltable
```

`eliminationPos = active.length` computed *before* removal is what makes the
finishing position correct: the tenth-from-last player out finishes 10th.

The auto-transition to `finaltable` is deliberately narrow — only a
**multi-table event that has not already redrawn**. A single-table nine-person
home game is already at its final table from the first hand; announcing "final
table!" when the ninth player busts a ten-handed single table would be absurd.

---

## 26. Seating and table balancing

### 26.1 The draw

```dart
enum TableSeatingMode { random, manual, keepGuests, separateGuests }

maxPerTable = effectiveTableSettings.maxPerTable.clamp(2, 999)   // default 9
tableCount  = canHostPlayers(count) ? ceil(count / maxPerTable) : 1

perTable = List.filled(tableCount, count ~/ tableCount);
for (var i = 0; i < count % tableCount; i++) perTable[i]++;
```

The remainder spreads one seat at a time across the first tables, so the largest
and smallest differ by at most one.

**Worked example — 19 players, max 9:**

```
tableCount = ceil(19 / 9) = 3
base       = 19 ~/ 3 = 6
remainder  = 19 % 3  = 1
perTable   = [7, 6, 6]
```

Players are dealt **round-robin** into seats 1..n, and a dealer button is drawn
at random from the seated players.

`keepGuests` / `separateGuests` bias the ordering *before* the round-robin deal —
a member who brought three friends either sits them together or spreads them,
but the table sizes are unaffected either way.

### 26.2 Balancing

```dart
if (maxCount - minCount > 1) {
    move = lowest-seat player on the LARGEST table
        →  first free seat on the SMALLEST table
}
```

The trigger is a difference of **more than one**, not one. Tables of 7 and 6 are
balanced; moving a player to make them 6 and 7 achieves nothing and interrupts a
hand.

Picking the *lowest-seat* player and the *first free seat* is deterministic, so
every device recommends the same move and the host is never shown two different
suggestions on two screens.

**The app recommends; it does not move anybody.** Manual seat moves are Premium.

---

## 27. Live intelligence: pace, speed, extensions

### 27.1 Drift

```dart
estimatedFinishDriftMinutes() = projectedFinish − targetFinish
```

The projection accounts for levels remaining, elapsed time, breaks not yet taken
and the current level's remaining seconds.

### 27.2 The recommendation

```dart
drift > +20 min  → recommend SPEED UP
drift < −20 min  → recommend SLOW DOWN
otherwise        → say nothing
```

±20 minutes because below that the recommendation fires and un-fires as players
bust — and a suggestion that appears and vanishes is worse than none.

### 27.3 Accepting a recommendation

The most intricate live edit in the app:

```
level duration:  ±5 minutes, clamped to [10, 20]

SPEED UP:
  · advance the ante by 1–2 levels
  · multiply every FUTURE big blind by 1.25

SLOW DOWN:
  · delay the ante
  · where the next BB would be >= 2× the current BB,
    INSERT an intermediate level at 1.5× the current BB

then, in both cases:
  · re-index every level from the edit point onward
  · mark every touched future level `manuallyEdited`
```

Marking them `manuallyEdited` is what stops the next `recalculateStructure` from
quietly undoing the host's decision — and what stops verification (§33) from
flagging it as tampering.

The 1.5× insertion exists because slowing a tournament by lengthening levels
alone leaves the *jumps* intact; a structure that goes 400 → 800 more slowly is
still a structure that doubles.

### 27.4 Running past the last level

When the last planned level ends and players remain, the app does **not** invent
a level and carry on:

```
pendingLevelExtension:
    proposed BB = snapToPracticalBlind(lastBB × 1.4)
    proposed SB = proposed BB × 0.45, snapped
    THE CLOCK HOLDS, awaiting admin approval
```

`acceptLevelExtension` / `declineLevelExtension`. The hold is the point — the
host is in the room and should decide, and a structure that grew itself while
nobody was watching cannot be reconciled afterwards.

### 27.5 Structure recalculation

```dart
recalculateStructure({keepManualLevels = true})
```

Hand-edited future levels are preserved **by level NUMBER, not by index** — so
inserting a level does not shift which edits survive. The method reports what it
kept and what it had to drop, and the host sees both.

### 27.6 Headcount

```
generateFinalStructure precedence:
    lockedExpectedPlayers > expectedPlayersOverride > RSVP count
    then floored at the confirmed player count
    then minimum of 2
```

The floor at *confirmed* matters: if twelve people have physically checked in, no
setting may design a structure for eight.

```dart
lockExpectedPlayers() / unlockExpectedPlayers()
lockedHeadcountDrift   // how far reality has moved from the locked number
```

Locking exists because a host who has already bought chips for sixteen does not
want the structure re-planning itself every time somebody RSVPs. The drift
figure tells them when the lock has become a lie.

---

## 28. The cash game module

A separate, simpler mode: no clock, no structure, no prize pool.

```dart
CashSessionSettings { minBuyIn, maxBuyIn, … }
CashPlayer { id, name, stack, totalBuyIns, buyInCount, cashedOut, hasCashedOut }
```

### 28.1 Buy-ins

```dart
cashBuyIn(playerOrName, amount, {isNew}):
    amount <= 0        → 'Amount must be positive.'
    amount < minBuyIn  → 'Minimum buy-in is {min}.'
    amount > maxBuyIn  → 'Maximum buy-in is {max}.'
    otherwise:  stack       += amount
                totalBuyIns += amount
                buyInCount  += 1
```

A new player can be added mid-session with their first buy-in in one action —
which is how it actually happens when somebody walks in at 22:00.

### 28.2 Net position

```dart
_netOf(p) = p.hasCashedOut ? p.cashedOut - p.totalBuyIns
                           : p.stack     - p.totalBuyIns
```

The branch is the important part: **mid-session a player is valued at their
current stack, not their zero `cashedOut`.** Without it, everyone still playing
shows as down their entire buy-in and the standings are meaningless until the
last person leaves.

### 28.3 Reconciliation

```
difference = totalBuyIns − (totalOnTable + totalCashedOut)
balances   = |difference| < 0.01
```

Money in must equal money on the table plus money taken off it. Any other result
means a miscount, and the host is told the exact figure rather than a red cross.

### 28.4 Settlement — who pays whom

Greedy largest-debtor → largest-creditor pairing:

```
1.  compute every player's net (above), in whole CENTS
2.  split into debtors (net < 0) and creditors (net > 0)
3.  sort both by magnitude, descending
4.  repeat:
        amount = min(|largest debt|, largest credit)
        emit CashTransfer(from: debtor, to: creditor, amount)
        reduce both by `amount`
        drop whichever reached zero
    until no debtors remain
```

**Why greedy.** Minimising the number of transfers exactly is NP-hard. Greedy
pairing produces at most `n − 1` transfers and in practice produces the obvious
answer — the big loser pays the big winner. Nobody at a kitchen table wants a
provably optimal settlement that routes four ways.

**Why cents.** This was the exact bug: in doubles the settlement was off by a
penny roughly one session in three, and the person handed the odd penny noticed
every time.

Active sessions snapshot to the device-local recovery store, so a closed tab does
not lose the night's ledger.

---
---

# PART V — EVERYTHING AROUND IT

---

## 29. Chat, polls and notifications

### 29.1 Chat scopes

| Scope | Storage | Who writes |
|---|---|---|
| Group chat | `groups/{gid}/chat` | any member |
| Game chat | `groups/{gid}/games/{gameId}/chat` | host and every member, **directly** |
| Offline / mock | on the local game model | — |

Game chat is its own subcollection specifically so members can append **without
a game-document write**. Members are forbidden the game document's `chat` field,
and routing chat through the host's projection would make every message wait on
a round trip through the host's device.

### 29.2 Rate limiting

```dart
_chatBurstLimit  = 8 messages
_chatBurstWindow = 30 seconds
_chatMinSendGap  = 4000 ms

rateLimited(uid):
    drop timestamps older than the window
    if none                 → allowed
    if count >= 8           → blocked
    if now − last < 4000ms  → blocked
```

The client limit (4000 ms) is deliberately **stricter** than the server's
(~3750 ms on `rate_limits/chat-{uid}`). A compliant client therefore never
submits a burst the server would silently drop — the user sees a clear *"you are
sending messages too quickly"* instead of a message that vanishes.

### 29.3 Unread counts

```dart
unread(scope) = messages.where((m) =>
      !m.deleted
   && m.authorId != me
   && (lastRead == null || m.timestamp.isAfter(lastRead))
).length
```

Per-scope last-read timestamps (`group:{gid}`, `game:{gid}`), so reading the
group chat does not clear the game chat badge.

### 29.4 Polls

```dart
createPoll(question, options, {multi}):
    sanitize question (<=200) and every option (<=100)
    empty question        → 'Poll needs a question.'
    < 2 options           → 'Poll needs at least two options.'
    > 10 options          → 'Polls support at most ten options.'
    case-insensitive dup  → 'Duplicate options are not allowed.'
```

```dart
votes: Map<String, List<String>>     // userId → chosen options
```

Storing votes keyed by **user** rather than as per-option counters is what makes
a vote *change* correct: re-voting replaces that user's entry. Counters would
need a separate record of who voted for what to decrement correctly, and would
drift the first time a write was retried.

```dart
single-choice → keep only selected.first
multi-choice  → keep all selected
empty         → remove the user's entry entirely (an un-vote)
optionCounts() derives the tallies on read
```

An admin can `closePoll`, after which votes are refused.

### 29.5 Notifications

```
pushNotification(n):
 ├─ de-duplicate the id  ('id', 'id-2', 'id-3' …)
 │     several call sites build ids from millisecondsSinceEpoch alone,
 │     which collide when notifications are created in a loop
 ├─ addressed (audience non-empty) and I am not a recipient?
 │     → skip MY OWN inbox
 │       (otherwise a member requesting check-in files
 │        "… is waiting to be checked in" against themselves)
 ├─ record the id in _seenNotificationIds
 │     → this device never re-banners an event it originated when the
 │       mirrored outbox copy arrives back
 ├─ stage into groups/{gid}/notifications   (the outbox)
 └─ _fanOutPush(gid, n)
```

**Fan-out:**

```dart
targets = (audience non-empty ? audience ∩ memberIds : memberIds)
          .where((id) => id != myUid)
if (targets.isEmpty) return;
OneSignalSender.send(title, body, appUrlPath: n.link, externalIds: targets)
```

**Only the staging device sends.** Every other device simply mirrors the outbox
into its own inbox. This is what stops nine devices each firing the same push
when they all receive the same outbox document.

Each notification carries a `link` (`/chat`, `/group`, `/game/{id}`) so tapping
the banner lands on the thing it is about.

---

## 30. Voice announcements and the Audio Master

The problem: a host's phone, a player's laptop and the TV are all in one room,
all running the same app, all reaching the same level change at the same second.
Three voices saying "blinds are now 200 and 400" over each other.

```dart
thisDeviceId = _repo.deviceId        // PERSISTED, survives a reload
```

The same persisted value the editor claim uses. An earlier `dev-<timestamp>`
value was regenerated on every reload, so an Audio Master choice never survived
a refresh and could not be compared across devices at all.

```dart
audioMasterDeviceId   // stored ON THE GAME DOCUMENT — every device agrees

bool get thisDeviceIsAudioMaster {
  final chosen = audioMasterDeviceId;
  if (chosen != null) return chosen == thisDeviceId;
  return _isGameAuthority;          // nobody chosen → the authority speaks
}
```

The fallback matters. The rule used to be "nobody chosen means everybody may
speak", which produced exactly the chorus above. Now, with no explicit choice,
the authority device speaks **alone** — still exactly one voice, with no
configuration required.

```dart
addAnnouncement(text, [speakOutLoud])
    → speaks only when  _voiceEnabled && thisDeviceIsAudioMaster
```

Setting the Audio Master is admin-only and force-claims the editor lock, since
it writes to the shared document.

---

## 31. TV and public display

A TV joins with its own `kind: 'tv'` join code, reads the `tv` projection (§6.2)
and renders a read-only board. It never authenticates and never holds a writable
reference to anything.

```dart
class TvDisplaySettings {
  textScale       = 1.0    // clamped to [0.7, 2.0]
  showLeaderboard = true
  showPayouts     = true
  showUpcoming    = true
  rotateSeconds   = 8      // presets [5, 8, 12, 20, 30]
}
bool get hasAnyPanel => showLeaderboard || showPayouts || showUpcoming;
```

**Two scales, two jobs.** An automatic width-derived scale handles screen *size*;
`textScale` handles how far away the players are sitting, which no amount of
measuring the viewport can know.

**Stored per device, not per account.** The laptop wedged at the end of the table
has its own size, its own viewing distance and its own job. The same host's
phone should not inherit the text scale that suits a 55-inch screen across the
room.

`hasAnyPanel` exists because a screen with every panel switched off would rotate
through nothing — the caller is told to fall back rather than render an empty
box.

Every field has a safe default, so a TV that has never been configured, or whose
local storage is unreadable, behaves exactly as it did before the feature
existed.

---

## 32. Sync, authority, undo and recovery

This is the subsystem that makes "nine devices, one tournament" work.

### 32.1 The single-writer rule

```dart
_isGameAuthority = isAdmin
                && editorDeviceId == thisDeviceId
                && tabLeader.isLeader
```

All three conditions:

- **`isAdmin`** — only a host may change a live game.
- **`editorDeviceId == thisDeviceId`** — of the host's possibly several devices,
  exactly one holds the claim.
- **`tabLeader.isLeader`** — of that device's possibly several browser tabs,
  exactly one is elected.

### 32.2 Tab leadership

`TabLeader` elects a leader across tabs of the same browser via
`BroadcastChannel`.

```
tabLeader.isLeader == null  →  read as "assume leader"
```

A null leader means the election has not resolved — most often because the
platform has no BroadcastChannel at all. Treating that as *not* leader would
leave the host unable to control their own tournament on an unsupported browser.
Treating it as leader risks two writers in a case that is already rare and is
caught downstream by the revision check.

### 32.3 Claiming the editor lock

```dart
_editorClaimStaleWindow = Duration(seconds: 90)

_claimEditorIfNeeded():
    no current editor          → claim
    I am the editor            → keep
    editor claimed > 90 s ago  → claim (stale — that device went silent)
    otherwise                  → do NOT claim
```

`_forceClaimEditor()` takes the lock immediately, used where the host has made an
unambiguous act of control.

Ninety seconds is the balance point: long enough that a host switching tabs or
locking their phone does not lose control mid-level, short enough that a host
whose phone died can pick up a laptop and take over before anybody notices.

### 32.4 Idempotency

```dart
key = providedKey ?? '$action-$target-${revision + 1}'

if (key == game.lastIdempotencyKey)
    → this is a REPLAY; return a null revision, write nothing
```

The default key binds the action to the revision it *expects* to produce. Two
devices attempting the same action against the same revision generate the same
key; the second is recognised as a replay rather than applied twice. This is
what stops a retried "eliminate player 7" from eliminating them twice.

### 32.5 Undo

```dart
_maxUndoDepth = 30
```

Pushed before every mutating action, and cleared whenever the document is
replaced wholesale from a remote snapshot — an undo that would revert to a state
the server has never seen is not an undo, it is a conflict.

Thirty entries covers an entire tournament's worth of corrections without letting
the stack grow into the document size limit.

### 32.6 Recovery

```dart
RecoveryService.saveGame(game)   // active tournament + lastSavedAt
RecoveryService.saveCash(...)    // active cash session
GuestSession                     // guest's own approved seat
```

Snapshots go to device-local storage through the same `model_codec.dart` the
cloud uses. On relaunch the host is offered *"Restore active tournament — last
saved 21:43"* rather than a blank screen.

### 32.7 Targeted writes

Wherever more than one party can write, the app patches **dot-paths** rather than
whole objects:

- `_persistOwnRsvpPatch` — a member's own RSVP
- `_persistOwnCheckInPatch` — a member's own check-in
- `_updatePrizePool` — only `prizePool`, `organizerAmount`, `roundingRemainder`,
  `prizes`

Whole-document writes are reserved for the authority device.

---

## 33. Integrity and verification

The question: **how does a player know the host did not quietly rewrite the
structure or the payouts after the money was in?**

The answer: the engine is pure and deterministic (§2), so **every device can
recompute the host's work from the same inputs and compare.**

```
StructureVerification:
    inputs = the game's own GameSettings (including every override)
    recompute the structure
    compare four fields against what the host published
    disagreement → report
```

Two rules that keep this honest:

- **`organizerPct` is compared as 0.** Players receive the projection (§6.2), in
  which the organizer's cut is stripped to zero. Verification must therefore
  recompute against zero too, or **every honest game on every player's device
  reports as tampered.**
- **Manually edited levels are excluded.** A host is *allowed* to hand-edit a
  level, and `manuallyEdited` records that they did. Verification checks that the
  un-edited levels match what the engine would produce, and that the edits are
  declared.

### Supporting trails

| Trail | Contents |
|---|---|
| `auditHistory` | Every action, actor, timestamp and amount — admin-only |
| `changeLog` | Structural changes to the tournament |
| `modifiedLevels` | Which levels differ from `originalLevels` — **derived, not stored** |
| `revision` | Monotonic; every authoritative write increments it |
| `payments` | Every attempt including failures, with idempotency keys |

Deriving `modifiedLevels` rather than storing a flag means it cannot be set
without the underlying level actually differing.

---

## 34. Statistics and history

Each player keeps their **own** copy of each result at
`users/{uid}/results/{gameId}`:

```dart
for (final r in rows) {
  if (r.position <= 0) continue;        // unranked / unfinished
  if (r.position == 1) wins++;
  if (r.position <= 3) podium++;
  knockouts += r.knockouts;
  finishSum += r.position;
}
played    = rows.where((r) => r.position > 0).length;
avgFinish = played == 0 ? 0 : finishSum / played;

UserStats { played, wins, podium, avgFinish, knockouts }
```

Two design points:

- **`position <= 0` is skipped everywhere**, including in `played`. A cancelled or
  abandoned game must not drag an average finish down — it was not a finish.
- **Each user owns their record.** Stats do not depend on the host's group
  document still existing, or on the host still being reachable. A player who
  leaves a group keeps their history.

If the write fails while offline, `_recordOwnResultOffline` queues it locally and
`_maybeRecordOwnResult` completes it on reconnect.

---

## 35. Free and Premium

> **Entitlements are device-local and payments are simulated.** This is a designed
> upgrade *experience*, not an enforced paywall, and it is written that way on
> purpose so the boundary can be reviewed before any billing is connected.

### The free limit is about hosting, not membership

```dart
freeMaxActivePlayers = 9
canHost(tier, players) = tier == premium || players <= 9
```

Nine is not arbitrary: the seating model is 1–9 on one table, and ten becomes
5 + 5 — a second table, which is a genuinely different product.

Group membership is explicitly **not** capped. Groups are persistent communities;
capping them would punish exactly the behaviour the app exists to encourage.

The blocked message says what the limit is and what lifts it:

> *"Free hosting covers one table — up to 9 players. This tournament has 14,
> which needs two tables. Premium unlocks multi-table hosting."*

### Where the line falls

| Feature | Free gets | Premium adds |
|---|---|---|
| Seating | Random draw | Manual, keep guests together, separate guests |
| Structure | The generated schedule | Hand-editing individual levels |
| Payouts | The recommended split | Choosing between the engine's options |
| Chips | The standard presets | Building and saving custom sets |
| Balancing | Automatic recommendation | Manual seat moves |
| TV | One read-only display | Customisation, multiple displays |
| Stats | Group history | Analytics and export |

### Two things deliberately NOT gated

**The tournament engine itself.** It is the only structure generator there is.
Gating it would leave free users with nothing to run a night on. Building a
deliberately worse second engine is more work than leaving this one free, and a
worse product.

**Rebuys, add-ons and eliminations.** Core operation. A clock that stops working
when somebody rebuys is not a free tier, it is a demo.

Every boundary is gathered in one file and named (`PremiumBoundary`,
`PremiumFeature`) precisely so the product owner can move any of them without
hunting through screens.

Placeholder pricing (9/month, 79/year, "Save 27%") exists so the screen can be
designed and reviewed. It is not agreed pricing.

---

## 36. Input safety and formatting

### Sanitization

Applied to every piece of user-generated text before it is stored:

```
1.  DECODE HTML entities first  (&amp; &lt; &gt; &quot; &#39; &nbsp;)
        — so obfuscated tags like &lt;script&gt; are EXPOSED before stripping
2.  remove <script> <style> <iframe> <object> <embed> blocks entirely
3.  strip all remaining HTML tags
4.  collapse runs of whitespace
5.  trim
6.  truncate to the field's limit
```

**Step 1 before step 2 is the whole trick.** Strip tags first and
`&lt;script&gt;alert(1)&lt;/script&gt;` survives untouched, then renders as a
live tag the moment something decodes it.

```dart
maxChatLength           = 1000
maxNameLength           =   50
maxTournamentNameLength =   80
maxLocationLength       =  160
maxPollQuestionLength   =  200
maxPollOptionLength     =  100
```

### Formatting

```dart
Formatters.chips(12500)    → '12.5K'      // CHIP COUNTS ONLY
Formatters.chips(1500000)  → '1.5M'
Formatters.chips(400)      → '400'

Formatters.prize(1250)     → '1,250'      // MONEY — never abbreviated
Formatters.time(725)       → '12:05'
Formatters.duration(200)   → '3h 20m'
Formatters.relativeTime()  → 'just now' | '15m ago' | '2h ago' | '3d ago'
Formatters.shortDateTime() → '7 Aug 2026, 20:00'
Formatters.averageStack(total, remaining)  → rounded to the nearest 100
```

**Money is never abbreviated.** A 1,250 prize pool shown as "1.3K" and a 1,150
payout shown as "1.2K" makes the table fail to add up — and the reconciliation a
reader is expected to be able to do by eye is the whole point of showing the
table.

**No currency symbols in the primary interface.** Amounts are shown as bare
numbers ("15", "15 + 5"). The group already knows what it plays for, and the app
does not need to guess a currency it was never told.

---
---

# PART VI — REFERENCE

---

## 37. Complete constants reference

### Engine

| Constant | Value |
|---|---|
| `engineVersion` | `'2.1.0'` |
| `kExpectedRebuyRate` | 0.35 |
| `kExpectedReEntryRate` | 0.20 |
| `kExpectedAddOnRate` | 0.65 |
| `targetHeadsUpAverageBB` | 15 → `targetFinalBB = totalChips / 30` |
| `_spareLevels` | 4 |
| `settlementBreakMins` | 15 |
| `validLevelDurations` (presets) | `[10, 15, 20]` |
| `kMinLevelDurationMins` / `kMaxLevelDurationMins` | 3 / 60 |
| Level-length fallback | ≤3 h → 10 · ≤5 h → 15 · else 20 |
| `defaultTableSize` | 9 |
| `maxChipsPerPlayer` | 25 (validated to `[1, 100]`) |
| `valueLadder` | `[5, 25, 100, 500, 1000, 5000]` |
| `validBlindLevels` | 34 pairs, 5/10 → 3000/6000 |
| Snap prefixes | `[1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0]` |
| Snap preference margin | `diff <= minDiff × 1.5` |
| Chip reserve ladders | `[0,4,6,8,10,12]` · `[0,2,4,6,8]` · `[0,2,4]` |
| Exactness penalty | `−10000 − |covered − target|` |
| `kMinTargetBBDepth` / `kMaxTargetBBDepth` | 40 / 220 |
| `_rebuyWorthwhileBB` | 20 |
| Rebuy ceiling fraction | 0.55 · 0.60 (≥18) · 0.65 (≥40) |
| Chip-payability cutoff | `minChipValue × 4 > BB` |
| `kBreakDurationPresets` | `[5, 10, 15, 20]` minutes |
| `kMaxScheduledBreaks` | 3 |
| Colour-up trigger | `bb >= chipValue × 20`, new count `ceil(...)` |
| Level-extension BB | `snap(lastBB × 1.4)`, SB at `× 0.45` |
| Slow-down insertion | `× 1.5` when next BB ≥ 2× current |
| Speed-up BB multiplier | `× 1.25` |
| Level duration adjust | ±5 min, clamped `[10, 20]` |
| Speed recommendation threshold | ±20 minutes |

### Depth bands

| Target style | Opening BB | Admissible band |
|---|---|---|
| turbo | < 60 | 40 – 70 |
| fast | < 75 | 55 – 90 |
| standard | ≤ 120 | 70 – 140 |
| deep | > 120 | 100 – 220 |

### Money

| Constant | Value |
|---|---|
| `maxOrganizerPct` | 20 |
| `roundingUnitFor(buyIn)` | always 10 |
| Per-place minimum | 10 |
| Paid-place tiers | ≥6 → 2 · ≥10 → 3 · ≥18 → 4 |
| Pool clamps | <100 → max 2 places · <400 → max 3 |
| Reference grid | 67 rows, pools 50 – 700 in 10s |
| Standard weights | 2: `[.73,.27]` · 3: `[.57,.30,.13]` · 4: `[.56,.30,.10,.04]` |
| 5+ places | `weightᵢ = e^(−0.7 i)`, normalised |
| `PayoutShape` ratios | topHeavy .65 · flat .50 · winnerTakeMost .90 |
| Payout options cap | 5 places, and ≤ players |
| Option drop rule | ≥3 places sharing the lowest award |
| `Icm.maxExactPlayers` | 9 |
| Cash reconciliation tolerance | `< 0.01` |
| Rounding rule | round half up, integer cents |

### Live control

| Constant | Value |
|---|---|
| `_maxUndoDepth` | 30 |
| `_editorClaimStaleWindow` | 90 s |
| Server-time recalibration | every 10 minutes |
| Clock tick | 1 s |
| Countdown spoken | 5-4-3-2-1, one per second |
| `ShotClock` presets | `[30, 60, 90]` s, default 30 |
| `ShotClock.isUrgentAt` | ≤ 10 s |

### Social and limits

| Constant | Value |
|---|---|
| `_chatBurstLimit` | 8 per 30 s |
| `_chatMinSendGap` | 4000 ms (server ~3750 ms) |
| Code lookup throttle | 10 per minute per device |
| Poll options | 2 – 10 |
| `maxChatLength` | 1000 |
| `maxNameLength` | 50 |
| `maxTournamentNameLength` | 80 |
| `maxLocationLength` | 160 |
| `maxPollQuestionLength` | 200 |
| `maxPollOptionLength` | 100 |

### Seating, tiers, display

| Constant | Value |
|---|---|
| `TableSettings.maxPerTable` | 9 |
| Balance trigger | `max − min > 1` |
| `Entitlements.freeMaxActivePlayers` | 9 |
| Final-table auto-trigger | `remaining <= 9 && multiTable && !redrawn` |
| `TvDisplaySettings.textScale` | `[0.7, 2.0]`, default 1.0 |
| `rotatePresets` | `[5, 8, 12, 20, 30]` s |
| Join code space | 31⁶ = 887,503,681 |
| `secureId` space | 62²² ≈ 2.7 × 10³⁹ |
| RSVP deadline | start − 1 hour |

---

## 38. Documented deviations and judgement calls

Gathered here so nothing is buried.

| # | Decision | Rationale | To change |
|---|---|---|---|
| 1 | Three paid places start at **10** players, not 8 | 3 of 8 is 37.5% of the field, above the 15–25% target, and third prize lands at or below the buy-in | `players >= 10` → `players >= 8` in `_paidPlacesFor`; nothing else moves |
| 2 | `maxChipsPerPlayer = 25` | One standard chip-tray row; not mandated by spec | `TournamentParams` override, or the constant |
| 3 | Snap prefers a standard prefix within `× 1.5` | 20/50 reads right; the arithmetic nearest does not | the 1.5 multiplier |
| 4 | Payout rounding unit always 10 | Multiples of 10, never ending in 5 — residue carried out as `roundingRemainder` | `roundingUnitFor` |
| 5 | Universal depth floor replaced by a **band** | A floor lengthened short events it was never meant to touch | `admissibleDepthBand` |
| 6 | Free/Premium boundary lines | The spec names the tiers, never where the line falls | `PremiumBoundary` — one file |
| 7 | Guests can never be organizers (D7) | Organizers handle money; a guest has no verified identity | `Permissions` |
| 8 | ICM proportional above 9 players | Exact recursion is factorial; nobody chops 12-handed | `Icm.maxExactPlayers` |
| 9 | Greedy cash settlement | Exact minimisation is NP-hard; greedy gives the obvious answer in ≤ n−1 transfers | `CashSettlement.settle` |
| 10 | No chip race on colour-up | A race costs more time and goodwill than the fractional chips are worth | — |

---

## 39. Boundaries — what the app does not claim to do

Stated plainly so nothing here is read as more than it is:

1. **Payments are simulated.** The flow, ledger, idempotency, audit trail and
   reconciliation are complete and real. No money moves. Swapping in a real
   provider is one assignment (`Payments.instance`); no screen imports a
   concrete implementation.

2. **Premium entitlement is device-local.** It is a designed upgrade experience
   and a visible boundary, not an enforced paywall. A determined user can bypass
   it. The boundary is gathered in one named file so it can be reviewed and
   moved before billing is connected.

3. **Integrity verification is peer recomputation, not attestation.** Every
   device independently recomputes the host's structure and reports
   disagreement. That detects an altered structure; it is not a cryptographic
   guarantee.

4. **The shot clock is soft.** It never folds a hand. It is an instrument for the
   host to point at.

5. **ICM above nine players is proportional, not exact** — and says so where it
   is shown.

6. **Table balancing recommends; it does not move anybody.** The host moves
   players.

---

*End of document.*
