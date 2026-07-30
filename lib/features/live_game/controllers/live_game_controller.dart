import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:poker_night/features/live_game/models/game_state_model.dart';
import 'package:poker_night/features/live_game/models/player_action_model.dart';
import 'package:poker_night/features/tournament/models/blind_structure_model.dart';
import 'package:poker_night/services/storage_service.dart';
import 'package:poker_night/services/voice_service.dart';

class LiveGameController extends GetxController {
  final StorageService _storage;
  final VoiceService _voiceService;
  final String _gameId;
  Timer? _timer;
  Timer? _warningTimer;
  DateTime? _resumedAt;
  BlindStructure? _structure;

  /// Remaining seconds captured when the clock last started/resumed. The value
  /// shown is always derived as `_anchorRemaining - elapsedSinceResume`, so the
  /// clock can neither drift nor accelerate across pauses, sleeps or reloads
  /// (spec 4.3 — persist timestamps, never a per-second counter).
  int _anchorRemaining = 0;
  bool _spokeFiveMin = false;
  bool _spokeOneMin = false;
  final List<GameAction> _actionHistory = [];
  final List<String> _bountyLog = [];

  late final Rx<GameState> rxState;

  GameState get state => rxState.value;
  set state(GameState val) => rxState.value = val;

  LiveGameController(this._storage, this._voiceService, this._gameId) {
    rxState = GameState.initial(_gameId).obs;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _warningTimer?.cancel();
    super.dispose();
  }

  int get remainingSeconds => state.pausedRemainingSeconds;
  bool get isRunning => state.status == 'running';
  bool get isPaused => state.status == 'paused';
  int get currentLevelNumber => state.currentLevel;
  int get bountyCount => _bountyLog.length;
  bool get canUndo => _actionHistory.isNotEmpty;

  void initializeWithStructure(BlindStructure structure) {
    _structure = structure;
    if (structure.levels.isEmpty) return;
    final first = structure.levels.first;
    final next = structure.levels.length > 1 ? structure.levels[1] : first;
    final players = state.players;
    final totalChips = structure.startingStack * (players.isEmpty ? 1 : players.length);

    state = state.copyWith(
      currentLevel: 1,
      pausedRemainingSeconds: first.durationMinutes * 60,
      currentBlinds: BlindLevelData(smallBlind: first.smallBlind, bigBlind: first.bigBlind, ante: first.ante),
      nextBlinds: BlindLevelData(smallBlind: next.smallBlind, bigBlind: next.bigBlind, ante: next.ante),
      totalChips: totalChips,
      averageStack: players.isNotEmpty ? totalChips ~/ players.length : 0,
    );
    _saveLocally();
  }

  void startGame() {
    if (state.status == 'running') return;
    _resumedAt = DateTime.now();
    state = state.copyWith(
      status: 'running',
      startedAt: DateTime.now(),
      resumedAt: _resumedAt!.toIso8601String(),
    );
    _startTimer();
    _startWarningTimer();
    _voiceService.announceLevelChange(state.currentLevel, state.currentBlinds.smallBlind, state.currentBlinds.bigBlind);
    _saveLocally();
  }

  void pauseGame() {
    _timer?.cancel();
    _warningTimer?.cancel();
    state = state.copyWith(status: 'paused', pausedAt: DateTime.now());
    _saveLocally();
  }

  void resumeGame() {
    if (state.status != 'paused') return;
    _resumedAt = DateTime.now();
    state = state.copyWith(
      status: 'running',
      resumedAt: _resumedAt!.toIso8601String(),
    );
    _startTimer();
    _startWarningTimer();
    _saveLocally();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _startWarningTimer() {
    _warningTimer?.cancel();
    // Warnings are evaluated in _tick(), so no separate timer is needed here.
  }

  /// Derives remaining time from the resume timestamp rather than decrementing
  /// a counter, so backgrounding or sleeping never double-counts elapsed time.
  void _tick() {
    if (_resumedAt == null) return;
    final elapsed = DateTime.now().difference(_resumedAt!).inSeconds;
    final remaining = max(0, _anchorRemaining - elapsed);

    if (remaining != state.pausedRemainingSeconds) {
      state = state.copyWith(pausedRemainingSeconds: remaining);
    }
    _maybeAnnounceWarnings(remaining);

    if (remaining <= 0) {
      advanceLevel();
    }
  }

  void _maybeAnnounceWarnings(int remaining) {
    if (!_spokeFiveMin && remaining <= 300 && remaining > 60) {
      _spokeFiveMin = true;
      _voiceService.announceFiveMinutes();
    }
    if (!_spokeOneMin && remaining <= 60 && remaining > 0) {
      _spokeOneMin = true;
      _voiceService.announceOneMinute();
    }
  }

  /// Anchors the clock to `remaining` and starts counting down from now.
  void _anchorAndRun(int remaining, {bool resetWarnings = false}) {
    if (resetWarnings) {
      _spokeFiveMin = false;
      _spokeOneMin = false;
    }
    _anchorRemaining = remaining;
    _resumedAt = DateTime.now();
    state = state.copyWith(
      pausedRemainingSeconds: remaining,
      resumedAt: _resumedAt!.toIso8601String(),
    );
    _startTimer();
  }

  void advanceLevel() {
    _timer?.cancel();
    _warningTimer?.cancel();
    if (_structure == null || state.currentLevel >= _structure!.levels.length) {
      _timer?.cancel();
      _warningTimer?.cancel();
      state = state.copyWith(status: 'completed');
      _voiceService.announce('Tournament complete');
      _saveLocally();
      return;
    }

    final nextLevelIdx = state.currentLevel;
    final nextLevel = _structure!.levels[nextLevelIdx];
    final nextNextIdx = nextLevelIdx + 1;
    final nextNextLevel = nextNextIdx < _structure!.levels.length ? _structure!.levels[nextNextIdx] : nextLevel;

    final ante = state.anteActive ? nextLevel.ante : 0;

    state = state.copyWith(
      currentLevel: nextLevelIdx + 1,
      pausedRemainingSeconds: nextLevel.durationMinutes * 60,
      currentBlinds: BlindLevelData(smallBlind: nextLevel.smallBlind, bigBlind: nextLevel.bigBlind, ante: ante),
      nextBlinds: BlindLevelData(smallBlind: nextNextLevel.smallBlind, bigBlind: nextNextLevel.bigBlind, ante: state.anteActive ? nextNextLevel.ante : 0),
    );

    _resumedAt = DateTime.now();
    state = state.copyWith(resumedAt: _resumedAt!.toIso8601String());
    _voiceService.announceLevelChange(state.currentLevel, state.currentBlinds.smallBlind, state.currentBlinds.bigBlind);
    _startTimer();
    _startWarningTimer();
    _saveLocally();
  }

  void _recordAction(String type, Map<String, dynamic> payload) {
    _actionHistory.add(GameAction(
      id: const Uuid().v4(),
      gameId: _gameId,
      sequence: _actionHistory.length + 1,
      actorUserId: 'admin',
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    ));
  }

  void eliminatePlayer(String playerId, {String? knockoutRecipientId}) {
    final player = state.players.firstWhere((p) => p.id == playerId, orElse: () => PlayerState(id: '', name: '', tableNo: 0, seatNo: 0, stack: 0, status: ''));
    if (player.id.isEmpty) return;

    _recordAction('eliminate', {
      'playerId': playerId,
      'previousStatus': player.status,
      'previousFinishPosition': player.finishPosition,
      'previousStack': player.stack,
      'knockoutRecipientId': knockoutRecipientId,
    });

    final players = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(status: 'eliminated', finishPosition: state.playersRemaining, stack: 0);
      }
      return p;
    }).toList();

    final totalActive = players.where((p) => p.status == 'active').length;
    final totalStack = players.fold(0, (sum, p) => sum + (p.status == 'active' ? p.stack : 0));

    if (player.name.isNotEmpty) {
      _voiceService.announcePlayerEliminated(player.name, state.playersRemaining);
    }

    if (knockoutRecipientId != null && knockoutRecipientId.isNotEmpty) {
      _bountyLog.add('${player.name} knocked out by ${state.players.where((p) => p.id == knockoutRecipientId).firstOrNull?.name ?? 'unknown'} at Level ${state.currentLevel}');
    }

    state = state.copyWith(
      players: players,
      playersRemaining: totalActive,
      averageStack: totalActive > 0 ? totalStack ~/ totalActive : 0,
    );
    _saveLocally();
  }

  void rebuyPlayer(String playerId) {
    if (_structure == null) return;
    final player = state.players.firstWhere((p) => p.id == playerId, orElse: () => PlayerState(id: '', name: '', tableNo: 0, seatNo: 0, stack: 0, status: ''));
    if (player.id.isEmpty || player.status != 'eliminated') return;

    _recordAction('rebuy', {
      'playerId': playerId,
      'previousStatus': player.status,
      'previousStack': player.stack,
    });

    final players = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(status: 'active', stack: p.stack + _structure!.rebuyStack);
      }
      return p;
    }).toList();

    final remaining = players.where((p) => p.status == 'active').length;
    final totalStack = players.fold(0, (sum, p) => sum + (p.status == 'active' ? p.stack : 0));

    state = state.copyWith(
      players: players,
      playersRemaining: remaining,
      totalChips: state.totalChips + (_structure?.rebuyStack ?? 0),
      averageStack: remaining > 0 ? totalStack ~/ remaining : 0,
    );
    _saveLocally();
  }

  void addOnPlayer(String playerId) {
    if (_structure == null) return;
    final player = state.players.firstWhere((p) => p.id == playerId, orElse: () => PlayerState(id: '', name: '', tableNo: 0, seatNo: 0, stack: 0, status: ''));
    if (player.id.isEmpty) return;

    _recordAction('addOn', {
      'playerId': playerId,
      'previousStack': player.stack,
    });

    final players = state.players.map((p) {
      if (p.id == playerId && p.status == 'active') {
        return p.copyWith(stack: p.stack + _structure!.addOnStack);
      }
      return p;
    }).toList();

    final totalStack = players.fold(0, (sum, p) => sum + (p.status == 'active' ? p.stack : 0));
    final remaining = players.where((p) => p.status == 'active').length;

    state = state.copyWith(
      players: players,
      totalChips: state.totalChips + (_structure?.addOnStack ?? 0),
      averageStack: remaining > 0 ? totalStack ~/ remaining : 0,
    );
    _saveLocally();
  }

  void reentryPlayer(String playerId) {
    if (_structure == null) return;
    final player = state.players.firstWhere((p) => p.id == playerId, orElse: () => PlayerState(id: '', name: '', tableNo: 0, seatNo: 0, stack: 0, status: ''));
    if (player.id.isEmpty || player.status != 'eliminated') return;

    _recordAction('reentry', {
      'playerId': playerId,
      'previousStatus': player.status,
      'previousStack': player.stack,
    });

    final players = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(status: 'active', stack: _structure!.startingStack, finishPosition: null);
      }
      return p;
    }).toList();

    final active = players.where((p) => p.status == 'active').length;
    final totalStack = players.fold(0, (sum, p) => sum + (p.status == 'active' ? p.stack : 0));

    state = state.copyWith(
      players: players,
      playersRemaining: active,
      totalChips: state.totalChips + _structure!.startingStack,
      averageStack: active > 0 ? totalStack ~/ active : 0,
    );
    _saveLocally();
  }

  void reopenGame() {
    if (state.status != 'completed') return;
    state = state.copyWith(status: 'paused');
    _resumedAt = null;
    _saveLocally();
  }

  Map<String, dynamic> previewPaceChange(String direction) {
    final currentSeconds = state.pausedRemainingSeconds;
    final adjustedSeconds = direction == 'speedUp'
        ? currentSeconds ~/ 2
        : currentSeconds + 300;
    return {
      'current': currentSeconds,
      'proposed': adjustedSeconds.clamp(0, adjustedSeconds),
      'difference': adjustedSeconds - currentSeconds,
      'effect': direction == 'speedUp'
          ? 'Levels will progress faster. Estimated finish: ~${_formatDuration((adjustedSeconds * (_structure?.levels.length ?? 1) / 60).round())}'
          : 'Levels will progress slower. Estimated finish: ~${_formatDuration((adjustedSeconds * (_structure?.levels.length ?? 1) / 60).round())}',
    };
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m > 0 ? ' $m' : ''}';
  }

  void undoLastAction() {
    if (_actionHistory.isEmpty) return;
    final lastAction = _actionHistory.removeLast();
    final payload = lastAction.payload;

    switch (lastAction.type) {
      case 'eliminate':
        final playerId = payload['playerId'] as String;
        final prevStatus = payload['previousStatus'] as String;
        final prevStack = payload['previousStack'] as int;
        final prevFinishPos = payload['previousFinishPosition'] as int?;
        final koId = payload['knockoutRecipientId'] as String?;

        if (koId != null && koId.isNotEmpty && _bountyLog.isNotEmpty) {
          _bountyLog.removeLast();
        }

        final players = state.players.map((p) {
          if (p.id == playerId) {
            return p.copyWith(status: prevStatus, stack: prevStack, finishPosition: prevFinishPos);
          }
          return p;
        }).toList();
        final active = players.where((p) => p.status == 'active').length;
        final totalStack = players.fold(0, (sum, p) => sum + (p.status == 'active' ? p.stack : 0));
        state = state.copyWith(players: players, playersRemaining: active + 1, averageStack: active > 0 ? totalStack ~/ active : 0);
        break;

      case 'rebuy':
        final playerId = payload['playerId'] as String;
        final prevStatus = payload['previousStatus'] as String;
        final prevStack = payload['previousStack'] as int;
        final players = state.players.map((p) {
          if (p.id == playerId) {
            return p.copyWith(status: prevStatus, stack: prevStack);
          }
          return p;
        }).toList();
        final active = players.where((p) => p.status == 'active').length;
        final totalStack = players.fold(0, (sum, p) => sum + (p.status == 'active' ? p.stack : 0));
        final rebuyStack = _structure?.rebuyStack ?? 0;
        state = state.copyWith(players: players, playersRemaining: active, totalChips: state.totalChips - rebuyStack, averageStack: active > 0 ? totalStack ~/ active : 0);
        break;

      case 'addOn':
        final playerId = payload['playerId'] as String;
        final prevStack = payload['previousStack'] as int;
        final players = state.players.map((p) {
          if (p.id == playerId) {
            return p.copyWith(stack: prevStack);
          }
          return p;
        }).toList();
        final active = players.where((p) => p.status == 'active').length;
        final totalStack = players.fold(0, (sum, p) => sum + (p.status == 'active' ? p.stack : 0));
        final addOnStack = _structure?.addOnStack ?? 0;
        state = state.copyWith(players: players, totalChips: state.totalChips - addOnStack, averageStack: active > 0 ? totalStack ~/ active : 0);
        break;
    }
    _saveLocally();
  }

  void setPlayers(List<PlayerState> players) {
    final totalStack = players.fold(0, (sum, p) => sum + p.stack);
    final activeCount = players.where((p) => p.status == 'active').length;

    state = state.copyWith(
      players: players,
      playersTotal: players.length,
      playersRemaining: activeCount,
      totalChips: max(state.totalChips, totalStack),
      averageStack: activeCount > 0 ? totalStack ~/ activeCount : 0,
    );
    _saveLocally();
  }

  void speedUp() {
    state = state.copyWith(
      pausedRemainingSeconds: 300.clamp(0, state.pausedRemainingSeconds ~/ 2),
    );
    _saveLocally();
  }

  void slowDown() {
    state = state.copyWith(
      pausedRemainingSeconds: state.pausedRemainingSeconds + 300,
    );
    _saveLocally();
  }

  void setAnteActive(bool active) {
    state = state.copyWith(anteActive: active);
    _saveLocally();
  }

  void updatePrizePool(int prizePool) {
    state = state.copyWith(prizePool: prizePool);
    _saveLocally();
  }

  void completeGame() {
    _timer?.cancel();
    _warningTimer?.cancel();
    state = state.copyWith(status: 'completed');
    _voiceService.announce('Game completed');
    _saveLocally();
  }

  Future<void> recoverFromLocal() async {
    final data = await _storage.getJson('game_state_$_gameId');
    if (data != null) {
      try {
        final recovered = GameState.fromJson(data);
        if (recovered.status == 'running' || recovered.status == 'paused') {
          state = recovered;
          if (recovered.status == 'running') {
            _resumedAt = DateTime.tryParse(recovered.resumedAt ?? '');
            _startTimer();
            _startWarningTimer();
          }
        }
      } catch (_) {}
    }
  }

  String formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool isFinalTable() {
    return state.playersRemaining <= 9 && state.playersTotal <= 9;
  }

  void redrawFinalTable(List<PlayerState> finalTablePlayers) {
    setPlayers(finalTablePlayers);
    _voiceService.announceFinalTable();
  }

  void _saveLocally() {
    _storage.set('game_state_$_gameId', state.toJson());
  }

  void recordAction(GameAction action) {
    switch (action.type) {
      case 'eliminate':
        eliminatePlayer(
          action.payload['playerId'] as String,
          knockoutRecipientId: action.payload['knockoutParticipantId'] as String?,
        );
      case 'rebuy':
        rebuyPlayer(action.payload['playerId'] as String);
      case 'addOn':
        addOnPlayer(action.payload['playerId'] as String);
      case 'undo':
        break;
    }
  }
}
