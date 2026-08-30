import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart'
    show DocumentSnapshot, FieldValue, FirebaseFirestore;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/live_game.dart';
import '../models/table_settings.dart';
import '../models/tournament.dart';
import '../models/tournament_preset.dart';
import '../models/user.dart';
import '../models/chip_color.dart';
import '../repositories/firebase_repository.dart';
import '../utils/formatters.dart';
import '../utils/mock_data.dart';
import '../utils/model_codec.dart';
import '../utils/sanitization.dart';
import '../utils/tournament_engine.dart';
import '../utils/voice_service.dart';
import '../services/browser_notifications.dart';
import '../services/projections.dart' as projections;
import '../services/recovery_service.dart';

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

/// Application-level UI state (no business logic / backend).
class AppProvider extends ChangeNotifier {
  AppProvider() {
    _currentGame = null;
    _startTick();
    _loadRecovery();
    _initConnectivity();
    // Firebase may be unavailable (widget tests run before initializeApp);
    // degrade gracefully by marking auth resolved so route guards open up.
    try {
      _authSub = _repo.authStateChanges().listen(_onAuthStateChanged);
    } catch (_) {
      _backendUp = false;
      _authReady = true;
    }
  }

  final FirebaseRepository _repo = FirebaseRepository.instance;

  /// False when Firebase never came up (widget tests) — every cloud sync
  /// entry point checks this before touching the repository.
  bool _backendUp = true;

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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gameDocSub;
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

  /// Initializes real connectivity monitoring (spec §15).
  void _initConnectivity() {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        final wasOffline = _isOffline;
        _isOffline = results.every((r) => r == ConnectivityResult.none);
        if (wasOffline && !_isOffline) {
          _hasReconnected = true;
        }
        notifyListeners();
      });
    } catch (_) {
      // connectivity_plus unavailable (tests) — stay with manual toggle
    }
  }

  /// Clears the reconnection banner after the user acknowledges it.
  void clearReconnectedBanner() {
    _hasReconnected = false;
    notifyListeners();
  }

  /// True when the active game was restored from local storage on startup.
  bool _restoredFromRecovery = false;
  bool get restoredFromRecovery => _restoredFromRecovery;
  DateTime? _recoveryTime;
  DateTime? get recoveryTime => _recoveryTime;

  /// Timestamp of the last non-clock data sync. TV/player/guest views use it
  /// to show "last updated" and distinguish a live feed from a stale one
  /// (checklist 15-039, 18-028, 20-038). Clock ticks do not count as syncs.
  DateTime _lastSync = DateTime.now();
  DateTime get lastSync => _lastSync;

  /// Demo-only toggle: flips the connectivity indicator. While offline every
  /// change is still persisted to local storage (RecoveryService), so nothing
  /// is lost and the app "reconnects" on tap.
  void toggleOffline() {
    _isOffline = !_isOffline;
    if (!_isOffline) _hasReconnected = true;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_isTickUpdate) return;
    _lastSync = DateTime.now();
    _syncGameToCloud();
    _ensureRequestsSubscription();
    if (_currentGame != null) {
      RecoveryService.saveGame(_currentGame!);
    } else {
      RecoveryService.clearGame();
    }
    final session = _cashSession;
    if (session != null && !session.isCompleted) {
      RecoveryService.saveCashSession(session);
    } else {
      RecoveryService.clearCashSession();
    }
  }

  // ── Preferences ────────────────────────────────────────────────────────────
  bool _notificationsEnabled = false;
  bool get notificationsEnabled => _notificationsEnabled;

  /// Enables browser notifications (web) after explicit permission, or just
  /// flips the flag where the API is unsupported (in-app inbox remains the
  /// delivery path there). Returns an error message on denial, null on
  /// success (spec §14.3 — push when granted, inbox as fallback).
  Future<String?> setNotificationsEnabled(bool value) async {
    if (value && BrowserNotify.supported) {
      final granted = await BrowserNotify.requestPermission();
      if (!granted) {
        _notificationsEnabled = false;
        _persistPref('browserNotify', false);
        notifyListeners();
        return 'Permission denied in this browser.';
      }
    }
    _notificationsEnabled = value;
    _persistPref('browserNotify', value);
    notifyListeners();
    return null;
  }

  /// Delivers newly-arrived inbox items as browser notifications when the
  /// user opted in; history is never replayed on sign-in.
  void _deliverBrowserNotifications(List<AppNotification> list) {
    if (!_notificationsPrimed) {
      _notificationsPrimed = true;
      for (final n in list) {
        _seenNotificationIds.add(n.id);
      }
      return;
    }
    for (final n in list) {
      final isNew = _seenNotificationIds.add(n.id);
      if (isNew && !n.read && _notificationsEnabled) {
        BrowserNotify.show(n.title, n.body);
      }
    }
  }

  // ── Cloud sync plumbing ────────────────────────────────────────────────────
  /// Tracks which active-game document this device mirrors. When the key
  /// changes the old doc subscription is replaced and a fresh baseline is
  /// awaited before further remote adoptions.
  void _syncGameToCloud() {
    if (!_backendUp) return;
    final game = _currentGame;
    final gid = game != null && game.groupId.isNotEmpty
        ? game.groupId
        : _currentGroupId;
    final key =
        (game == null || gid == null || _user == null) ? null : '$gid|${game.id}';

    if (key != _syncedGameKey) {
      _syncedGameKey = key;
      _gameSyncPrimed = false;
      _gameDocSub?.cancel();
      _gameDocSub = null;
      _gameSaveDebounce?.cancel();
      _pendingGameSave = false;
      if (key != null && game != null && gid != null) {
        _gameDocSub = _repo.gameDocSnapshots(gid, game.id, isAdmin: _isGameAuthority).listen(
          _adoptRemoteGame,
          onError: (Object e) => debugPrint('gameDoc stream error: $e'),
        );
      }
    }

    if (game == null || gid == null || _user == null) return;
    // Whole-document writes are reserved for the admin/authority device
    // (locked architecture §writes). Members patch their own fields and
    // guests use the request queue instead.
    if (!_isGameAuthority) return;
    // Identity check skips re-saving freshly adopted remote state (prevents
    // A↔B write loops).
    if (identical(_lastSavedGame, game)) return;
    _gameSaveDebounce?.cancel();
    final effectiveGid = game.groupId.isNotEmpty ? game.groupId : gid;
    _gameSaveDebounce = Timer(const Duration(milliseconds: 400), () async {
      final g = _currentGame;
      if (g == null || _user == null) return;
      try {
        // Stamp the owning group so recovered/draft games land in the right
        // collection even when the model was built before selection.
        final toSave =
            g.groupId.isNotEmpty ? g : g.copyWith(groupId: effectiveGid);
        await _repo.saveGame(toSave);
        await _publishProjections(toSave);
        _lastSavedGame = g;
      } catch (e) {
        debugPrint('saveGame failed: $e');
      }
      _pendingGameSave = false;
    });
    _pendingGameSave = true;
  }

  LiveGame? _lastSavedGame;

  /// True when the signed-in user may write the whole game document (group
  /// owner or admin member). Guests and plain members never qualify.
  bool get isAdmin {
    final user = _user;
    if (user == null) return false;
    if (_currentGroup.ownerId == user.id) return true;
    return _currentGroup.members
        .any((m) => m.id == user.id && m.isAdmin);
  }

  /// True when the signed-in user holds the elevated Co-Admin role in the
  /// current group: can add members directly and grant rebuys, but cannot
  /// advance the tournament or touch blinds/seating settings.
  bool get isCoAdmin {
    final user = _user;
    if (user == null || isAdmin) return false;
    return _currentGroup.members.any((m) => m.id == user.id && m.isCoAdmin);
  }

  /// MVP spec §3.1: exactly one administrator per event. Co-admin permissions
  /// are restricted to admin-only until the multi-admin feature is implemented.
  bool get canManageMembers => isAdmin;

  /// MVP spec §3.3: only admin can grant rebuys/add-ons.
  bool get canGrantRebuys => isAdmin;

  /// This member's role in the current group, for role-picker UIs.
  GroupRole roleOf(AppUser member) => member.isAdmin
      ? GroupRole.admin
      : (member.isCoAdmin ? GroupRole.coAdmin : GroupRole.member);

  bool get _isGameAuthority => isAdmin;

  /// Resolves `(gid, gameId)` for cloud operations on the active game, or
  /// null when there is nothing to target yet.
  (String, String)? get _cloudGameContext {
    final game = _currentGame;
    if (game == null || _user == null || !_backendUp) return null;
    final gid = game.groupId.isNotEmpty ? game.groupId : _currentGroupId;
    if (gid == null) return null;
    return (gid, game.id);
  }

  /// Member/guest-safe field patch: writes dot-paths without touching the
  /// rest of the document (locked architecture §writes).
  void _patchActiveGame(Map<String, dynamic> dotPaths) {
    final ctx = _cloudGameContext;
    if (ctx == null || dotPaths.isEmpty) return;
    unawaited(_repo
        .patchGame(ctx.$1, ctx.$2, dotPaths)
        .catchError((Object e) => debugPrint('patchGame failed: $e')));
  }

  /// Publishes sanitized public/TV/player/guest projections after a
  /// successful whole-doc save so TVs and guest devices can follow along.
  Future<void> _publishProjections(LiveGame game) async {
    if (!_backendUp) return;
    try {
      await _repo.publishPublicProjections(
        game: game,
        tv: liveGameToMap(projections.tvProjection(game)),
        player:
            liveGameToMap(projections.playerProjection(game, viewerId: '')),
        guest: liveGameToMap(projections.guestProjection(game)),
      );
      await _repo.upsertGameCodes(game);
    } catch (e) {
      debugPrint('publishProjections failed: $e');
    }
  }

  /// Opens the request-queue subscription once this device qualifies as
  /// authority for the active game. Re-evaluated on every provider change so
  /// late-loading membership flips it on at the right moment.
  void _ensureRequestsSubscription() {
    if (!_backendUp || _currentGame == null || !_isGameAuthority) return;
    if (_requestsSub != null) return;
    final gameId = _currentGame!.id;
    _requestsSub = _repo.requestsStream(gameId).listen(
      _consumeRequests,
      onError: (Object e) => debugPrint('requests stream error: $e'),
    );
  }

  /// Applies queued member/guest requests to the authoritative local game,
  /// then marks each one consumed so other devices ignore it.
  Future<void> _consumeRequests(List<GameRequest> requests) async {
    final game = _currentGame;
    if (requests.isEmpty || game == null) return;
    final gameId = game.id;
    var changed = false;
    var hadError = false;
    for (final req in requests) {
      String? error;
      switch (req.kind) {
        case 'guestCheckIn':
          error = _applyQueuedGuestCheckIn(req.payload);
          break;
        case 'rebuyReq':
          requestRebuy((req.payload['playerId'] as String?) ?? '');
          break;
        case 'addOnReq':
          requestAddOn((req.payload['playerId'] as String?) ?? '');
          break;
        default:
          error = 'unknown kind';
      }
      if (error != null) hadError = true;
      try {
        await _repo.consumeRequest(gameId, req.id);
      } catch (e) {
        debugPrint('consumeRequest failed: $e');
      }
      changed = true;
    }
    if (changed && !hadError) notifyListeners();
  }

  /// Attaches a queued guest check-in to the authoritative game. Returns an
  /// error string when the slot is invalid — the request is consumed either
  /// way so it never re-processes.
  String? _applyQueuedGuestCheckIn(Map<String, dynamic> payload) {
    final game = _currentGame;
    if (game == null) return 'no active game';
    final name = (payload['name'] as String?) ?? 'Guest';
    final inviterId = (payload['inviterId'] as String?) ?? '';
    final slotNo = (payload['slot'] as num?)?.toInt() ?? 0;
    final guestId =
        (payload['guestId'] as String?) ?? 'g-${DateTime.now().millisecondsSinceEpoch}';

    final existingSlot = game.guestSlots
        .where((s) => s.inviterId == inviterId && s.slot == slotNo)
        .firstOrNull;
    if (game.status.isActiveLive && game.rebuysClosed) {
      return 'Late registration has closed - no new players can be added.';
    }
    if (existingSlot != null && !existingSlot.available) {
      return 'slot taken';
    }
    if (game.players.any(
      (p) => p.isGuest && p.inviterId == inviterId && p.guestSlot == slotNo,
    )) {
      return 'slot claimed';
    }

    final guest = Player(
      id: guestId,
      name: name,
      isGuest: true,
      inviterId: inviterId,
      guestSlot: slotNo,
      rsvp: Rsvp.going,
      checkedIn: false,
      confirmed: false,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: 0,
      seat: 0,
      active: false,
    );
    _pushUndo();
    _currentGame = game.copyWith(
      players: [...game.players, guest],
      pendingGuests: [...game.pendingGuests, guest],
      guestSlots: _markSlotReserved(
        game.guestSlots,
        inviterId,
        slotNo,
        name: name.trim(),
        // The queued claim carries the guest's check-in request (spec §7.1).
        requested: true,
      ),
    );
    return null;
  }

  /// Adopts a remote game document unless it is our own latency-compensated
  /// write or the ack of a write we just made (echo prevention, locked
  /// architecture §reads).
  void _adoptRemoteGame(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (!snap.exists || data == null) return;
    if (snap.metadata.hasPendingWrites) return;
    if (!_gameSyncPrimed) {
      _gameSyncPrimed = true;
    } else if (data['writerId'] == _repo.deviceId) {
      return;
    }
    if (_pendingGameSave) return;
    try {
      final remote =
          liveGameFromFirestoreDoc(Map<String, dynamic>.from(data));
      if (_currentGame?.id != remote.id) return;
      _currentGame = remote;
      _lastSavedGame = remote;
      RecoveryService.saveGame(remote);
      // Another device may have settled the tournament — record my result.
      _maybeRecordOwnResult(remote);
      notifyListeners();
    } catch (e) {
      debugPrint('remote game decode failed: $e');
    }
  }

  /// Subscribes every user-scoped collection after sign-in / hydration.
  void _subscribeUserData() {
    final uid = _repo.currentUid;
    if (!_backendUp || uid == null) return;

    // Release anyone waiting on a previous (now-cancelled) subscription before
    // starting a fresh bootstrap.
    if (!(_userBootstrap?.isCompleted ?? true)) _userBootstrap!.complete();
    _userBootstrap = Completer<void>();
    final bootstrap = _userBootstrap!;
    void bootstrapDone() {
      if (!bootstrap.isCompleted) bootstrap.complete();
    }

    _groupsSub?.cancel();
    _groupsSub = _repo.groupsIndexStream(uid).listen((rows) {
      // Rebuild from the lightweight index, but keep the already-loaded rich
      // bundle for the selected group (its members/games) so the sidebar count
      // doesn't flip back to 0 on every index re-delivery — apply the index's
      // pinned/name/icon on top.
      _groups = [
        for (final r in rows)
          if (r.groupId == _currentGroupId &&
              _currentGroup.id == r.groupId &&
              _currentGroup.members.isNotEmpty)
            _currentGroup.copyWith(
              name: r.name.isNotEmpty ? r.name : null,
              icon: r.icon,
              pinned: r.pinned,
            )
          else
            _groupFromMembership(r),
      ];
      // Additionally keep live member rosters for every group so home/sidebar
      // counts stay real-time even when no rich bundle is loaded yet.
      _syncGroupMembersSubs();
      // First group after sign-in is auto-selected (pinned first, then
      // alphabetical — same ordering the sidebar uses).
      if (_currentGroupId == null && rows.isNotEmpty) {
        final sorted = [...rows]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        sorted.sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
        _selectGroup(sorted.first.groupId);
      }
      // The index has loaded; if it picked a group, chain readiness to that
      // group's bundle so callers land on a populated dashboard.
      if (_currentGroupId != null) {
        groupReady.then((_) => bootstrapDone());
      } else {
        bootstrapDone();
      }
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('groupsIndex stream error: $e');
      bootstrapDone();
    });

    _presetsSub?.cancel();
    _presetsSub = _repo.presetsStream(uid).listen((list) {
      _presets
        ..clear()
        ..addAll(list);
      notifyListeners();
    },
        onError: (Object e) => debugPrint('presets stream error: $e'));

    _chipSetsSub?.cancel();
    _chipSetsSub = _repo.chipSetsStream(uid).listen((list) {
      _savedChipSets
        ..clear()
        ..addAll(list);
      notifyListeners();
    },
        onError: (Object e) => debugPrint('chipSets stream error: $e'));

    _notificationsSub?.cancel();
    _notificationsSub = _repo.notificationsStream(uid).listen((list) {
      _deliverBrowserNotifications(list);
      _notifications = list;
      notifyListeners();
    },
        onError: (Object e) => debugPrint('notifications stream error: $e'));

    // Lifetime stats: recompute whenever a result lands (this device wrote it
    // or another device did — same source of truth either way).
    _resultsSub?.cancel();
    _resultsSub = _repo.resultsStream(uid).listen((rows) {
      _myResults = rows;
      final user = _user;
      if (user != null) {
        _user = user.copyWith(stats: _statsFromResults(rows));
        _pushStatsSummaries();
      }
      notifyListeners();
    },
        onError: (Object e) => debugPrint('results stream error: $e'));

    // Free-plan: accept pending admin-by-email invites by self-writing the
    // user's own membership index (there is no Cloud Function to mirror it).
    _pendingInvitesSub?.cancel();
    _pendingInvitesSub = _repo.pendingInvitesStream(uid).listen((invites) {
      for (final invite in invites) {
        final gid = invite['gid'] as String?;
        if (gid == null) continue;
        if (_groups.any((g) => g.id == gid)) continue;
        unawaited(_repo
            .updateGroupIndex(
              uid,
              gid,
              name: invite['name'] as String?,
              icon: invite['icon'] as String?,
              role: 'member',
            )
            .catchError((Object e) => debugPrint('accept invite failed: $e')));
        final inviteId = invite['id'] as String? ?? invite['__inviteId'] as String?;
        if (inviteId != null) {
          unawaited(_repo.removePendingInvite(inviteId).catchError(
              (Object e) => debugPrint('remove invite failed: $e')));
        }
      }
      notifyListeners();
    },
        onError: (Object e) => debugPrint('pendingInvites stream error: $e'));
  }

  /// Mirrors the lifetime stats summary onto this user's roster row in every
  /// group they belong to, so other members see real numbers. Skipped when
  /// the summary is unchanged since the last push.
  void _pushStatsSummaries() {
    if (!_backendUp) return;
    final stats = _user?.stats;
    final uid = _repo.currentUid;
    if (stats == null || uid == null) return;
    final key =
        '${stats.played}/${stats.wins}/${stats.podium}/${stats.avgFinish}/${stats.knockouts}';
    if (key == _lastPushedStatsKey) return;
    _lastPushedStatsKey = key;
    for (final g in _groups) {
      unawaited(_repo.saveMemberStats(g.id, uid, stats)
          .catchError((Object e) => debugPrint('saveMemberStats failed: $e')));
    }
  }

  /// Aggregates raw result rows into the lifetime [UserStats].
  UserStats _statsFromResults(List<GameResultRow> rows) {
    var wins = 0, podium = 0, knockouts = 0, finishSum = 0;
    for (final r in rows) {
      if (r.position <= 0) continue; // malformed / partial row
      if (r.position == 1) wins++;
      if (r.position <= 3) podium++;
      knockouts += r.knockouts;
      finishSum += r.position;
    }
    final played = rows.where((r) => r.position > 0).length;
    return UserStats(
      played: played,
      wins: wins,
      podium: podium,
      avgFinish: played == 0 ? 0 : finishSum / played,
      knockouts: knockouts,
    );
  }

  /// Offline/demo fallback for [_maybeRecordOwnResult]: keeps the in-memory
  /// result list and stats moving with no backend round-trip.
  void _recordOwnResultOffline(LiveGame game) {
    final uid = _user?.id;
    if (uid == null || game.finishOrder.isEmpty) return;
    if (_resultsRecorded.contains(game.id)) return;
    final me =
        game.players.where((p) => p.id == uid && !p.isGuest).firstOrNull;
    if (me == null) return;
    final index = game.finishOrder.indexOf(uid);
    if (index == -1) return;
    _resultsRecorded.add(game.id);
    _myResults = [
      ..._myResults.where((r) => r.gameId != game.id),
      GameResultRow(
        gameId: game.id,
        groupId: game.groupId,
        position: index + 1,
        playerCount: game.finishOrder.length,
        knockouts: me.knockouts,
        finishedAt: DateTime.now(),
      ),
    ];
    _user = _user?.copyWith(stats: _statsFromResults(_myResults));
    notifyListeners();
  }

  /// When [game] has settled, records this signed-in player's own result
  /// (`users/{uid}/results/{gameId}`) so every device aggregates identical
  /// lifetime stats. Guests are skipped.
  void _maybeRecordOwnResult(LiveGame game) {
    final uid = _repo.currentUid;
    if (!_backendUp || uid == null || _user == null) return;
    if (game.status != LiveGameStatus.completed || game.finishOrder.isEmpty) {
      return;
    }
    if (_resultsRecorded.contains(game.id)) return;
    final me =
        game.players.where((p) => p.id == uid && !p.isGuest).firstOrNull;
    if (me == null) return;
    final index = game.finishOrder.indexOf(uid);
    if (index == -1) return;
    _resultsRecorded.add(game.id);
    unawaited(_repo
        .saveGameResult(
          uid,
          game.id,
          GameResultRow(
            gameId: game.id,
            groupId: game.groupId,
            position: index + 1,
            playerCount: game.finishOrder.length,
            knockouts: me.knockouts,
            finishedAt: DateTime.now(),
          ),
        )
        .catchError(
            (Object e) => debugPrint('saveGameResult failed: $e')));
  }

  /// Cancels all user/group-scoped subscriptions and clears derived state.
  void _teardownUserData() {
    for (final s in [
      _groupsSub,
      _bundleSub,
      _gameDocSub,
      _lookupSub,
      _presetsSub,
      _chipSetsSub,
      _notificationsSub,
      _requestsSub,
      _cashSub,
      _resultsSub,
      _pendingInvitesSub,
    ]) {
      s?.cancel();
    }
    for (final s in _groupMembersSubs.values) {
      s.cancel();
    }
    _groupMembersSubs.clear();
    _groupsSub = null;
    _bundleSub = null;
    _gameDocSub = null;
    _lookupSub = null;
    _presetsSub = null;
    _chipSetsSub = null;
    _notificationsSub = null;
    _requestsSub = null;
    _cashSub = null;
    _resultsSub = null;
    _pendingInvitesSub = null;
    _gameSaveDebounce?.cancel();
    _pendingGameSave = false;
    _syncedGameKey = null;
    _gameSyncPrimed = false;
    _currentGroupId = null;
    _bundleLoaded = false;
    _bundleReady = null;
    _userBootstrap = null;
    // Drop any group-scoped state from the previous session so a different
    // account signing in on this device never sees it.
    _currentGroup = _kEmptyGroup;
    _notifications = const [];
    _cashHistory = const [];
    _myResults = const [];
    _resultsRecorded.clear();
    _lastPushedStatsKey = null;
    _seenNotificationIds.clear();
    _notificationsPrimed = false;
  }

  /// Selects a group by id and (re)subscribes its live bundle.
  void _selectGroup(String gid) {
    if (_currentGroupId == gid && _bundleSub != null) return;
    _currentGroupId = gid;
    _bundleSub?.cancel();
    _cashSub?.cancel();
    _cashSub = null;
    _bundleSub = null;
    _bundleLoaded = false;
    _bundleReady = Completer<void>();
    // Until the full bundle arrives, show the lightweight index row (name +
    // icon) for this group rather than the previously-selected group's data.
    final row = _groups.where((g) => g.id == gid).firstOrNull;
    _currentGroup = row ?? _kEmptyGroup;

    void markReady() {
      if (!(_bundleReady?.isCompleted ?? true)) _bundleReady!.complete();
    }

    if (!_backendUp) {
      markReady();
      return;
    }
    _bundleSub = _repo.groupBundleStream(gid).listen((g) {
      // _setGroup (not a bare `_currentGroup = g`) so the full group — members,
      // games, code — is also written into `_groups`, which backs the sidebar
      // / drawer / orderedGroups (they'd otherwise show the lightweight index
      // row with 0 members).
      _setGroup(g);
      _bundleLoaded = true;
      markReady();
      // Catch results of games this device never followed live (e.g. the
      // player sat out or never opened the game screen).
      for (final finished in g.pastGames) {
        _maybeRecordOwnResult(finished);
      }
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('groupBundle stream error: $e');
      markReady();
    });
    _cashSub = _repo.completedCashSessionsStream(gid).listen((list) {
      _cashHistory = list;
      notifyListeners();
    }, onError: (Object e) => debugPrint('cashSessions stream error: $e'));
  }

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

  /// True while a group is selected but its live bundle (members, games, chat,
  /// settings) has not delivered its first snapshot — the group hub should
  /// render a loading state rather than an empty shell.
  bool get groupBundleLoading => _currentGroupId != null && !_bundleLoaded;

  /// Completes once the selected group's bundle has loaded (or errored).
  Future<void> get groupReady =>
      _bundleReady?.future ?? Future<void>.value();

  Group _groupFromMembership(GroupMembership r) => Group(
        id: r.groupId,
        name: r.name,
        joinCode: '',
        ownerId: '',
        members: const [],
        games: const [],
        chat: const [],
        polls: const [],
        notifications: const [],
        icon: r.icon,
        pinned: r.pinned,
      );

  /// Keeps the index-derived group list's `members` populated live so member
  /// counts on the home screen / sidebar are real-time. Subscribes a members
  /// stream per group and cancels subs for groups that were left/removed.
  void _syncGroupMembersSubs() {
    final wanted = {for (final g in _groups) g.id};
    final stale = [
      for (final entry in _groupMembersSubs.entries)
        if (!wanted.contains(entry.key)) entry.key,
    ];
    for (final gid in stale) {
      _groupMembersSubs.remove(gid)?.cancel();
    }
    for (final g in _groups) {
      if (_groupMembersSubs.containsKey(g.id)) continue;
      _groupMembersSubs[g.id] =
          _repo.groupMembersStream(g.id).listen((members) {
        final i = _groups.indexWhere((x) => x.id == g.id);
        if (i == -1) return;
        _groups = [..._groups]..[i] = _groups[i].copyWith(members: members);
        notifyListeners();
      }, onError: (Object e) => debugPrint('group members stream error: $e'));
    }
  }

  Future<void> _loadRecovery() async {
    final recovered = await RecoveryService.loadGame();
    if (recovered != null) {
      _currentGame = recovered;
      _restoredFromRecovery = true;
      _recoveryTime = DateTime.now();
    }
    final cash = await RecoveryService.loadCashSession();
    if (cash != null && !cash.isCompleted) {
      _cashSession = cash;
    }
    final guest = await RecoveryService.loadGuestSession();
    if (guest != null) {
      _guestSession = guest;
    }
    notifyListeners();
  }

  /// True if the locally recovered game state differs from the "cloud" state.
  /// Compares multiple fields to detect real conflicts, not just audit count.
  bool get hasOfflineConflict {
    if (_currentGame == null || !_restoredFromRecovery) return false;
    final cloudGame = _currentGroup.games
        .where((g) => g.id == _currentGame!.id)
        .firstOrNull;
    if (cloudGame == null) return false;
    return _currentGame!.auditHistory.length != cloudGame.auditHistory.length ||
        _currentGame!.currentLevel != cloudGame.currentLevel ||
        _currentGame!.secondsRemaining != cloudGame.secondsRemaining ||
        _currentGame!.status != cloudGame.status ||
        _currentGame!.finishOrder.length != cloudGame.finishOrder.length;
  }

  void resolveOfflineConflict({required bool keepLocal}) {
    if (_currentGame != null) {
      if (keepLocal) {
        // Sync local up to cloud
        final games = _currentGroup.games.toList();
        final idx = games.indexWhere((g) => g.id == _currentGame!.id);
        if (idx != -1) {
          games[idx] = _currentGame!;
          _setGroup(_currentGroup.copyWith(games: games));
        }
      } else {
        // Revert local down to cloud
        final cloudGame = _currentGroup.games
            .where((g) => g.id == _currentGame!.id)
            .firstOrNull;
        if (cloudGame != null) {
          _currentGame = cloudGame;
          RecoveryService.saveGame(cloudGame);
        }
      }
    }
    _restoredFromRecovery = false;
    notifyListeners();
  }

  /// Exposes the snapshot timestamp so the restore prompt can show
  /// "last saved HH:MM" (Tech spec §20.1).
  DateTime? get restoredAt => RecoveryService.lastSavedAt;

  /// Admin declined the restored snapshot — drop the local active game.
  void discardRestoredGame() {
    _currentGame = null;
    _restoredFromRecovery = false;
    RecoveryService.clearGame();
    _syncGroupGame();
    notifyListeners();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  AppUser? _user;
  AppUser? get user => _user;

  bool get isAuthenticated => _user != null;

  /// True while the signed-in account is an anonymous (guest) session.
  bool get isGuest => _repo.isSignedInAsGuest;

  Future<void> _onAuthStateChanged(fa.User? fbUser) async {
    if (fbUser == null) {
      // Nothing to hydrate for a signed-out user — release the router now.
      _authReady = true;
      _teardownUserData();
      if (_user != null) {
        _user = null;
        notifyListeners();
      }
      return;
    }
    // Keep the router gated at splash until the restored session is actually
    // usable (profile + streams). Flipping `_authReady` before this made the
    // guard see `ready=true, authed=false` during hydration and bounce a
    // signed-in user to the login page until a rebuild happened (the "tap a
    // field / login button and it logs me in" bug).
    await _hydrateUser(fbUser);
    _authReady = true;
    _calibrateServerTime();
    // Re-run the router guard now that both `ready` and `authed` are settled.
    notifyListeners();
  }

  /// Runs [op], retrying on any failure with a short back-off. Right after
  /// sign-in on web the first Firestore calls can fail with permission-denied
  /// until the fresh auth token propagates into the Firestore SDK; retrying a
  /// few times bridges that window so the UI doesn't need a page refresh.
  Future<T?> _retryRead<T>(Future<T> Function() op, {int tries = 6}) async {
    for (var attempt = 0; attempt < tries; attempt++) {
      try {
        return await op();
      } catch (e) {
        if (attempt == tries - 1) {
          debugPrint('hydration read failed after $tries attempts: $e');
          return null;
        }
        await Future<void>.delayed(Duration(milliseconds: 200 + attempt * 250));
      }
    }
    return null;
  }

  Future<void>? _hydrating;

  /// Loads (creating on first sign-in) the Firestore profile for [fbUser] and
  /// mirrors it into [_user], then subscribes the user-scoped live streams.
  /// Called from the auth-state listener and directly after login/register;
  /// concurrent calls for the same session are coalesced.
  Future<void> _hydrateUser(fa.User fbUser) {
    final inFlight = _hydrating;
    if (inFlight != null) return inFlight;
    final run = _doHydrateUser(fbUser).whenComplete(() => _hydrating = null);
    _hydrating = run;
    return run;
  }

  Future<void> _doHydrateUser(fa.User fbUser) async {
    try {
      // Nudge the Firestore SDK to pick up the just-issued auth token.
      try {
        await fbUser.getIdToken();
      } catch (_) {}

      await _retryRead(() => _repo.ensureUserDoc(
            uid: fbUser.uid,
            name: fbUser.displayName ?? 'Player',
            email: fbUser.email ?? '',
            starterPresets: seedPresets,
            starterChipSet: seedChipSet,
          ));
      final loaded = await _retryRead(() => _repo.loadUser(fbUser.uid));
      _user = loaded ??
          _user ?? // never downgrade an already-hydrated profile
          AppUser(
            id: fbUser.uid,
            name: fbUser.displayName ?? 'Player',
            email: fbUser.email ?? '',
            isAdmin: false,
            stats: const UserStats(
              played: 0,
              wins: 0,
              podium: 0,
              avgFinish: 0,
              knockouts: 0,
            ),
          );
      notifyListeners();
      await _loadUserPrefs(fbUser.uid);
      // Subscribe only now — after the retried reads confirm the token works —
      // so the .snapshots() streams don't immediately error out (a Firestore
      // stream that hits permission-denied is dead until re-created).
      _subscribeUserData();
    } catch (e) {
      debugPrint('AppProvider: profile hydration failed: $e');
    }
  }

  /// Restores per-user preferences (`users/{uid}.prefs`) onto local state.
  Future<void> _loadUserPrefs(String uid) async {
    if (!_backendUp) return;
    try {
      final prefs = await _repo.loadUserPrefs(uid);
      final voice = prefs['voiceEnabled'];
      if (voice is bool) _voiceEnabled = voice;
      final notify = prefs['browserNotify'];
      if (notify is bool) _notificationsEnabled = notify;
      final colorTheme = prefs['colorTheme'];
      if (colorTheme is String) _colorTheme = colorTheme;
      final themePref = prefs['themePreference'];
      if (themePref is String) _themePreference = themePref;
    } catch (e) {
      debugPrint('loadUserPrefs failed: $e');
    }
  }

  /// Fire-and-forget write of a single preference key.
  void _persistPref(String key, Object? value) {
    final uid = _repo.currentUid;
    if (!_backendUp || uid == null) return;
    unawaited(_repo
        .saveUserPref(uid, key, value)
        .catchError((Object e) => debugPrint('saveUserPref($key) failed: $e')));
  }

  /// Returns `null` on success or a friendly error message for the UI.
  Future<String?> login(String email, String password) async {
    try {
      final cred = await _repo.signIn(email, password);
      if (cred.user != null) await _hydrateUser(cred.user!);
      // Wait (bounded) for groups + the auto-selected group's bundle so the
      // dashboard is populated the moment we navigate to it.
      await userDataReady.timeout(const Duration(seconds: 8), onTimeout: () {});
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Incorrect email or password.',
        'invalid-email' => 'Enter a valid email address.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Sign-in failed. Please try again.',
      };
    }
  }

  /// Returns `null` on success or a friendly error message for the UI.
  Future<String?> register(String name, String email, String password) async {
    try {
      final cred = await _repo.signUp(
        name: name,
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await _hydrateUser(cred.user!);
        // Guarantee the chosen name is stored even if displayName propagation
        // lagged during hydration's ensureUserDoc.
        if (_user != null && _user!.name != name) {
          await _retryRead(
              () => _repo.updateUserProfile(cred.user!.uid, name: name));
          _user = _user!.copyWith(name: name);
          notifyListeners();
        }
      }
      await userDataReady.timeout(const Duration(seconds: 8), onTimeout: () {});
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'That password is too weak — use at least 8 characters.',
        'invalid-email' => 'Enter a valid email address.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Registration failed. Please try again.',
      };
    }
  }

  /// Converts the current anonymous guest session into a full account by
  /// linking credentials onto the existing uid, so stats/results recorded as
  /// a guest carry over automatically (user-flow spec §6.7). Returns `null`
  /// on success or a friendly error message for the UI.
  Future<String?> convertGuestAccount(
      String name, String email, String password) async {
    if (!_repo.isSignedInAsGuest) return 'Not a guest session.';
    try {
      final cred = await _repo.linkGuestAccount(
        name: name,
        email: email,
        password: password,
      );
      if (cred.user != null) await _hydrateUser(cred.user!);
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'email-already-in-use' ||
        'credential-already-in-use' =>
          'An account already exists for that email.',
        'weak-password' =>
          'That password is too weak — use at least 8 characters.',
        'invalid-email' => 'Enter a valid email address.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Account creation failed. Please try again.',
      };
    } on StateError {
      return 'Your session expired. Please sign in again.';
    }
  }

  /// Sends the reset email; returns `null` on success or a friendly error.
  Future<String?> requestPasswordReset(String email) async {
    try {
      await _repo.sendPasswordReset(email);
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'user-not-found' || 'invalid-credential' =>
          'No account found for that email.',
        'invalid-email' => 'Enter a valid email address.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Could not send the reset email. Please try again.',
      };
    }
  }

  /// Signs in anonymously — the entry point of the guest flow.
  Future<String?> signInAsGuest() async {
    try {
      final cred = await _repo.signInAsGuest();
      if (cred.user != null) await _hydrateUser(cred.user!);
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return e.message ?? 'Guest sign-in failed. Please try again.';
    }
  }

  /// Triggers Google Sign-In and authenticates with Firebase. Returns `null`
  /// on success, an empty string when the user cancels (caller should no-op),
  /// or a friendly error message on failure.
  Future<String?> loginWithGoogle() async {
    try {
      final cred = await _repo.signInWithGoogle();
      if (cred == null) return ''; // user cancelled — silent abort
      if (cred.user != null) await _hydrateUser(cred.user!);
      await userDataReady.timeout(const Duration(seconds: 8), onTimeout: () {});
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'account-exists-with-different-credential' =>
          'An account already exists with this email using a different sign-in method.',
        'invalid-credential' => 'Google sign-in failed. Please try again.',
        'user-disabled' => 'This account has been disabled.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Google sign-in failed. Please try again.',
      };
    } catch (e) {
      return 'Google sign-in failed. Please try again.';
    }
  }

  /// Upgrades the current anonymous guest session to a Google-linked account.
  /// Returns `null` on success, empty string on cancel, or an error message.
  Future<String?> convertGuestWithGoogle() async {
    if (!_repo.isSignedInAsGuest) return 'Not a guest session.';
    try {
      final cred = await _repo.linkGuestWithGoogle();
      if (cred == null) return ''; // user cancelled
      if (cred.user != null) await _hydrateUser(cred.user!);
      return null;
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'credential-already-in-use' ||
        'email-already-in-use' =>
          'A Google account already exists for this email.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Google sign-in failed. Please try again.',
      };
    } on StateError {
      return 'Your session expired. Please sign in again.';
    } catch (e) {
      return 'Google sign-in failed. Please try again.';
    }
  }

  Future<void> logout() async {
    // Remove current device FCM token before signing out so stale tokens
    // don't linger on the user's Firestore doc.
    try {
      final fcm = FirebaseMessaging.instance;
      final token = await fcm.getToken();
      if (token != null) {
        final uid = _repo.currentUid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'fcmTokens': FieldValue.arrayRemove([token]),
          });
        }
      }
    } catch (_) {
      // Best-effort cleanup; don't block logout on FCM errors.
    }
    await _repo.signOut();
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

  List<({String id, String name, List<ChipColor> chips})> get savedChipSets =>
      _savedChipSets;

  void saveChipSet(String id, String name, List<ChipColor> chips) {
    final idx = _savedChipSets.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _savedChipSets[idx] = (id: id, name: name, chips: chips);
    } else {
      _savedChipSets.add((id: id, name: name, chips: chips));
    }
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null && id != seedChipSet.id) {
      unawaited(_repo.saveChipSet(uid, id, name, chips)
          .catchError((Object e) => debugPrint('saveChipSet failed: $e')));
    }
  }

  void deleteChipSet(String id) {
    if (id == 'cs-default') return; // protect default
    _savedChipSets.removeWhere((c) => c.id == id);
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.deleteChipSet(uid, id)
          .catchError((Object e) => debugPrint('deleteChipSet failed: $e')));
    }
  }

  /// Updates the signed-in member's display details (profile screen) and
  /// persists them to the Firestore profile.
  void updateProfile({String? name, String? email}) {
    final current = _user;
    if (current == null) return;
    final nextName =
        name?.trim().isNotEmpty == true ? name!.trim() : current.name;
    final nextEmail =
        email?.trim().isNotEmpty == true ? email!.trim() : current.email;
    _user = current.copyWith(name: nextName, email: nextEmail);
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.updateUserProfile(uid, name: nextName, email: nextEmail)
          .catchError((Object e) => debugPrint('updateUserProfile failed: $e')));
    }
  }

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

  List<TournamentPreset> get presets => List.unmodifiable(_presets);

  TournamentPreset? presetById(String? id) {
    if (id == null) return null;
    for (final p in _presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  void savePreset(TournamentPreset preset) {
    final idx = _presets.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      _presets[idx] = preset;
    } else {
      _presets.add(preset);
    }
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.savePreset(uid, preset)
          .catchError((Object e) => debugPrint('savePreset failed: $e')));
    }
  }

  void deletePreset(String id) {
    _presets.removeWhere((p) => p.id == id);
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.deletePreset(uid, id)
          .catchError((Object e) => debugPrint('deletePreset failed: $e')));
    }
  }

  /// Suggests up to two presets that match the signals parsed from closed
  /// polls (e.g. "What buy-in?" → 15, "How long?" → 3.5h). Used by the
  /// create-tournament wizard (09-007 / 09-008 / 09-009).
  List<TournamentPreset> suggestPresets({
    required int expectedPlayers,
    List<num> pollSignals = const [],
  }) {
    if (_presets.isEmpty) return const [];

    int scoreFor(TournamentPreset p) {
      var score = 0;
      for (final s in pollSignals) {
        if (s == p.buyIn) score += 40;
        if (s == p.durationHours) score += 30;
        if ((s - p.buyIn).abs() <= 2 && s != p.buyIn) score += 10;
      }
      if (expectedPlayers >= 2 && expectedPlayers <= 10 && p.rebuys) score += 5;
      if (expectedPlayers > 10 && !p.rebuys) score += 5;
      return score;
    }

    final scored =
        _presets
            .map((p) => (preset: p, score: scoreFor(p)))
            .where((e) => e.score >= 15)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(2).map((e) => e.preset).toList();
  }

  // ── Group ──────────────────────────────────────────────────────────────────
  /// Neutral placeholder until the first group of the signed-in user is
  /// auto-selected (or the user creates/joins one).
  Group _currentGroup = _kEmptyGroup;
  Group get currentGroup => _currentGroup;

  /// Id of the selected group — set the instant a group is chosen, even before
  /// its live bundle has loaded (unlike `currentGroup.id`, which lags).
  String? get currentGroupId => _currentGroupId;

  /// True once a real group bundle is subscribed (id is non-empty).
  bool get hasCurrentGroup => _currentGroupId != null;

  /// The group whose live bundle is currently subscribed.
  String? _currentGroupId;

  /// Every group the user belongs to, rebuilt from the live index stream.
  /// Rows are lightweight (no members/chat/games) — the rich state lives in
  /// [currentGroup] via the bundle subscription.
  List<Group> _groups = const [];
  List<Group> get groups => List.unmodifiable(_groups);

  /// Groups ordered pinned-first then alphabetically (client feedback: the
  /// sidebar lists all groups, pinnable, not a single slot).
  List<Group> get orderedGroups {
    final sorted = [..._groups]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    sorted.sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
    return sorted;
  }

  /// Replaces [currentGroup] everywhere it lives so the sidebar list and the
  /// group hub always reflect the same state.
  void _setGroup(Group group) {
    _currentGroup = group;
    final i = _groups.indexWhere((g) => g.id == group.id);
    _groups = i == -1 ? [..._groups, group] : ([..._groups]..[i] = group);
  }

  /// Selects the group hub target and subscribes its live Firestore bundle.
  void setCurrentGroup(Group group) => _selectGroup(group.id);

  /// Joins a group by its invite code. Returns false when the code is
  /// unknown or the request failed.
  Future<bool> joinGroup(String code) async {
    final user = _user;
    if (!_backendUp || user == null) return false;
    try {
      final gid = await _repo.joinByCode(code, user);
      if (gid == null) return false;
      _subscribeUserData(); // refresh the index with the new row promptly
      _selectGroup(gid);
      notifyListeners();
      // Wait for the group's live bundle (members, games, chat, polls,
      // settings) so the caller navigates into a fully-populated hub that then
      // keeps updating in real time — not an empty shell.
      await groupReady.timeout(const Duration(seconds: 10), onTimeout: () {});
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('joinGroup failed: $e');
      return false;
    }
  }

  /// Creates a new group with this account as owner. Returns null when the
  /// caller is unauthenticated or the write failed.
  Future<Group?> createGroup(String name, {String icon = '♠️'}) async {
    final user = _user;
    if (!_backendUp || user == null) return null;
    final group = Group(
      id: 'grp-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      joinCode: Formatters.generateCode(),
      ownerId: user.id,
      members: [user],
      games: const [],
      chat: const [],
      polls: const [],
      notifications: const [],
      icon: icon,
    );
    try {
      await _repo.createGroup(group, user);
    } catch (e) {
      debugPrint('createGroup failed: $e');
      return null;
    }
    _subscribeUserData();
    _selectGroup(group.id);
    notifyListeners();
    return group;
  }

  /// Pins/unpins a group so it floats to the top of the sidebar's group list.
  void togglePinGroup(Group group) {
    _setGroup(group.copyWith(pinned: !group.pinned));
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo
          .updateGroupIndex(uid, group.id, pinned: !group.pinned)
          .catchError((Object e) =>
              debugPrint('updateGroupIndex(pinned) failed: $e')));
    }
  }

  /// Owner-only: sets a member's role (Member / Co-Admin / Admin). Co-Admin
  /// can add members directly and grant rebuys; only Admin (or the owner)
  /// can advance the tournament or touch blinds/seating settings.
  void setGroupRole(String userId, GroupRole role) {
    if (_user?.id != _currentGroup.ownerId) return; // Only owner can do this
    if (userId == _currentGroup.ownerId) return; // Cannot change owner's role
    final members = _currentGroup.members.map((m) {
      if (m.id != userId) return m;
      return m.copyWith(
        isAdmin: role == GroupRole.admin,
        isCoAdmin: role == GroupRole.coAdmin,
      );
    }).toList();
    _setGroup(_currentGroup.copyWith(members: members));
    notifyListeners();
    if (_backendUp) {
      unawaited(_repo
          .setMemberRole(_currentGroup.id, userId, role.storageValue)
          .catchError(
              (Object e) => debugPrint('setMemberRole failed: $e')));
    }
  }

  /// Host/Admin or Co-Admin: adds a registered user directly to the group by
  /// email, without going through an invite link/QR/join code. Returns null
  /// on success, or a friendly error message for the UI.
  Future<String?> addMemberByEmail(String email) async {
    if (!canManageMembers) return 'Only the Host can add members.';
    if (!_backendUp) return 'You are offline.';
    final trimmed = email.trim();
    if (trimmed.isEmpty) return 'Enter an email address.';
    AppUser? found;
    try {
      found = await _repo.findUserByEmail(trimmed);
    } catch (e) {
      debugPrint('findUserByEmail failed: $e');
      return 'Could not look up that email. Please try again.';
    }
    if (found == null) {
      return 'No account found for that email. Ask them to sign up '
          '(or open the app once) first, then try again.';
    }
    if (found.id == _user?.id) {
      return "You're already in this group.";
    }
    if (_currentGroup.members.any((m) => m.id == found!.id)) {
      return '${found.name.isEmpty ? 'That user' : found.name} is already in this group.';
    }
    try {
      await _repo.addMemberToGroup(
        _currentGroup.id,
        found,
        groupName: _currentGroup.name,
        groupIcon: _currentGroup.icon,
      );
    } catch (e) {
      debugPrint('addMemberByEmail failed: $e');
      return 'Could not add that member. Please try again.';
    }
    return null;
  }

  /// Owner-only: updates the group's default table-capacity/randomization
  /// settings. Individual tournaments may still override this
  /// ([updateTournamentTableSettings]).
  void updateGroupTableSettings(TableSettings settings) {
    if (_user?.id != _currentGroup.ownerId) return;
    _setGroup(_currentGroup.copyWith(tableSettings: settings));
    notifyListeners();
    if (_backendUp) {
      unawaited(_repo
          .updateGroupTableSettings(_currentGroup.id, settings)
          .catchError((Object e) =>
              debugPrint('updateGroupTableSettings failed: $e')));
    }
  }

  /// The table-capacity/randomization rules that actually apply to the
  /// active tournament: its own override if set, otherwise the group
  /// default.
  TableSettings get effectiveTableSettings =>
      _currentGame?.settings.tableSettingsOverride ??
      _currentGroup.tableSettings;

  /// Admin-only: sets (or clears, passing null) this tournament's override of
  /// the group's default table settings.
  void updateTournamentTableSettings(TableSettings? override) {
    final game = _currentGame;
    if (game == null || !isAdmin) return;
    _currentGame = game.copyWith(
      settings: game.settings.copyWith(
        tableSettingsOverride: override,
        clearTableSettingsOverride: override == null,
      ),
    );
    _syncGroupGame();
    notifyListeners();
  }

  /// Owner-only: removes a member from the current group.
  void removeMember(String userId) {
    if (_user?.id != _currentGroup.ownerId) return;
    if (userId == _currentGroup.ownerId) return;
    final members =
        _currentGroup.members.where((m) => m.id != userId).toList();
    _setGroup(_currentGroup.copyWith(members: members));
    notifyListeners();
    if (_backendUp) {
      unawaited(_repo
          .deleteMember(_currentGroup.id, userId)
          .catchError(
              (Object e) => debugPrint('deleteMember failed: $e')));
    }
  }

  /// Non-owner members may leave a group voluntarily.
  void leaveGroup() {
    final userId = _user?.id;
    if (userId == null || userId == _currentGroup.ownerId) return;
    final leftGid = _currentGroup.id;
    if (_backendUp && leftGid.isNotEmpty) {
      unawaited(_repo
          .deleteMember(leftGid, userId)
          .catchError(
              (Object e) => debugPrint('leaveGroup deleteMember failed: $e')));
    }
    // Drop the left group locally and switch the hub to another group (or an
    // empty state) straight away, tearing down its now-inaccessible bundle.
    _bundleSub?.cancel();
    _bundleSub = null;
    _cashSub?.cancel();
    _cashSub = null;
    _currentGroupId = null;
    _bundleLoaded = false;
    _bundleReady = null;
    _groups = _groups.where((g) => g.id != leftGid).toList();
    final next = orderedGroups.firstOrNull;
    if (next != null) {
      _selectGroup(next.id);
    } else {
      _currentGroup = _kEmptyGroup;
    }
    notifyListeners();
  }

  // ── Game ───────────────────────────────────────────────────────────────────
  LiveGame? _currentGame;
  LiveGame? get currentGame => _currentGame;

  // Undo stack (checklist 12-042/12-043/12-044, technical §11.3). Before every
  // admin mutation we snapshot the previous game; undo pops and restores it.
  static const int _maxUndoDepth = 30;
  final List<LiveGame?> _undoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;

  /// Human-readable description of the most recent reversible action, used
  /// by the Undo confirmation ("Undo shows the action that will be reversed"
  /// — User Flow spec §12.6).
  String? get lastActionSummary {
    final history = _currentGame?.auditHistory;
    if (history == null || history.isEmpty) return null;
    return history.last.details;
  }

  /// Pending seat-balance recommendation (checklist §13.2), if any.
  SeatMoveRecommendation? _pendingSeatMove;

  void _pushUndo() {
    if (_currentGame == null) return;
    if (_undoStack.length >= _maxUndoDepth) _undoStack.removeAt(0);
    _undoStack.add(_currentGame);
  }

  void _clearUndoStack() {
    _undoStack.clear();
  }

  void setCurrentGame(LiveGame game) {
    _clearUndoStack();
    _currentGame = game;
    notifyListeners();
  }

  /// Resolves a game (live or past) by id from the group's synced list,
  /// falling back to the current active game (checklist 16-007).
  LiveGame? gameById(String id) {
    for (final g in _currentGroup.games) {
      if (g.id == id) return g;
    }
    return _currentGame?.id == id ? _currentGame : null;
  }

  LiveGame createGame(GameSettings settings) {
    // Client flow: creating an event does NOT generate the structure. The AI
    // finalises stacks/blinds/levels when the Admin taps "Generate Final
    // Structure" during check-in, using confirmed attendance.
    // Until then the structure stays empty.
    final structure = const TournamentStructure(
      startingStack: 0,
      chipPlan: [],
      rebuyStack: 0,
      rebuyChipPlan: [],
      addOnStack: 0,
      addOnChipPlan: [],
      levels: [],
      levelDuration: 15,
      expectedFinishMins: 0,
      prizes: [],
      prizePool: 0,
      organizerAmount: 0,
      colorUpInstructions: [],
      warnings: [],
    );
    // Seed participants from the group roster so the RSVP and check-in
    // screens list the real members. Guest seats appear as guest slots when
    // members answer Going +N — no placeholder players are invented.
    final seeded = [
      for (final member in _currentGroup.members)
        Player(
          id: member.id,
          name: member.name,
          isGuest: false,
          rsvp: null,
          checkedIn: false,
          confirmed: false,
          eliminated: false,
          rebuys: 0,
          hasAddOn: false,
          knockouts: 0,
          table: 0,
          seat: 0,
          active: true,
        ),
    ];
    final game = LiveGame(
      id: 'game-${DateTime.now().millisecondsSinceEpoch}',
      groupId: _currentGroup.id,
      settings: settings,
      structure: structure,
      status: LiveGameStatus.draft,
      publicCode: Formatters.generateCode(),
      tvCode: Formatters.generateCode(),
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: structure.levelDuration * 60,
      players: seeded,
      chat: const [],
      announcements: const [],
      totalChipsInPlay: structure.startingStack * seeded.length,
      pendingGuests: const [],
      finishOrder: const [],
      speedRecommendation: null,
    );
    _clearUndoStack();
    _currentGame = game;
    _syncGroupGame();
    notifyListeners();
    return game;
  }

  /// Keeps the group's copy of the current game in sync so the hub's upcoming
  /// list and history (12-090) reflect the live game's latest status. When the
  /// game does not exist yet on the group it is appended.
  void _syncGroupGame() {
    final game = _currentGame;
    if (game == null) return;
    _lastGameUpdate = DateTime.now();
    final games = _currentGroup.games;
    final idx = games.indexWhere((g) => g.id == game.id);
    _setGroup(
      _currentGroup.copyWith(
        games: idx == -1 ? [...games, game] : ([...games]..[idx] = game),
      ),
    );
  }

  void updateGameStatus(LiveGameStatus status) {
    final wasPublished = _currentGame?.status == LiveGameStatus.published;
    _currentGame = _currentGame!.copyWith(status: status);
    // Client feedback (07-018): inside the 30-minute window before start the
    // AI refreshes the stacks/blinds/levels estimate from the expected count.
    if (status == LiveGameStatus.checkin) generateFinalStructure(currentGame!.confirmedCount);
    if (status == LiveGameStatus.checkin && wasPublished) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Check-in opened',
          body:
              '${_currentGame!.settings.name} — you can check in now. Seats are assigned after the host confirms.',
          type: NotificationType.game,
          link: '/invitation',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
    _syncGroupGame();
    notifyListeners();
  }

  /// Cancels the tournament. Requires a reason: it is recorded in the audit
  /// log and members are notified (spec §12, checklist 10-042). Blocking —
  /// once cancelled the game cannot be started again.
  void cancelGame(String reason) {
    final game = _currentGame;
    if (game == null || _user == null) return;
    if (game.status == LiveGameStatus.completed ||
        game.status == LiveGameStatus.cancelled) {
      return;
    }
    _pushUndo();
    _ticker?.cancel();
    _currentGame = game.copyWith(
      status: LiveGameStatus.cancelled,
      timerRunning: false,
    );
    _syncGroupGame();
    addAuditRecord(
      'cancel',
      'Cancelled ${game.settings.name}. Reason: ${reason.trim().isEmpty ? 'Not provided' : reason.trim()}',
    );
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Tournament cancelled',
        body: '${game.settings.name} has been cancelled.',
        type: NotificationType.game,
        link: '/invitation',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
    addAnnouncement('${game.settings.name} has been cancelled.', true);
    notifyListeners();
  }

  /// Publishes the tournament (checklist §4.3): the game opens for RSVP, a
  /// pinned event card is posted to the group chat, every member is notified,
  /// and the published structure is snapshotted for the §12.4 live diff.
  void publishGame() {
    final game = _currentGame;
    if (game == null || _user == null) return;
    _pushUndo();

    final anteText = game.settings.anteEnabled
        ? 'Ante: L${game.settings.anteAfterLevel}+'
        : 'No ante';
    final rebuyText = game.settings.rebuysCloseLevel > 0
        ? 'Rebuys: until L${game.settings.rebuysCloseLevel}'
        : 'No rebuys';
    final addonText = game.settings.addOn ? 'Add-on: Yes' : 'No add-on';

    final card = ChatMessage(
      id: 'pinned-${DateTime.now().millisecondsSinceEpoch}',
      authorId: _user!.id,
      authorName: _user!.name,
      body:
          '${game.settings.name} — ${game.settings.date} at ${game.settings.time}\n'
          'Buy-in: ${game.settings.buyIn} · Code: ${game.publicCode}\n'
          '$anteText · $rebuyText · $addonText',
      timestamp: DateTime.now(),
      deleted: false,
      pinned: true,
      gameId: game.id,
    );
    _currentGame = game.copyWith(
      status: LiveGameStatus.published,
      chat: [...game.chat, card],
      originalLevels: List.of(game.structure.levels),
    );
    _setGroup(
      _currentGroup.copyWith(
        chat: [..._currentGroup.chat, card],
        games: _currentGroup.games
            .map(
              (g) => g.id == game.id
                  ? g.copyWith(
                      status: LiveGameStatus.published,
                      chat: [...g.chat, card],
                      originalLevels: List.of(game.structure.levels),
                    )
                  : g,
            )
            .toList(),
      ),
    );
    _postGroupChat(card);
    _syncGroupGame();
    addAuditRecord(
      'publish',
      'Published ${game.settings.name} '
          '(${game.settings.date} ${game.settings.time}) for RSVP.',
    );
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'New game published',
        body:
            '${game.settings.name} is open for RSVP — '
            '${game.settings.date} at ${game.settings.time}.',
        type: NotificationType.game,
        link: '/invitation',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
    addAnnouncement('${game.settings.name} is now open for RSVP.', true);
    notifyListeners();
  }

  /// Admin edits an already-created event's details. Records an audit entry,
  /// notifies members, and re-generates the structure when the field change
  /// would affect it (checklist §10.4). RSVP validity is surfaced in the audit.
  void updateEventSettings(GameSettings next, {bool clearRsvps = false}) {
    final game = _currentGame;
    if (game == null || _user == null) return;
    final prev = game.settings;
    if (prev == next) return;
    _pushUndo();

    var s = next;
    // The structure only depends on players, buy-in, duration and ante rules;
    // cosmetic fields (name/date/time/location/privacy) keep the structure.
    final affectsStructure =
        prev.players != s.players ||
        prev.buyIn != s.buyIn ||
        prev.durationHours != s.durationHours ||
        prev.anteEnabled != s.anteEnabled ||
        prev.anteAfterLevel != s.anteAfterLevel ||
        prev.anteStyle != s.anteStyle ||
        prev.koEnabled != s.koEnabled ||
        prev.koAmount != s.koAmount ||
        prev.rebuys != s.rebuys ||
        prev.rebuysCloseLevel != s.rebuysCloseLevel ||
        prev.reEntry != s.reEntry ||
        prev.addOn != s.addOn ||
        prev.addOnCloseLevel != s.addOnCloseLevel;

    final edits = <String>[];
    if (prev.name != s.name) edits.add('name → ${s.name}');
    if (prev.date != s.date) edits.add('date → ${s.date}');
    if (prev.time != s.time) edits.add('time → ${s.time}');
    if (prev.location != s.location) {
      edits.add('location ${s.locationPrivate ? '(private) ' : ''}updated');
    }
    if (prev.buyIn != s.buyIn) edits.add('buy-in → ${s.buyIn}');
    if (prev.locationPrivate != s.locationPrivate) {
      edits.add(s.locationPrivate ? 'address hidden' : 'address visible');
    }

    if (affectsStructure) {
      if (game.structure.levels.isEmpty && !(game.status == LiveGameStatus.ready)) {
        _currentGame = game.copyWith(
          settings: s,
          players: clearRsvps
              ? game.players.map((p) => p.copyWithClearRsvp()).toList()
              : game.players,
        );
        edits.add('settings saved (structure deferred)');
      } else {
        var structure = TournamentEngine.generate(
          TournamentParams(
            players: s.players,
            durationHours: s.durationHours,
            buyIn: s.buyIn,
            chipSet: s.chipSet,
            rebuys: s.rebuys,
            rebuysCloseLevel: s.rebuysCloseLevel,
            reEntry: s.reEntry,
            addOn: s.addOn,
            anteEnabled: s.anteEnabled,
            anteAfterLevel: s.anteAfterLevel,
            anteStyle: s.anteStyle,
            koEnabled: s.koEnabled,
            koAmount: s.koAmount,
            organizerPct: s.organizerPct,
            rebuyCost: s.rebuyCost,
            addOnCost: s.addOnCost,
          ),
        );
        // After play starts the starting stacks are frozen (client rule).
        if (game.stacksLocked) {
          structure = structure.copyWith(
            startingStack: game.structure.startingStack,
            chipPlan: game.structure.chipPlan,
            rebuyStack: game.structure.rebuyStack,
            rebuyChipPlan: game.structure.rebuyChipPlan,
            addOnStack: game.structure.addOnStack,
            addOnChipPlan: game.structure.addOnChipPlan,
          );
        }
        _currentGame = game.copyWith(
          settings: s,
          structure: structure,
          secondsRemaining: structure.levelDuration * 60,
          speedRecommendation: null,
          players: clearRsvps
              ? game.players.map((p) => p.copyWithClearRsvp()).toList()
              : game.players,
        );
        edits.add('structure regenerated');
      }
    } else {
      _currentGame = game.copyWith(
        settings: s,
        players: clearRsvps
            ? game.players.map((p) => p.copyWithClearRsvp()).toList()
            : game.players,
      );
    }

    // §10.4: persist a visible change timeline on the event record so every
    // member sees what moved without digging through chat history.
    if (edits.isNotEmpty) {
      final stamp = DateTime.now().toString().substring(0, 16);
      var log = [...game.changeLog, ...edits.map((e) => '$stamp · $e')];
      if (log.length > 12) log = log.sublist(log.length - 12);
      _currentGame = _currentGame!.copyWith(changeLog: log);
      _postUpdatedEventCard(log.last, s);
    }

    _syncGroupGame();
    addAuditRecord('event_edit', 'Event updated: ${edits.join('; ')}.');
    if (edits.isNotEmpty) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Event updated',
          body: '${s.name} — ${edits.take(2).join('; ')}.',
          type: NotificationType.game,
          link: '/invitation',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
    addAnnouncement('Event details updated.', false);
    notifyListeners();
  }

  /// Reposts the pinned event card after a published-event edit (User Flow
  /// §10.4 "Mark important changes in the pinned chat card"). The card uses
  /// the exact format of [publishGame]'s announcement card and appends an
  /// "Updated:" line carrying the newest change-log entry. Posted to both the
  /// game chat list and the group chat list, with cloud persistence mirroring
  /// the publish path. Only called when a change-log entry was produced.
  void _postUpdatedEventCard(String newestChangeLogEntry, GameSettings s) {
    final game = _currentGame;
    if (game == null || _user == null) return;
    final anteText = s.anteEnabled
        ? 'Ante: L${s.anteAfterLevel}+'
        : 'No ante';
    final rebuyText = s.rebuysCloseLevel > 0
        ? 'Rebuys: until L${s.rebuysCloseLevel}'
        : 'No rebuys';
    final addonText = s.addOn ? 'Add-on: Yes' : 'No add-on';
    final card = ChatMessage(
      id: 'pinned-${DateTime.now().millisecondsSinceEpoch}',
      authorId: _user!.id,
      authorName: _user!.name,
      body:
          '${s.name} — ${s.date} at ${s.time}\n'
          'Buy-in: ${s.buyIn} · Code: ${game.publicCode}\n'
          '$anteText · $rebuyText · $addonText\n'
          'Updated: $newestChangeLogEntry',
      timestamp: DateTime.now(),
      deleted: false,
      pinned: true,
      gameId: game.id,
    );
    _currentGame = game.copyWith(chat: [...game.chat, card]);
    _setGroup(
      _currentGroup.copyWith(chat: [..._currentGroup.chat, card]),
    );
    _postGroupChat(card);
  }

  /// Records that the end-of-rebuy settlement has been confirmed. From this
  /// point the public label reads "Prize Pool" instead of "Estimated Prize
  /// Pool" (12-068, 14-038/14-039, 15-009, 15-030), and no more rebuys,
  /// re-entries or add-ons are possible (12-065).
  /// Computes the *final* prize distribution from the actual contributions
  /// recorded at the end of the rebuy level (client rule: prices are only
  /// calculated there — exact field size, actual rebuys and the selected
  /// add-ons). [addOnCount] is the number of add-ons taken at settlement.
  ({int organizerAmount, int prizePool, List<Prize> prizes})
  previewSettlementPrizes(int addOnCount) {
    final game = _currentGame;
    if (game == null) {
      return (organizerAmount: 0, prizePool: 0, prizes: const []);
    }
    final s = game.settings;
    final participants = game.players
        .where((p) => p.confirmed || p.checkedIn)
        .length;
    final rebuys = game.players.fold<int>(0, (sum, p) => sum + p.rebuys);
    final reEntries = game.players.fold<int>(0, (sum, p) => sum + p.reEntries);
    final addOns = game.players.where((p) => p.hasAddOn).length + addOnCount;
    final gross =
        s.buyIn * participants +
        s.effectiveRebuyCost * rebuys +
        s.buyIn * reEntries +
        s.effectiveAddOnCost * addOns;
    return TournamentEngine.recalculatePrizes(
      gross,
      participants,
      s.organizerPct.toDouble(),
      forcePaidPlaces: s.forcePaidPlaces,
    );
  }

  void confirmSettlement() {
    final game = _currentGame;
    if (game == null) return;
    final finalPrizes = previewSettlementPrizes(0);
    _currentGame = game.copyWith(
      settlementConfirmed: true,
      pendingGuests: const [],
      structure: game.structure.copyWith(
        organizerAmount: finalPrizes.organizerAmount,
        prizePool: finalPrizes.prizePool,
        prizes: finalPrizes.prizes,
      ),
    );
    _syncGroupGame();
    addAuditRecord(
      'settlement',
      'Rebuy/add-on break settled. Final prize pool: ${finalPrizes.prizePool}.',
    );
    addAnnouncement('Prize pool confirmed: ${finalPrizes.prizePool}.', true);
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Prize Pool confirmed',
        body:
            '${game.settings.name} — final prize pool: ${finalPrizes.prizePool}.',
        type: NotificationType.game,
        link: '/player-live',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────
  Timer? _ticker;
  Timer? _serverTimeRecalibration;

  /// Marks already announced per level (checklist 15-047/15-048) so the
  /// five-minute and one-minute warnings fire only once per level.
  final Set<String> _levelAnnouncementMarks = <String>{};

  void _announceLevelMark(int remaining) {
    final game = _currentGame;
    if (game == null || !game.timerRunning) return;
    final level = game.currentLevel;
    final mark = '$level';
    if (remaining <= 300 &&
        remaining > 60 &&
        !_levelAnnouncementMarks.contains('$mark:300')) {
      _levelAnnouncementMarks.add('$mark:300');
      addAnnouncement('Five minutes remaining in level $level.', true);
    }
    if (remaining <= 60 &&
        remaining > 0 &&
        !_levelAnnouncementMarks.contains('$mark:60')) {
      _levelAnnouncementMarks.add('$mark:60');
      addAnnouncement('One minute remaining in level $level.', true);
    }
  }

  void _startTick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentGame == null || !_currentGame!.timerRunning) return;
      int remaining;
      if (_currentGame!.levelEndTime != null) {
        remaining = _currentGame!.levelEndTime!
            .difference(_serverNow)
            .inSeconds;
      } else {
        remaining = _currentGame!.secondsRemaining - 1;
      }
      if (remaining <= 0) {
        final atRebuyClose =
            _currentGame!.settings.rebuys &&
            _currentGame!.currentLevel ==
                _currentGame!.settings.rebuysCloseLevel;
        _currentGame = _currentGame!.copyWith(
          secondsRemaining: 0,
          timerRunning: false,
          status: atRebuyClose
              ? LiveGameStatus.rebuypause
              : _currentGame!.status,
        );
        addAnnouncement(
          atRebuyClose
              ? 'Rebuys are now closed. Add-ons are available.'
              : 'Level ${_currentGame!.currentLevel} has ended.',
        );
        if (atRebuyClose) {
          pushNotification(
            AppNotification(
              id: 'n-${DateTime.now().millisecondsSinceEpoch}',
              title: 'Rebuys closed',
              body:
                  '${_currentGame!.settings.name} — rebuy period ended. Settlement required.',
              type: NotificationType.game,
              link: '/rebuy-settlement',
              read: false,
              timestamp: DateTime.now(),
            ),
          );
        }
        _evaluateSpeedRecommendation();
        return;
      }
      _announceLevelMark(remaining);
      _currentGame = _currentGame!.copyWith(secondsRemaining: remaining);
      _isTickUpdate = true;
      notifyListeners();
      _isTickUpdate = false;
    });
  }

  /// Estimated minutes still to play from now, minus the minutes the target
  /// schedule still allows (technical §11.4). Positive drift means the
  /// tournament is running long; negative means it is running short. Returns
  /// 0 when no meaningful estimate exists (game not live yet, already over,
  /// or fewer than two players).
  ///
  /// Estimate: remaining levels' durations scaled by a pace factor of expected
  /// remaining field / actual remaining field (clamped 0.5..2.0). Target:
  /// settings.durationHours * 60 minus elapsed playing time (summed completed
  /// level durations plus the consumed part of the current level).
  int estimatedFinishDriftMinutes() {
    final game = _currentGame;
    if (game == null || !game.status.isActiveLive) return 0;
    if (game.players.length < 2) return 0;
    final levels = game.structure.levels;
    // Elapsed playing time: completed levels plus the consumed seconds of the
    // current level.
    var elapsedMins = 0.0;
    for (var i = 0; i < game.currentLevel - 1 && i < levels.length; i++) {
      elapsedMins += levels[i].durationMins;
    }
    final currentLevelData = game.currentLevelData;
    final currentDurationMins =
        currentLevelData?.durationMins ?? game.structure.levelDuration;
    final consumedSeconds =
        currentDurationMins * 60 - game.currentSecondsRemaining();
    elapsedMins += consumedSeconds.clamp(0, currentDurationMins * 60) / 60.0;
    // Remaining scheduled work: future levels only.
    var remainingLevelsMins = 0;
    for (var i = game.currentLevel; i < levels.length; i++) {
      remainingLevelsMins += levels[i].durationMins;
    }
    // Pace factor: how the actual remaining field compares with the expected
    // one (clamped so extreme fields cannot produce absurd estimates).
    final expectedRemaining = game.settings.players;
    final actualRemaining = game.activePlayers.length;
    if (actualRemaining < 1 || expectedRemaining < 1) return 0;
    final paceFactor =
        (expectedRemaining / actualRemaining).clamp(0.5, 2.0);
    final estimateMins = remainingLevelsMins * paceFactor;
    final targetRemainingMins =
        game.settings.durationHours * 60 - elapsedMins;
    return (estimateMins - targetRemainingMins).round();
  }

  /// Live recommendation (technical §11.4): if the estimated finish differs
  /// from the target by more than 20 minutes, offer a recommendation. Running
  /// long suggests speeding up future levels; running short suggests slowing
  /// them down. Never auto-mutates the structure and is cleared again on
  /// nextLevel/previousLevel/restart.
  void _evaluateSpeedRecommendation() {
    final game = _currentGame;
    if (game == null || game.status != LiveGameStatus.running) return;
    if (game.players.length < 2) return;
    final drift = estimatedFinishDriftMinutes();
    SpeedRecommendation? rec;
    if (drift > 20) {
      rec = SpeedRecommendation.speedUp;
    } else if (drift < -20) {
      rec = SpeedRecommendation.slowDown;
    }
    if (rec == game.speedRecommendation) return;
    _currentGame = game.copyWith(speedRecommendation: rec);
    notifyListeners();
  }

  /// Manually forces recalculation of finish time/speed recommendations.
  void forceEvaluateSpeedRecommendation() {
    _evaluateSpeedRecommendation();
    addAnnouncement('Recalculated speed recommendation.', false);
  }

  /// Used to derive server-authoritative timer from Firestore server time.
  Duration? _serverTimeOffset;

  /// The calibrated offset between local device time and server truth.
  Duration get serverTimeOffset => _serverTimeOffset ?? Duration.zero;

  /// Calibrates the local-to-server time offset using a Firestore write/read
  /// round-trip. Call once on startup and periodically to keep drift minimal.
  Future<void> _calibrateServerTime() async {
    if (!_backendUp) return;
    try {
      final before = DateTime.now();
      final ref = _repo.serverTimeRef;
      await ref.set({'t': FieldValue.serverTimestamp()});
      final snap = await ref.get();
      final serverTs = snap.data()?['t'];
      final after = DateTime.now();
      if (serverTs != null) {
        final serverDt = (serverTs as dynamic).toDate() as DateTime;
        final mid = before.add(after.difference(before) ~/ 2);
        _serverTimeOffset = serverDt.difference(mid);
      }
    } catch (_) {
      // Ignore — fallback to local time
    }
  }

  /// Returns the current server-authoritative time, falling back to local time
  /// if calibration hasn't completed.
  DateTime get _serverNow =>
      DateTime.now().add(_serverTimeOffset ?? Duration.zero);

  /// Starts periodic server-time re-calibration (tech spec §4.3). During a
  /// long tournament the local clock can drift; re-calibrating every 10 minutes
  /// keeps the timer display accurate across all connected devices.
  void _startServerTimeRecalibration() {
    _serverTimeRecalibration?.cancel();
    _serverTimeRecalibration = Timer.periodic(
      const Duration(minutes: 10),
      (_) => _calibrateServerTime(),
    );
  }

  void startTimer() {
    // Client rule: no guessed player count at setup — the AI finalises the
    // stacks/blinds/levels right now, from the actual final headcount
    // (checked-in players if any confirmed, otherwise final RSVPs), the
    // moment the admin presses Start. This supersedes whatever estimate the
    // 30-minute pre-start window may have already shown.
    recalculateStructure();
    _currentGame = _currentGame!.copyWith(structureConfirmed: true);
    addAuditRecord(
      'structure_final',
      'Structure finalised at start for ${_currentGame!.settings.players} '
          'players: stack ${_currentGame!.structure.startingStack}, '
          '${_currentGame!.structure.levels.length} levels.',
    );

    _levelAnnouncementMarks.clear();
    // Re-calibrate server time and start periodic re-calibration for long
    // tournaments (tech spec §4.3).
    _calibrateServerTime();
    _startServerTimeRecalibration();
    final level = _currentGame!.currentLevelData;
    _currentGame = _currentGame!.copyWith(
      timerRunning: true,
      status: LiveGameStatus.running,
      levelEndTime: _serverNow.add(
        Duration(seconds: _currentGame!.secondsRemaining),
      ),
    );
    addAnnouncement(
      'Tournament starts. Level ${_currentGame!.currentLevel}. '
      'Blinds ${level?.sb ?? 0} and ${level?.bb ?? 0}.',
      true,
    );
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Tournament starting',
        body: '${_currentGame!.settings.name} is live now.',
        type: NotificationType.game,
        link: '/player-live',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void pauseTimer() {
    _currentGame = _currentGame!.copyWith(
      timerRunning: false,
      status: LiveGameStatus.paused,
      secondsRemaining: _currentGame!.currentSecondsRemaining(),
      levelEndTime: null,
    );
    notifyListeners();
  }

  void resumeTimer() {
    _currentGame = _currentGame!.copyWith(
      timerRunning: true,
      status: LiveGameStatus.running,
      levelEndTime: _serverNow.add(
        Duration(seconds: _currentGame!.secondsRemaining),
      ),
    );
    notifyListeners();
  }

  void nextLevel() {
    final next = _currentGame!.currentLevel + 1;
    if (next > _currentGame!.structure.levels.length) return;
    _pushUndo();
    _levelAnnouncementMarks.clear();
    final level = _currentGame!.structure.levels[next - 1];
    // Auto-trigger rebuy pause when crossing rebuysCloseLevel (spec §1, §12 A12)
    final wasBelowRebuyClose =
        _currentGame!.currentLevel < _currentGame!.settings.rebuysCloseLevel;
    final nowAtOrAboveRebuyClose =
        next >= _currentGame!.settings.rebuysCloseLevel;
    final shouldPauseRebuy =
        _currentGame!.settings.rebuys &&
        wasBelowRebuyClose &&
        nowAtOrAboveRebuyClose;
    if (shouldPauseRebuy) {
      _currentGame = _currentGame!.copyWith(
        currentLevel: next,
        secondsRemaining: level.durationMins * 60,
        timerRunning: false,
        status: LiveGameStatus.rebuypause,
        speedRecommendation: null,
        levelEndTime: null,
      );
      addAnnouncement(
        'Rebuys are now closed. Add-ons are available.',
        true,
      );
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Rebuys closed',
          body:
              '${_currentGame!.settings.name} — rebuy period ended. Settlement required.',
          type: NotificationType.game,
          link: '/rebuy-settlement',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    } else {
      _currentGame = _currentGame!.copyWith(
        currentLevel: next,
        secondsRemaining: level.durationMins * 60,
        timerRunning: true,
        status: LiveGameStatus.running,
        speedRecommendation: null,
        levelEndTime: _serverNow.add(Duration(minutes: level.durationMins)),
      );
      addAnnouncement(
        'Level $next. Blinds ${level.sb} and ${level.bb}'
        '${level.ante != null ? ', ante ${level.ante}' : ''}.',
        true,
      );
    }
  }

  /// Rewinds to the previous level (spec §12 "Previous" control). The clock
  /// resets to the full previous-level duration and the game resumes running.
  void previousLevel() {
    final prev = _currentGame!.currentLevel - 1;
    if (prev < 1) return;
    _pushUndo();
    _levelAnnouncementMarks.clear();
    final level = _currentGame!.structure.levels[prev - 1];
    _currentGame = _currentGame!.copyWith(
      currentLevel: prev,
      secondsRemaining: level.durationMins * 60,
      timerRunning: true,
      status: LiveGameStatus.running,
      speedRecommendation: null,
      levelEndTime: _serverNow.add(Duration(minutes: level.durationMins)),
    );
    addAnnouncement(
      'Level $prev. Blinds ${level.sb} and ${level.bb}'
      '${level.ante != null ? ', ante ${level.ante}' : ''}.',
      true,
    );
  }

  /// Restarts the clock for the current level (spec §12: requires
  /// confirmation showing its exact effect — the admin UI gates this behind a
  /// confirm dialog). Resets to the full level duration and resumes running.
  void restartLevel() {
    final game = _currentGame;
    if (game == null) return;
    if (game.status != LiveGameStatus.running &&
        game.status != LiveGameStatus.paused) {
      return;
    }
    _pushUndo();
    _levelAnnouncementMarks.clear();
    final level = game.currentLevelData;
    final durationMins = level?.durationMins ?? game.structure.levelDuration;
    _currentGame = game.copyWith(
      secondsRemaining: durationMins * 60,
      timerRunning: true,
      status: LiveGameStatus.running,
      speedRecommendation: null,
      levelEndTime: _serverNow.add(Duration(minutes: durationMins)),
    );
    _syncGroupGame();
    addAuditRecord(
      'restart-level',
      'Restarted level ${game.currentLevel} (blinds ${level?.sb ?? 0}/${level?.bb ?? 0}).',
    );
    addAnnouncement('Level ${game.currentLevel} restarted.', true);
    notifyListeners();
  }

  // ── Player management ──────────────────────────────────────────────────────
  void eliminatePlayer(String playerId, {String? koRecipientId}) {
    _pushUndo();
    final active = _currentGame!.players
        .where((p) => p.active && !p.eliminated)
        .toList();
    final pos = active.length;
    final bounty = _currentGame!.settings.koEnabled
        ? _currentGame!.settings.koAmount
        : 0;
    final updated = _currentGame!.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(eliminated: true, active: false, eliminationPos: pos);
      }
      // Optional single knockout recipient (technical §11.3). The bounty
      // chips transfer from the eliminated player, so total chips in play
      // is unchanged — only the recipient's knockout count increases.
      if (koRecipientId != null && p.id == koRecipientId) {
        return p.copyWith(knockouts: p.knockouts + 1);
      }
      return p;
    }).toList();
    final remaining = updated.where((p) => p.active).length;
    final maxPerTable = effectiveTableSettings.maxPerTable;
    // Final table redraw only fires for multi-table events (spec §7 and BR-020: "If a
    // multi-table event hits <= 9 players, a complete random redraw occurs.
    // Single table events do NOT trigger a redraw.").
    final multiTableEvent = _currentGame!.confirmedCount > maxPerTable;
    final redrawNotCompleted = !_currentGame!.finalTableRedrawCompleted;
    if (remaining <= 9 && multiTableEvent && redrawNotCompleted) {
      _currentGame = _currentGame!.copyWith(
        players: updated,
        status: LiveGameStatus.finaltable,
        timerRunning: false,
      );
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Final table reached',
          body: '${_currentGame!.settings.name} — nine players remain.',
          type: NotificationType.game,
          link: '/final-table',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    } else {
      _currentGame = _currentGame!.copyWith(players: updated);
    }
    final p = _currentGame!.players.firstWhere((pl) => pl.id == playerId);
    // Elimination names are optional per tournament and disabled by default
    // (15-053) — spoken only when the admin enabled the setting.
    final speakElimination = _currentGame!.settings.announceEliminations;
    if (koRecipientId != null && bounty > 0) {
      final koPlayer = _currentGame!.players
          .where((pl) => pl.id == koRecipientId)
          .firstOrNull;
      addAnnouncement(
        '${p.name} eliminated by ${koPlayer?.name ?? '?'} — $bounty bounty awarded.',
        speakElimination,
      );
    } else {
      addAnnouncement('${p.name} eliminated.', speakElimination);
    }
  }

  /// Manual trigger for final table state (small tournaments that never
  /// auto-transition because they started with ≤9 players).
  void triggerFinalTable() {
    if (_currentGame == null) return;
    if (_currentGame!.status == LiveGameStatus.finaltable) return;
    _currentGame = _currentGame!.copyWith(
      status: LiveGameStatus.finaltable,
      timerRunning: false,
    );
    addAuditRecord(
      'final_table',
      'Final table triggered manually.',
    );
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Final table',
        body: '${_currentGame!.settings.name} — final table triggered.',
        type: NotificationType.game,
        link: '/final-table',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
    _syncGroupGame();
    notifyListeners();
  }

  /// Explicitly corrects a past elimination without using Undo (which is unsafe
  /// if dependent actions occurred). Adds a compensating audit action.
  void correctElimination(String playerId) {
    if (_currentGame == null) return;

    // We intentionally bypass `_pushUndo()` for audit preservation,
    // but the spec says "never delete audit history", so we just append.
    final players = _currentGame!.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(
          eliminated: false,
          eliminationPos: null,
          active: true,
        );
      }
      return p;
    }).toList();

    _currentGame = _currentGame!.copyWith(players: players);
    final correctedPlayer = players.firstWhere((p) => p.id == playerId);

    addAuditRecord(
      'correction',
      'Corrected elimination for ${correctedPlayer.name}',
    );
    addAnnouncement(
      'Correction: ${correctedPlayer.name} has been reinstated to the game.',
      false,
    );
  }

  /// Host/Admin- or Co-Admin-only (spec §4: rebuys are never self-service —
  /// a member may only [requestRebuy]).
  void grantRebuy(String playerId) {
    final game = _currentGame;
    if (game == null || !canGrantRebuys) return;
    if (!game.settings.rebuys || game.rebuysClosed) return;
    final player = game.players.where((p) => p.id == playerId).firstOrNull;
    if (player == null || !player.eliminated) return;

    _pushUndo();
    final rebuyStack = game.structure.rebuyStack;
    _currentGame = game.copyWith(
      players: game.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(
                    rebuys: p.rebuys + 1,
                    eliminated: false,
                    active: true,
                  )
                : p,
          )
          .toList(),
      totalChipsInPlay: game.totalChipsInPlay + rebuyStack,
      rebuyRequests: game.rebuyRequests.where((id) => id != playerId).toList(),
    );
    // Recalculate prize pool/prizes after money enters the game.
    // This updates only prizePool, organizerAmount and prizes on the structure,
    // leaving blind levels and any manual edits completely intact.
    _updatePrizePool();
  }

  /// Registers a player's request for a rebuy from the live view. The admin
  /// approves it from the dashboard, which clears the request. Non-authority
  /// devices also push the change as an array-union patch so the admin's
  /// dashboard picks it up live.
  void requestRebuy(String playerId) {
    if (_currentGame!.rebuyRequests.contains(playerId)) return;
    _currentGame = _currentGame!.copyWith(
      rebuyRequests: [..._currentGame!.rebuyRequests, playerId],
    );
    notifyListeners();
    if (!_isGameAuthority) {
      _patchActiveGame({
        'rebuyRequests': FieldValue.arrayUnion([playerId]),
      });
    }
  }

  void cancelRebuyRequest(String playerId) {
    _currentGame = _currentGame!.copyWith(
      rebuyRequests: _currentGame!.rebuyRequests
          .where((id) => id != playerId)
          .toList(),
    );
    notifyListeners();
    if (!_isGameAuthority) {
      _patchActiveGame({
        'rebuyRequests': FieldValue.arrayRemove([playerId]),
      });
    }
  }

  /// Records a re-entry (checklist §12.5): a separate, secondary option that
  /// grants the approved entry stack and is tracked independently of rebuys
  /// (12-046/12-047). Closes with late registration/rebuys (12-049), which is
  /// enforced by only showing the action while rebuys are still open.
  void grantReEntry(String playerId) {
    final game = _currentGame;
    if (game == null || !canGrantRebuys) return;
    if (!game.settings.reEntry || game.rebuysClosed) return;
    final player = game.players.where((p) => p.id == playerId).firstOrNull;
    if (player == null || !player.eliminated) return;

    _pushUndo();
    final entryStack = game.structure.startingStack;
    _currentGame = game.copyWith(
      players: game.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(
                    reEntries: p.reEntries + 1,
                    eliminated: false,
                    active: true,
                  )
                : p,
          )
          .toList(),
      totalChipsInPlay: game.totalChipsInPlay + entryStack,
    );
    _updatePrizePool();
  }

  void grantAddOn(String playerId) {
    final game = _currentGame;
    if (game == null || !canGrantRebuys) return;
    if (!game.settings.addOn || game.settlementConfirmed) return;
    final player = game.players.where((p) => p.id == playerId).firstOrNull;
    if (player == null ||
        player.eliminated ||
        !player.active ||
        player.hasAddOn) {
      return;
    }

    _pushUndo();
    final addOnStack = game.structure.addOnStack;
    _currentGame = game.copyWith(
      players: game.players
          .map((p) => p.id == playerId ? p.copyWith(hasAddOn: true) : p)
          .toList(),
      totalChipsInPlay: game.totalChipsInPlay + addOnStack,
      addOnRequests: game.addOnRequests.where((id) => id != playerId).toList(),
    );
    // Recalculate prize pool/prizes after money enters the game.
    _updatePrizePool();
  }

  /// Registers a player's request for an add-on from the live view. The admin
  /// approves it during the settlement flow, which clears the request.
  void requestAddOn(String playerId) {
    if (_currentGame!.addOnRequests.contains(playerId)) return;
    _currentGame = _currentGame!.copyWith(
      addOnRequests: [..._currentGame!.addOnRequests, playerId],
    );
    notifyListeners();
    if (!_isGameAuthority) {
      _patchActiveGame({
        'addOnRequests': FieldValue.arrayUnion([playerId]),
      });
    }
  }

  void cancelAddOnRequest(String playerId) {
    _currentGame = _currentGame!.copyWith(
      addOnRequests: _currentGame!.addOnRequests
          .where((id) => id != playerId)
          .toList(),
    );
    notifyListeners();
    if (!_isGameAuthority) {
      _patchActiveGame({
        'addOnRequests': FieldValue.arrayRemove([playerId]),
      });
    }
  }

  void undoLast() {
    if (_undoStack.isEmpty) {
      addAnnouncement('Nothing to undo.', false);
      return;
    }
    final previous = _undoStack.removeLast();
    if (previous == null) return;
    _currentGame = previous;
    notifyListeners();
    addAnnouncement('Last action undone.', false);
  }

  void requestCheckIn(String playerId) {
    final requester = _currentGame!.players
        .where((p) => p.id == playerId)
        .firstOrNull;
    if (_currentGame!.status.isActiveLive && _currentGame!.rebuysClosed) {
      addAnnouncement('Late registration has closed.', false);
      return;
    }
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(checkedIn: true, confirmed: false)
                : p,
          )
          .toList(),
    );
    if (requester != null && _user?.id != playerId) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Check-in request',
          body: '${requester.name} is waiting to be checked in.',
          type: NotificationType.game,
          link: '/check-in',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  void checkInPlayer(String playerId) {
    if (_currentGame!.status.isActiveLive && _currentGame!.rebuysClosed) {
      addAnnouncement('Late registration has closed.', false);
      return;
    }
    _pushUndo();
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(checkedIn: true, confirmed: true)
                : p,
          )
          .toList(),
    );
  }

  void cancelCheckIn(String playerId) {
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(checkedIn: false, confirmed: false)
                : p,
          )
          .toList(),
    );
    notifyListeners();
  }

  /// Closes door check-in (spec §4.7). Once closed, the host is prompted to
  /// start the tournament and no further walk-ins are accepted.
  void closeCheckIn() {
    _currentGame = _currentGame!.copyWith(
      checkInClosed: true,
      status: LiveGameStatus.ready,
    );
    _syncGroupGame();
    addAnnouncement(
      'Check-in is now closed. No more players may join unless re-opened.',
      false,
    );
    notifyListeners();
  }

  void reopenCheckIn() {
    _currentGame = _currentGame!.copyWith(
      checkInClosed: false,
      status: LiveGameStatus.checkin,
    );
    _syncGroupGame();
    addAnnouncement('Check-in re-opened.', false);
    notifyListeners();
  }

  /// Registers an un-invited walk-in player at the door (spec §4.7). They are
  /// checked in immediately and seated by the next seating generation.
  ///
  /// Late-registration guard (User Flow §3.2 / §12.5): once the game is live
  /// and late registration has closed permanently at the end of the selected
  /// rebuy level, no new players may be added ("A player arrives after late
  /// registration closes; the system prevents addition"). Rebuy-break, final
  /// table, completed and cancelled states also block outright. Pre-live
  /// door walk-ins stay allowed by design even when check-in has been closed.
  ///
  /// Returns a validation message when the addition is illegal, or null on
  /// success. Callers may ignore the result safely.
  String? addWalkInPlayer(String name) {
    final game = _currentGame;
    if (game == null) return 'No active game.';
    final trimmed = Sanitization.sanitizeName(name);
    if (trimmed.isEmpty) return 'Enter a name for the walk-in.';
    switch (game.status) {
      case LiveGameStatus.completed:
        return 'The tournament has finished — no new players can be added.';
      case LiveGameStatus.cancelled:
        return 'The tournament was cancelled — no new players can be added.';
      case LiveGameStatus.rebuypause:
        return 'Rebuy break in progress — registration is closed.';
      case LiveGameStatus.finaltable:
        return 'Final table is set — no new players can be added.';
      default:
        break;
    }
    if (game.status.isActiveLive && game.rebuysClosed) {
      return 'Late registration has closed — no new players can be added.';
    }
    _pushUndo();
    final id = 'p-${DateTime.now().millisecondsSinceEpoch}';
    final player = Player(
      id: id,
      name: trimmed,
      isGuest: false,
      rsvp: null,
      checkedIn: true,
      confirmed: true,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: 0,
      seat: 0,
      active: true,
    );
    _currentGame = game.copyWith(
      players: [...game.players, player],
      totalChipsInPlay: game.totalChipsInPlay + game.structure.startingStack,
    );
    _updatePrizePool();
    recalculateStructure();

    // Suggest a seat if tables are already generated (meaning play has started or seating is done)
    if (_currentGame!.players.any((p) => p.table > 0)) {
      final tables = _currentGame!.players
          .where((p) => p.table > 0)
          .map((p) => p.table)
          .toSet();
      if (tables.isNotEmpty) {
        // Find table with minimum players
        int minTable = tables.first;
        int minCount = 999;
        for (var t in tables) {
          int count = _currentGame!.players
              .where((p) => p.table == t && p.active)
              .length;
          if (count < minCount) {
            minCount = count;
            minTable = t;
          }
        }
        // Find first empty seat at minTable
        final taken = _currentGame!.players
            .where((p) => p.table == minTable)
            .map((p) => p.seat)
            .toSet();
        int freeSeat = 1;
        while (taken.contains(freeSeat)) {
          freeSeat++;
        }
        _pendingSeatMove = SeatMoveRecommendation(
          fromPlayerId: player.id,
          fromPlayerName: player.name,
          fromTable: 0,
          fromSeat: 0,
          toTable: minTable,
          toSeat: freeSeat,
          reason: 'Late add requires a seat.',
        );
      }
    }

    _syncGroupGame();
    addAnnouncement('${player.name} walked in and is checked in.', true);
    notifyListeners();
    return null;
  }

  void confirmGuest(String guestId) {
    _pushUndo();
    final game = _currentGame!;

    final updated = game.players
        .map(
          (p) => p.id == guestId
              ? p.copyWith(confirmed: true, checkedIn: true, active: true)
              : p,
        )
        .toList();

    final extraChips = game.structure.startingStack;
    final guest = game.players.where((p) => p.id == guestId).firstOrNull;

    final inviterId = guest?.inviterId;
    final guestSlot = guest?.guestSlot;
    final canTagSlot = guest != null && inviterId != null && guestSlot != null;

    _currentGame = game.copyWith(
      players: updated,
      pendingGuests: game.pendingGuests.where((p) => p.id != guestId).toList(),
      totalChipsInPlay: game.totalChipsInPlay + extraChips,
      guestSlots: canTagSlot
          ? game.guestSlots.map((s) {
              if (s.inviterId == inviterId && s.slot == guestSlot) {
                return s.copyWith(
                  guestName: guest.name,
                  status: GuestSlotStatus.checkedIn,
                );
              }
              return s;
            }).toList()
          : game.guestSlots,
    );

    if (extraChips > 0) {
      _updatePrizePool();
    }

    addAnnouncement('Guest confirmed and seated.', false);
    if (guest != null) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Guest confirmed',
          body: '${guest.name} is confirmed for ${game.settings.name}.',
          type: NotificationType.invite,
          link: '/guest-flow',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Admin rejects a pending guest request — the guest is removed from the
  /// players list and no longer sits at the table (07-026). Their slot is
  /// freed so another guest can claim it.
  void rejectGuest(String guestId) {
    _pushUndo();
    final guest = _currentGame!.players
        .where((p) => p.id == guestId)
        .firstOrNull;
    final inviterId = guest?.inviterId;
    final guestSlot = guest?.guestSlot;
    final canFree = guest != null && inviterId != null && guestSlot != null;
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players.where((p) => p.id != guestId).toList(),
      pendingGuests: _currentGame!.pendingGuests
          .where((p) => p.id != guestId)
          .toList(),
      guestSlots: canFree
          ? _currentGame!.guestSlots
                .map(
                  (s) => s.inviterId == inviterId && s.slot == guestSlot
                      ? s.copyWith(
                          guestName: null,
                          status: GuestSlotStatus.unclaimed,
                        )
                      : s,
                )
                .toList()
          : _currentGame!.guestSlots,
    );
    addAnnouncement('Guest request rejected.', false);
    // Free the server-side slot claim too, so another guest can claim the
    // slot immediately (spec §7.1 — admin correction reopens the slot).
    if (canFree && _backendUp) {
      _repo
          .releaseSlotClaim(_currentGame!.id, inviterId, guestSlot)
          .catchError((_) {});
    }
  }

  /// Marks the matching guest slot as claimed so the free-slot count
  /// on the guest flow and invitation screens stays accurate. When
  /// [requested] is true the claim carries a check-in request and the slot
  /// moves to [GuestSlotStatus.checkInRequested] (user-flow spec §7.1:
  /// Unclaimed → Reserved → Check-in Requested → Checked In).
  List<GuestSlot> _markSlotReserved(
    List<GuestSlot> slots,
    String inviterId,
    int slot, {
    String? name,
    bool requested = false,
  }) {
    final target = requested
        ? GuestSlotStatus.checkInRequested
        : GuestSlotStatus.reserved;
    final updated = slots.map((s) {
      if (s.inviterId == inviterId && s.slot == slot && s.available) {
        return s.copyWith(guestName: name, status: target);
      }
      return s;
    }).toList();
    // Safety net: the inviter somehow has no persisted slot record.
    if (!updated.any((s) => s.inviterId == inviterId && s.slot == slot)) {
      updated.add(
        GuestSlot(
          id: 'slot-${DateTime.now().millisecondsSinceEpoch}-$inviterId-$slot',
          inviterId: inviterId,
          slot: slot,
          guestName: name,
          status: target,
        ),
      );
    }
    return updated;
  }

  /// Guest flow: attach a brand-new guest to a game and mark them pending.
  /// With a backend this posts a request to the game's queue for the admin
  /// device to consume — the guest's own view stays read-only. Offline (no
  /// backend) the same mutation is applied locally so the demo flow keeps
  /// working. The guest's session is persisted either way so the device can
  /// recover the request after a refresh (checklist 07-030). Returns an error
  /// string if the slot is invalid or already taken.
  Future<String?> requestGuestCheckIn(
      String name, String inviterId, int slot) async {
    final game = _currentGame;
    if (game == null) return 'No active game found.';

    final existingSlot = game.guestSlots
        .where((s) => s.inviterId == inviterId && s.slot == slot)
        .firstOrNull;
    if (existingSlot != null && !existingSlot.available) {
      return 'That guest slot is already reserved or checked in.';
    }
    final alreadyClaimed = game.players.any(
      (p) => p.isGuest && p.inviterId == inviterId && p.guestSlot == slot,
    );
    if (alreadyClaimed) {
      return 'That guest slot is already claimed.';
    }

    final guestId = 'g-${DateTime.now().millisecondsSinceEpoch}';
    final sanitizedName = Sanitization.sanitizeName(name);
    _saveGuestSession(
      GuestSession(
        gameId: game.id,
        name: sanitizedName,
        inviterId: inviterId,
        slot: slot,
      ),
    );

    if (_backendUp) {
      try {
        // Transactional claim: Firestore serializes racing guests on the
        // deterministic slot doc, so the first reservation wins server-side
        // even when both devices hold stale snapshots (spec §7.1).
        final err = await _repo.reserveGuestSlotTx(
          gameId: game.id,
          inviterId: inviterId,
          slot: slot,
          payload: {
            'guestId': guestId,
            'name': name.trim(),
            'inviterId': inviterId,
            'slot': slot,
            // Lets security rules verify only group admins consume requests.
            'gid': game.groupId,
          },
        );
        if (err != null) return err;
      } catch (e) {
        debugPrint('reserveGuestSlotTx(guestCheckIn) failed: $e');
        return 'Could not reach the host. Check your connection.';
      }
      // The guest stays pending until the host confirms them at check-in
      // (spec §6 "waiting for admin confirmation", checklist 07-027/07-028).
      return null;
    }

    // Offline / mock mode: apply locally (same rules the admin would apply).
    _pushUndo();
    final guest = Player(
      id: guestId,
      name: name,
      isGuest: true,
      inviterId: inviterId,
      guestSlot: slot,
      rsvp: Rsvp.going,
      checkedIn: false,
      confirmed: false,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: 0,
      seat: 0,
      active: false,
    );
    _currentGame = game.copyWith(
      players: [...game.players, guest],
      pendingGuests: [...game.pendingGuests, guest],
      guestSlots: _markSlotReserved(
        game.guestSlots,
        inviterId,
        slot,
        name: name.trim(),
        // Claim + check-in request are one step in this flow (spec §6.3–6.5).
        requested: true,
      ),
    );
    notifyListeners();
    return null;
  }

  /// Signs this device in anonymously so guests can read public projections
  /// and write to the request queue without an account. A no-op when a real
  /// account is already signed in — never replaces an authenticated session.
  Future<void> ensureGuestAuth() async {
    if (!_backendUp) return;
    if (_repo.currentUser != null) return;
    await signInAsGuest();
  }

  // ── Guest session (device-local, checklist 07-030) ─────────────────────────
  GuestSession? _guestSession;
  GuestSession? get guestSession => _guestSession;

  /// True while this device holds an approved/requested guest session
  /// (used by the router guard to allow guests into player-live without an
  /// account — checklist 15-014).
  bool get hasGuestSession => _guestSession != null;

  /// Role-safe game copies (§2.3). Non-admin views must never read private
  /// fields; the public surfaces are fed from these projections, never from
  /// the raw game object.
  LiveGame? get tvGame =>
      _currentGame == null ? null : projections.tvProjection(_currentGame!);

  /// The game as a registered non-admin member sees it: payout amounts and
  /// organizer amount removed, chat preserved.
  LiveGame? get playerProjection => _currentGame == null
      ? null
      : projections.playerProjection(_currentGame!, viewerId: _user?.id);

  /// The game as a guest sees it: payout/organizer amounts and chat removed.
  LiveGame? get guestProjection =>
      _currentGame == null ? null : projections.guestProjection(_currentGame!);

  /// The projection matching the current viewer (guest vs registered member).
  LiveGame? get viewerProjection =>
      hasGuestSession ? guestProjection : playerProjection;

  void _saveGuestSession(GuestSession session) {
    _guestSession = session;
    RecoveryService.saveGuestSession(session);
  }

  /// Clears the stored guest session (e.g. the guest was rejected or left).
  void clearGuestSession() {
    _guestSession = null;
    RecoveryService.clearGuestSession();
    notifyListeners();
  }

  /// Assign table + seat numbers to every checked-in player (spec §12.1).
  /// Tables are capped at [effectiveTableSettings.maxPerTable] (configurable
  /// per group, overridable per tournament — defaults to 10); once checked-in
  /// count exceeds that, multiple balanced tables are created automatically.
  /// Every player gets exactly one unique (table, seat) — no duplicates.
  void generateSeating(TableSeatingMode mode) {
    final game = _currentGame;
    if (game == null) return;

    // Only checked-in, confirmed, non-eliminated participants are seated.
    final seated = game.players
        .where((p) => p.checkedIn && p.confirmed && !p.eliminated)
        .toList();
    if (seated.isEmpty) return;
    _pushUndo();

    // Order players according to the chosen seating mode.
    List<Player> ordered;
    switch (mode) {
      case TableSeatingMode.random:
        ordered = [...seated]..shuffle(Random());
        break;
      case TableSeatingMode.manual:
        ordered = [...seated];
        break;
      case TableSeatingMode.keepGuests:
        // Group each guest next to their inviter so the round-robin deal keeps
        // them on the same table where capacity allows.
        ordered = _orderKeepingGuests(seated, together: true);
        break;
      case TableSeatingMode.separateGuests:
        ordered = _orderKeepingGuests(seated, together: false);
        break;
    }

    // Balanced tables: ceil(count / maxPerTable), distributed as evenly as
    // possible. maxPerTable comes from the tournament's override, or the
    // group's default otherwise (spec: configurable, defaults to 10).
    final maxPerTable = effectiveTableSettings.maxPerTable.clamp(2, 999);
    final count = ordered.length;
    final tableCount = (count / maxPerTable).ceil();
    final perTable = List<int>.filled(tableCount, count ~/ tableCount);
    for (var i = 0; i < count % tableCount; i++) {
      perTable[i]++;
    }

    // Deal round-robin into tables, filling seats 1..n per table.
    final seatCursor = List<int>.filled(tableCount, 0);
    final assignments = <String, ({int table, int seat})>{};
    var idx = 0;
    for (final p in ordered) {
      // Find the next table that still has capacity (round-robin).
      var table = idx % tableCount;
      var guard = 0;
      while (seatCursor[table] >= perTable[table] && guard < tableCount) {
        table = (table + 1) % tableCount;
        guard++;
      }
      seatCursor[table]++;
      assignments[p.id] = (table: table + 1, seat: seatCursor[table]);
      idx++;
    }

    // Random initial dealer position (13-012/13-026) chosen from the seated
    // players. The system does not track dealer-button rotation (13-032).
    final dealer = seated.isEmpty
        ? null
        : seated[Random().nextInt(seated.length)];

    _currentGame = game.copyWith(
      players: game.players.map((p) {
        final a = assignments[p.id];
        return a == null ? p : p.copyWith(table: a.table, seat: a.seat);
      }).toList(),
      dealerPlayerId: dealer?.id,
      // A new draw invalidates any previous confirmation (13-013).
      seatingConfirmed: false,
    );
    // Announce the drawn dealer out loud so the room hears who deals first
    // (checklist 13-026). Falls back quietly if voice is disabled.
    if (dealer != null) {
      addAnnouncement('Seating drawn. ${dealer.name} deals first.', true);
    }
    notifyListeners();
  }

  /// Marks the generated physical seating as confirmed before play starts
  /// (checklist 13-013). Seats remain editable afterwards via the move flow.
  void confirmSeating() {
    final game = _currentGame;
    if (game == null) return;
    _currentGame = game.copyWith(seatingConfirmed: true);
    addAnnouncement('Seating confirmed. Shuffle up and deal!', true);
    // Notify each seated participant of their table and seat (Tech §14.3).
    for (final p in game.players.where((p) => p.confirmed && p.table > 0)) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}-${p.id}',
          title: 'Seat assigned',
          body:
              '${game.settings.name} — you are Table ${p.table}, Seat ${p.seat}.',
          type: NotificationType.game,
          link: '/invitation',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Assigns one player to an explicit (table, seat) — used by Manual seating
  /// (13-002) and validated to prevent duplicate seats (13-021). Clearing the
  /// previous confirmation forces a re-confirm of the physical layout.
  String? assignSeat(String playerId, int table, int seat) {
    final game = _currentGame;
    if (game == null) return null;
    if (table < 1 || seat < 1) return 'Choose a valid table and seat.';
    final occupied = game.players.any(
      (p) =>
          p.id != playerId &&
          p.table == table &&
          p.seat == seat &&
          !p.eliminated,
    );
    if (occupied) return 'That seat is already taken — choose another.';
    _pushUndo();
    _currentGame = game.copyWith(
      players: game.players
          .map(
            (p) => p.id == playerId ? p.copyWith(table: table, seat: seat) : p,
          )
          .toList(),
      seatingConfirmed: false,
    );
    notifyListeners();
    return null;
  }

  /// Detects when tables differ by more than one active player and builds a
  /// recommendation for the administrator (checklist 13-015/13-016/13-017).
  SeatMoveRecommendation? _buildSeatMoveRecommendation() {
    final game = _currentGame;
    if (game == null) return null;
    final seated = game.players.where((p) => p.active && p.table > 0).toList();
    if (seated.length < 2) return null;
    final counts = <int, int>{};
    for (final p in seated) {
      counts[p.table] = (counts[p.table] ?? 0) + 1;
    }
    final tables = counts.keys.toList();
    if (tables.length < 2) return null;

    // Sort tables by player count
    final sortedByCount = tables.toList()
      ..sort((a, b) => counts[a]!.compareTo(counts[b]!));
    final minTable = sortedByCount.first;
    final maxTable = sortedByCount.last;

    final minCount = counts[minTable]!;
    final maxCount = counts[maxTable]!;
    if (maxCount - minCount <= 1) return null;
    // Pick the player with the smallest seat number on the largest table so the
    // recommendation is deterministic and understandable.
    final mover = seated.where((p) => p.table == maxTable).toList()
      ..sort((a, b) => a.seat.compareTo(b.seat));
    final from = mover.first;
    // Find the first free seat on the destination table.
    final taken = seated
        .where((p) => p.table == minTable)
        .map((p) => p.seat)
        .toSet();
    var toSeat = 1;
    while (taken.contains(toSeat)) {
      toSeat++;
    }
    return SeatMoveRecommendation(
      fromPlayerId: from.id,
      fromPlayerName: from.name,
      fromTable: from.table,
      fromSeat: from.seat,
      toTable: minTable,
      toSeat: toSeat,
      reason:
          'Table $maxTable has $maxCount players while Table $minTable has '
          '$minCount. Moving ${from.name} balances the tables.',
    );
  }

  /// Current pending seat-move recommendation, if any (checklist §13.2).
  SeatMoveRecommendation? get seatingRecommendation => _pendingSeatMove;

  bool get hasSeatingImbalance => seatingRecommendation != null;

  /// Asks the engine for a fresh table-balance recommendation. Nothing is
  /// applied — the admin must review and confirm (13-018).
  void requestSeatingBalance() {
    _pendingSeatMove = _buildSeatMoveRecommendation();
    notifyListeners();
  }

  /// Clears the pending recommendation without changing any seats (13-020).
  void dismissSeatMove() {
    if (_pendingSeatMove == null) return;
    _pendingSeatMove = null;
    notifyListeners();
  }

  /// Applies the confirmed recommendation: the player moves, source and
  /// destination seats update consistently (13-018/13-019).
  void confirmSeatMove() {
    final rec = _pendingSeatMove;
    if (rec == null) return;
    final game = _currentGame;
    if (game == null) return;
    final occupied = game.players.any(
      (p) =>
          p.id != rec.fromPlayerId &&
          p.table == rec.toTable &&
          p.seat == rec.toSeat &&
          !p.eliminated,
    );
    if (occupied) {
      _pendingSeatMove = null;
      notifyListeners();
      return;
    }
    _pushUndo();
    _currentGame = game.copyWith(
      players: game.players
          .map(
            (p) => p.id == rec.fromPlayerId
                ? p.copyWith(table: rec.toTable, seat: rec.toSeat)
                : p,
          )
          .toList(),
      seatingConfirmed: false,
    );
    _pendingSeatMove = null;
    addAnnouncement(
      '${rec.fromPlayerName} moved to Table ${rec.toTable} seat ${rec.toSeat}.',
      true,
    );
    notifyListeners();
  }

  // ── Late registration (checklist §12.3) ────────────────────────────────────

  /// Late registration stays open until the rebuy period ends — the configured
  /// closing level, normally the end of Level 6 (07-039, 12-028, 20-023).
  bool get lateRegistrationOpen {
    final game = _currentGame;
    if (game == null) return false;
    final live =
        game.status == LiveGameStatus.running ||
        game.status == LiveGameStatus.paused;
    return live &&
        !game.settlementConfirmed &&
        game.currentLevel <= game.settings.rebuysCloseLevel;
  }

  /// Adds a registered player during late registration (12-022/12-023).
  /// The late player receives a full fresh starting stack (12-024) and is
  /// assigned to the recommended balanced table and an available seat
  /// (12-025). Totals are recalculated (12-026).
  void addLatePlayer(String name) {
    if (!lateRegistrationOpen) return;
    _pushUndo();
    final game = _currentGame!;
    final id = 'p-${DateTime.now().millisecondsSinceEpoch}';
    final (table: table, seat: seat) = _findAvailableSeat();
    final player = Player(
      id: id,
      name: name.trim(),
      isGuest: false,
      rsvp: null,
      checkedIn: true,
      confirmed: true,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: table,
      seat: seat,
      active: true,
    );
    _currentGame = game.copyWith(
      players: [...game.players, player],
      totalChipsInPlay: game.totalChipsInPlay + game.structure.startingStack,
    );
    // Recalculate prize pool/prizes after money enters the game.
    _updatePrizePool();
    _syncGroupGame();
    addAnnouncement('${player.name} has joined the tournament.', true);
    notifyListeners();
  }

  /// Completely removes a player from the active tournament.
  /// Deducts starting stack, rebuys, and add-ons from total chips.
  /// Recalculates prize pool and distribution.
  void removePlayer(String playerId) {
    if (_currentGame == null) return;
    _pushUndo();
    final game = _currentGame!;
    final p = game.players.where((pl) => pl.id == playerId).firstOrNull;
    if (p == null) return;

    int chipsToRemove = game.structure.startingStack;
    if (p.rebuys > 0) {
      chipsToRemove += p.rebuys * game.structure.startingStack;
    }
    if (p.hasAddOn) {
      chipsToRemove += game.structure.addOnStack;
    }

    final newPlayers = game.players.where((pl) => pl.id != playerId).toList();

    _currentGame = game.copyWith(
      players: newPlayers,
      totalChipsInPlay: (game.totalChipsInPlay - chipsToRemove).clamp(
        0,
        99999999,
      ),
    );

    _updatePrizePool();
    _syncGroupGame();
    // A removed guest frees their slot: drop the server-side claim lock so
    // the seat can be claimed again (spec §7.1).
    if (p.isGuest && p.inviterId != null && p.guestSlot != null && _backendUp) {
      _repo
          .releaseSlotClaim(game.id, p.inviterId!, p.guestSlot!)
          .catchError((_) {});
    }
    addAnnouncement('${p.name} has been removed from the tournament.', true);
    notifyListeners();
  }

  /// Finds the table with the fewest active players and its first free seat.
  ({int table, int seat}) _findAvailableSeat() {
    final game = _currentGame;
    if (game == null) return (table: 1, seat: 1);
    final seated = game.players.where((p) => p.active && p.table > 0).toList();
    if (seated.isEmpty) return (table: 1, seat: 1);
    final counts = <int, int>{};
    for (final p in seated) {
      counts[p.table] = (counts[p.table] ?? 0) + 1;
    }
    final maxPerTable = effectiveTableSettings.maxPerTable.clamp(2, 999);
    final tableCount =
        (game.activePlayers.length / maxPerTable).ceil().clamp(1, maxPerTable);
    var bestTable = 1;
    var bestCount = 1 << 30;
    for (var t = 1; t <= tableCount; t++) {
      final c = counts[t] ?? 0;
      if (c < maxPerTable && c < bestCount) {
        bestTable = t;
        bestCount = c;
      }
    }
    final taken = seated
        .where((p) => p.table == bestTable)
        .map((p) => p.seat)
        .toSet();
    var seat = 1;
    while (taken.contains(seat)) {
      seat++;
    }
    return (table: bestTable, seat: seat);
  }

  /// Re-computes prizePool, organizerAmount and prize distribution after any
  /// money enters the game (late registration, rebuy, re-entry, add-on).
  ///
  /// This is surgical update on the structure only: it uses
  /// [TournamentStructure.copyWith] to update the three financial fields while
  /// leaving every blind level — including manual edits from StructureEditor —
  /// completely unchanged (fixes checklist 12-026).
  void _updatePrizePool() {
    final game = _currentGame;
    if (game == null) return;

    final s = game.settings;
    final structure = game.structure;

    // Gross eligible = all actual money that entered the game:
    //   confirmed players × buy-in  +  all rebuys × rebuy price
    //   +  all re-entries × buy-in  +  all add-ons × add-on price.
    // Rebuy/add-on prices default to the buy-in unless the admin set a custom
    // price (09-050/12-051, 12-060).
    final confirmedCount = game.players.where((p) => p.confirmed).length;
    final totalRebuys = game.players.fold<int>(0, (sum, p) => sum + p.rebuys);
    final totalReEntries = game.players.fold<int>(
      0,
      (sum, p) => sum + p.reEntries,
    );
    final totalAddOns = game.players.where((p) => p.hasAddOn).length;

    final grossEligible =
        confirmedCount * s.buyIn +
        totalRebuys * s.effectiveRebuyCost +
        totalReEntries * s.buyIn +
        totalAddOns * (s.addOn ? s.effectiveAddOnCost : 0);

    // Delegate the organizer-cut and prize-split maths to the shared helper in
    // TournamentEngine so the rules stay consistent everywhere.
    final recalculated = TournamentEngine.recalculatePrizes(
      grossEligible,
      confirmedCount,
      s.organizerPct.toDouble(),
      forcePaidPlaces: s.forcePaidPlaces,
    );

    // Patch only the financial fields; levels and all other structure data
    // remain exactly as they were (including any StructureEditor overrides).
    _currentGame = game.copyWith(
      structure: structure.copyWith(
        prizePool: recalculated.prizePool,
        organizerAmount: recalculated.organizerAmount,
        prizes: recalculated.prizes,
      ),
    );
  }

  /// Manually overrides the number of paid places and recalculates prizes.
  void overridePaidPlaces(int? count) {
    if (_currentGame == null) return;
    _pushUndo();
    _currentGame = _currentGame!.copyWith(
      settings: _currentGame!.settings.copyWith(forcePaidPlaces: count),
    );
    _updatePrizePool();
    addAuditRecord(
      'structure_edit',
      'Paid places overridden to ${count ?? 'auto'}',
    );
    notifyListeners();
  }

  /// Orders players so guests are placed immediately after (together) or far
  /// from (separate) their inviter, used to steer the round-robin deal.
  List<Player> _orderKeepingGuests(
    List<Player> players, {
    required bool together,
  }) {
    final registered = players.where((p) => !p.isGuest).toList();
    final guests = players.where((p) => p.isGuest).toList();
    if (together) {
      final result = <Player>[];
      for (final r in registered) {
        result.add(r);
        result.addAll(guests.where((g) => g.inviterId == r.id));
      }
      // Any guest whose inviter isn't seated still gets placed.
      result.addAll(
        guests.where((g) => !registered.any((r) => r.id == g.inviterId)),
      );
      return result;
    }
    // Separate: interleave registered and guests so inviter/guest land apart.
    final result = <Player>[];
    final maxLen = registered.length > guests.length
        ? registered.length
        : guests.length;
    for (var i = 0; i < maxLen; i++) {
      if (i < registered.length) result.add(registered[i]);
      if (i < guests.length) result.add(guests[i]);
    }
    return result;
  }

  void acceptSpeedRecommendation({SpeedRecommendation? rec}) {
    final game = _currentGame;
    if (game == null) return;
    final recommendation = rec ?? game.speedRecommendation;
    if (recommendation == null) return;
    _pushUndo();
    final structure = game.structure;
    final newDuration = recommendation == SpeedRecommendation.speedUp
        ? structure.levelDuration - 5
        : structure.levelDuration + 5;
    final clamped = newDuration < 10
        ? 10
        : (newDuration > 20 ? 20 : newDuration);
    // Apply the new duration to future levels only (spec: active level never changes, starts next level).
    final levels = structure.levels
        .map(
          (l) => l.level > game.currentLevel
              ? BlindLevel(
                  level: l.level,
                  sb: l.sb,
                  bb: l.bb,
                  ante: l.ante,
                  durationMins: clamped,
                )
              : l,
        )
        .toList();
    _currentGame = game.copyWith(
      speedRecommendation: null,
      structure: structure.copyWith(levels: levels, levelDuration: clamped),
    );
    addAnnouncement(
      recommendation == SpeedRecommendation.speedUp
          ? 'Future levels sped up to $clamped minutes.'
          : 'Future levels slowed down to $clamped minutes.',
      true,
    );
  }

  TournamentStructure _structureWithLevels(
    TournamentStructure s,
    List<BlindLevel> levels,
  ) {
    return TournamentStructure(
      startingStack: s.startingStack,
      chipPlan: s.chipPlan,
      rebuyStack: s.rebuyStack,
      rebuyChipPlan: s.rebuyChipPlan,
      addOnStack: s.addOnStack,
      addOnChipPlan: s.addOnChipPlan,
      levels: levels,
      levelDuration: s.levelDuration,
      expectedFinishMins: s.expectedFinishMins,
      prizes: s.prizes,
      prizePool: s.prizePool,
      organizerAmount: s.organizerAmount,
      colorUpInstructions: s.colorUpInstructions,
      warnings: s.warnings,
    );
  }

  /// Regenerates the whole structure for the actual confirmed attendance
  /// (checklist 09-003 / 22-006: the engine always regenerates rather than
  /// reusing a fixed template). Keeps the current level and resets its clock.
  /// Total expected attendance taken from RSVPs: every "Going" answer counts
  /// the member plus their guest slots (Going +2 = 3 people). Falls back to
  /// the group roster when nobody has answered yet.
  int expectedPlayersFromRsvps(LiveGame game) {
    var total = 0;
    for (final p in game.players) {
      if (!p.isGuest && p.rsvp != null && p.rsvp!.isGoing) {
        total += 1 + p.rsvp!.guestCount;
      }
    }
    return total >= 2 ? total : game.players.where((p) => !p.isGuest).length;
  }

  /// Admin has reviewed the generated structure (30-minute estimate).
  void confirmStructure() {
    final game = _currentGame;
    if (game == null) return;
    _currentGame = game.copyWith(structureConfirmed: true);
    addAuditRecord(
      'structure_confirm',
      'Structure confirmed: stack ${game.structure.startingStack}, '
          '${game.structure.levels.length} levels of ${game.structure.levelDuration}m.',
    );
    _syncGroupGame();
    notifyListeners();
  }

  /// Generates (or regenerates) the structure estimate from the inputs the
  /// admin provided plus the current expected attendance. Only allowed once
  /// the 30-minute pre-start window is open (client rule: the structure is
  /// reviewed ~30 minutes before the game, while people are still deciding
  /// whether to attend).
  /// C1: Admin-Triggered Final Structure Generation at Check-in
  void generateFinalStructure(int confirmedCount, {bool force = false}) {
    final game = _currentGame;
    if (game == null) return;
    _pushUndo();
    final count = confirmedCount;
    final s = game.settings.copyWith(players: count);
    final structure = TournamentEngine.generate(
      TournamentParams(
        players: count,
        durationHours: s.durationHours,
        buyIn: s.buyIn,
        chipSet: s.chipSet,
        rebuys: s.rebuys,
        rebuysCloseLevel: s.rebuysCloseLevel,
        reEntry: s.reEntry,
        addOn: s.addOn,
        anteEnabled: s.anteEnabled,
        anteAfterLevel: s.anteAfterLevel,
        anteStyle: s.anteStyle,
        koEnabled: s.koEnabled,
        koAmount: s.koAmount,
        organizerPct: s.organizerPct,
        rebuyCost: s.rebuyCost,
        addOnCost: s.addOnCost,
      ),
    );
    _currentGame = game.copyWith(
      settings: s,
      structure: structure,
      originalLevels: List.of(structure.levels),
      totalChipsInPlay: structure.startingStack * count,
      currentLevel: 1,
      secondsRemaining: structure.levelDuration * 60,
      structureConfirmed: false,
    );
    addAuditRecord(
      'structure_estimate',
      'AI generated the structure estimate for $count expected players.',
    );
    notifyListeners();
  }

  void recalculateStructure() {
    final game = _currentGame;
    if (game == null) return;
    _pushUndo();

    final confirmed = game.players.where((p) => p.confirmed).length;
    final count = confirmed >= 2 ? confirmed : expectedPlayersFromRsvps(game);
    _recalculateWithPlayers(count);
  }

  void updateStructurePlayerCount(int players) {
    final game = _currentGame;
    if (game == null) return;
    _pushUndo();
    _recalculateWithPlayers(players);
  }

  void _recalculateWithPlayers(int count) {
    final game = _currentGame!;
    final s = game.settings;
    final newSettings = s.copyWith(players: count);
    var structure = TournamentEngine.generate(
      TournamentParams(
        players: count,
        durationHours: newSettings.durationHours,
        buyIn: newSettings.buyIn,
        chipSet: newSettings.chipSet,
        rebuys: newSettings.rebuys,
        rebuysCloseLevel: newSettings.rebuysCloseLevel,
        reEntry: newSettings.reEntry,
        addOn: newSettings.addOn,
        anteEnabled: newSettings.anteEnabled,
        anteAfterLevel: newSettings.anteAfterLevel,
        anteStyle: newSettings.anteStyle,
        koEnabled: newSettings.koEnabled,
        koAmount: newSettings.koAmount,
        organizerPct: newSettings.organizerPct,
        rebuyCost: newSettings.rebuyCost,
        addOnCost: newSettings.addOnCost,
      ),
    );
    // Once play has started the starting stacks are frozen — blinds, levels
    // and the player count may still change (client rule).
    if (game.stacksLocked) {
      structure = structure.copyWith(
        startingStack: game.structure.startingStack,
        chipPlan: game.structure.chipPlan,
        rebuyStack: game.structure.rebuyStack,
        rebuyChipPlan: game.structure.rebuyChipPlan,
        addOnStack: game.structure.addOnStack,
        addOnChipPlan: game.structure.addOnChipPlan,
      );
    }

    final newLevel = game.currentLevel.clamp(1, structure.levels.length);
    _currentGame = game.copyWith(
      settings: newSettings,
      structure: structure,
      currentLevel: newLevel,
      secondsRemaining: structure.levels[newLevel - 1].durationMins * 60,
      speedRecommendation: null,
    );
    addAnnouncement(
      'Structure recalculated for $count confirmed player${count != 1 ? 's' : ''}.',
      true,
    );
  }



  /// Applies admin edits to future levels (the structure editor modal).
  /// The active and already-finished levels are left untouched.
  void applyLevelEdits(List<LevelEdit> edits) {
    final game = _currentGame;
    if (game == null || edits.isEmpty) return;
    _pushUndo();
    final byLevel = {for (final e in edits) e.level: e};
    final levels = game.structure.levels.map((l) {
      final e = byLevel[l.level];
      if (e == null) return l;
      return BlindLevel(
        level: l.level,
        sb: e.sb,
        bb: e.bb,
        ante: e.ante,
        durationMins: e.durationMins,
      );
    }).toList();
    _currentGame = game.copyWith(
      structure: _structureWithLevels(game.structure, levels),
    );
    addAnnouncement('Level structure updated by admin.', false);
  }

  /// Replaces the future levels (everything from the current level onward)
  /// with a renumbered list produced by the structure editor. Inserting or
  /// removing levels is supported because the whole future segment is swapped,
  /// not patched by level number (checklist §12.4).
  void applyFutureLevels(List<BlindLevel> futureLevels) {
    final game = _currentGame;
    if (game == null || futureLevels.isEmpty) return;
    _pushUndo();
    final startIdx = game.currentLevel - 1;
    final prefix = startIdx > 0
        ? game.structure.levels.take(startIdx).toList()
        : <BlindLevel>[];
    // Renumber sequentially so inserting a level shifts the rest correctly.
    var n = startIdx + 1;
    final renumbered = [
      for (final l in futureLevels)
        BlindLevel(
          level: n++,
          sb: l.sb,
          bb: l.bb,
          ante: l.ante,
          durationMins: l.durationMins,
        ),
    ];
    final levels = [...prefix, ...renumbered];
    _currentGame = game.copyWith(
      structure: _structureWithLevels(game.structure, levels),
      secondsRemaining: game.secondsRemaining,
    );
    addAuditRecord(
      'structure_edit',
      'Future levels updated: ${renumbered.length} future level'
          '${renumbered.length == 1 ? '' : 's'} (was ${(game.structure.levels.length - prefix.length).clamp(0, 999)})',
    );
    addAnnouncement('Level structure updated by admin.', false);
  }

  /// Inserts one intermediate future level directly after [afterLevel]
  /// (Tech Spec §8.6 permitted slow-down action; User Flow §4.14 "An
  /// intermediate future blind level may be inserted"). Subsequent levels are
  /// renumbered with a +1 shift; completed and active levels stay immutable
  /// (spec §12.4/§8.6), so [afterLevel] must be >= the current level.
  ///
  /// Validation: game must exist, durationMins must be one of the allowed
  /// 10/15/20 minute values, bb > sb > 0 and ante >= 0. Monotonic blind
  /// progression across neighbours is left to the admin's responsibility.
  ///
  /// Returns a validation message when the insert was rejected, or null on
  /// success. Undoable via [_pushUndo]; audited as 'structure_insert_level'.
  String? insertFutureLevel(
    int afterLevel,
    int sb,
    int bb,
    int? ante,
    int durationMins,
  ) {
    final game = _currentGame;
    if (game == null) return 'No active game.';
    if (afterLevel < game.currentLevel) {
      return 'Completed and active levels cannot be changed.';
    }
    if (durationMins != 10 && durationMins != 15 && durationMins != 20) {
      return 'Level duration must be 10, 15 or 20 minutes.';
    }
    if (sb <= 0 || bb <= sb) {
      return 'Blinds must increase — small blind first, then big blind.';
    }
    if (ante != null && ante < 0) return 'Ante cannot be negative.';
    _pushUndo();
    final inserted = BlindLevel(
      level: afterLevel + 1,
      sb: sb,
      bb: bb,
      ante: ante,
      durationMins: durationMins,
    );
    final levels = <BlindLevel>[];
    var appended = false;
    for (final l in game.structure.levels) {
      final shifted = BlindLevel(
        level: l.level >= afterLevel + 1 ? l.level + 1 : l.level,
        sb: l.sb,
        bb: l.bb,
        ante: l.ante,
        durationMins: l.durationMins,
      );
      levels.add(shifted);
      if (l.level == afterLevel) {
        levels.add(inserted);
        appended = true;
      }
    }
    // Appending below the current last level: no anchor row exists.
    if (!appended) levels.add(inserted);
    _currentGame = game.copyWith(
      structure: _structureWithLevels(game.structure, levels),
    );
    addAuditRecord(
      'structure_insert_level',
      'Inserted level ${inserted.level}: '
          '$sb/$bb${ante != null ? ' ante $ante' : ''}, $durationMins min.',
    );
    addAnnouncement(
      'Level ${inserted.level} inserted ($sb/$bb, $durationMins min).',
      false,
    );
    return null;
  }

  void confirmFinalTable({
    List<({String playerId, int seat})>? seating,
    String? dealerId,
  }) {
    final finalists = _currentGame!.players
        .where((p) => p.active && !p.eliminated)
        .toList();
    // The final table seats at most 9 players (checklist 13-025).
    if (finalists.length > 9) return;
    _pushUndo();
    final players = seating == null
        ? _currentGame!.players
        : _currentGame!.players.map((p) {
            for (final s in seating) {
              if (s.playerId == p.id) {
                return p.copyWith(seat: s.seat, table: 1);
              }
            }
            return p;
          }).toList();
    // Initial dealer for the final table: the admin's choice, or a random
    // finalist (Tech spec §12.3 — the redraw picks the seats AND the
    // initial dealer-button position).
    final dealer =
        (dealerId != null
            ? finalists.where((f) => f.id == dealerId).firstOrNull
            : null) ??
        (finalists.isEmpty
            ? null
            : finalists[Random().nextInt(finalists.length)]);
    final currentLevelData = _currentGame!.currentLevelData;
    final durationMins =
        currentLevelData?.durationMins ?? _currentGame!.structure.levelDuration;
    _currentGame = _currentGame!.copyWith(
      players: players,
      status: LiveGameStatus.running,
      timerRunning: true,
      finalTableRedrawCompleted: true,
      dealerPlayerId: dealer?.id,
      // The paused level is over — restart the clock for the current level.
      secondsRemaining: durationMins * 60,
      levelEndTime: DateTime.now().add(Duration(minutes: durationMins)),
    );
    addAnnouncement('Final table! Please take your new seats.', true);
    if (dealer != null) {
      addAnnouncement('Dealer on the final table: ${dealer.name}.', true);
    }
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Final table reached',
        body:
            '${_currentGame!.settings.name} — 9 players remain, seats redrawn.',
        type: NotificationType.game,
        link: '/player-live',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Validation message explaining why completion was refused (User Flow
  /// §4.17 "System validates that every paid position has one player"). Set
  /// by [recordFinishOrder] when the recorded finish order fails
  /// [validateCompletion]; cleared again on the next attempt.
  String? _completionError;
  String? get completionError => _completionError;

  /// Validates that the tournament can be completed cleanly (User Flow
  /// §4.17). Returns an error message, or null when everything checks out:
  ///
  /// - every eliminated player carries a finish position,
  /// - no two players share the same finishing position,
  /// - every paid place defined by structure.prizes (places 1..N) is
  ///   assigned to exactly one player,
  /// - a winner exists (place 1).
  ///
  /// Evaluated prospectively from the current state, so it can be called
  /// before [recordFinishOrder] commits anything.
  String? validateCompletion() {
    final game = _currentGame;
    if (game == null) return 'No active game.';
    final eliminated = game.players.where((p) => p.eliminated).toList()
      ..sort(
        (a, b) => (b.eliminationPos ?? 0).compareTo(a.eliminationPos ?? 0),
      );
    final prospectiveOrder = [
      ...eliminated.map((p) => p.id),
      ...game.activePlayers.map((p) => p.id),
    ];
    return _validateCompletionState(game, prospectiveOrder);
  }

  /// Shared §4.17 validator over an explicit finish order (first-out first).
  String? _validateCompletionState(LiveGame game, List<String> order) {
    final unpositioned = game.players
        .where((p) => p.eliminated && p.eliminationPos == null)
        .length;
    if (unpositioned > 0) {
      return '$unpositioned eliminated player'
          '${unpositioned == 1 ? ' has' : 's have'} no recorded finish position.';
    }
    final placeHolders = <int, String>{};
    for (final p in game.players.where((p) => p.eliminated)) {
      final clash = placeHolders[p.eliminationPos!];
      if (clash != null) {
        return 'Players $clash and ${p.name} both hold place '
            '${p.eliminationPos}.';
      }
      placeHolders[p.eliminationPos!] = p.id;
    }
    final activeCount = game.activePlayers.length;
    var survivorRank = 0;
    final seen = <String>{};
    for (final id in order) {
      if (!seen.add(id)) continue;
      final p = game.players.where((x) => x.id == id).firstOrNull;
      if (p == null || p.eliminated) continue;
      survivorRank++;
      final pos = activeCount - survivorRank + 1;
      final clash = placeHolders[pos];
      if (clash != null && clash != id) {
        return 'Two players are recorded for place $pos.';
      }
      placeHolders[pos] = id;
    }
    final paidPlaces = game.structure.prizes.length;
    for (var place = 1; place <= paidPlaces; place++) {
      if (!placeHolders.containsKey(place)) {
        return 'Paid place $place has no player assigned.';
      }
    }
    return null;
  }

  /// Updates the payout prizes (for custom deals/chops before finalizing results).
  void updatePrizes(List<Prize> customPrizes) {
    if (_currentGame == null) return;
    _pushUndo();
    _currentGame = _currentGame!.copyWith(
      structure: _currentGame!.structure.copyWith(
        prizes: customPrizes,
      ),
    );
    _syncGroupGame();
    notifyListeners();
  }

  void recordFinishOrder(List<String> order) {
    final game = _currentGame;
    if (game == null) return;
    final error = _validateCompletionState(game, order);
    if (error != null) {
      _completionError = error;
      addAnnouncement(error, false);
      notifyListeners();
      return;
    }
    _completionError = null;
    _pushUndo();
    _currentGame = _currentGame!.copyWith(
      finishOrder: order,
      status: LiveGameStatus.completed,
      timerRunning: false,
    );
    _syncGroupGame();
    // This device settled the game — write my own result now (other members'
    // devices record theirs when the completed doc reaches them).
    if (_backendUp) {
      _maybeRecordOwnResult(_currentGame!);
    } else {
      // Offline fallback: aggregate locally so stats still move in demo mode.
      _recordOwnResultOffline(_currentGame!);
    }
    addAnnouncement('We have a winner!', true);
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Tournament finished',
        body: '${_currentGame!.settings.name} is over — see the final results.',
        type: NotificationType.result,
        link: '/result-podium',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void addAnnouncement(String text, [bool speakOutLoud = true]) {
    final announcement = Announcement(
      id: 'ann-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      timestamp: DateTime.now(),
    );
    _currentGame = _currentGame!.copyWith(
      announcements: [..._currentGame!.announcements, announcement],
    );
    // Speak key tournament announcements when the admin has enabled voice
    // and this device is the Audio Master (checklist §15.4). Failure is
    // swallowed by VoiceService (15-054).
    if (speakOutLoud && _voiceEnabled && thisDeviceIsAudioMaster) {
      VoiceService.instance.speak(text);
    }
    notifyListeners();
  }

  /// Appends a new audit record to the history. This history is never deleted.
  void addAuditRecord(String type, String details) {
    if (_currentGame == null || _user == null) return;
    final record = AuditRecord(
      id: 'audit-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: type,
      actor: _user!.name,
      details: details,
    );
    _currentGame = _currentGame!.copyWith(
      auditHistory: [..._currentGame!.auditHistory, record],
    );
    notifyListeners();
  }

  // ── Chat & polls ───────────────────────────────────────────────────────────
  /// Maximum message length (checklist 08-009).
  static const int maxChatMessageLength = 1000;

  /// Basic spam rate limit (tech spec §14.1): at most
  /// [_chatBurstLimit] messages per sliding [_chatBurstWindow].
  static const int _chatBurstLimit = 8;
  static const Duration _chatBurstWindow = Duration(seconds: 30);
  final Map<String, List<DateTime>> _chatSendTimes = <String, List<DateTime>>{};

  /// True when [userId] has exceeded the chat burst limit right now.
  bool _chatRateLimited(String userId) {
    final now = DateTime.now();
    final times = _chatSendTimes.putIfAbsent(userId, () => <DateTime>[]);
    times.removeWhere((t) => now.difference(t) > _chatBurstWindow);
    return times.length >= _chatBurstLimit;
  }

  void _recordChatSend(String userId) {
    _chatSendTimes.putIfAbsent(userId, () => <DateTime>[]).add(DateTime.now());
  }

  // ── Chat unread tracking (Tech Spec §14.1) ────────────────────────────────
  /// Last-read timestamp per chat scope key. Scope keys are `group:<gid>`
  /// for the group hub chat and `game:<gid>` for a live game's chat.
  final Map<String, DateTime> _chatLastRead = {};

  /// Marks an entire chat scope as read up to now so its unread counter
  /// resets. Callers (chat sheet / group hub screens) invoke this when the
  /// conversation becomes visible.
  void markChatRead(String scopeKey) {
    _chatLastRead[scopeKey] = DateTime.now();
    notifyListeners();
  }

  /// Unread count over one chat list: non-deleted messages authored by
  /// someone else, posted after the scope's last-read timestamp.
  int _unreadChatCount(String scopeKey, List<ChatMessage> messages) {
    final uid = _user?.id;
    if (uid == null) return 0;
    final lastRead = _chatLastRead[scopeKey];
    var count = 0;
    for (final m in messages) {
      if (m.deleted || m.authorId == uid) continue;
      if (lastRead != null && !m.timestamp.isAfter(lastRead)) continue;
      count++;
    }
    return count;
  }

  /// Number of unread group-chat messages for group [gid] (Tech Spec §14.1).
  int unreadGroupChatCount(String gid) =>
      _unreadChatCount('group:$gid', _currentGroup.chat);

  /// Number of unread messages in game [gid]'s chat (Tech Spec §14.1). Reads
  /// the current live game when it matches, otherwise the mirrored copy kept
  /// on the group bundle.
  int unreadGameChatCount(String gid) {
    final LiveGame? target = _currentGame?.id == gid
        ? _currentGame
        : _currentGroup.games.where((g) => g.id == gid).firstOrNull;
    return _unreadChatCount('game:$gid', target?.chat ?? const []);
  }

  /// Sends a chat message. Returns a validation message when the message
  /// cannot be sent (empty, too long or rate limited), or null on success.
  String? sendChatMessage(String? gameId, String body) {
    if (_user == null) return null;
    // Spec §22: sanitize input before processing.
    final sanitized = Sanitization.sanitizeChat(body);
    if (sanitized.isEmpty) return 'Message cannot be empty.';
    if (sanitized.length > maxChatMessageLength) {
      return 'Message is too long — maximum $maxChatMessageLength characters.';
    }
    if (_chatRateLimited(_user!.id)) {
      return 'You are sending messages too quickly — wait a moment and try again.';
    }
    _recordChatSend(_user!.id);
    final msg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      authorId: _user!.id,
      authorName: _user!.name,
      body: sanitized,
      timestamp: DateTime.now(),
      deleted: false,
    );
    if (gameId != null && gameId == _currentGame!.id) {
      _currentGame = _currentGame!.copyWith(chat: [..._currentGame!.chat, msg]);
      if (!_isGameAuthority) {
        // Game chat is a plain list in the doc — append via array union so
        // member devices never rewrite the whole document.
        _patchActiveGame({
          'chat': FieldValue.arrayUnion([chatMessageToMap(msg)]),
        });
      }
    } else {
      _setGroup(_currentGroup.copyWith(chat: [..._currentGroup.chat, msg]));
      _postGroupChat(msg);
    }
    notifyListeners();
    return null;
  }

  /// Persists a group-chat message to `groups/{gid}/chat` (fire-and-forget).
  void _postGroupChat(ChatMessage msg) {
    if (!_backendUp || _currentGroupId == null) return;
    unawaited(_repo
        .sendGroupChatMessage(_currentGroupId!, msg)
        .catchError((Object e) => debugPrint('sendGroupChat failed: $e')));
  }

  /// Persists a poll create/update to `groups/{gid}/polls` (fire-and-forget).
  void _persistPoll(Poll poll) {
    if (!_backendUp || _currentGroupId == null) return;
    unawaited(_repo
        .savePoll(_currentGroupId!, poll)
        .catchError((Object e) => debugPrint('savePoll failed: $e')));
  }

  void deleteMessage(String msgId) {
    _setGroup(
      _currentGroup.copyWith(
        chat: _currentGroup.chat
            .map((m) => m.id == msgId ? m.copyWith(deleted: true) : m)
            .toList(),
      ),
    );
    _currentGame = _currentGame!.copyWith(
      chat: _currentGame!.chat
          .map((m) => m.id == msgId ? m.copyWith(deleted: true) : m)
          .toList(),
    );
    notifyListeners();
    if (_backendUp && _currentGroupId != null) {
      unawaited(_repo
          .markChatMessageDeleted(_currentGroupId!, msgId)
          .catchError((Object e) => debugPrint('deleteMessage failed: $e')));
    }
  }

  /// Creates a poll. Returns a validation message when the question or options
  /// are invalid (empty or duplicate options rejected — checklist 08-015/08-016),
  /// or null on success.
  String? createPoll(
    String question,
    List<String> options, {
    bool multi = false,
  }) {
    // Spec §22: sanitize all poll input.
    final trimmedQuestion = Sanitization.sanitizePollQuestion(question);
    final trimmed = options
        .map((o) => Sanitization.sanitizePollOption(o))
        .where((o) => o.isNotEmpty)
        .toList();
    if (trimmedQuestion.isEmpty) return 'Poll needs a question.';
    if (trimmed.length < 2) return 'Poll needs at least two options.';
    if (trimmed.length > 10) return 'Polls support at most ten options.';
    final unique = <String>{};
    for (final o in trimmed) {
      if (!unique.add(o.toLowerCase())) {
        return 'Duplicate options are not allowed.';
      }
    }
    final poll = Poll(
      id: 'poll-${DateTime.now().millisecondsSinceEpoch}',
      question: trimmedQuestion,
      options: trimmed,
      votes: const {},
      closed: false,
      createdAt: DateTime.now(),
      multi: multi,
    );
    _setGroup(_currentGroup.copyWith(polls: [..._currentGroup.polls, poll]));
    _persistPoll(poll);
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'New poll',
        body: trimmedQuestion,
        type: NotificationType.admin,
        link: '/group',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
    return null;
  }

  /// Records a vote. For single-choice polls [selected] holds one option;
  /// for multi-choice polls it holds every option the member ticked.
  void votePoll(String pollId, List<String> selected) {
    final userId = _user?.id;
    if (userId == null) return;
    Poll? updated;
    _setGroup(
      _currentGroup.copyWith(
        polls: _currentGroup.polls.map((p) {
          if (p.id != pollId || p.closed) return p;
          final kept = p.multi
              ? selected
              : selected.isNotEmpty
              ? [selected.first]
              : <String>[];
          updated = Poll(
            id: p.id,
            question: p.question,
            options: p.options,
            votes: {...p.votes, userId: kept},
            closed: p.closed,
            createdAt: p.createdAt,
            multi: p.multi,
          );
          return updated!;
        }).toList(),
      ),
    );
    if (updated != null) _persistPoll(updated!);
    notifyListeners();
  }

  /// Admin closes a poll so it no longer accepts votes (checklist 08-022/08-023).
  void closePoll(String pollId) {
    Poll? closedPoll;
    _setGroup(
      _currentGroup.copyWith(
        polls: _currentGroup.polls
            .map(
              (p) => p.id == pollId
                  ? (closedPoll = Poll(
                      id: p.id,
                      question: p.question,
                      options: p.options,
                      votes: p.votes,
                      closed: true,
                      createdAt: p.createdAt,
                      multi: p.multi,
                    ))
                  : p,
            )
            .toList(),
      ),
    );
    if (closedPoll != null) {
      final poll = closedPoll!;
      _persistPoll(poll);
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Poll closed',
          body: poll.question,
          type: NotificationType.admin,
          link: '/group',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  /// Whether the RSVP change deadline (1 hour before scheduled start,
  /// 07-011/07-012, UAT-025) has passed for the current game.
  bool get rsvpCutoffPassed => _currentGame?.settings.rsvpCutoffPassed ?? false;

  /// Sets (or clears) the signed-in member's RSVP for a game — the one open on
  /// screen, or any game in the current group (e.g. tapped from the chat invite
  /// card). Re-selecting the response the member already holds is a no-op; a
  /// different response is persisted and stays selected after the round-trip.
  void setRSVP(Rsvp? rsvp, {String? gameId}) {
    final userId = _user?.id;
    if (userId == null) return;

    final targetId = gameId ?? _currentGame?.id;
    if (targetId == null) return;

    final isCurrent = _currentGame?.id == targetId;
    final target = isCurrent
        ? _currentGame
        : _currentGroup.games.where((g) => g.id == targetId).firstOrNull;
    if (target == null) return;
    if (target.settings.rsvpCutoffPassed) return;

    // No-op when the member already holds exactly this response — a tap on the
    // already-selected button must not churn a write or flicker the UI.
    final mine = target.players.where((p) => p.id == userId).firstOrNull;
    if (mine != null && mine.rsvp == rsvp) return;

    LiveGame applyRsvp(LiveGame g) {
      final onRoster = g.players.any((p) => p.id == userId);
      // A member who joined the group *after* this game was created is not on
      // the seeded roster yet — add them when they answer the invite.
      final players = onRoster
          ? g.players
              .map((p) => p.id == userId ? p.copyWith(rsvp: rsvp) : p)
              .toList()
          : [...g.players, _memberAsPlayer(userId, rsvp)];
      var updated = g.copyWith(players: players);
      updated = _syncGuestSlots(updated, userId, rsvp?.guestCount ?? 0);
      updated = _reconcileExcessGuestSlots(updated, userId, rsvp?.guestCount ?? 0);
      return updated;
    }

    final before = target;
    final after = applyRsvp(target);

    if (isCurrent) {
      _currentGame = after;
      // Members write only their own fields via dot-path so concurrent admin
      // edits are never clobbered (locked architecture §writes). The admin's
      // whole-doc save is handled by _syncGameToCloud on notifyListeners.
      if (!_isGameAuthority) {
        _patchActiveGame(_rsvpDotPatch(before, after));
      }
    } else {
      // RSVP on a group game that isn't the one open on screen (chat invite
      // card). Persist the same scoped member patch against that game doc so
      // the selection survives the live-bundle round-trip.
      _patchGroupGame(targetId, _rsvpDotPatch(before, after));
    }

    // Notify the admin of RSVP changes (spec §8 notification triggers).
    if (_currentGroup.ownerId != userId) {
      final name = mine?.name ?? _user?.name ?? '';
      final playerName = name.isEmpty ? 'A member' : name;
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'RSVP update',
          body: '$playerName is ${rsvp?.label ?? 'no response'}.',
          type: NotificationType.rsvp,
          link: '/invitation',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }

    // Keep the group's copy of the game in sync so hub badges update at once.
    _setGroup(
      _currentGroup.copyWith(
        games: _currentGroup.games
            .map((g) => g.id == targetId ? applyRsvp(g) : g)
            .toList(),
      ),
    );
    notifyListeners();
  }

  /// Member/guest-safe field patch on *any* game in the current group — not
  /// just the one wired into [_cloudGameContext]. Used for RSVPs posted from
  /// the chat invite card.
  void _patchGroupGame(String gameId, Map<String, dynamic> dotPaths) {
    if (!_backendUp || _user == null || dotPaths.isEmpty) return;
    final g = _currentGroup.games.where((g) => g.id == gameId).firstOrNull;
    final gid = (g != null && g.groupId.isNotEmpty) ? g.groupId : _currentGroupId;
    if (gid == null) return;
    unawaited(_repo
        .patchGame(gid, gameId, dotPaths)
        .catchError((Object e) => debugPrint('patchGame(group) failed: $e')));
  }

  /// A roster [Player] for the signed-in member, from the group roster. Used
  /// when a member RSVPs to a game created before they joined the group.
  Player _memberAsPlayer(String userId, Rsvp? rsvp) {
    final m = _currentGroup.members.where((x) => x.id == userId).firstOrNull;
    return Player(
      id: userId,
      name: m?.name ?? _user?.name ?? '',
      isGuest: false,
      rsvp: rsvp,
      checkedIn: false,
      confirmed: false,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: 0,
      seat: 0,
      active: true,
    );
  }

  /// Builds the dot-path patch describing an RSVP change: the member's own
  /// `players.{id}` entry plus the guest-slot rows their +N count creates,
  /// updates or removes. A member new to the roster is written whole; an
  /// existing one gets a field-level `players.{id}.rsvp` patch.
  Map<String, dynamic> _rsvpDotPatch(LiveGame before, LiveGame after) {
    final patch = <String, dynamic>{};
    final uid = _user?.id;

    final beforePlayer = before.players.where((p) => p.id == uid).firstOrNull;
    final afterPlayer = after.players.where((p) => p.id == uid).firstOrNull;
    if (afterPlayer != null) {
      if (beforePlayer == null) {
        patch['players.$uid'] = playerToMap(afterPlayer);
      } else if (afterPlayer.rsvp?.name != beforePlayer.rsvp?.name) {
        patch['players.$uid.rsvp'] = afterPlayer.rsvp?.name;
      }
    }

    final beforeSlots = {for (final s in before.guestSlots) s.id: s};
    for (var i = 0; i < after.guestSlots.length; i++) {
      final s = after.guestSlots[i];
      final old = beforeSlots[s.id];
      if (old == null) {
        patch['guestSlots.${s.id}'] = {
          ...guestSlotToMap(s),
          'orderIndex': i,
        };
      } else if (old.guestName != s.guestName ||
          old.status != s.status ||
          old.slot != s.slot) {
        patch['guestSlots.${s.id}'] = {
          ...guestSlotToMap(s),
          'orderIndex': i,
        };
      }
    }
    for (final s in before.guestSlots) {
      if (!after.guestSlots.any((n) => n.id == s.id)) {
        patch['guestSlots.${s.id}'] = FieldValue.delete();
      }
    }
    return patch;
  }

  /// Keeps the persisted [GuestSlot] records aligned with a member's "Going +N"
  /// RSVP count (checklist 07-014). Missing slots are created as unclaimed;
  /// slots beyond the new count that are still unclaimed are removed. Claimed
  /// slots are never deleted here — excess claims are handled by
  /// [_reconcileExcessGuestSlots].
  LiveGame _syncGuestSlots(LiveGame game, String userId, int newCount) {
    final existing = game.guestSlots
        .where((s) => s.inviterId == userId)
        .toList();
    final claimed = existing.where((s) => !s.available).toList();
    final keep = <GuestSlot>[];
    for (var slot = 1; slot <= newCount; slot++) {
      final existingForSlot = existing.where((s) => s.slot == slot).firstOrNull;
      if (existingForSlot != null) {
        keep.add(existingForSlot);
      } else {
        keep.add(
          GuestSlot(
            id: 'slot-${DateTime.now().millisecondsSinceEpoch}-$userId-$slot',
            inviterId: userId,
            slot: slot,
            status: GuestSlotStatus.unclaimed,
          ),
        );
      }
    }
    // Unclaimed slots beyond the new count are dropped; claimed ones remain.
    final rest = game.guestSlots
        .where(
          (s) =>
              s.inviterId != userId ||
              (s.inviterId == userId && s.slot > newCount && !s.available),
        )
        .toList();
    final slots = [
      ...rest,
      ...keep,
      ...claimed.where((s) => s.slot <= newCount),
    ];
    // Deduplicate (id-based) to be safe.
    final seen = <String>{};
    final merged = <GuestSlot>[];
    for (final s in slots) {
      if (seen.add(s.id)) merged.add(s);
    }
    return game.copyWith(guestSlots: merged);
  }

  /// Checklist 07-015 / 20-030 / 20-031: when a player lowers their guest
  /// count, unused guest slots beyond the new count are released safely.
  /// Unconfirmed requests are removed; guests already confirmed on an excess
  /// slot are kept but surfaced to the administrator as a conflict.
  LiveGame _reconcileExcessGuestSlots(
    LiveGame game,
    String userId,
    int newCount,
  ) {
    final excess = game.players
        .where(
          (p) =>
              p.isGuest &&
              p.inviterId == userId &&
              (p.guestSlot ?? 0) > newCount,
        )
        .toList();
    if (excess.isEmpty) return game;
    final excessIds = excess.map((p) => p.id).toSet();
    final confirmed = excess.where((p) => p.confirmed).toList();
    final updated = game.copyWith(
      players: game.players.where((p) => !excessIds.contains(p.id)).toList(),
      pendingGuests: game.pendingGuests
          .where((p) => !excessIds.contains(p.id))
          .toList(),
    );
    if (confirmed.isNotEmpty) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'RSVP reduced after guest check-in',
          body:
              '${confirmed.map((p) => p.name).join(', ')} '
              '${confirmed.length == 1 ? 'is' : 'are'} confirmed on a guest slot '
              'the inviter just removed. Review before seating.',
          type: NotificationType.admin,
          link: '/check-in',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
    return updated;
  }

  /// Sends an RSVP reminder to every member who has not yet responded
  /// (checklist 04-023/04-024). Pushes a notification per member so the
  /// (dummy) inbox shows the reminders, and logs the action for the admin.
  void sendRSVPReminders(String gameId) {
    final game = gameById(gameId);
    if (game == null || _user == null) return;
    final target = _currentGame?.id == gameId ? _currentGame : game;
    if (target == null) return;
    final pending = target.players
        .where((p) => !p.isGuest && p.rsvp == null)
        .toList();
    if (pending.isEmpty) return;
    for (final _ in pending) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'RSVP reminder',
          body:
              'You haven\'t responded to ${target.settings.name} '
              '(${target.settings.date} at ${target.settings.time}). '
              'Let the host know if you\'re in.',
          type: NotificationType.rsvp,
          link: '/invitation',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
    addAuditRecord(
      'rsvp_reminder',
      'Reminder sent to ${pending.length} member'
          '${pending.length == 1 ? '' : 's'} who have not responded.',
    );
    addAnnouncement(
      'Reminder sent to ${pending.length} player'
      '${pending.length == 1 ? '' : 's'} without an RSVP.',
      false,
    );
    notifyListeners();
  }

  // ── Code lookup ────────────────────────────────────────────────────────────

  /// Extracts a bare join code from anything the user might enter: a raw code
  /// (`FRIDAY7`), a full invite link
  /// (`https://poker-night-tools.web.app/join-group?code=FRIDAY7`), a game link
  /// (`.../game/FP2608`) or a QR payload. Returns an upper-cased `[A-Z0-9]`
  /// string, or `''` when nothing code-like is present.
  static String extractJoinCode(String input) {
    var s = input.trim();
    if (s.isEmpty) return '';

    final uri = Uri.tryParse(s);
    if (uri != null && uri.hasScheme) {
      final q = uri.queryParameters['code'];
      if (q != null && q.isNotEmpty) {
        s = q;
      } else if (uri.pathSegments.isNotEmpty) {
        // `/game/FP2608`, `/join/FP2608`, `/join-group/FRIDAY7`
        s = uri.pathSegments.last;
      }
    } else if (s.contains('code=')) {
      s = s.split('code=').last.split('&').first;
    } else if (s.contains('/')) {
      s = s.split('/').last.split('?').first.split('#').first;
    }

    return s.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  }

  /// Classifies a join code (or invite link / QR payload) as a group code, a
  /// game code or a TV code — without joining or subscribing to anything.
  /// The unified join screen uses this to route guests and signed-in users to
  /// the right flow. Safe to call unauthenticated (join codes are world-
  /// readable by design).
  Future<JoinCodeResolution> resolveJoinCode(String input) async {
    final code = extractJoinCode(input);
    if (code.isEmpty) return const JoinCodeResolution(JoinCodeKind.notFound, '');
    if (!_backendUp) return JoinCodeResolution(JoinCodeKind.error, code);
    if (!_consumeCodeLookupSlot()) {
      return JoinCodeResolution(JoinCodeKind.rateLimited, code);
    }
    try {
      final data = await _repo.peekJoinCode(code);
      if (data == null) return JoinCodeResolution(JoinCodeKind.notFound, code);
      final gameId = data['gameId'] as String?;
      if (gameId == null || gameId.isEmpty) {
        return JoinCodeResolution(JoinCodeKind.group, code);
      }
      final kind = (data['kind'] as String?) ?? 'game';
      return JoinCodeResolution(
        kind == 'tv' ? JoinCodeKind.tv : JoinCodeKind.game,
        code,
      );
    } catch (e) {
      debugPrint('resolveJoinCode failed: $e');
      return JoinCodeResolution(JoinCodeKind.error, code);
    }
  }

  /// Sliding-window throttle for join-code lookups (spec §22 rate limits).
  /// Firestore rules cannot count reads, so the client caps itself at 10
  /// lookups per minute per device.
  final List<DateTime> _codeLookupTimes = <DateTime>[];
  bool _consumeCodeLookupSlot() {
    final now = DateTime.now();
    _codeLookupTimes
        .removeWhere((t) => now.difference(t) > const Duration(minutes: 1));
    if (_codeLookupTimes.length >= 10) return false;
    _codeLookupTimes.add(now);
    return true;
  }

  /// Resolves a public/TV join code through Firestore and subscribes the
  /// matching feed. TVs and guests read the sanitized `publicGames/{id}`
  /// projections (never the raw game doc); the returned result tells the
  /// caller which screen to open. Returns [CodeLookupResult.notFound] for
  /// unknown codes or when no backend is available.
  Future<CodeLookupResult> enterGameCode(String code) async {
    if (!_backendUp) return CodeLookupResult.notFound;
    if (!_consumeCodeLookupSlot()) return CodeLookupResult.rateLimited;
    try {
      final hit = await _repo.findGameByCode(code);
      if (hit == null) return CodeLookupResult.notFound;

      _lookupSub?.cancel();
      if (hit.kind == 'game' &&
          (_isGameAuthority || _currentGroup.id == hit.gid)) {
        // Group members with dashboard access can follow the raw document.
        _lookupSub =
            _repo.gameDocSnapshots(hit.gid, hit.gameId, isAdmin: _isGameAuthority).listen((snap) {
          final data = snap.data();
          if (!snap.exists || data == null) return;
          try {
            _clearUndoStack();
            final remote =
                liveGameFromFirestoreDoc(Map<String, dynamic>.from(data));
            _currentGame = remote;
            _lastSavedGame = remote;
            notifyListeners();
          } catch (e) {
            debugPrint('code-lookup game decode failed: $e');
          }
        }, onError: (Object e) => debugPrint('lookup stream error: $e'));
      } else {
        // Guests / TVs: sanitized projection feed.
        final projectionKey = hit.kind == 'tv' ? 'tv' : 'guest';
        _lookupSub = _repo.publicGameStream(hit.gameId).listen((doc) {
          final payload = doc[projectionKey];
          if (payload == null) return;
          try {
            _clearUndoStack();
            _currentGame = liveGameFromMap(
              Map<String, dynamic>.from(payload as Map),
            );
            notifyListeners();
          } catch (e) {
            debugPrint('projection decode failed: $e');
          }
        }, onError: (Object e) => debugPrint('public stream error: $e'));
      }
      return hit.kind == 'tv'
          ? CodeLookupResult.tv
          : CodeLookupResult.game;
    } catch (e) {
      debugPrint('enterGameCode failed: $e');
      return CodeLookupResult.notFound;
    }
  }

  // ── Cash game ──────────────────────────────────────────────────────────────
  CashSession? _cashSession;
  CashSession? get cashSession => _cashSession;

  /// Completed cash sessions shown in history (checklist 16-002). Cloud-backed
  /// per group via [completedCashSessionsStream]; locally appended when the
  /// backend is unavailable.
  List<CashSession> _cashHistory = const [];
  List<CashSession> get cashHistory => List.unmodifiable(_cashHistory);

  void startCashGame(CashSessionSettings settings, List<String> playerNames) {
    _cashSession = CashSession(
      id: 'cash-${DateTime.now().millisecondsSinceEpoch}',
      settings: settings,
      isCompleted: false,
      startTime: DateTime.now(),
      players: List.generate(
        playerNames.length,
        (i) => CashPlayer(
          id: 'cp-${DateTime.now().millisecondsSinceEpoch}-$i',
          name: playerNames[i],
          stack: settings.minBuyIn,
          totalBuyIns: settings.minBuyIn,
          buyInCount: 1,
          cashedOut: 0,
        ),
      ),
    );
    notifyListeners();
  }

  /// Records a cash buy-in / rebuy for a player (or adds a brand-new player).
  /// Returns a validation message when the amount falls outside the session's
  /// [CashSessionSettings.minBuyIn]..[CashSessionSettings.maxBuyIn] bounds, or
  /// null on success.
  String? cashBuyIn(
    String playerIdOrName,
    double amount, {
    bool isNew = false,
  }) {
    final session = _cashSession;
    if (session == null) return 'No active cash session.';
    if (amount <= 0) return 'Amount must be positive.';
    final min = session.settings.minBuyIn;
    final max = session.settings.maxBuyIn;
    // No currency symbols in the primary interface (User Flow spec §3.4).
    if (amount < min) return 'Minimum buy-in is $min.';
    if (amount > max) return 'Maximum buy-in is $max.';
    if (isNew) {
      _cashSession = session.copyWith(
        players: [
          ...session.players,
          CashPlayer(
            id: 'cp-${DateTime.now().millisecondsSinceEpoch}',
            name: playerIdOrName,
            stack: amount,
            totalBuyIns: amount,
            buyInCount: 1,
            cashedOut: 0,
          ),
        ],
      );
    } else {
      _cashSession = session.copyWith(
        players: session.players
            .map(
              (p) => p.id == playerIdOrName
                  ? p.copyWith(
                      stack: p.stack + amount,
                      totalBuyIns: p.totalBuyIns + amount,
                      buyInCount: p.buyInCount + 1,
                    )
                  : p,
            )
            .toList(),
      );
    }
    notifyListeners();
    return null;
  }

  void cashCashOut(String playerId, double amount) {
    final session = _cashSession;
    if (session == null) return;
    _cashSession = session.copyWith(
      players: session.players
          .map(
            (p) =>
                p.id == playerId ? p.copyWith(cashedOut: amount, stack: 0) : p,
          )
          .toList(),
    );
    notifyListeners();
  }

  /// Corrects an incorrectly entered buy-in, top-up or cash-out (checklist
  /// 17-020 / 17-028 / 20-047). All totals are recomputed from the corrected
  /// fields; stack/total/buyInCount/cashedOut that are null are left as-is.
  void cashEditPlayer(
    String playerId, {
    double? stack,
    double? totalBuyIns,
    int? buyInCount,
    double? cashedOut,
  }) {
    final session = _cashSession;
    if (session == null) return;
    _cashSession = session.copyWith(
      players: session.players
          .map(
            (p) => p.id == playerId
                ? CashPlayer(
                    id: p.id,
                    name: p.name,
                    stack: stack ?? p.stack,
                    totalBuyIns: totalBuyIns ?? p.totalBuyIns,
                    buyInCount: buyInCount ?? p.buyInCount,
                    cashedOut: cashedOut ?? p.cashedOut,
                  )
                : p,
          )
          .toList(),
    );
    notifyListeners();
  }

  void endCashGame({String? unresolvedNote}) {
    final session = _cashSession;
    if (session == null) return;
    _cashSession = session.copyWith(
      isCompleted: true,
      unresolvedNote: unresolvedNote,
    );
    _cashHistory = [_cashSession!, ..._cashHistory];
    notifyListeners();
    final gid = _currentGroupId ?? _currentGame?.groupId;
    final uid = _repo.currentUid;
    if (_backendUp && gid != null && uid != null) {
      unawaited(_repo
          .saveCashSession(gid, _cashSession!)
          .catchError(
              (Object e) => debugPrint('saveCashSession failed: $e')));
    }
    clearCashSession();
  }

  /// Discards the current cash session so a fresh game can be started.
  void clearCashSession() {
    _cashSession = null;
    RecoveryService.clearCashSession();
    notifyListeners();
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  /// Replaced by the live inbox stream once user data is subscribed; empty
  /// until then (no demo seed — a fresh account starts clean).
  List<AppNotification> _notifications = const [];
  List<AppNotification> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.read).length;

  void markAllRead() {
    _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.markAllNotificationsRead(uid)
          .catchError((Object e) => debugPrint('markAllRead failed: $e')));
    }
  }

  void markNotificationRead(String id) {
    _notifications = _notifications
        .map((n) => n.id == id ? n.copyWith(read: true) : n)
        .toList();
    notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.markNotificationRead(uid, id)
          .catchError((Object e) => debugPrint('markRead failed: $e')));
    }
  }

  /// Prepends a notification locally and stages it in the current group's
  /// outbox (`groups/{gid}/notifications/{id}`). The Cloud Function fans it
  /// out to every member's inbox (C6) — clients can no longer write directly
  /// into arbitrary recipients' inboxes.
  void pushNotification(AppNotification notification) {
    _notifications = [notification, ..._notifications];
    notifyListeners();
    if (_backendUp) {
      final gid = _currentGroup.id;
      if (gid.isNotEmpty) {
        unawaited(_repo.stageGroupNotification(gid, notification)
            .catchError((Object e) => debugPrint('stageGroupNotification failed: $e')));
      }
    }
  }

  // ── Voice & misc ───────────────────────────────────────────────────────────
  bool _voiceEnabled = true;
  bool get voiceEnabled => _voiceEnabled;

  void toggleVoice() {
    _voiceEnabled = !_voiceEnabled;
    _persistPref('voiceEnabled', _voiceEnabled);
    notifyListeners();
  }

  void setVoiceEnabled(bool value) {
    if (_voiceEnabled == value) return;
    _voiceEnabled = value;
    _persistPref('voiceEnabled', _voiceEnabled);
    notifyListeners();
  }

  /// Audio Master (checklist 15-041/15-042/15-043): the administrator manually
  /// selects which connected device plays announcements. When no master is
  /// chosen (`null`) every device with voice enabled may announce — the
  /// backwards-compatible default.
  ///
  /// `_audioMasterDeviceId` is `null` when no master is selected; otherwise it
  /// holds the device id of the chosen Audio Master. `thisDeviceIsAudioMaster`
  /// is true when this device may speak.
  String? _audioMasterDeviceId;

  /// Stable per-session id for the current browser/device.
  String? _thisDeviceId;
  String get thisDeviceId =>
      _thisDeviceId ??= 'dev-${DateTime.now().millisecondsSinceEpoch}';

  String? get audioMasterDeviceId => _audioMasterDeviceId;

  /// Whether announcements may play on this device (no master selected, or
  /// this device is the master).
  bool get thisDeviceIsAudioMaster => _audioMasterDeviceId == thisDeviceId;

  /// Selects this device as the Audio Master. Only this device will announce.
  void setAudioMasterDevice() {
    if (_audioMasterDeviceId == thisDeviceId) return;
    _audioMasterDeviceId = thisDeviceId;
    notifyListeners();
  }

  /// Clears the Audio Master selection — every device with voice enabled may
  /// announce again.
  void clearAudioMasterDevice() {
    if (_audioMasterDeviceId == null) return;
    _audioMasterDeviceId = null;
    notifyListeners();
  }

  /// Whether eliminated-player names are announced (checklist 15-053) —
  /// optional per tournament and disabled by default.
  bool get announceEliminations =>
      _currentGame?.settings.announceEliminations ?? false;

  void setAnnounceEliminations(bool value) {
    final game = _currentGame;
    if (game == null || game.settings.announceEliminations == value) return;
    _currentGame = game.copyWith(
      settings: game.settings.copyWith(announceEliminations: value),
    );
    _syncGroupGame();
    notifyListeners();
  }

  // ── Account preferences (settings screen) ─────────────────────────────────
  bool _soundsEnabled = true;
  bool get soundsEnabled => _soundsEnabled;

  void setSoundsEnabled(bool value) {
    if (_soundsEnabled == value) return;
    _soundsEnabled = value;
    notifyListeners();
  }

  bool _compactSummary = false;
  bool get compactSummary => _compactSummary;

  void setCompactSummary(bool value) {
    if (_compactSummary == value) return;
    _compactSummary = value;
    notifyListeners();
  }

  /// SMS/text notifications for RSVPs and game events.
  bool _smsEnabled = false;
  bool get smsEnabled => _smsEnabled;

  void setSmsEnabled(bool value) {
    if (_smsEnabled == value) return;
    _smsEnabled = value;
    notifyListeners();
  }

  /// Theme preference: one of "dark", "light", "system".
  String _themePreference = 'dark';
  String get themePreference => _themePreference;

  void setThemePreference(String value) {
    if (_themePreference == value) return;
    _themePreference = value;
    _persistPref('themePreference', value);
    notifyListeners();
  }

  /// Color theme id — one of the [ThemePalettes.all] ids.
  String _colorTheme = 'red';
  String get colorTheme => _colorTheme;

  void setColorTheme(String value) {
    if (_colorTheme == value) return;
    _colorTheme = value;
    _persistPref('colorTheme', value);
    notifyListeners();
  }

  /// Id of the chip set used as the default for new tournaments; null = the
  /// standard set.
  String? _defaultChipSetId;
  String? get defaultChipSetId => _defaultChipSetId;

  void setDefaultChipSet(String? id) {
    if (_defaultChipSetId == id) return;
    _defaultChipSetId = id;
    notifyListeners();
  }

  /// Selected avatar colour index (into the app's avatar palette).
  int _avatarColorIndex = 0;
  int get avatarColorIndex => _avatarColorIndex;

  void setAvatarColor(int index) {
    if (_avatarColorIndex == index) return;
    _avatarColorIndex = index;
    notifyListeners();
  }

  /// Deletes the signed-in account (profile doc, membership mirrors, auth
  /// user) and invalidates every session so a deleted account cannot keep
  /// using a stale live game (checklist 05-014). Returns a friendly error
  /// message on failure — notably `requires-recent-login`, where the caller
  /// must re-authenticate first.
  Future<String?> deleteAccount() async {
    try {
      await _repo.deleteAccount();
    } on fa.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'For security please sign in again before deleting your account.';
      }
      return e.message ?? 'Could not delete the account. Please try again.';
    }
    _user = null;
    _currentGame = null;
    _cashSession = null;
    _guestSession = null;
    _restoredFromRecovery = false;
    _recoveryTime = null;
    RecoveryService.clearGame();
    RecoveryService.clearCashSession();
    RecoveryService.clearGuestSession();
    notifyListeners();
    return null;
  }

  String _guestCode = '';
  String get guestCode => _guestCode;

  void setGuestCode(String code) {
    _guestCode = code;
    notifyListeners();
  }

  // ── Drawer state ───────────────────────────────────────────────────────────
  bool _isDrawerOpen = false;
  bool get isDrawerOpen => _isDrawerOpen;

  void openDrawer() {
    if (_isDrawerOpen) return;
    _isDrawerOpen = true;
    notifyListeners();
  }

  void closeDrawer() {
    if (!_isDrawerOpen) return;
    _isDrawerOpen = false;
    notifyListeners();
  }

  void toggleDrawer() {
    _isDrawerOpen = !_isDrawerOpen;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _serverTimeRecalibration?.cancel();
    _authSub?.cancel();
    _connectivitySub?.cancel();
    _teardownUserData();
    super.dispose();
  }
}
