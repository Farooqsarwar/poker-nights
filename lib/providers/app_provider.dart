import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../app/route_paths.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show DocumentSnapshot, FieldValue, FirebaseException;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';

import 'package:localstore/localstore.dart';

import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/live_game.dart';
import '../models/payment_record.dart';
import '../models/shot_clock.dart';
import '../models/table_settings.dart';
import '../models/tournament.dart';
import '../models/tournament_preset.dart';
import '../models/user.dart';
import '../models/chip_color.dart';
import '../repositories/firebase_repository.dart';
import '../services/entitlements.dart';
import '../services/permissions.dart';
import '../services/payment_service.dart';
import '../utils/formatters.dart';
import '../utils/mock_data.dart';
import '../utils/model_codec.dart';
import '../utils/sanitization.dart';
import '../utils/tournament_engine.dart';
import '../utils/voice_service.dart';
import '../services/browser_notifications.dart';
import '../services/onesignal_sender.dart';
import '../services/projections.dart' as projections;
import '../services/push_service.dart';
import '../services/recovery_service.dart';
import '../services/tab_leader.dart';

part 'app_provider_auth.dart';
part 'app_provider_cloud_sync.dart';
part 'app_provider_user_data.dart';
part 'app_provider_groups.dart';
part 'app_provider_game.dart';
part 'app_provider_timer.dart';
part 'app_provider_players.dart';
part 'app_provider_tournament.dart';
part 'app_provider_social.dart';
part 'app_provider_codes_cash.dart';
part 'app_provider_payments.dart';
part 'app_provider_notifications_settings.dart';

/// One future-level edit produced by the admin structure editor.
typedef LevelEdit = ({int level, int sb, int bb, int? ante, int durationMins});

/// Result of looking up a game / TV code.
enum CodeLookupResult { game, tv, notFound, rateLimited }

/// What a scanned / typed / pasted join code points at. Produced by
/// [AppProvider.resolveJoinCode] so the unified join screen can pick a flow.
enum JoinCodeKind { group, game, tv, notFound, rateLimited, error }

/// Outcome of [AppProvider.resolveJoinCode] — the [kind] plus the cleaned
/// [code] that was extracted from whatever the user entered (bare code,
/// full invite link, or QR payload).
class JoinCodeResolution {
  const JoinCodeResolution(this.kind, this.code);

  final JoinCodeKind kind;
  final String code;
}

/// How the admin wants checked-in players distributed to tables/seats
/// (checklist §13.1). Mirrored by the screen's `SeatingMode`.
enum TableSeatingMode { random, manual, keepGuests, separateGuests }

/// A suggested seat move that balances table counts. Produced by
/// [AppProvider.requestSeatingBalance]; the admin must confirm it before it is
/// applied (checklist §13.2).
class SeatMoveRecommendation {
  const SeatMoveRecommendation({
    required this.fromPlayerId,
    required this.fromPlayerName,
    required this.fromTable,
    required this.fromSeat,
    required this.toTable,
    required this.toSeat,
    required this.reason,
  });

  final String fromPlayerId;
  final String fromPlayerName;
  final int fromTable;
  final int fromSeat;
  final int toTable;
  final int toSeat;
  final String reason;
}

/// Folds member-owned fields from the [remote] server game back into the
/// admin's [local] game just before an authority whole-document `.set()`, so a
/// member's RSVP / guest-slot write that landed while the admin's save was
/// debouncing is not silently overwritten.
///
/// Rules:
///  - the admin's own player row ([adminId]) keeps the local value (the admin
///    owns their own RSVP through a separate write path);
///  - every other member row adopts a differing server RSVP;
///  - rows present on the server but not locally are appended (a member who
///    joined after the game was created writes their whole row on first RSVP;
///    a "+N" RSVP creates guest rows) — local rows are never dropped;
///  - the server's guest-slot list wins whenever it differs (members rewrite
///    it via their +N count / guest names; the admin never edits slots).
///
/// Pure and side-effect free so it can be unit tested.
LiveGame mergeMemberOwnedFields(LiveGame local, LiveGame remote,
    {String? adminId}) {
  if (remote.id != local.id) return local;
  final localById = {for (final p in local.players) p.id: p};
  var changed = false;

  final merged = <Player>[
    for (final p in local.players)
      if (p.isGuest || p.id == adminId)
        p
      else
        () {
          final r = remote.players.where((x) => x.id == p.id).firstOrNull;
          if (r != null) {
            final rsvpChanged = r.rsvp != p.rsvp;
            // Merge checkedIn if the member checked themselves in remotely,
            // taking care not to let a stale remote overwrite an admin's local check-in.
            final checkInArrived = r.checkedIn && !p.checkedIn;
            
            if (rsvpChanged || checkInArrived) {
              changed = true;
              return p.copyWith(
                rsvp: r.rsvp,
                checkedIn: checkInArrived ? true : p.checkedIn,
              );
            }
          }
          return p;
        }(),
  ];

  for (final r in remote.players) {
    if (!localById.containsKey(r.id)) {
      merged.add(r);
      changed = true;
    }
  }

  String slotSig(List<GuestSlot> s) =>
      s.map((x) => guestSlotToMap(x).toString()).join('|');
  final slotsDiffer = slotSig(remote.guestSlots) != slotSig(local.guestSlots);

  if (!changed && !slotsDiffer) return local;
  return local.copyWith(
    players: merged,
    guestSlots: slotsDiffer ? remote.guestSlots : null,
  );
}

/// Re-attaches the admin-only figures that `saveGame` scrubs out of the public
/// game document (organizer cut, prize amounts, per-player financial counters)
/// onto a [remote] copy, taking them from the [local] one already in memory.
///
/// Every path that rebuilds the admin's current game from a server document
/// must apply this, so all of them produce structurally identical results for
/// identical server state. Pure and side-effect free for testing.
LiveGame restoreAdminPrivateFields(LiveGame remote, LiveGame local) {
  if (local.id != remote.id) return remote;
  final saved = {for (final p in local.players) p.id: p};
  return remote.copyWith(
    settings: remote.settings.copyWith(
      organizerPct: local.settings.organizerPct,
    ),
    players: [
      for (final p in remote.players)
        if (saved[p.id] case final r?)
          p.copyWith(
            rebuys: r.rebuys,
            reEntries: r.reEntries,
            hasAddOn: r.hasAddOn,
            knockouts: r.knockouts,
          )
        else
          p,
    ],
    structure: remote.structure.copyWith(
      prizes: local.structure.prizes,
      organizerAmount: local.structure.organizerAmount,
    ),
    // `saveGame` blanks the audit timeline out of the member-readable game
    // document and keeps it in the admin sidecar, so the copy that comes back
    // over the wire is always empty. Re-attach the one already in memory —
    // otherwise every remote snapshot would wipe the host's audit history and
    // flip the content signature on every emit.
    auditHistory:
        remote.auditHistory.isEmpty ? local.auditHistory : remote.auditHistory,
    // Same story for the pending request queue: scrubbed on the wire, held
    // in memory and in the admin sidecar.
    rebuyRequests:
        remote.rebuyRequests.isEmpty ? local.rebuyRequests : remote.rebuyRequests,
    addOnRequests:
        remote.addOnRequests.isEmpty ? local.addOnRequests : remote.addOnRequests,
  );
}

/// Field state, app-wide constants and shared scalar helpers for
/// [AppProvider].
///
/// The per-domain behaviour lives in the `AppProvider*` extension part files
/// (`app_provider_*.dart`). Every field lives here — plus the small
/// self-contained helpers and the `isAdmin` verdict — so they are visible to
/// every one of those extensions (all parts share this library) and directly
/// to the class body itself.
class AppProvider extends ChangeNotifier {
  final FirebaseRepository _repo = FirebaseRepository.instance;

  /// False when Firebase never came up (widget tests) — every cloud sync
  /// entry point checks this before touching the repository.
  bool _backendUp = true;
  bool _disposed = false;

  /// Firebase auth session subscription — cancelled on dispose.
  StreamSubscription<fa.User?>? _authSub;

  /// Live data subscriptions, all keyed to the signed-in user / selected
  /// group and cancelled on sign-out or dispose.
  StreamSubscription<List<GroupMembership>>? _groupsSub;
  StreamSubscription<Group>? _bundleSub;

  /// Whether the current group's live bundle has delivered its first snapshot.
  /// Reset to false on every [_selectGroup]; flipped true on the first emit.
  bool _bundleLoaded = false;

  /// Completes when the current group's bundle first loads (or errors). Lets
  /// [joinGroup] wait for real-time group data before the caller navigates.
  Completer<void>? _bundleReady;

  /// Completes once the signed-in user's data has bootstrapped after login —
  /// the groups index has loaded and (if a group was auto-selected) its bundle
  /// too. Lets [login] / [register] land the user on a populated dashboard.
  Completer<void>? _userBootstrap;

  /// Future that resolves when post-login data is ready (see [_userBootstrap]).
  Future<void> get userDataReady =>
      _userBootstrap?.future ?? Future<void>.value();
  StreamSubscription? _gameDocSub;

  /// Backoff re-subscription timers for the game-scoped streams. A Firestore
  /// `.snapshots()` that hits `permission-denied` (the auth token has not yet
  /// propagated into the SDK in the seconds after a web login) is dead for
  /// good, so we rebuild it a few times until it sticks — no page reload.
  Timer? _gameDocRetryTimer;
  Timer? _gameChatRetryTimer;

  /// Per-game chat lives in `groups/{gid}/games/{gameId}/chat` — a subcollection
  /// both the host and members append to directly. This keeps a member's
  /// message from being rolled back by the game-doc rule that forbids member
  /// `chat` writes, and from vanishing while it waits for the host to
  /// re-publish a projection.
  StreamSubscription<List<ChatMessage>>? _gameChatSub;
  List<ChatMessage> _gameChatMessages = const [];
  String? _gameChatKey;

  /// The signed-in member's own pending RSVP per game id. The write is
  /// committed the instant [setRSVP] runs; this overlay is re-applied on top
  /// of every adopted remote game so a lagging or racing snapshot never
  /// visibly reverts the member's own selection before their ack lands. The
  /// entry is dropped once a remote snapshot agrees, or if the write is
  /// rejected. `containsKey` distinguishes "no overlay" from "overlay = clear".
  final Map<String, Rsvp?> _pendingOwnRsvp = {};
  final Map<String, String> _pendingCheckIn = {};
  final Map<String, bool> _checkInLanded = {};

  /// Last member-RSVP patch failure, surfaced on the invitation screen so
  /// backend rejections are never invisible (vs silent optimistic state that
  /// vanishes on refresh). Debug aid for the persistence audit.
  /// Addendum §3: free hosting covers one table, up to nine active players.
  ///
  /// Device-local, read from [MockPaymentService]. Real Premium authorization
  /// belongs on a server (§7, acceptance 12) and does not exist yet, so this
  /// is an honest product limit rather than security. A determined user can
  /// change it; the point is that an ordinary host is told before the night
  /// goes wrong, not that it cannot be defeated.
  PremiumTier premiumTier = PremiumTier.free;

  /// Resolves the effective Premium tier.
  ///
  /// Two sources, deliberately:
  ///
  ///  * `entitlements/{uid}` in Firestore — AUTHORITATIVE. Read-only to every
  ///    client by security rule, so it cannot be forged from the app. This is
  ///    the enforcement the specification asks for (§7, acceptance 12), and it
  ///    needs no Cloud Functions: the rule runs on Google's servers and there
  ///    is no write condition a client request can satisfy.
  ///
  ///  * [MockPaymentService] on the device — DEMO ONLY. It is what the
  ///    dummy checkout screen writes, so the upgrade flow can be shown and
  ///    reviewed while the commercial terms are unsettled. Trivially
  ///    bypassed, and never treated as proof of anything.
  ///
  /// Either grants Premium, because the demo has to work. When real billing
  /// arrives, delete the local branch and this becomes enforcement outright.
  /// Whether the device-local demo entitlement may grant Premium.
  ///
  /// True by default so the dummy checkout screen works while the commercial
  /// terms are unsettled. Build with `--dart-define=DEMO_PREMIUM=false` and
  /// ONLY the server-held entitlement counts -- at which point a manipulated
  /// client flag grants nothing, which is what QA cases PN-SEC-003 and
  /// PN-NEG-001 are actually asking for.
  static const bool demoPremiumEnabled =
      bool.fromEnvironment('DEMO_PREMIUM', defaultValue: false);

  Future<void> loadPremiumTier() async {
    // Both awaits below sit behind a ternary: with the backend down and
    // DEMO_PREMIUM off, neither is taken and this method runs start to finish
    // synchronously — `notifyListeners()` included. UpgradeScreen calls it
    // from `initState`, so that notification landed mid-build and the
    // framework threw "setState() or markNeedsBuild() called during build",
    // blanking the screen. `await null` yields to the microtask queue, which
    // cannot run until the build phase has finished, so the notification is
    // always delivered from outside a build no matter which branch is taken.
    await null;
    final server = _backendUp ? await _repo.fetchPremiumEntitlement() : false;
    final local = demoPremiumEnabled
        ? await Payments.instance.currentTier()
        : PremiumTier.free;
    if (_disposed) return;
    premiumTier = (server || local == PremiumTier.premium)
        ? PremiumTier.premium
        : PremiumTier.free;
    premiumIsServerGranted = server;
    notifyListeners();
  }

  /// True when Premium came from the server rather than the local demo flag.
  ///
  /// Screens that need to be honest about this — a settings panel, a support
  /// view — can say "granted" rather than implying a purchase happened.
  bool premiumIsServerGranted = false;

  /// Whether this device may host a field of [players] (addendum §3, §4).
  bool canHostPlayers(int players) =>
      Entitlements.canHost(premiumTier, players);

  String? lastRsvpError;

  /// Last authority whole-document save failure. Non-null means the admin's
  /// most recent change did NOT reach Firestore — screens can surface it so a
  /// rejected write is never mistaken for a successful one.
  String? lastSaveError;

  bool forceEditorClaim = false;

  StreamSubscription<dynamic>? _lookupSub;
  StreamSubscription<List<TournamentPreset>>? _presetsSub;
  StreamSubscription<
          List<({String id, String name, List<ChipColor> chips})>>?
      _chipSetsSub;
  StreamSubscription<List<AppNotification>>? _notificationsSub;
  StreamSubscription<List<GameRequest>>? _requestsSub;
  StreamSubscription<List<CashSession>>? _cashSub;
  StreamSubscription<List<GameResultRow>>? _resultsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _pendingInvitesSub;

  /// Live member-rosters per group id, so the index-derived group list on the
  /// home screen / sidebar shows real-time member counts (free plan — no Cloud
  /// Function, and the membership index itself is not live).
  final Map<String, StreamSubscription<List<AppUser>>> _groupMembersSubs = {};

  /// Game ids whose own-result has already been written this session
  /// (doc id = gameId makes the write idempotent anyway).
  final Set<String> _resultsRecorded = <String>{};

  /// This player's lifetime results — aggregated into [_user.stats].
  List<GameResultRow> _myResults = const [];

  /// Signature of the last stats summary pushed to roster rows (dedupe).
  String? _lastPushedStatsKey;

  /// Browser-notification delivery bookkeeping: the first inbox emission is
  /// treated as history (never pushed); afterwards only new unread ids fire.
  final Set<String> _seenNotificationIds = <String>{};
  bool _notificationsPrimed = false;

  /// Debounces whole-document game saves so rapid admin edits coalesce.
  Timer? _gameSaveDebounce;
  Timer? _projectionDebounce;

  /// The game doc currently mirrored via [_gameDocSub] — used to skip
  /// adopting our own server acks (echo prevention).
  String? _syncedGameKey;

  /// True once a remote emission for [_syncedGameKey] was adopted; afterwards
  /// snapshots written by this device are ignored so debounced local edits are
  /// never reverted by their own ack.
  bool _gameSyncPrimed = false;

  /// True while a debounced save is pending — remote adoptions wait until it
  /// flushes so newer local state is not overwritten by an older snapshot.
  bool _pendingGameSave = false;

  /// Content signature of the last game state this device persisted (or
  /// adopted). `_syncGameToCloud` compares against this instead of object
  /// identity, so a bundle re-emit that hands back a fresh `LiveGame` instance
  /// with unchanged content is NOT treated as a local edit — that false
  /// "dirty" was starving the admin's `_adoptRemoteMap` and making the admin
  /// side look frozen while members updated live.
  String? _lastSavedSignature;
  String _gameSignature(LiveGame g) => jsonEncode(liveGameToMap(g));

  /// True the instant an authority makes a local edit to [_currentGame] that
  /// has not yet been persisted — set synchronously when the debounce timer is
  /// armed (not when it fires), so a remote snapshot that lands during the
  /// debounce window can no longer overwrite the admin's optimistic change
  /// (pause / resume / next level / accept check-in / confirm seating all
  /// "undoing themselves" a beat after the tap). Cleared once the save queue
  /// drains with nothing left to write.
  bool _localGameDirty = false;

  /// True once the first Firebase auth snapshot has been resolved. The router
  /// holds navigation at splash until this flips so the persisted session is
  /// restored before any guard runs.
  bool _authReady = false;
  bool get authReady => _authReady;

  bool _isTickUpdate = false;

  /// Timestamp of the last Firestore game sync — shown on TV mode as a
  /// staleness indicator so viewers know if the feed is stale.
  DateTime? _lastGameUpdate;
  DateTime? get lastGameUpdate => _lastGameUpdate;

  // ── Connectivity / recovery state (offline indicator, checklist 12-075) ────
  bool _isOffline = false;
  bool get isOffline => _isOffline;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _hasReconnected = false;
  bool get hasReconnected => _hasReconnected;

  /// True when the active game was restored from local storage on startup.
  bool _restoredFromRecovery = false;
  bool get restoredFromRecovery => _restoredFromRecovery;
  DateTime? _recoveryTime;
  DateTime? get recoveryTime => _recoveryTime;

  /// Timestamp of the last non-clock data sync. TV/player/guest views use it
  /// to show "last updated" and distinguish a live feed from a stale one
  /// (checklist 15-039, 18-028, 20-038). Clock ticks do not count as syncs.
  DateTime _lastSync = DateTime.now();

  // ── Preferences ────────────────────────────────────────────────────────────
  bool _notificationsEnabled = true;

  // ── Cloud sync plumbing ────────────────────────────────────────────────────
  bool _gameSaveInFlight = false;

  /// Sticky "this device is taking over" flag for the NEXT whole-document
  /// save. [forceEditorClaim] is consumed the moment the debounce timer fires,
  /// but the drain it kicks off may be a no-op (an earlier drain is still in
  /// flight) — in which case the blocking write it was raised for (cancelling
  /// a tournament) would have been retried WITHOUT the override. Latching it
  /// here keeps the override attached to the queued state until the save that
  /// carries it actually runs.
  bool _pendingSaveForce = false;

  /// Consecutive whole-document save failures. Holding the admin's unsaved
  /// state blocks incoming updates, so that hold is bounded — see the
  /// `_localGameDirty` assignment in [_drainGameSaveQueue].
  int _consecutiveSaveFailures = 0;

  /// A blind level proposed because play ran past the generated structure,
  /// awaiting the admin's approval (User Flow sections 3.3 / 4.14, 12-082).
  /// Null whenever there is nothing to approve. The clock is held while it is
  /// set, so the app never advances the structure on its own.
  BlindLevel? pendingLevelExtension;

  /// Set by [_reconcileMemberOwnedFields] when the pre-save server read folded
  /// a member's change (RSVP / check-in / a whole new roster row) into the
  /// admin's live game. The save drain notifies listeners once it settles so
  /// the host's screen actually redraws with it.
  bool _reconcileAdoptedLocally = false;

  /// Set by [_adoptRemoteMap] when a game-doc snapshot had to be dropped
  /// because an authority save was in flight. The drain re-reads the document
  /// once it settles, so a member write that landed inside that window is not
  /// lost until the next unrelated write happens to wake the stream.
  bool _droppedRemoteWhileBusy = false;
  bool _editorClaimInFlight = false;
  LiveGame? _pendingLatestSave;

  LiveGame? _lastSavedGame;

  /// Last resolved admin verdict per group id. While a group's live bundle is
  /// re-subscribing, [_currentGroup] is briefly the empty placeholder
  /// (blank ownerId, no members). Without this cache [isAdmin] would flip to
  /// false for those frames and the router / screen guards would bounce the
  /// admin off `/admin-dashboard` (or `/check-in`) mid-flow, then land them
  /// back a moment later. The cache holds the last real answer across that gap.
  final Map<String, bool> _adminVerdictByGroup = {};

  DateTime? _lastEditorHeartbeatAt;
  static const Duration _editorHeartbeatInterval = Duration(seconds: 25);

  /// Resolves `(gid, gameId)` for cloud operations on the active game, or
  /// null when there is nothing to target yet.
  (String, String)? get _cloudGameContext {
    final game = _currentGame;
    if (game == null || _user == null || !_backendUp) return null;
    final gid = game.groupId.isNotEmpty ? game.groupId : _currentGroupId;
    if (gid == null) return null;
    return (gid, game.id);
  }

  /// How many times this member has re-written their own RSVP for a game after
  /// a foreign writer reverted it. Capped so a genuine rules rejection can't
  /// loop forever.
  final Map<String, int> _rsvpReassertCount = {};

  /// Lightweight placeholder used before a group's live bundle has loaded and
  /// after the user leaves their last group.
  static const Group _kEmptyGroup = Group(
    id: '',
    name: '',
    joinCode: '',
    ownerId: '',
    members: [],
    games: [],
    chat: [],
    polls: [],
    notifications: [],
  );

  // ── Notification outbox mirror (free-plan fan-out) ─────────────────────────
  final Map<String, StreamSubscription<List<OutboxNotification>>>
      _groupOutboxSubs = {};
  final Set<String> _mirroredOutboxIds = <String>{};
  final Map<String, bool> _outboxPrimed = {};
  final Map<String, int> _mirrorCursors = {};

  // ── Auth ───────────────────────────────────────────────────────────────────
  AppUser? _user;

  Future<void>? _hydrating;

  /// Fire-and-forget write of a single preference key.
  void _persistPref(String key, Object? value) {
    if (key == 'colorTheme' || key == 'themePreference') {
      try {
        final db = Localstore.instance;
        db.collection('app').doc('prefs').set({key: value}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to save theme to localstore: $e');
      }
    }
    
    final uid = _repo.currentUid;
    if (!_backendUp || uid == null) return;
    unawaited(_repo
        .saveUserPref(uid, key, value)
        .catchError((Object e) => debugPrint('saveUserPref($key) failed: $e')));
  }

  // ── Chip Sets ──────────────────────────────────────────────────────────────
  /// Starter chip set seeded into new Firestore accounts (doc id `cs-default`
  /// keeps the "protected default" semantics of deleteChipSet).
  static const seedChipSet = (
    id: 'cs-default',
    name: 'Home Set (4 colour)',
    chips: MockData.defaultChipSet,
  );

  final List<({String id, String name, List<ChipColor> chips})> _savedChipSets =
      [seedChipSet];

  // ── Tournament Presets (checklist §9.1) ──────────────────────────────────
  /// Starter presets seeded into new Firestore accounts so the create-
  /// tournament wizard works out of the box.
  static final List<TournamentPreset> seedPresets = [
    TournamentPreset(
      id: 'pr-friday',
      name: 'Friday Night Regular',
      buyIn: 15,
      koEnabled: false,
      koAmount: 5,
      rebuys: true,
      rebuysCloseLevel: 6,
      reEntry: true,
      addOn: true,
      durationHours: 3.5,
      anteEnabled: true,
      anteAfterLevel: 6,
      organizerPct: 10,
      chipSetName: 'Home Set (4 colour)',
      chipSet: List.of(MockData.defaultChipSet),
    ),
    TournamentPreset(
      id: 'pr-deep',
      name: 'Deep Stack Turbo',
      buyIn: 25,
      koEnabled: true,
      koAmount: 10,
      rebuys: false,
      rebuysCloseLevel: 5,
      reEntry: false,
      addOn: false,
      durationHours: 5,
      anteEnabled: true,
      anteAfterLevel: 5,
      organizerPct: 0,
      chipSetName: 'Standard 500',
      chipSet: List.of(TournamentEngine.getPreset('Standard 500')),
    ),
  ];

  final List<TournamentPreset> _presets = List.of(seedPresets);

  // ── Group ──────────────────────────────────────────────────────────────────
  /// Neutral placeholder until the first group of the signed-in user is
  /// auto-selected (or the user creates/joins one).
  Group _currentGroup = _kEmptyGroup;

  /// The group whose live bundle is currently subscribed.
  String? _currentGroupId;

  /// Every group the user belongs to, rebuilt from the live index stream.
  /// Rows are lightweight (no members/chat/games) — the rich state lives in
  /// [currentGroup] via the bundle subscription.
  List<Group> _groups = const [];

  /// The table-capacity/randomization rules that actually apply to the
  /// active tournament: its own override if set, otherwise the group
  /// default.
  TableSettings get effectiveTableSettings =>
      _currentGame?.settings.tableSettingsOverride ??
      _currentGroup.tableSettings;

  // ── Game ───────────────────────────────────────────────────────────────────
  LiveGame? _currentGame;

  /// Elects a single leader among same-browser tabs viewing [_tabLeaderScope]
  /// (a live game id), so the editor-authority check below cannot let two
  /// tabs of one browser both act as the single writer. No-op off the web —
  /// see `services/tab_leader.dart`. Rebound by [_syncTabLeader] whenever the
  /// open game changes.
  TabLeader? _tabLeader;
  String? _tabLeaderScope;

  /// Keeps [_tabLeader] bound to whichever game is currently open, creating
  /// or replacing it only when the game id actually changes so the election
  /// (and its in-flight peer list) survives ordinary re-renders.
  void _syncTabLeader() {
    final gameId = _currentGame?.id;
    if (gameId == _tabLeaderScope) return;
    try {
      _tabLeader?.dispose();
      _tabLeaderScope = gameId;
      _tabLeader = gameId == null ? null : TabLeader(gameId);
    } catch (e) {
      // BroadcastChannel is missing on older Safari and blocked in some
      // embedded contexts. This runs inside notifyListeners(), so letting it
      // throw would take the UI update with it — and the cost of losing the
      // election is only that two tabs of one browser can both write again,
      // which is exactly the behaviour that shipped before it existed. A null
      // leader reads as "assume leader" at every call site, so the host keeps
      // control of their own game rather than being locked out of editing.
      debugPrint('tab leader election unavailable, continuing without it: $e');
      _tabLeader = null;
      _tabLeaderScope = gameId;
    }
  }

  // Undo stack (checklist 12-042/12-043/12-044, technical §11.3). Before every
  // admin mutation we snapshot the previous game; undo pops and restores it.
  static const int _maxUndoDepth = 30;
  final List<LiveGame?> _undoStack = [];

  /// An editor claim older than this is considered stale: any admin device may
  /// take over the single-writer role (90 seconds of silence).
  static const Duration _editorClaimStaleWindow = Duration(seconds: 90);

  /// Pending seat-balance recommendation (checklist §13.2), if any.
  SeatMoveRecommendation? _pendingSeatMove;

  /// Idempotency guard (technical §18.1): claims the next revision for an
  /// administrator action carrying [idempotencyKey]. Returns the new revision
  /// to persist, or null when the key was already applied — a replayed action
  /// (browser retry, offline-restore redelivery) must never be applied twice.
  ///
  /// Callers fold the returned revision (and the key) into their final
  /// [LiveGame.copyWith] so the guard survives save, restore and fan-out.
  /// Claims the next revision for an admin mutation, rejecting a replayed
  /// action: if [idempotencyKey] matches the key that produced the current
  /// revision, the call is a duplicate and returns null. When the caller does
  /// not supply a key, one is derived deterministically from the action's own
  /// identity (`action-target-revision+1`) instead of bypassing replay
  /// protection entirely. Returns the new revision and the persistence key
  /// (the caller stores the latter as `lastIdempotencyKey`).
  (int?, String) _claimIdempotency(String idempotencyKey,
      {required String action, String target = ''}) {
    final g = _currentGame;
    if (g == null) return (null, '');
    final key = idempotencyKey.isNotEmpty
        ? idempotencyKey
        : '$action-${target.isEmpty ? g.id : target}-${g.revision + 1}';
    if (g.lastIdempotencyKey == key) return (null, key); // replay
    return (g.revision + 1, key);
  }

  // ── Timer ──────────────────────────────────────────────────────────────────
  Timer? _ticker;
  Timer? _serverTimeRecalibration;

  /// Marks already announced per level (checklist 15-047/15-048) so the
  /// five-minute and one-minute warnings fire only once per level.
  final Set<String> _levelAnnouncementMarks = <String>{};

  /// Used to derive server-authoritative timer from Firestore server time.
  Duration? _serverTimeOffset;

  // ── Guest session (device-local, checklist 07-030) ─────────────────────────
  GuestSession? _guestSession;
  GuestSession? get guestSession => _guestSession;

  // ── Late registration (checklist §12.3) ────────────────────────────────────
  /// Validation message explaining why completion was refused (User Flow
  /// §4.17 "System validates that every paid position has one player"). Set
  /// by [recordFinishOrder] when the recorded finish order fails
  /// [validateCompletion]; cleared again on the next attempt.
  String? _completionError;

  // ── Chat & polls ───────────────────────────────────────────────────────────
  /// Basic spam rate limit (tech spec §14.1): at most
  /// [_chatBurstLimit] messages per sliding [_chatBurstWindow], and no more
  /// than one message per [_chatMinSendGap] (aligns the client with the
  /// server-side ~3750ms `rate_limits` throttle so bursts aren't dropped).
  static const int _chatBurstLimit = 8;
  static const Duration _chatBurstWindow = Duration(seconds: 30);
  static const Duration _chatMinSendGap = Duration(milliseconds: 4000);
  final Map<String, List<DateTime>> _chatSendTimes = <String, List<DateTime>>{};

  // ── Chat unread tracking (Tech Spec §14.1) ────────────────────────────────
  /// Last-read timestamp per chat scope key. Scope keys are `group:<gid>`
  /// for the group hub chat and `game:<gid>` for a live game's chat.
  final Map<String, DateTime> _chatLastRead = {};

  /// Persists the member's own RSVP dot-path patch against a game doc (the one
  /// open on screen or any game in the current group — chat invite card).
  ///
  /// The optimistic overlay ([_pendingOwnRsvp]) is held for the entire retry
  /// window and only dropped once every attempt has failed — so a tap never
  /// "un-selects itself" while the group id is still resolving or the auth
  /// token is still propagating right after login.
  final Map<String, int> _checkInReassertCount = {};

  // ── Code lookup ────────────────────────────────────────────────────────────
  /// Sliding-window throttle for join-code lookups (spec §22 rate limits).
  /// Firestore rules cannot count reads, so the client caps itself at 10
  /// lookups per minute per device.
  final List<DateTime> _codeLookupTimes = <DateTime>[];

  // ── Cash game ──────────────────────────────────────────────────────────────
  CashSession? _cashSession;

  /// Completed cash sessions shown in history (checklist 16-002). Cloud-backed
  /// per group via [completedCashSessionsStream]; locally appended when the
  /// backend is unavailable.
  List<CashSession> _cashHistory = const [];

  // ── Notifications ──────────────────────────────────────────────────────────
  /// Replaced by the live inbox stream once user data is subscribed; empty
  /// until then (no demo seed — a fresh account starts clean).
  List<AppNotification> _notifications = const [];

  // ── Voice & misc ───────────────────────────────────────────────────────────
  bool _voiceEnabled = true;

  bool _showAppTour = true;

  // Audio Master (checklist 15-041/15-042/15-043, User Flow §7.4): the chosen
  // speaking device now lives on the GAME (`LiveGame.audioMasterDeviceId`) and
  // this device's identity comes from the repository's persisted device id.
  // Both used to be per-session provider fields, which meant the choice was
  // invisible to other devices and lost on every reload — so every open tab
  // announced at once. See `thisDeviceIsAudioMaster`.

  // ── Account preferences (settings screen) ─────────────────────────────────
  bool _soundsEnabled = true;

  bool _compactSummary = false;

  /// SMS/text notifications for RSVPs and game events.
  bool _smsEnabled = false;

  /// Theme preference: one of "dark", "light", "system".
  String _themePreference = 'dark';

  /// Color theme id — one of the [ThemePalettes.all] ids.
  String _colorTheme = 'red';

  /// Id of the chip set used as the default for new tournaments; null = the
  /// standard set.
  String? _defaultChipSetId;

  /// Selected avatar colour index (into the app's avatar palette).
  int _avatarColorIndex = 0;

  String _guestCode = '';

  // ── Drawer state ───────────────────────────────────────────────────────────
  bool _isDrawerOpen = false;

  // ── App-wide constants ─────────────────────────────────────────────────────
  /// Maximum message length (checklist 08-009).
  static const int maxChatMessageLength = 1000;

  // ── Admin verdict (shared by every domain; the class body needs it too) ────
  /// True when the signed-in user administers the current group (owner or a
  /// member row flagged `isAdmin`). Resilient to the transient empty-group
  /// window via [_adminVerdictByGroup].
  /// What the signed-in user is, for the tournament in front of them (§28).
  Actor get currentActor => Permissions.actorFor(
        user: _user,
        group: _currentGroup,
        game: _currentGame,
        isGuestSession: hasGuestSession,
      );

  /// Whether the signed-in user may run the CURRENT tournament — an admin
  /// anywhere, or an organizer assigned to this one (§3, §28).
  ///
  /// This is what the live controls should ask, rather than `isAdmin`: an
  /// organizer exists precisely so the host can hand over a night without
  /// handing over the group.
  bool get canRunCurrentGame =>
      Permissions.can(Capability.runThisTournament, currentActor);

  /// Whether the signed-in user may see this tournament's private money.
  /// §28's one conditional cell: an organizer, but only for their own game.
  bool get canSeePrivateFinancials =>
      Permissions.can(Capability.viewPrivateFinancials, currentActor);

  /// Assigns or removes a tournament organizer (§3).
  ///
  /// Admin only — §28 puts organizer management alongside the other
  /// group-level rights an organizer does not get, so an organizer cannot
  /// appoint another.
  void setTournamentOrganizer(String userId, {required bool assigned}) {
    final game = _currentGame;
    if (game == null || !isAdmin) return;
    if (game.isOrganizer(userId) == assigned) return;

    // D7: a guest can never be an organizer. §32 fixes guests as
    // event-scoped, and an organizer must be assignable, auditable and
    // accountable across check-in, seating and money — which needs an account,
    // not a name in a slot.
    final member = _currentGroup.members.any((m) => m.id == userId);
    if (assigned && !member) {
      lastRsvpError =
          'Only a group member can run a tournament. Ask them to join first.';
      if (!_disposed) notifyListeners();
      return;
    }

    _pushUndo();
    _currentGame = game.copyWith(
      organizerIds: assigned
          ? [...game.organizerIds, userId]
          : game.organizerIds.where((id) => id != userId).toList(),
    );
    final name = _currentGroup.members
            .where((m) => m.id == userId)
            .firstOrNull
            ?.name ??
        userId;
    addAuditRecord(
      assigned ? 'organizer_assigned' : 'organizer_removed',
      assigned
          ? '$name was made organizer of this tournament.'
          : '$name is no longer organizer of this tournament.',
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  bool get isAdmin {
    final user = _user;
    if (user == null) return false;
    final group = _currentGroup;
    final gid = _currentGroupId ?? group.id;
    final resolvable =
        group.id.isNotEmpty && (group.ownerId.isNotEmpty || group.members.isNotEmpty);
    if (resolvable) {
      final verdict = group.ownerId == user.id ||
          group.members.any((m) => m.id == user.id && m.isAdmin);
      if (gid.isNotEmpty) _adminVerdictByGroup[gid] = verdict;
      return verdict;
    }
    // Placeholder group during a bundle re-subscription — reuse the last
    // real verdict for this group if we have one.
    if (gid.isNotEmpty && _adminVerdictByGroup.containsKey(gid)) {
      return _adminVerdictByGroup[gid]!;
    }
    return false;
  }

  /// Application-level UI state (no business logic / backend).
  AppProvider({String? initialColorTheme, String? initialThemePreference}) {
    if (initialColorTheme != null) _colorTheme = initialColorTheme;
    if (initialThemePreference != null) _themePreference = initialThemePreference;
    _currentGame = null;
    AppProviderTimer(this)._startTick();
    AppProviderUserData(this)._loadRecovery();
    _initConnectivity();
    // Firebase may be unavailable (widget tests run before initializeApp);
    // degrade gracefully by marking auth resolved so route guards open up.
    try {
      _authSub = _repo.authStateChanges().listen(
          (u) => AppProviderAuth(this)._onAuthStateChanged(u));
    } catch (_) {
      _backendUp = false;
      _authReady = true;
    }
  }

  /// Initializes real connectivity monitoring (spec §15).
  void _initConnectivity() {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        final wasOffline = _isOffline;
        _isOffline = results.every((r) => r == ConnectivityResult.none);
        if (!wasOffline && _isOffline) {
          AppProviderNotificationsSettings(this).pushNotification(
            AppNotification(
              id: 'n-${DateTime.now().millisecondsSinceEpoch}',
              title: 'Connection warning',
              body: 'You are offline. Real-time sync is paused.',
              type: NotificationType.system,
              link: '/',
              read: false,
              timestamp: DateTime.now(),
            ),
          );
        }
        if (wasOffline && !_isOffline) {
          _hasReconnected = true;
        }
        if (!_disposed) notifyListeners();
      });
    } catch (_) {
      // connectivity_plus unavailable (tests) — stay with manual toggle
    }
  }

  /// Clears the reconnection banner after the user acknowledges it.
  void clearReconnectedBanner() {
    _hasReconnected = false;
    if (!_disposed) notifyListeners();
  }

  /// Demo-only toggle: flips the connectivity indicator. While offline every
  /// change is still persisted to local storage (RecoveryService), so nothing
  /// is lost and the app "reconnects" on tap.
  void toggleOffline() {
    _isOffline = !_isOffline;
    if (!_isOffline) _hasReconnected = true;
    if (!_disposed) notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_isTickUpdate) return;
    _lastSync = DateTime.now();
    _syncTabLeader();
    AppProviderCloudSync(this)._syncGameToCloud();
    AppProviderCloudSync(this)._ensureRequestsSubscription();
    final game = _currentGame;
    if (game == null) {
      RecoveryService.clearGame();
    } else if (isAdmin) {
      // Crash-resume snapshots belong to the ADMIN only — they are the device
      // that owns the live game document. Saving one on a member's device made
      // their optimistic RSVP look "persisted" across a reload while the
      // server never received it (and, worse, the restored copy then blocked
      // all remote adoption — see [_dropRecoveryIfNotAuthority]).
      RecoveryService.saveGame(game);
    }
    final session = _cashSession;
    if (session != null && !session.isCompleted) {
      RecoveryService.saveCashSession(session);
    } else {
      RecoveryService.clearCashSession();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestsSub?.cancel();
    _ticker?.cancel();
    _serverTimeRecalibration?.cancel();
    _authSub?.cancel();
    _connectivitySub?.cancel();
    _tabLeader?.dispose();
    AppProviderUserData(this)._teardownUserData();
    super.dispose();
  }
}

/// Result of a guest slot resolve (booking vs re-identification vs conflict).
enum GuestCheckInStatus { booked, confirmed, taken, failed }

class GuestCheckInResult {
  const GuestCheckInResult(this.status, {this.message});

  final GuestCheckInStatus status;

  /// Optional user-facing message, e.g. the conflict explanation when the slot
  /// belongs to a different name.
  final String? message;

  /// True when the guest now owns a booking on the slot ([booked] just made
  /// one; [confirmed] reused the one already under their name).
  bool get ok =>
      status == GuestCheckInStatus.booked || status == GuestCheckInStatus.confirmed;
}