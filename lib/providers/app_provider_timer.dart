/// AppProvider: Timer domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Timer ──`). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderTimer on AppProvider {
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
        final isLastLevel = _currentGame!.currentLevel >= _currentGame!.structure.levels.length;
        if (isLastLevel) {
          _currentGame = _currentGame!.copyWith(
            secondsRemaining: 0,
            timerRunning: false,
          );
          addAnnouncement('Tournament has reached the end of the structure.', true);
          _syncGroupGame();
          notifyListeners();
        } else {
          nextLevel();
        }
        _evaluateSpeedRecommendation();
        return;
      }
      _announceLevelMark(remaining);
      // While the clock runs off [levelEndTime], every widget derives the
      // countdown from that timestamp via `currentSecondsRemaining()` — the
      // `secondsRemaining` field is not read. Mutating `_currentGame` each
      // second would only churn the object and make the NEXT unrelated
      // snapshot see a "changed" game and trigger a spurious whole-doc save.
      // Only refresh the field when there is no end-time to derive from.
      if (_currentGame!.levelEndTime == null) {
        _currentGame = _currentGame!.copyWith(secondsRemaining: remaining);
      }
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
    _syncGroupGame();
  }

  void pauseTimer() {
    _currentGame = _currentGame!.copyWith(
      timerRunning: false,
      status: LiveGameStatus.paused,
      secondsRemaining: _currentGame!.currentSecondsRemaining(_serverTimeOffset ?? Duration.zero),
      levelEndTime: null,
      clearLevelEndTime: true,
    );
    _syncGroupGame();
    notifyListeners();
  }

  void resumeTimer() {
    if (_currentGame?.status == LiveGameStatus.completed || 
        _currentGame?.status == LiveGameStatus.cancelled) {
      return;
    }
    _currentGame = _currentGame!.copyWith(
      timerRunning: true,
      status: LiveGameStatus.running,
      levelEndTime: _serverNow.add(
        Duration(seconds: _currentGame!.secondsRemaining),
      ),
    );
    _syncGroupGame();
    notifyListeners();
  }

  void nextLevel({String? idempotencyKey}) {
    final (rev, idemKey) =
        _claimIdempotency(idempotencyKey ?? '', action: 'nextLevel');
    if (rev == null) return; // replayed action — already applied
    final next = _currentGame!.currentLevel + 1;
    _pushUndo();
    _levelAnnouncementMarks.clear();
    // Auto-trigger rebuy pause when crossing rebuysCloseLevel (spec §1, §12 A12)
    final wasBelowRebuyClose =
        _currentGame!.currentLevel <= _currentGame!.settings.rebuysCloseLevel;
    final nowAtOrAboveRebuyClose =
        next > _currentGame!.settings.rebuysCloseLevel;
    final shouldPauseRebuy =
        _currentGame!.settings.rebuys &&
        wasBelowRebuyClose &&
        nowAtOrAboveRebuyClose;
    if (shouldPauseRebuy) {
      final level = (next <= _currentGame!.structure.levels.length)
          ? _currentGame!.structure.levels[next - 1]
          : _currentGame!.structure.levels.last;
      _currentGame = _currentGame!.copyWith(
        currentLevel: next,
        secondsRemaining: level.durationMins * 60,
        timerRunning: false,
        status: LiveGameStatus.rebuypause,
        speedRecommendation: null,
        levelEndTime: null,
        clearSpeedRecommendation: true,
        clearLevelEndTime: true,
        revision: rev,
        lastIdempotencyKey: idemKey,
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
      // Spec C5: if next index is past the generated end, append an auto-extension
      // level (payable, ~1.4x last BB, same duration, capped by chips in play).
      if (next > _currentGame!.structure.levels.length) {
        final lastLevel = _currentGame!.structure.levels.last;
        int nextBB = (lastLevel.bb * 1.4).ceil();
        final chipsInPlay = _currentGame!.totalChipsInPlay;
        if (nextBB >= chipsInPlay) {
          nextBB = chipsInPlay;
          addAnnouncement('Max blinds reached - sudden death until a winner is decided.', true);
        }
        final nextSB = (nextBB * 0.4).ceil();
        final extensionLevel = BlindLevel(
          level: next,
          sb: nextSB,
          bb: nextBB,
          durationMins: lastLevel.durationMins,
          ante: lastLevel.ante,
        );
        _currentGame = _currentGame!.copyWith(
          structure: _currentGame!.structure.copyWith(
            levels: [..._currentGame!.structure.levels, extensionLevel],
          ),
        );
      }
      final extLevel = _currentGame!.structure.levels[next - 1];
      _currentGame = _currentGame!.copyWith(
        currentLevel: next,
        secondsRemaining: extLevel.durationMins * 60,
        timerRunning: true,
        status: LiveGameStatus.running,
        speedRecommendation: null,
        clearSpeedRecommendation: true,
        levelEndTime: _serverNow.add(Duration(minutes: extLevel.durationMins)),
        revision: rev,
        lastIdempotencyKey: idemKey,
      );
      addAnnouncement(
        'Level $next. Blinds ${extLevel.sb} / ${extLevel.bb}'
        '${extLevel.ante != null ? " — ante ${extLevel.ante}" : ""}.',
        true,
      );
    }
    _syncGroupGame();
    notifyListeners();
  }

  /// Rewinds to the previous level (spec §12 "Previous" control). The clock
  /// resets to the full previous-level duration and the game resumes running.
  void previousLevel({String? idempotencyKey}) {
    final (rev, idemKey) =
        _claimIdempotency(idempotencyKey ?? '', action: 'previousLevel');
    if (rev == null) return; // replayed action — already applied
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
      clearSpeedRecommendation: true,
      levelEndTime: _serverNow.add(Duration(minutes: level.durationMins)),
      revision: rev,
      lastIdempotencyKey: idemKey,
    );
    addAnnouncement(
      'Level $prev. Blinds ${level.sb} and ${level.bb}'
      '${level.ante != null ? ', ante ${level.ante}' : ''}.',
      true,
    );
    _syncGroupGame();
    notifyListeners();
  }

  /// Restarts the clock for the current level (spec §12: requires
  /// confirmation showing its exact effect — the admin UI gates this behind a
  /// confirm dialog). Resets to the full level duration and resumes running.
  void restartLevel({String? idempotencyKey}) {
    final game = _currentGame;
    if (game == null) return;
    if (game.status != LiveGameStatus.running &&
        game.status != LiveGameStatus.paused &&
        game.status != LiveGameStatus.rebuypause) {
      return;
    }
    final (rev, idemKey) =
        _claimIdempotency(idempotencyKey ?? '', action: 'restartLevel');
    if (rev == null) return; // replayed action — already applied
    _pushUndo();
    _levelAnnouncementMarks.clear();
    final level = game.currentLevelData;
    final durationMins = level?.durationMins ?? game.structure.levelDuration;
    _currentGame = game.copyWith(
      secondsRemaining: durationMins * 60,
      timerRunning: true,
      status: LiveGameStatus.running,
      speedRecommendation: null,
      clearSpeedRecommendation: true,
      levelEndTime: _serverNow.add(Duration(minutes: durationMins)),
      revision: rev,
      lastIdempotencyKey: idemKey,
    );
    _syncGroupGame();
    addAuditRecord(
      'restart-level',
      'Restarted level ${game.currentLevel} (blinds ${level?.sb ?? 0}/${level?.bb ?? 0}).',
    );
    addAnnouncement('Level ${game.currentLevel} restarted.', true);
    notifyListeners();
  }
}