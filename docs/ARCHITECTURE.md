# Poker Night — Architecture

Notes on how the app is structured, how state reaches Firestore, and the invariants that keep multi-device tournaments consistent. File references are relative to `lib/`.

## Layer diagram

```
+-------------------------------------------------------------------+
| Screens (screens/*)                                               |
|   read state via provider getters, mutate via intent methods      |
+------------------------------+------------------------------------+
                               | watch / calls
+------------------------------v------------------------------------+
| AppProvider (providers/app_provider.dart)                         |
|   single ChangeNotifier: UI + domain state, optimistic local      |
|   mutations, echo prevention, debounced saves, request handling   |
+--------------+--------------------------------+------------------+
               | writes / streams               | snapshots
+--------------v-----------------+   +----------v------------------+
| FirebaseRepository             |   | RecoveryService             |
| (repositories/                 |   | (services/                  |
|  firebase_repository.dart)     |   |  recovery_service.dart)     |
| sole Firestore access point:   |   | device-local crash recovery |
| whole-doc saves (authority),   |   | via localstore: active game,|
| dot-path patches (members),    |   | active cash session, guest  |
| projections, request queue     |   | session                     |
+--------------+-----------------+   +-----------------------------+
               |
+--------------v-----------------+
| Cloud Firestore                |
| users / groups / joinCodes /   |
| publicGames / requests         |
+--------------------------------+
```

Screens never touch Firestore directly. `AppProvider` mutates local state optimistically and then persists through `FirebaseRepository` (the only class importing `cloud_firestore`). In parallel, every non-tick state change is mirrored into `RecoveryService` so a crash or refresh can restore the live game locally (`app_provider.dart`, `notifyListeners` override).

Key plumbing inside `AppProvider`:

- **Echo prevention** — remote game snapshots are adopted only when `metadata.hasPendingWrites == false` and after the first baseline for the mirrored doc arrived (`_adoptRemoteGame`), so a device's own acks never revert its newer local edits.
- **Debounced saves** — authority devices coalesce rapid edits into one whole-document save per 400 ms window.
- **Dot-path patches** — members write only their own fields via `patchGame(gid, gameId, {dotPaths})`, avoiding clobbered concurrent edits.

## Roles & data projection model

Four roles — `admin`, `player`, `guest`, `tv` — are defined once in `services/projections.dart` (`GameProjectionRole`) and mirrored by `firestore.rules`. `projectionFor()` returns a copy of the `LiveGame` safe for each role:

| Role | Sees |
| --- | --- |
| Admin | Full object |
| Player | No organizer amount or per-place payout amounts; other players' rebuys/re-entries/add-ons/knockouts zeroed; only own rebuy/add-on requests; chat visible |
| Guest | Same financial stripping plus no chat, no pending guests, no audit history, no request lists |
| TV | Same as guest (read-only presentation feed) |

The public prize-pool *total* stays visible to all roles; only per-place amounts and the organizer cut are stripped. Because stripping happens at the data layer — before the payload is written to `publicGames/{id}` — private financial fields are physically absent from what guests/TVs download, not merely hidden in UI. Security rules enforce the same boundaries from the write side (guests have no access to `groups/{gid}/games` at all).

## Tournament engine

`utils/tournament_engine.dart` is a pure, deterministic generator: identical `TournamentParams` always produce an identical `TournamentStructure` (no clock, no randomness, no I/O). Inputs: player count, duration hours, buy-in, chip set, rebuy/re-entry/add-on flags with close levels, ante style, KO bounty, organizer percentage. Outputs: starting stack + chip plan, rebuy/add-on plans, blind levels, color-up instructions, prize split, warnings.

### Blind-curve math

1. **Level duration** — 10 min for events <= 3 h, 15 min for <= 5 h, otherwise 20 min. Durations outside `{10, 15, 20}` are unrepresentable (`validLevelDurations`). Level count = `max(6, floor(hours * 60 * 0.9 / duration))`.
2. **Target starting depth (big blinds)** — clamped formula:
   `depth = clamp(125 + 28 * (hours - 3.5) - 2.5 * max(0, players - 8), 80..240)`;
   `startingStack = round(depth * openingBB / 100) * 100` (never below one opening BB). If physical chip inventory cannot cover the target stack, it is reduced in 100-steps until the greedy chip plan fits.
3. **Expected total chips** — starting stacks plus statistically expected volume: ~35 % of field rebuys, ~20 % re-entries, ~65 % add-ons.
4. **Final big-blind target** — heads-up should begin with ~15 BB average stacks:
   `targetFinalBB = expectedTotalChips / (2 x 15)`.
5. **Growth curve** — `rawBB(i) = openingBB * growthFactor^i` with
   `growthFactor = (targetFinalBB / openingBB)^(1 / max(1, levels - 1))`.
   Every raw value is snapped to the closest entry on the legal blind ladder (`validBlindLevels`: 25/50 ... 300/600, then SB +100-step jumps); the sequence stays strictly monotonically increasing, and the ladder extends in +200/+400 steps for very large fields.
6. **Antes** — big-blind ante defaults to the BB itself; individual ante = `BB / 9` snapped to a practical chip denomination.

### Organizer cut & payouts

`recalculatePrizes(gross, players, pct)` picks the organizer amount closest to `gross * pct` among candidates sharing gross's units digit — which guarantees the remaining prize pool is a multiple of 10:

> Worked example — gross 165 at 10 %: target = 16.5, candidates {15, 25}; 15 is closer -> **organizer 15, pool 150**.

Payout splitting honors exact-sum invariants: awards sum precisely to the pool, place 1 is largest, amounts are monotonically non-increasing down the places, lower places are multiples of 10 with a minimum of 10 (no paid place ever pays 0). When the computed pool matches the built-in reference schedule (pools 50-700 in steps of 10), that approved split is used verbatim; otherwise distribution weights approximate it: **~73/27** for 2 places, **~57/30/13** for 3, **~56/30/10/4** for 4. Paid-place count derives from both field size and pool size (never more than 2 places under a 100 pool, never more than 3 under 400). KO bounties are excluded from `grossEligible` entirely — bounty money passes straight through and never inflates the prize pool.

## Timekeeping model

The authoritative clock is the wall-clock timestamp `levelEndTime` on `LiveGame`: "when this level hits zero". The 1-second ticker (`AppProvider._startTick`) *derives* remaining time from `levelEndTime - now`; it never accumulates its own counter as truth. Tick updates are flagged `_isTickUpdate` so they skip cloud sync, recovery writes and last-sync bookkeeping — per-second counters are never persisted as state changes. Pausing/stopping clears `levelEndTime`.

Offline/crash recovery: `RecoveryService` keeps a localstore snapshot of the active game (plus cash session and guest session). On startup `loadGame()` performs **restore-with-catch-up**: if the snapshot says the timer was running, elapsed wall-clock since `lastSavedAt` is subtracted from the stored remainder, so a restored game resumes at the correct point rather than replaying lost seconds. When local and cloud state diverge, a conflict resolution offers keep-local or adopt-cloud.

## Realtime fan-out

Instead of a named-events bus (the original Tech Spec §19 sketch), realtime distribution uses plain Firestore snapshot listeners over **sanitized projection documents**:

- The authority device saves the game doc and publishes three role projections (`tv`, `player`, `guest`) into a single `publicGames/{gameId}` document (`_publishProjections` -> `publishPublicProjections`).
- TVs and guest devices resolve a public/TV code via `joinCodes/{code}`, then subscribe to `publicGameStream(gameId)` and decode only their role's sub-payload. Group members with dashboard access subscribe to the raw `groups/{gid}/games/{gameId}` document instead.
- Group content (meta, members, chat, polls, games) streams through `groupBundleStream`, which merges five listeners and emits only once every source has delivered its initial snapshot.

This substitution keeps everything inside Firestore's security model — guests/TVs read pre-sanitized data they cannot escalate — and requires no additional infrastructure.

## Concurrency model

- **Authority-only whole-document writes.** Only the group owner or admin members ("authority devices", mirroring `_isGameAuthority` and the rules helper `isGroupAdmin`) may write entire game documents. Plain member updates must pass the rules' `memberGameEdit()` whitelist: only their own slices (RSVP, check-in flag, chat appends, rebuy/add-on request lists) may vary; every other field must be byte-identical before/after.
- **Idempotency-keyed request queue.** Member/guest actions aimed at the admin device (rebuy/add-on/check-in requests, guest check-ins) are posted to `requests/{gameId}/items`. When an idempotency key is supplied, the write targets a deterministic doc id, so double-taps and retries overwrite instead of duplicating (spec §18.1). The authority consumes items via a snapshot listener and marks them `consumed: true`.
- **Transactional guest-slot claims.** `reserveGuestSlotTx` claims the deterministic doc `requests/{gameId}/items/guestCheckIn-{inviterId}-{slot}` inside a Firestore transaction — racing guests are serialized server-side, first reservation wins, and the loser gets an error instead of enqueueing a duplicate. Admins free slots again via `releaseSlotClaim`.
- **Optimistic local state + undo.** All mutations land locally first (with an undo stack for admin actions), then propagate; remote adoption is guarded against echo loops (see above).

## Firestore collections map

```
users/{uid}                       Private profile: name, email, stats, prefs
  /presets/{presetId}             Saved tournament parameter presets
  /chipSets/{setId}               Personal chip sets
  /notifications/{notifId}        Notification inbox (fan-out target)
  /groups/{groupId}               Membership mirror (name/icon/pinned/role) powering the sidebar
  /results/{gameId}               Player's own settled results (lifetime stats source)

groups/{gid}                      Meta: name, joinCode, ownerId, icon
  /members/{uid}                  Roster row: name, role ('admin'|'member'), joinedAt, stats summary
  /chat/{msgId}                   Group chat (soft-delete only)
  /polls/{pollId}                 Polls
  /games/{gameId}                 Full live-game documents (authority-written)
  /cashSessions/{sessionId}       Completed cash-game ledger entries

joinCodes/{CODE}                  Code lookup: kind 'group' | 'game' | 'tv' plus gid/gameId

publicGames/{gameId}              Sanitized tv/player/guest projections (+ codes, status)

requests/{gameId}
  /items/{reqId}                  Request queue: kind, payload, consumed flag;
                                  deterministic ids double as idempotency keys and slot locks
```

All writes carry `updatedAt` (server timestamp) and `writerId` (stable per-install id) stamps applied by `FirebaseRepository._stamp`.

## Security notes

`firestore.rules` ends with a catch-all deny; everything not matched is inaccessible. Highlights:

- `users/{uid}` subtree is owner-only; any signed-in user may drop a notification into another user's inbox, but only the owner reads/marks it.
- Group meta and roster are member-readable; role changes and removals are admin operations (members may fix their own display name and mirror their own stats).
- Game docs: authority create/delete/update; member updates restricted by the byte-comparison whitelist described under Concurrency; guests denied outright.
- `publicGames` is world-readable by design (TVs are often unauthenticated browsers); projections contain no personal data beyond first names/seat assignments, and only group admins can write them.
- `joinCodes`: any signed-in user may resolve codes; updates/deletes require group admin rights.
- Chat is soft-delete-only by author or admin; hard deletes are denied.

### Known limitations

- **No server-side rate limiting.** Firestore rules cannot count reads or throttle writes, and this project ships no Cloud Functions (Tech Spec §22 is only partially implemented). Throttling exists purely client-side: join-code lookups are capped at 10 per minute per device (`_consumeCodeLookupSlot`) and chat at 8 messages per 30 s per user (`_chatBurstLimit`). A malicious client bypasses both; enforcing real limits would require Cloud Functions in front of these endpoints.
- **App Check is dormant without a dart-define.** `FirebaseAppCheck.activate` runs only when `--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY` supplies a reCAPTCHA v3 site key (`main.dart`). Without it, no attestation is attached to requests; rules do not currently enforce App Check either.

## Testing strategy

Tests are pure Dart against the domain layer — no Firebase emulator required:

| Suite | Covers |
| --- | --- |
| `test/tournament_engine_test.dart` | Tech Spec §23.1 acceptance properties: durations always 10/15/20, blinds strictly increasing/contiguous/payable, stack/chip-plan consistency, organizer rounding, exact-sum payout invariants across parameter grids |
| `test/model_codec_test.dart` | Round-trips through `model_codec.dart` for every model — the same codecs serve local recovery and Firestore, so wire-format drift would fail here |
| `test/projections_test.dart` | Role-projection privacy: financial fields stripped for player/guest/tv, chat/audit/pending-guest visibility, viewer-scoped request lists |
| `test/cash_reconciliation_test.dart` | §16.3/§23.2 cash math: buy-ins + top-ups vs stacks + cash-outs reconcile to zero difference |

Run with `flutter test` from the repo root.

## Seeding / demo data

There is no automated seeder and no demo dataset — intentionally. `lib/utils/mock_data.dart` shipped demo groups/games/history when state was local; since the move to Firestore-backed state it contains only `defaultChipSet`, a neutral chip template for new games and chip sets. Nothing seeds fake runtime data anymore.

To get realistic data for manual acceptance testing:

1. Create a Firebase project as described in the README, deploy rules, run the app.
2. Register an account, create a group, share its join code with a second browser profile and join as a second member (optionally one anonymous guest session).
3. Create a tournament from a preset or let the engine generate a structure (`TournamentEngine.getPreset('Standard 300')` etc. provide sensible defaults), publish it, and walk check-in -> live -> settlement.
4. For TV/guest views, open the public/tv code on a separate browser window — those flows read only `publicGames` projections and need no account.
