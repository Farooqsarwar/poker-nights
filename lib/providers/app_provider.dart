import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';
import '../models/user.dart';
import '../models/chip_color.dart';
import '../utils/formatters.dart';
import '../utils/mock_data.dart';
import '../utils/tournament_engine.dart';
import '../utils/voice_service.dart';
import '../services/recovery_service.dart';

/// Result of looking up a game / TV code.
enum CodeLookupResult { game, tv, notFound }

/// How the admin wants checked-in players distributed to tables/seats
/// (checklist §13.1). Mirrored by the screen's `SeatingMode`.
enum TableSeatingMode { random, manual, keepGuests, separateGuests }

/// Application-level UI state (no business logic / backend).
class AppProvider extends ChangeNotifier {
  AppProvider() {
    _currentGame = null;
    _startTick();
    _loadRecovery();
  }

  bool _isTickUpdate = false;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_isTickUpdate) {
      if (_currentGame != null) {
        RecoveryService.saveGame(_currentGame!);
      } else {
        RecoveryService.clearGame();
      }
    }
  }

  Future<void> _loadRecovery() async {
    final recovered = await RecoveryService.loadGame();
    if (recovered != null) {
      _currentGame = recovered;
      notifyListeners();
    }
  }

  // ── Auth ───────────────────────────────────────────────────────────────────
  AppUser? _user;
  AppUser? get user => _user;

  bool get isAuthenticated => _user != null;

  bool login(String email, String password) {
    final found = MockData.members
        .where((m) => m.email.toLowerCase() == email.trim().toLowerCase())
        .toList();
    if (found.isNotEmpty) {
      _user = found.first;
      notifyListeners();
      return true;
    }
    if (email.trim().toLowerCase() == MockData.demoUser.email) {
      _user = MockData.demoUser;
      notifyListeners();
      return true;
    }
    return false;
  }

  void register(String name, String email, String password) {
    _user = MockData.demoUser;
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }

  // ── Chip Sets ──────────────────────────────────────────────────────────────
  List<({String id, String name, List<ChipColor> chips})> _savedChipSets = [
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

  // ── Game ───────────────────────────────────────────────────────────────────
  LiveGame? _currentGame;
  LiveGame? get currentGame => _currentGame;

  // Undo stack (checklist 12-042/12-043/12-044, technical §11.3). Before every
  // admin mutation we snapshot the previous game; undo pops and restores it.
  static const int _maxUndoDepth = 30;
  final List<LiveGame?> _undoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;

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
      games: idx == -1 ? [...games, game] : [...games]..[idx] = game,
    );
  }

  void updateGameStatus(LiveGameStatus status) {
    _currentGame = _currentGame!.copyWith(status: status);
    _syncGroupGame();
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
  void _evaluateSpeedRecommendation() {
    final game = _currentGame;
    if (game == null || game.structure.levels.isEmpty) return;
    final total = game.players.where((p) => !p.isGuest).length;
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
    if (koRecipientId != null && bounty > 0) {
      final koPlayer =
          _currentGame!.players.where((pl) => pl.id == koRecipientId).firstOrNull;
      addAnnouncement(
        '${p.name} eliminated by ${koPlayer?.name ?? '?'} — $bounty bounty awarded.',
        false,
      );
    } else {
      addAnnouncement('${p.name} eliminated.', false);
    }
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

  void confirmGuest(String guestId) {
    _pushUndo();
    final updated = _currentGame!.players
        .map((p) => p.id == guestId
            ? p.copyWith(confirmed: true, checkedIn: true)
            : p)
        .toList();
    _currentGame = _currentGame!.copyWith(
      players: updated,
      pendingGuests: _currentGame!.pendingGuests
          .where((p) => p.id != guestId)
          .toList(),
    );
    addAnnouncement('Guest confirmed and seated.', false);
  }

  /// Admin rejects a pending guest request — the guest is removed from the
  /// players list and no longer sits at the table (07-026).
  void rejectGuest(String guestId) {
    _pushUndo();
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .where((p) => p.id != guestId)
          .toList(),
      pendingGuests: _currentGame!.pendingGuests
          .where((p) => p.id != guestId)
          .toList(),
    );
    addAnnouncement('Guest request rejected.', false);
  }

  /// Guest flow: attach a brand-new guest to a game and mark them pending.
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
    );
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
    );
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

  void confirmFinalTable({List<({String playerId, int seat})>? seating}) {
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
    final finalists = players.where((p) => p.active && !p.eliminated).toList();
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
    // (checklist §15.4). Failure is swallowed by VoiceService (15-054).
    if (speakOutLoud && _voiceEnabled) {
      VoiceService.instance.speak(text);
    }
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

  void startCashGame(CashSessionSettings settings, List<String> playerNames) {
    _cashSession = CashSession(
      id: 'cash-${DateTime.now().millisecondsSinceEpoch}',
      settings: settings,
      isCompleted: false,
      startTime: DateTime.now(),
      players: List.generate(playerNames.length, (i) => CashPlayer(
            id: 'cp-$i',
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

  void endCashGame() {
    final session = _cashSession;
    if (session == null) return;
    _cashSession = session.copyWith(isCompleted: true);
    notifyListeners();
  }

  /// Discards the current cash session so a fresh game can be started.
  void clearCashSession() {
    _cashSession = null;
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