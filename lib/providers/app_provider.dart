import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';
import '../models/tournament_preset.dart';
import '../models/user.dart';
import '../models/chip_color.dart';
import '../utils/formatters.dart';
import '../utils/mock_data.dart';
import '../utils/tournament_engine.dart';
import '../utils/voice_service.dart';
import '../services/recovery_service.dart';

/// One future-level edit produced by the admin structure editor.
typedef LevelEdit = ({int level, int sb, int bb, int? ante, int durationMins});

/// Result of looking up a game / TV code.
enum CodeLookupResult { game, tv, notFound }

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
  }

  bool _isTickUpdate = false;

  // ── Connectivity / recovery state (offline indicator, checklist 12-075) ────
  bool _isOffline = false;
  bool get isOffline => _isOffline;

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
    notifyListeners();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_isTickUpdate) return;
    _lastSync = DateTime.now();
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

  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    notifyListeners();
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
  bool get hasOfflineConflict {
    if (_currentGame == null || !_restoredFromRecovery) return false;
    final cloudGame = _currentGroup.games.where((g) => g.id == _currentGame!.id).firstOrNull;
    if (cloudGame == null) return false;
    // Simple mock comparison: if local has more audit records or different level, it's out of sync
    return _currentGame!.auditHistory.length != cloudGame.auditHistory.length ||
           _currentGame!.currentLevel != cloudGame.currentLevel;
  }

  void resolveOfflineConflict({required bool keepLocal}) {
    if (_currentGame != null) {
      if (keepLocal) {
        // Sync local up to cloud
        final games = _currentGroup.games.toList();
        final idx = games.indexWhere((g) => g.id == _currentGame!.id);
        if (idx != -1) {
          games[idx] = _currentGame!;
          _currentGroup = _currentGroup.copyWith(games: games);
        }
      } else {
        // Revert local down to cloud
        final cloudGame = _currentGroup.games.where((g) => g.id == _currentGame!.id).firstOrNull;
        if (cloudGame != null) {
          _currentGame = cloudGame;
          RecoveryService.saveGame(cloudGame);
        }
      }
    }
    _restoredFromRecovery = false;
    notifyListeners();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  AppUser? _user;
  AppUser? get user => _user;

  bool get isAuthenticated => _user != null;

  /// Shared demo password for every seeded mock account.
  static const seedPassword = 'password123';

  /// Emails → passwords for every account that can sign in (seeded members
  /// plus anything created via `register`). Acts as the dummy auth store.
  final Map<String, String> _passwords = {
    for (final m in MockData.members) m.email.toLowerCase(): seedPassword,
  };

  int _userIdSeq = 100;

  bool login(String email, String password) {
    final key = email.trim().toLowerCase();
    final found = MockData.members.where((m) => m.email.toLowerCase() == key);
    if (found.isNotEmpty && _passwords[key] == password) {
      _user = found.first;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Returns `true` when a new account was created, `false` when the email
  /// is already registered (duplicate).
  bool register(String name, String email, String password) {
    final key = email.trim().toLowerCase();
    if (MockData.members.any((m) => m.email.toLowerCase() == key) ||
        _passwords.containsKey(key)) {
      return false;
    }
    final user = AppUser(
      id: 'u-${_userIdSeq++}',
      name: name.trim(),
      email: email.trim(),
      isAdmin: false,
      stats: const UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
    );
    _passwords[key] = password;
    _user = user;
    notifyListeners();
    return true;
  }

  /// True when an account exists for [email], so a reset "link" can be sent.
  bool requestPasswordReset(String email) {
    final key = email.trim().toLowerCase();
    return MockData.members.any((m) => m.email.toLowerCase() == key) ||
        _passwords.containsKey(key);
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  // ── Chip Sets ──────────────────────────────────────────────────────────────
  final List<({String id, String name, List<ChipColor> chips})> _savedChipSets = [
    (id: 'cs-default', name: 'Home Set (4 colour)', chips: MockData.defaultChipSet),
  ];

  List<({String id, String name, List<ChipColor> chips})> get savedChipSets => _savedChipSets;

  void saveChipSet(String id, String name, List<ChipColor> chips) {
    final idx = _savedChipSets.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _savedChipSets[idx] = (id: id, name: name, chips: chips);
    } else {
      _savedChipSets.add((id: id, name: name, chips: chips));
    }
    notifyListeners();
  }

  void deleteChipSet(String id) {
    if (id == 'cs-default') return; // protect default
    _savedChipSets.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Updates the signed-in member's display details (profile screen).
  void updateProfile({String? name, String? email}) {
    final current = _user;
    if (current == null) return;
    _user = current.copyWith(
      name: name?.trim().isNotEmpty == true ? name!.trim() : current.name,
      email: email?.trim().isNotEmpty == true ? email!.trim() : current.email,
    );
    notifyListeners();
  }

  // ── Tournament Presets (checklist §9.1) ──────────────────────────────────
  final List<TournamentPreset> _presets = [
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
  }

  void deletePreset(String id) {
    _presets.removeWhere((p) => p.id == id);
    notifyListeners();
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

    final scored = _presets
        .map((p) => (preset: p, score: scoreFor(p)))
        .where((e) => e.score >= 15)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(2).map((e) => e.preset).toList();
  }

  // ── Group ──────────────────────────────────────────────────────────────────
  Group _currentGroup = MockData.demoGroup;
  Group get currentGroup => _currentGroup;

  void setCurrentGroup(Group group) {
    _currentGroup = group;
    notifyListeners();
  }

  bool joinGroup(String code) {
    if (code.trim().toUpperCase() == MockData.demoGroup.joinCode) {
      _currentGroup = MockData.demoGroup;
      notifyListeners();
      return true;
    }
    return false;
  }

  Group createGroup(String name) {
    final group = Group(
      id: 'grp-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      joinCode: Formatters.generateCode(),
      ownerId: _user?.id ?? 'u1',
      members: _user != null ? [_user!] : const [],
      games: const [],
      chat: const [],
      polls: const [],
      notifications: const [],
    );
    _currentGroup = group;
    notifyListeners();
    return group;
  }

  void toggleAdminRole(String userId, bool isAdmin) {
    if (_user?.id != _currentGroup.ownerId) return; // Only owner can do this
    if (userId == _currentGroup.ownerId) return; // Cannot change owner's role
    final members = _currentGroup.members.map((m) {
      if (m.id == userId) {
        return m.copyWith(isAdmin: isAdmin);
      }
      return m;
    }).toList();
    _currentGroup = _currentGroup.copyWith(members: members);
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
    final structure = TournamentEngine.generate(TournamentParams(
      players: settings.players,
      durationHours: settings.durationHours,
      buyIn: settings.buyIn,
      chipSet: settings.chipSet,
      rebuys: settings.rebuys,
      rebuysCloseLevel: settings.rebuysCloseLevel,
      reEntry: settings.reEntry,
      addOn: settings.addOn,
      anteEnabled: settings.anteEnabled,
      anteAfterLevel: settings.anteAfterLevel,
      koEnabled: settings.koEnabled,
      koAmount: settings.koAmount,
      organizerPct: settings.organizerPct,
    ));
    // Seed participants from the group roster so the check-in screen lists the
    // real members first; extra seats become placeholder players.
    final seeded = List<Player>.generate(settings.players, (i) {
      final member = i < _currentGroup.members.length ? _currentGroup.members[i] : null;
      return Player(
        id: member?.id ?? 'p-${i + 1}-${DateTime.now().millisecondsSinceEpoch}',
        name: member?.name ?? 'Player ${i + 1}',
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
      );
    });
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
    final games = _currentGroup.games;
    final idx = games.indexWhere((g) => g.id == game.id);
    _currentGroup = _currentGroup.copyWith(
      games: idx == -1 ? [...games, game] : ([...games]..[idx] = game),
    );
  }

  void updateGameStatus(LiveGameStatus status) {
    _currentGame = _currentGame!.copyWith(status: status);
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
    final addonText = game.settings.addOn 
        ? 'Add-on: Yes' 
        : 'No add-on';

    final card = ChatMessage(
      id: 'pinned-${DateTime.now().millisecondsSinceEpoch}',
      authorId: _user!.id,
      authorName: _user!.name,
      body: '${game.settings.name} — ${game.settings.date} at ${game.settings.time}\n'
          'Buy-in: ${game.settings.buyIn} · Code: ${game.publicCode}\n'
          '$anteText · $rebuyText · $addonText',
      timestamp: DateTime.now(),
      deleted: false,
      pinned: true,
    );
    _currentGame = game.copyWith(
      status: LiveGameStatus.published,
      chat: [...game.chat, card],
      originalLevels: List.of(game.structure.levels),
    );
    _currentGroup = _currentGroup.copyWith(
      chat: [..._currentGroup.chat, card],
      games: _currentGroup.games
          .map((g) => g.id == game.id
              ? g.copyWith(
                  status: LiveGameStatus.published,
                  chat: [...g.chat, card],
                  originalLevels: List.of(game.structure.levels),
                )
              : g)
          .toList(),
    );
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
        body: '${game.settings.name} is open for RSVP — '
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
        prev.koAmount != s.koAmount;

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
      final structure = TournamentEngine.generate(TournamentParams(
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
      ));
      _currentGame = game.copyWith(
        settings: s,
        structure: structure,
        secondsRemaining: structure.levelDuration * 60,
        speedRecommendation: null,
        players: clearRsvps ? game.players.map((p) => p.copyWithClearRsvp()).toList() : game.players,
      );
      edits.add('structure regenerated');
    } else {
      _currentGame = game.copyWith(
        settings: s,
        players: clearRsvps ? game.players.map((p) => p.copyWithClearRsvp()).toList() : game.players,
      );
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

  /// Records that the end-of-rebuy settlement has been confirmed. From this
  /// point the public label reads "Prize Pool" instead of "Estimated Prize
  /// Pool" (12-068, 14-038/14-039, 15-009, 15-030), and no more rebuys,
  /// re-entries or add-ons are possible (12-065).
  void confirmSettlement() {
    _currentGame = _currentGame!.copyWith(
      settlementConfirmed: true,
      pendingGuests: const [],
    );
    notifyListeners();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────
  Timer? _ticker;

  /// Marks already announced per level (checklist 15-047/15-048) so the
  /// five-minute and one-minute warnings fire only once per level.
  final Set<String> _levelAnnouncementMarks = <String>{};

  void _announceLevelMark(int remaining) {
    final game = _currentGame;
    if (game == null || !game.timerRunning) return;
    final level = game.currentLevel;
    final mark = '$level';
    if (remaining == 300 && !_levelAnnouncementMarks.contains('$mark:300')) {
      _levelAnnouncementMarks.add('$mark:300');
      addAnnouncement('Five minutes remaining in level $level.', true);
    } else if (remaining == 60 && !_levelAnnouncementMarks.contains('$mark:60')) {
      _levelAnnouncementMarks.add('$mark:60');
      addAnnouncement('One minute remaining in level $level.', true);
    }
  }

  void _startTick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentGame == null || !_currentGame!.timerRunning) return;
      final remaining = _currentGame!.secondsRemaining - 1;
      if (remaining <= 0) {
        final atRebuyClose = _currentGame!.settings.rebuys &&
            _currentGame!.currentLevel == _currentGame!.settings.rebuysCloseLevel;
        _currentGame = _currentGame!.copyWith(
          secondsRemaining: 0,
          timerRunning: false,
          status: atRebuyClose ? LiveGameStatus.rebuypause : _currentGame!.status,
        );
        addAnnouncement(atRebuyClose
            ? 'Rebuys are now closed. Add-ons are available.'
            : 'Level ${_currentGame!.currentLevel} has ended.');
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

  /// Lightweight live recommendation (technical §11.4): compare the expected
  /// elimination pace against what actually happened so far. If the field is
  /// falling behind schedule the tournament runs long → suggest shorter future
  /// levels; if it is ahead → suggest longer ones. Never mutates blinds, level
  /// count or duration on its own.
  /// Manually forces recalculation of finish time/speed recommendations
  void forceEvaluateSpeedRecommendation() {
    _evaluateSpeedRecommendation();
    addAnnouncement('Recalculated speed recommendation.', false);
  }

  void _evaluateSpeedRecommendation() {
    final game = _currentGame;
    if (game == null || game.status != LiveGameStatus.running) return;
    final total = game.players.length;
    if (total < 2) return;
    final levels = game.structure.levels.length;
    final progress = (game.currentLevel - 1) / levels;
    final expectedEliminated = (total * progress).round();
    final eliminated = total - game.activePlayers.length;
    final diff = eliminated - expectedEliminated;
    final threshold = (total * 0.15).ceil();
    SpeedRecommendation? rec;
    if (diff < -threshold) {
      rec = SpeedRecommendation.speedUp;
    } else if (diff > threshold) {
      rec = SpeedRecommendation.slowDown;
    }
    if (rec == game.speedRecommendation) return;
    _currentGame = game.copyWith(speedRecommendation: rec);
    notifyListeners();
  }

  void startTimer() {
    _levelAnnouncementMarks.clear();
    final level = _currentGame!.currentLevelData;
    _currentGame = _currentGame!.copyWith(
      timerRunning: true,
      status: LiveGameStatus.running,
    );
    addAnnouncement(
      'Tournament starts. Level ${_currentGame!.currentLevel}. '
      'Blinds ${level?.sb ?? 0} and ${level?.bb ?? 0}.',
      true,
    );
  }

  void pauseTimer() {
    _currentGame = _currentGame!.copyWith(
      timerRunning: false,
      status: LiveGameStatus.paused,
    );
    notifyListeners();
  }

  void resumeTimer() {
    _currentGame = _currentGame!.copyWith(
      timerRunning: true,
      status: LiveGameStatus.running,
    );
    notifyListeners();
  }

  void nextLevel() {
    final next = _currentGame!.currentLevel + 1;
    if (next > _currentGame!.structure.levels.length) return;
    _pushUndo();
    _levelAnnouncementMarks.clear();
    final level = _currentGame!.structure.levels[next - 1];
    _currentGame = _currentGame!.copyWith(
      currentLevel: next,
      secondsRemaining: _currentGame!.structure.levelDuration * 60,
      timerRunning: true,
      status: LiveGameStatus.running,
      speedRecommendation: null,
    );
    addAnnouncement(
      'Level $next. Blinds ${level.sb} and ${level.bb}'
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
    _currentGame = game.copyWith(
      secondsRemaining: game.structure.levelDuration * 60,
      timerRunning: true,
      status: LiveGameStatus.running,
      speedRecommendation: null,
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
    final bounty = _currentGame!.settings.koEnabled ? _currentGame!.settings.koAmount : 0;
    final updated = _currentGame!.players
        .map((p) {
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
        })
        .toList();
    final remaining = updated.where((p) => p.active).length;
    final wasMoreThanNine = _currentGame!.players.where((p) => p.active).length > 9;
    if (remaining == 9 && wasMoreThanNine) {
      _currentGame = _currentGame!.copyWith(
        players: updated,
        status: LiveGameStatus.finaltable,
        timerRunning: false,
      );
    } else {
      _currentGame = _currentGame!.copyWith(players: updated);
    }
    final p = _currentGame!.players.firstWhere((pl) => pl.id == playerId);
    // Elimination names are optional per tournament and disabled by default
    // (15-053) — spoken only when the admin enabled the setting.
    final speakElimination = _currentGame!.settings.announceEliminations;
    if (koRecipientId != null && bounty > 0) {
      final koPlayer =
          _currentGame!.players.where((pl) => pl.id == koRecipientId).firstOrNull;
      addAnnouncement(
        '${p.name} eliminated by ${koPlayer?.name ?? '?'} — $bounty bounty awarded.',
        speakElimination,
      );
    } else {
      addAnnouncement('${p.name} eliminated.', speakElimination);
    }
  }

  /// Explicitly corrects a past elimination without using Undo (which is unsafe
  /// if dependent actions occurred). Adds a compensating audit action.
  void correctElimination(String playerId) {
    if (_currentGame == null) return;
    
    // We intentionally bypass `_pushUndo()` for audit preservation, 
    // but the spec says "never delete audit history", so we just append.
    final players = _currentGame!.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(eliminated: false, eliminationPos: null);
      }
      return p;
    }).toList();

    _currentGame = _currentGame!.copyWith(players: players);
    final correctedPlayer = players.firstWhere((p) => p.id == playerId);
    
    addAuditRecord('correction', 'Corrected elimination for ${correctedPlayer.name}');
    addAnnouncement('Correction: ${correctedPlayer.name} has been reinstated to the game.', false);
  }

  void grantRebuy(String playerId) {
    _pushUndo();
    final rebuyStack = _currentGame!.structure.rebuyStack;
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map((p) => p.id == playerId
              ? p.copyWith(
                  rebuys: p.rebuys + 1,
                  eliminated: false,
                  active: true,
                )
              : p)
          .toList(),
      totalChipsInPlay: _currentGame!.totalChipsInPlay + rebuyStack,
    );
    // Recalculate prize pool/prizes after money enters the game.
    // This updates only prizePool, organizerAmount and prizes on the structure,
    // leaving blind levels and any manual edits completely intact.
    _updatePrizePool();
  }

  /// Records a re-entry (checklist §12.5): a separate, secondary option that
  /// grants the approved entry stack and is tracked independently of rebuys
  /// (12-046/12-047). Closes with late registration/rebuys (12-049), which is
  /// enforced by only showing the action while rebuys are still open.
  void grantReEntry(String playerId) {
    _pushUndo();
    final entryStack = _currentGame!.structure.startingStack;
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map((p) => p.id == playerId
              ? p.copyWith(
                  reEntries: p.reEntries + 1,
                  eliminated: false,
                  active: true,
                )
              : p)
          .toList(),
      totalChipsInPlay: _currentGame!.totalChipsInPlay + entryStack,
    );
    _updatePrizePool();
  }

  void grantAddOn(String playerId) {
    _pushUndo();
    final addOnStack = _currentGame!.structure.addOnStack;
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map((p) =>
              p.id == playerId && !p.hasAddOn ? p.copyWith(hasAddOn: true) : p)
          .toList(),
      totalChipsInPlay: _currentGame!.totalChipsInPlay + addOnStack,
    );
    // Recalculate prize pool/prizes after money enters the game.
    _updatePrizePool();
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
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map((p) => p.id == playerId
              ? p.copyWith(checkedIn: true, confirmed: false)
              : p)
          .toList(),
    );
    notifyListeners();
  }

  void checkInPlayer(String playerId) {
    _pushUndo();
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map((p) => p.id == playerId
              ? p.copyWith(checkedIn: true, confirmed: true)
              : p)
          .toList(),
    );
  }

  void cancelCheckIn(String playerId) {
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map((p) => p.id == playerId
              ? p.copyWith(checkedIn: false, confirmed: false)
              : p)
          .toList(),
    );
    notifyListeners();
  }

  void confirmGuest(String guestId) {
    _pushUndo();
    final game = _currentGame!;
    
    // Find a generic placeholder to replace (so we don't exceed expected active players)
    final placeholderIdx = game.players.indexWhere((p) => !p.checkedIn && !p.isGuest && p.name.startsWith('Player'));
    
    final updated = game.players
        .where((p) => placeholderIdx == -1 || p.id != game.players[placeholderIdx].id)
        .map((p) => p.id == guestId
            ? p.copyWith(confirmed: true, checkedIn: true, active: true)
            : p)
        .toList();
        
    final extraChips = placeholderIdx == -1 ? game.structure.startingStack : 0;
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
  }

  /// Admin rejects a pending guest request — the guest is removed from the
  /// players list and no longer sits at the table (07-026). Their slot is
  /// freed so another guest can claim it.
  void rejectGuest(String guestId) {
    _pushUndo();
    final guest = _currentGame!.players.where((p) => p.id == guestId).firstOrNull;
    final inviterId = guest?.inviterId;
    final guestSlot = guest?.guestSlot;
    final canFree = guest != null && inviterId != null && guestSlot != null;
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .where((p) => p.id != guestId)
          .toList(),
      pendingGuests: _currentGame!.pendingGuests
          .where((p) => p.id != guestId)
          .toList(),
      guestSlots: canFree
          ? _currentGame!.guestSlots
              .map((s) =>
                  s.inviterId == inviterId && s.slot == guestSlot
                      ? s.copyWith(
                          guestName: null,
                          status: GuestSlotStatus.unclaimed,
                        )
                      : s)
              .toList()
          : _currentGame!.guestSlots,
    );
    addAnnouncement('Guest request rejected.', false);
  }

  /// Marks the matching guest slot as reserved/claimed so the free-slot count
  /// on the guest flow and invitation screens stays accurate.
  List<GuestSlot> _markSlotReserved(
    List<GuestSlot> slots,
    String inviterId,
    int slot, {
    String? name,
  }) {
    final updated = slots.map((s) {
      if (s.inviterId == inviterId && s.slot == slot && s.available) {
        return s.copyWith(guestName: name, status: GuestSlotStatus.reserved);
      }
      return s;
    }).toList();
    // Safety net: the inviter somehow has no persisted slot record.
    if (!updated.any((s) => s.inviterId == inviterId && s.slot == slot)) {
      updated.add(GuestSlot(
        id: 'slot-${DateTime.now().millisecondsSinceEpoch}-$inviterId-$slot',
        inviterId: inviterId,
        slot: slot,
        guestName: name,
        status: GuestSlotStatus.reserved,
      ));
    }
    return updated;
  }

  /// Guest flow: attach a brand-new guest to a game and mark them pending.
  /// The guest's own session is persisted so the same device can recover the
  /// request after a refresh (checklist 07-030).
  void requestGuestCheckIn(String name, String inviterId, int slot) {
    _pushUndo();
    final id = 'g-${DateTime.now().millisecondsSinceEpoch}';
    final guest = Player(
      id: id,
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
    _currentGame = _currentGame!.copyWith(
      players: [..._currentGame!.players, guest],
      pendingGuests: [..._currentGame!.pendingGuests, guest],
      guestSlots: _markSlotReserved(
        _currentGame!.guestSlots,
        inviterId,
        slot,
        name: name.trim(),
      ),
    );
    _saveGuestSession(
      GuestSession(
        gameId: _currentGame!.id,
        name: name.trim(),
        inviterId: inviterId,
        slot: slot,
      ),
    );

    // The guest stays pending until the host confirms them at check-in
    // (spec §6 "waiting for admin confirmation", checklist 07-027/07-028).
    notifyListeners();
  }

  // ── Guest session (device-local, checklist 07-030) ─────────────────────────
  GuestSession? _guestSession;
  GuestSession? get guestSession => _guestSession;

  /// True while this device holds an approved/requested guest session
  /// (used by the router guard to allow guests into player-live without an
  /// account — checklist 15-014).
  bool get hasGuestSession => _guestSession != null;

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
  /// Max 9 per table; 10+ checked-in players create multiple balanced tables.
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

    // Balanced tables: ceil(count / 9), distributed as evenly as possible.
    final count = ordered.length;
    final tableCount = (count / 9).ceil();
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
    final dealer = seated.isEmpty ? null : seated[Random().nextInt(seated.length)];

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
      addAnnouncement(
        'Seating drawn. ${dealer.name} deals first.',
        true,
      );
    }
    notifyListeners();
  }

  /// Marks the generated physical seating as confirmed before play starts
  /// (checklist 13-013). Seats remain editable afterwards via the move flow.
  void confirmSeating() {
    if (_currentGame == null) return;
    _currentGame = _currentGame!.copyWith(seatingConfirmed: true);
    addAnnouncement('Seating confirmed. Shuffle up and deal!', true);
  }

  /// Assigns one player to an explicit (table, seat) — used by Manual seating
  /// (13-002) and validated to prevent duplicate seats (13-021). Clearing the
  /// previous confirmation forces a re-confirm of the physical layout.
  String? assignSeat(String playerId, int table, int seat) {
    final game = _currentGame;
    if (game == null) return null;
    if (table < 1 || seat < 1) return 'Choose a valid table and seat.';
    final occupied = game.players.any((p) =>
        p.id != playerId && p.table == table && p.seat == seat && !p.eliminated);
    if (occupied) return 'That seat is already taken — choose another.';
    _pushUndo();
    _currentGame = game.copyWith(
      players: game.players
          .map((p) =>
              p.id == playerId ? p.copyWith(table: table, seat: seat) : p)
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
    final sortedByCount = tables.toList()..sort((a, b) => counts[a]!.compareTo(counts[b]!));
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
    final occupied = game.players.any((p) =>
        p.id != rec.fromPlayerId &&
        p.table == rec.toTable &&
        p.seat == rec.toSeat &&
        !p.eliminated);
    if (occupied) {
      _pendingSeatMove = null;
      notifyListeners();
      return;
    }
    _pushUndo();
    _currentGame = game.copyWith(
      players: game.players
          .map((p) => p.id == rec.fromPlayerId
              ? p.copyWith(table: rec.toTable, seat: rec.toSeat)
              : p)
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
    final live = game.status == LiveGameStatus.running ||
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
      chipsToRemove += game.structure.startingStack;
    }

    final newPlayers = game.players.where((pl) => pl.id != playerId).toList();

    _currentGame = game.copyWith(
      players: newPlayers,
      totalChipsInPlay: (game.totalChipsInPlay - chipsToRemove).clamp(0, 99999999),
    );

    _updatePrizePool();
    _syncGroupGame();
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
    final tableCount = (game.activePlayers.length / 9).ceil().clamp(1, 9);
    var bestTable = 1;
    var bestCount = 1 << 30;
    for (var t = 1; t <= tableCount; t++) {
      final c = counts[t] ?? 0;
      if (c < 9 && c < bestCount) {
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
    final totalReEntries = game.players.fold<int>(0, (sum, p) => sum + p.reEntries);
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
    addAuditRecord('structure_edit', 'Paid places overridden to ${count ?? 'auto'}');
    notifyListeners();
  }

  /// Orders players so guests are placed immediately after (together) or far
  /// from (separate) their inviter, used to steer the round-robin deal.
  List<Player> _orderKeepingGuests(List<Player> players, {required bool together}) {
    final registered = players.where((p) => !p.isGuest).toList();
    final guests = players.where((p) => p.isGuest).toList();
    if (together) {
      final result = <Player>[];
      for (final r in registered) {
        result.add(r);
        result.addAll(guests.where((g) => g.inviterId == r.id));
      }
      // Any guest whose inviter isn't seated still gets placed.
      result.addAll(guests.where((g) => !registered.any((r) => r.id == g.inviterId)));
      return result;
    }
    // Separate: interleave registered and guests so inviter/guest land apart.
    final result = <Player>[];
    final maxLen = registered.length > guests.length ? registered.length : guests.length;
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
    final clamped = newDuration < 10 ? 10 : (newDuration > 20 ? 20 : newDuration);
    // Apply the new duration to the current and future levels; already-finished
    // levels keep their original durations (checklist 12-037/12-040).
    final levels = structure.levels
        .map((l) => l.level >= game.currentLevel
            ? BlindLevel(
                level: l.level,
                sb: l.sb,
                bb: l.bb,
                ante: l.ante,
                durationMins: clamped,
              )
            : l)
        .toList();
    _currentGame = game.copyWith(
      speedRecommendation: null,
      structure: TournamentStructure(
        startingStack: structure.startingStack,
        chipPlan: structure.chipPlan,
        rebuyStack: structure.rebuyStack,
        rebuyChipPlan: structure.rebuyChipPlan,
        addOnStack: structure.addOnStack,
        addOnChipPlan: structure.addOnChipPlan,
        levels: levels,
        levelDuration: clamped,
        expectedFinishMins: structure.expectedFinishMins,
        prizes: structure.prizes,
        prizePool: structure.prizePool,
        organizerAmount: structure.organizerAmount,
        colorUpInstructions: structure.colorUpInstructions,
        warnings: structure.warnings,
      ),
      secondsRemaining:
          game.secondsRemaining > clamped * 60 ? clamped * 60 : game.secondsRemaining,
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
  void recalculateStructure() {
    final game = _currentGame;
    if (game == null) return;
    _pushUndo();

    final confirmed = game.players.where((p) => p.confirmed).length;
    final count = confirmed >= 2 ? confirmed : game.settings.players;
    final s = game.settings;
    final structure = TournamentEngine.generate(TournamentParams(
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
    ));

    final newLevel = game.currentLevel.clamp(1, structure.levels.length);
    _currentGame = game.copyWith(
      settings: GameSettings(
        name: s.name,
        date: s.date,
        time: s.time,
        location: s.location,
        players: count,
        durationHours: s.durationHours,
        buyIn: s.buyIn,
        koEnabled: s.koEnabled,
        koAmount: s.koAmount,
        rebuys: s.rebuys,
        rebuysCloseLevel: s.rebuysCloseLevel,
        reEntry: s.reEntry,
        addOn: s.addOn,
        anteEnabled: s.anteEnabled,
        anteAfterLevel: s.anteAfterLevel,
        anteStyle: s.anteStyle,
        organizerPct: s.organizerPct,
        chipSet: s.chipSet,
        chipSetName: s.chipSetName,
      ),
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
      '${renumbered.length == 1 ? '' : 's'} (was ${
          (game.structure.levels.length - prefix.length).clamp(0, 999)})',
    );
    addAnnouncement('Level structure updated by admin.', false);
  }

  void confirmFinalTable({List<({String playerId, int seat})>? seating}) {
    final finalists = _currentGame!.players.where((p) => p.active && !p.eliminated).toList();
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
    final dealer = finalists.isEmpty ? null : finalists[Random().nextInt(finalists.length)];
    _currentGame = _currentGame!.copyWith(
      players: players,
      status: LiveGameStatus.running,
      timerRunning: true,
      dealerPlayerId: dealer?.id,
      // The paused level is over — restart the clock for the current level.
      secondsRemaining: _currentGame!.structure.levelDuration * 60,
    );
    addAnnouncement('Final table! Please take your new seats.', true);
  }

  void recordFinishOrder(List<String> order) {
    _pushUndo();
    _currentGame = _currentGame!.copyWith(
      finishOrder: order,
      status: LiveGameStatus.completed,
      timerRunning: false,
    );
    _syncGroupGame();
    addAnnouncement('We have a winner!', true);
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

  /// Sends a chat message. Returns a validation message when the message
  /// cannot be sent (empty or too long), or null on success.
  String? sendChatMessage(String? gameId, String body) {
    if (_user == null) return null;
    if (body.trim().isEmpty) return 'Message cannot be empty.';
    if (body.trim().length > maxChatMessageLength) {
      return 'Message is too long — maximum $maxChatMessageLength characters.';
    }
    final msg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      authorId: _user!.id,
      authorName: _user!.name,
      body: body.trim(),
      timestamp: DateTime.now(),
      deleted: false,
    );
    if (gameId != null && gameId == _currentGame!.id) {
      _currentGame = _currentGame!.copyWith(chat: [..._currentGame!.chat, msg]);
    } else {
      _currentGroup = _currentGroup.copyWith(chat: [..._currentGroup.chat, msg]);
    }
    notifyListeners();
    return null;
  }

  void deleteMessage(String msgId) {
    _currentGroup = _currentGroup.copyWith(
      chat: _currentGroup.chat
          .map((m) => m.id == msgId ? ChatMessage(
              id: m.id,
              authorId: m.authorId,
              authorName: m.authorName,
              body: m.body,
              timestamp: m.timestamp,
              deleted: true,
            ) : m)
          .toList(),
    );
    _currentGame = _currentGame!.copyWith(
      chat: _currentGame!.chat
          .map((m) => m.id == msgId ? ChatMessage(
              id: m.id,
              authorId: m.authorId,
              authorName: m.authorName,
              body: m.body,
              timestamp: m.timestamp,
              deleted: true,
            ) : m)
          .toList(),
    );
    notifyListeners();
  }

  /// Creates a poll. Returns a validation message when the question or options
  /// are invalid (empty or duplicate options rejected — checklist 08-015/08-016),
  /// or null on success.
  String? createPoll(String question, List<String> options) {
    final trimmedQuestion = question.trim();
    final trimmed = options.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
    if (trimmedQuestion.isEmpty) return 'Poll needs a question.';
    if (trimmed.length < 2) return 'Poll needs at least two options.';
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
    );
    _currentGroup = _currentGroup.copyWith(polls: [..._currentGroup.polls, poll]);
    notifyListeners();
    return null;
  }

  void votePoll(String pollId, String option) {
    final userId = _user?.id;
    if (userId == null) return;
    _currentGroup = _currentGroup.copyWith(
      polls: _currentGroup.polls
          .map((p) => p.id == pollId
              ? Poll(
                  id: p.id,
                  question: p.question,
                  options: p.options,
                  votes: {...p.votes, userId: option},
                  closed: p.closed,
                  createdAt: p.createdAt,
                )
              : p)
          .toList(),
    );
    notifyListeners();
  }

  /// Admin closes a poll so it no longer accepts votes (checklist 08-022/08-023).
  void closePoll(String pollId) {
    _currentGroup = _currentGroup.copyWith(
      polls: _currentGroup.polls
          .map((p) => p.id == pollId
              ? Poll(
                  id: p.id,
                  question: p.question,
                  options: p.options,
                  votes: p.votes,
                  closed: true,
                  createdAt: p.createdAt,
                )
              : p)
          .toList(),
    );
    notifyListeners();
  }

  /// Whether the RSVP change deadline (1 hour before scheduled start,
  /// 07-011/07-012, UAT-025) has passed for the current game.
  bool get rsvpCutoffPassed =>
      _currentGame?.settings.rsvpCutoffPassed ?? false;

  void setRSVP(Rsvp? rsvp, {String? gameId}) {
    final userId = _user?.id;
    if (userId == null) return;
    final target = _currentGame;
    // After the cutoff players can no longer alter their RSVP without admin
    // handling (07-012, UAT-025).
    if (target != null && target.settings.rsvpCutoffPassed) return;
    if (gameId == null) {
      if (_currentGame != null) {
        _currentGame = _currentGame!.copyWith(
          players: _currentGame!.players
              .map((p) => p.id == userId ? p.copyWith(rsvp: rsvp) : p)
              .toList(),
        );
        // Persist named guest slots for the new count so unclaimed seats are
        // visible even before a guest claims them (checklist 07-014).
        _syncGuestSlots(userId, rsvp?.guestCount ?? 0);
        // Lowering the guest count releases extra unused guest slots safely
        // and surfaces a conflict when a confirmed guest exceeds the new count
        // (07-015, 20-030, 20-031).
        _reconcileExcessGuestSlots(userId, rsvp?.guestCount ?? 0);
      }
    }
    // Keep the group's copy of the game in sync so badges update on the hub.
    _currentGroup = _currentGroup.copyWith(
      games: _currentGroup.games
          .map((g) => (gameId != null ? g.id == gameId : _currentGame != null && g.id == _currentGame!.id)
              ? g.copyWith(
                  players: g.players
                      .map((p) => p.id == userId ? p.copyWith(rsvp: rsvp) : p)
                      .toList(),
                )
              : g)
          .toList(),
    );
    notifyListeners();
  }

  /// Keeps the persisted [GuestSlot] records aligned with a member's "Going +N"
  /// RSVP count (checklist 07-014). Missing slots are created as unclaimed;
  /// slots beyond the new count that are still unclaimed are removed. Claimed
  /// slots are never deleted here — excess claims are handled by
  /// [_reconcileExcessGuestSlots].
  void _syncGuestSlots(String userId, int newCount) {
    final game = _currentGame;
    if (game == null) return;
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
        keep.add(GuestSlot(
          id: 'slot-${DateTime.now().millisecondsSinceEpoch}-$userId-$slot',
          inviterId: userId,
          slot: slot,
          status: GuestSlotStatus.unclaimed,
        ));
      }
    }
    // Unclaimed slots beyond the new count are dropped; claimed ones remain.
    final rest = game.guestSlots
        .where((s) =>
            s.inviterId != userId ||
            (s.inviterId == userId && s.slot > newCount && !s.available))
        .toList();
    final slots = [...rest, ...keep, ...claimed.where((s) => s.slot <= newCount)];
    // Deduplicate (id-based) to be safe.
    final seen = <String>{};
    final merged = <GuestSlot>[];
    for (final s in slots) {
      if (seen.add(s.id)) merged.add(s);
    }
    _currentGame = game.copyWith(guestSlots: merged);
  }

  /// Checklist 07-015 / 20-030 / 20-031: when a player lowers their guest
  /// count, unused guest slots beyond the new count are released safely.
  /// Unconfirmed requests are removed; guests already confirmed on an excess
  /// slot are kept but surfaced to the administrator as a conflict.
  void _reconcileExcessGuestSlots(String userId, int newCount) {
    final game = _currentGame;
    if (game == null) return;
    final excess = game.players
        .where((p) => p.isGuest && p.inviterId == userId && (p.guestSlot ?? 0) > newCount)
        .toList();
    if (excess.isEmpty) return;
    final excessIds = excess.map((p) => p.id).toSet();
    final confirmed = excess.where((p) => p.confirmed).toList();
    _currentGame = _currentGame!.copyWith(
      players: game.players.where((p) => !excessIds.contains(p.id)).toList(),
      pendingGuests:
          game.pendingGuests.where((p) => !excessIds.contains(p.id)).toList(),
    );
    if (confirmed.isNotEmpty) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'RSVP reduced after guest check-in',
          body: '${confirmed.map((p) => p.name).join(', ')} '
              '${confirmed.length == 1 ? 'is' : 'are'} confirmed on a guest slot '
              'the inviter just removed. Review before seating.',
          type: NotificationType.admin,
          link: '/check-in',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
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
          body: 'You haven\'t responded to ${target.settings.name} '
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
  CodeLookupResult enterGameCode(String code) {
    final c = code.trim().toUpperCase();
    if (c == MockData.demoGame.publicCode || c == MockData.demoGame.tvCode) {
      _currentGame = MockData.demoGame;
      notifyListeners();
      return c == MockData.demoGame.tvCode ? CodeLookupResult.tv : CodeLookupResult.game;
    }
    return CodeLookupResult.notFound;
  }

  // ── Cash game ──────────────────────────────────────────────────────────────
  CashSession? _cashSession;
  CashSession? get cashSession => _cashSession;

  /// Completed cash sessions shown in history (checklist 16-002). Seeded with
  /// a demo record so the section is populated out of the box.
  List<CashSession> _cashHistory = [
    MockData.demoCashSession.copyWith(
      isCompleted: true,
      players: const [
        CashPlayer(id: 'cp-0', name: 'Daniel', stack: 0, totalBuyIns: 60, buyInCount: 2, cashedOut: 82),
        CashPlayer(id: 'cp-1', name: 'Marcus', stack: 0, totalBuyIns: 20, buyInCount: 1, cashedOut: 14),
        CashPlayer(id: 'cp-2', name: 'Sophia', stack: 0, totalBuyIns: 40, buyInCount: 2, cashedOut: 38),
      ],
    ),
  ];
  List<CashSession> get cashHistory => List.unmodifiable(_cashHistory);

  void startCashGame(CashSessionSettings settings, List<String> playerNames) {
    _cashSession = CashSession(
      id: 'cash-${DateTime.now().millisecondsSinceEpoch}',
      settings: settings,
      isCompleted: false,
      startTime: DateTime.now(),
      players: List.generate(playerNames.length, (i) => CashPlayer(
            id: 'cp-${DateTime.now().millisecondsSinceEpoch}-$i',
            name: playerNames[i],
            stack: settings.minBuyIn,
            totalBuyIns: settings.minBuyIn,
            buyInCount: 1,
            cashedOut: 0,
          )),
    );
    notifyListeners();
  }

  /// Records a cash buy-in / rebuy for a player (or adds a brand-new player).
  /// Returns a validation message when the amount falls outside the session's
  /// [CashSessionSettings.minBuyIn]..[CashSessionSettings.maxBuyIn] bounds, or
  /// null on success.
  String? cashBuyIn(String playerIdOrName, double amount, {bool isNew = false}) {
    final session = _cashSession;
    if (session == null) return 'No active cash session.';
    if (amount <= 0) return 'Amount must be positive.';
    final min = session.settings.minBuyIn;
    final max = session.settings.maxBuyIn;
    if (amount < min) return 'Minimum buy-in is ${session.settings.currency}$min.';
    if (amount > max) return 'Maximum buy-in is ${session.settings.currency}$max.';
    if (isNew) {
      _cashSession = session.copyWith(players: [
        ...session.players,
        CashPlayer(
          id: 'cp-${DateTime.now().millisecondsSinceEpoch}',
          name: playerIdOrName,
          stack: amount,
          totalBuyIns: amount,
          buyInCount: 1,
          cashedOut: 0,
        ),
      ]);
    } else {
      _cashSession = session.copyWith(players: session.players
          .map((p) => p.id == playerIdOrName
              ? p.copyWith(
                  stack: p.stack + amount,
                  totalBuyIns: p.totalBuyIns + amount,
                  buyInCount: p.buyInCount + 1,
                )
              : p)
          .toList());
    }
    notifyListeners();
    return null;
  }

  void cashCashOut(String playerId, double amount) {
    final session = _cashSession;
    if (session == null) return;
    _cashSession = session.copyWith(players: session.players
        .map((p) => p.id == playerId
            ? p.copyWith(cashedOut: amount, stack: 0)
            : p)
        .toList());
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
    _cashSession = session.copyWith(players: session.players
        .map((p) => p.id == playerId
            ? CashPlayer(
                id: p.id,
                name: p.name,
                stack: stack ?? p.stack,
                totalBuyIns: totalBuyIns ?? p.totalBuyIns,
                buyInCount: buyInCount ?? p.buyInCount,
                cashedOut: cashedOut ?? p.cashedOut,
              )
            : p)
        .toList());
    notifyListeners();
  }

  void endCashGame() {
    final session = _cashSession;
    if (session == null) return;
    _cashSession = session.copyWith(isCompleted: true);
    _cashHistory = [_cashSession!, ..._cashHistory];
    notifyListeners();
    clearCashSession();
  }

  /// Discards the current cash session so a fresh game can be started.
  void clearCashSession() {
    _cashSession = null;
    RecoveryService.clearCashSession();
    notifyListeners();
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  List<AppNotification> _notifications = List.of(MockData.demoNotifications);
  List<AppNotification> get notifications => _notifications;

  int get unreadCount =>
      _notifications.where((n) => !n.read).length;

  void markAllRead() {
    _notifications = _notifications
        .map((n) => n.copyWith(read: true))
        .toList();
    notifyListeners();
  }

  void markNotificationRead(String id) {
    _notifications = _notifications
        .map((n) => n.id == id ? n.copyWith(read: true) : n)
        .toList();
    notifyListeners();
  }

  /// Appends a notification to the top of the inbox (checklist §08).
  void pushNotification(AppNotification notification) {
    _notifications = [notification, ..._notifications];
    notifyListeners();
  }

  // ── Voice & misc ───────────────────────────────────────────────────────────
  bool _voiceEnabled = false;
  bool get voiceEnabled => _voiceEnabled;

  void toggleVoice() {
    _voiceEnabled = !_voiceEnabled;
    notifyListeners();
  }

  void setVoiceEnabled(bool value) {
    if (_voiceEnabled == value) return;
    _voiceEnabled = value;
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
  String get thisDeviceId => _thisDeviceId ??= 'dev-${DateTime.now().millisecondsSinceEpoch}';

  String? get audioMasterDeviceId => _audioMasterDeviceId;

  /// Whether announcements may play on this device (no master selected, or
  /// this device is the master).
  bool get thisDeviceIsAudioMaster =>
      _audioMasterDeviceId == null || _audioMasterDeviceId == thisDeviceId;

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

  /// Deletes the signed-in account and invalidates every session so a deleted
  /// account cannot keep using a stale live game (checklist 05-014).
  void deleteAccount() {
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
    super.dispose();
  }
}