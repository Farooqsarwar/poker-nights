/// AppProvider: Timer domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Timer ──`). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderTimer on AppProvider {
  /// Voice marks within a level (specification section 17).
  ///
  /// Section 17 narrowed the scope to "level-transition announcements only"
  /// and specifies exactly two moments:
  ///
  ///   * at 1 minute — "1 minute remaining", THEN the next level's blinds;
  ///   * at level end — an audible 5-4-3-2-1, then the new level.
  ///
  /// The next-level blinds are the useful half: a player deciding whether to
  /// play a marginal hand wants to know what it will cost them next level,
  /// not merely that time is short.
  ///
  /// The five-minute warning that used to fire here was removed. It is not in
  /// section 17's list, and the addendum's "Voice" section names only the
  /// one-minute warning and the level transition.
  void _announceLevelMark(int remaining) {
    final game = _currentGame;
    if (game == null || !game.timerRunning) return;
    // A scheduled break has its own rhythm; counting a level down through it
    // would announce blinds nobody is about to post.
    if (game.status == LiveGameStatus.onBreak) return;
    final level = game.currentLevel;
    final mark = '$level';

    if (remaining <= 60 &&
        remaining > 5 &&
        !_levelAnnouncementMarks.contains('$mark:60')) {
      _levelAnnouncementMarks.add('$mark:60');
      final next = game.currentLevel < game.structure.levels.length
          ? game.structure.levels[game.currentLevel]
          : null;
      final blinds = next == null
          ? ''
          : ' Next level: blinds ${next.sb} and ${next.bb}'
              '${next.ante != null ? ', ante ${next.ante}' : ''}.';
      addAnnouncement('One minute remaining in level $level.$blinds', true);
    }

    // Section 17's audible countdown. Spoken one number per second so it
    // lands with the clock rather than as a single burst.
    if (remaining <= 5 && remaining >= 1) {
      final key = '$mark:count:$remaining';
      if (!_levelAnnouncementMarks.contains(key)) {
        _levelAnnouncementMarks.add(key);
        // Silent in the feed — this is a spoken cue, not a written notice,
        // and five one-digit rows would bury the announcements list.
        if (_voiceEnabled && thisDeviceIsAudioMaster) {
          VoiceService.instance.speak('$remaining');
        }
      }
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
        // Only the authority (admin editor) device OPERATES the clock
        // (User Flow §7 step 7, Technical §11.4). A member/guest/TV device
        // used to run this same branch, which meant every viewer locally
        // advanced the level and fired host-only side effects with it:
        // spoken announcements, a staged group notification (members are
        // allowed to create those, so one duplicate per open device), and an
        // undo-stack write that the rules reject. Viewers still roll the
        // level over so the clock never freezes at 00:00 — but silently, as
        // display state only, and the host's next snapshot remains the truth.
        if (!_isGameAuthority) {
          _rollOverLevelForViewer();
          return;
        }
        // A scheduled break that has run its time ends by itself and play
        // resumes — section 8 makes it part of the structure, so it does not
        // wait for the host the way a manual pause does.
        if (_currentGame!.status == LiveGameStatus.onBreak) {
          endBreak();
          _evaluateSpeedRecommendation();
          return;
        }
        final isLastLevel = _currentGame!.currentLevel >= _currentGame!.structure.levels.length;
        if (isLastLevel) {
          _currentGame = _currentGame!.copyWith(
            secondsRemaining: 0,
            timerRunning: false,
          );
          addAnnouncement('Tournament has reached the end of the structure.', true);
          _syncGroupGame();
          if (!_disposed) notifyListeners();
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
      if (!_disposed) notifyListeners();
      _isTickUpdate = false;
    });
  }

  /// Display-only level rollover for a NON-authority device (member, guest,
  /// TV) whose current level has run out before the host's update arrives.
  ///
  /// Deliberately does none of what [nextLevel] does: no announcement (so it
  /// cannot speak), no notification (so it cannot write to Firestore), no
  /// `_pushUndo` (so it cannot hit the admin-only undo sidecar), no revision
  /// bump and no idempotency claim. It only moves the displayed level and
  /// end-time forward so the countdown keeps running; when the host's real
  /// transition lands, `_adoptRemoteMap` overwrites all of it.
  void _rollOverLevelForViewer() {
    final game = _currentGame;
    if (game == null) return;
    final next = game.currentLevel + 1;
    if (next > game.structure.levels.length) {
      // Past the generated end — hold at zero and wait for the host rather
      // than inventing an extension level the host has not created.
      if (game.timerRunning) {
        _currentGame = game.copyWith(secondsRemaining: 0, timerRunning: false);
        if (!_disposed) notifyListeners();
      }
      return;
    }
    final level = game.structure.levels[next - 1];
    _currentGame = game.copyWith(
      currentLevel: next,
      secondsRemaining: level.durationMins * 60,
      levelEndTime: _serverNow.add(Duration(minutes: level.durationMins)),
    );
    if (!_disposed) notifyListeners();
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
    final currentLevelData = game.currentLevelData;
    final currentDurationMins =
        currentLevelData?.durationMins ?? game.structure.levelDuration;

    // Elapsed time against the WALL CLOCK, from the first Start press.
    //
    // Summing level durations could not see a pause, and the biggest pause of
    // the night is a scheduled one: the end-of-rebuy settlement break runs
    // without a countdown (User Flow section 4.13) and the engine budgets 15
    // minutes for it (11-031). A settlement that took half an hour therefore
    // left this reading on-target while the dashboard's own wall-clock finish
    // window — computed from `DateTime.now()` — showed the evening slipping.
    // The two now agree, and a long pause produces the "Speed Up" offer the
    // spec relies on (Technical section 11.4).
    var elapsedMins = 0.0;
    final startedAt = game.startedAt;
    if (startedAt != null) {
      elapsedMins = _serverNow.difference(startedAt).inSeconds / 60.0;
      if (elapsedMins < 0) elapsedMins = 0;
    } else {
      // Legacy game, or the clock was never started through `startTimer`:
      // fall back to scheduled level time.
      for (var i = 0; i < game.currentLevel - 1 && i < levels.length; i++) {
        elapsedMins += levels[i].durationMins;
      }
      final consumedSeconds =
          currentDurationMins * 60 - game.currentSecondsRemaining();
      elapsedMins += consumedSeconds.clamp(0, currentDurationMins * 60) / 60.0;
    }
    // Remaining scheduled work: future PLANNED levels only.
    //
    // The generator appends a spare tail so a slow field cannot run off the
    // end of the structure. Counting it here made a fresh 3.5 h / 15-minute
    // event report about +45 minutes of drift at level 1 with a full field and
    // nobody eliminated — past the 20-minute threshold, so "Speed Up" was
    // recommended from the first level boundary of every tournament. A
    // permanent nag trains the admin to ignore a control the spec leans on
    // (Technical section 11.4, 12-071).
    final planned = game.structure.effectivePlannedLevels;
    var remainingLevelsMins = 0.0;
    for (var i = game.currentLevel; i < planned && i < levels.length; i++) {
      remainingLevelsMins += levels[i].durationMins;
    }
    // The rest of the level being played is still work to do. Its CONSUMED
    // part was added to `elapsedMins` above but its remainder was counted
    // nowhere, so the estimate understated by up to a full level — enough on
    // its own to tip a fresh event into a false "Slow Down".
    remainingLevelsMins +=
        game.currentSecondsRemaining().clamp(0, currentDurationMins * 60) / 60.0;

    final targetMins = game.settings.durationHours * 60;
    final actualRemaining = game.activePlayers.length;
    final startingField = game.settings.players;
    if (actualRemaining < 1 || startingField < 1 || targetMins <= 0) return 0;

    // Pace factor: actual field against the EXPECTED field at this point in
    // the schedule (Technical section 11.4 — "compare actual players remaining
    // with the expected curve").
    //
    // This used to divide the STARTING field by the current one, which grows
    // without bound as players bust. It therefore drifted toward "Speed Up"
    // precisely when the field was thinning and the tournament was running
    // AHEAD: at a three-handed final table of a ten-player game the factor
    // clamped to 2.0 and recommended speeding up a game about to finish early.
    // The comparison now runs the right way round — more players left than the
    // schedule expects means slow progress (speed up); fewer means fast
    // progress (slow down).
    final elapsedFraction = (elapsedMins / targetMins).clamp(0.0, 1.0);
    final expectedNow = max(2.0, startingField * (1 - elapsedFraction));
    final paceFactor = (actualRemaining / expectedNow).clamp(0.5, 2.0);

    final estimateMins = remainingLevelsMins * paceFactor;
    final targetRemainingMins = targetMins - elapsedMins;
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
    if (!_disposed) notifyListeners();
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

  void startTimer({List<String> noShowIds = const []}) {
    _forceClaimEditor();

    if (noShowIds.isNotEmpty) {
      _currentGame = _currentGame!.copyWith(
        players: _currentGame!.players.map((p) {
          if (noShowIds.contains(p.id)) {
            return p.copyWith(noShow: true, active: false);
          }
          return p;
        }).toList(),
      );
    }

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
      // Wall-clock origin for the pace model. Set once, on the first Start,
      // and never rewritten — a restart of the current level or a recovered
      // session must not move it, or the drift estimate loses the pauses it
      // exists to notice (11-031).
      startedAt: _currentGame!.startedAt ?? _serverNow,
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
    _forceClaimEditor();
    _currentGame = _currentGame!.copyWith(
      timerRunning: false,
      status: LiveGameStatus.paused,
      secondsRemaining: _currentGame!.currentSecondsRemaining(_serverTimeOffset ?? Duration.zero),
      levelEndTime: null,
      clearLevelEndTime: true,
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  void resumeTimer() {
    _forceClaimEditor();
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
    if (!_disposed) notifyListeners();
  }

  /// Puts a player on the clock (§12).
  ///
  /// Host-initiated, never automatic: an automatic clock belongs in a casino
  /// with floor staff, not at a kitchen table. It runs BESIDE the level timer
  /// and never touches it -- §12 requires it to be "independent of level
  /// timer", and a level must not end early because somebody tanked.
  void startShotClock(String playerId, {int? seconds}) {
    final game = _currentGame;
    if (game == null) return;
    final duration = seconds ?? ShotClock.defaultSeconds;
    _currentGame = game.copyWith(
      shotClock: ShotClock(
        playerId: playerId,
        // A timestamp, not a countdown -- every device derives the same
        // remaining time without having to tick in step, exactly as the level
        // clock does.
        endsAt: _serverNow.add(Duration(seconds: duration)),
        seconds: duration,
      ),
    );
    final name =
        game.players.where((p) => p.id == playerId).firstOrNull?.name;
    addAnnouncement(
      '${name ?? 'Player'} is on the clock — $duration seconds.',
      true,
    );
    addAuditRecord(
      'shot_clock',
      '${name ?? playerId} put on the clock for $duration seconds.',
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  /// Clears the clock — the player acted, or the table waved it off.
  ///
  /// Nothing else happens. It is a SOFT clock: running out does not fold a
  /// hand, and neither does clearing it. The table decides what a expired
  /// clock means, which is the only workable rule for a home game.
  void clearShotClock() {
    final game = _currentGame;
    if (game == null || game.shotClock == null) return;
    _currentGame = game.copyWith(clearShotClock: true);
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  /// Ends a scheduled break and starts the next level.
  ///
  /// Called by the clock when the break runs out, and by the host if they want
  /// to cut it short. Section 8 makes the break part of the structure, so
  /// ending it simply resumes the sequence — it is not a separate "resume"
  /// with its own rules.
  void endBreak({bool skipped = false}) {
    final game = _currentGame;
    if (game == null || game.status != LiveGameStatus.onBreak) return;
    _pushUndo();
    _currentGame = game.copyWith(status: LiveGameStatus.running);
    addAuditRecord(
      skipped ? 'break_skipped' : 'break_end',
      skipped
          ? 'Break after level ${game.currentLevel} ended early by the host.'
          : 'Break after level ${game.currentLevel} finished.',
    );
    // Now advance for real. The status is no longer onBreak, so `nextLevel`
    // will not re-enter the same break.
    nextLevel();
  }

  void nextLevel({String? idempotencyKey}) {
    final (rev, idemKey) =
        _claimIdempotency(idempotencyKey ?? '', action: 'nextLevel');
    if (rev == null) return; // replayed action — already applied
    final next = _currentGame!.currentLevel + 1;
    _pushUndo();
    _levelAnnouncementMarks.clear();

    // Section 8 / addendum section 5: a scheduled break is a real state, not
    // a manual pause. If one falls after the level that just finished, the
    // tournament enters it and the clock counts the break down; `endBreak`
    // then advances into the next level. Without this the breaks were
    // configured, stored and counted in the duration but never actually
    // happened.
    final scheduled =
        _currentGame!.structure.breakAfter(_currentGame!.currentLevel);
    if (scheduled != null &&
        _currentGame!.status != LiveGameStatus.onBreak &&
        next <= _currentGame!.structure.levels.length) {
      _currentGame = _currentGame!.copyWith(
        status: LiveGameStatus.onBreak,
        timerRunning: true,
        secondsRemaining: scheduled.durationMins * 60,
        levelEndTime: _serverNow.add(
          Duration(minutes: scheduled.durationMins),
        ),
        speedRecommendation: null,
        clearSpeedRecommendation: true,
        revision: rev,
        lastIdempotencyKey: idemKey,
      );
      addAnnouncement(
        'Break — ${scheduled.durationMins} minutes.',
        true,
      );
      addAuditRecord(
        'break_start',
        'Scheduled break after level ${_currentGame!.currentLevel} '
            '(${scheduled.durationMins} minutes).',
      );
      _syncGroupGame();
      if (!_disposed) notifyListeners();
      return;
    }
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
      // Play has run past the generated structure.
      //
      // User Flow sections 3.3 and 4.14 allow a future level to be inserted
      // "only after admin confirmation" (12-082), and 11-004 requires every
      // blind to be postable. This used to silently invent a level at
      // ceil(lastBB * 1.4) with an SB at ceil(bb * 0.4) — unconfirmed, and
      // snapped to nothing, so it could ask for blinds the chips cannot pay.
      //
      // The engine now generates spare levels past the target so this is rare.
      // When it still happens the clock HOLDS on the finished level and the
      // admin is asked to approve the extension, rather than the app changing
      // the structure on its own.
      if (next > _currentGame!.structure.levels.length) {
        final lastLevel = _currentGame!.structure.levels.last;
        final chipsInPlay = _currentGame!.totalChipsInPlay;
        var proposedBB = TournamentEngine.snapToPracticalBlind(
          lastLevel.bb * 1.4,
          _currentGame!.settings.chipSet,
        );
        if (proposedBB <= lastLevel.bb) proposedBB = lastLevel.bb * 2;
        if (chipsInPlay > 0 && proposedBB > chipsInPlay) {
          proposedBB = TournamentEngine.snapToPracticalBlind(
            chipsInPlay.toDouble(),
            _currentGame!.settings.chipSet,
          );
        }
        final proposedSB = TournamentEngine.snapToPracticalBlind(
          proposedBB * 0.45,
          _currentGame!.settings.chipSet,
        );
        pendingLevelExtension = BlindLevel(
          level: next,
          sb: proposedSB >= proposedBB ? (proposedBB ~/ 2) : proposedSB,
          bb: proposedBB,
          durationMins: lastLevel.durationMins,
          ante: lastLevel.ante,
        );
        _currentGame = _currentGame!.copyWith(
          timerRunning: false,
          secondsRemaining: 0,
          levelEndTime: null,
          clearLevelEndTime: true,
        );
        addAnnouncement(
          'Structure complete — the host must approve the next blind level.',
          true,
        );
        _syncGroupGame();
        if (!_disposed) notifyListeners();
        return;
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
      // Section 17's exact shape: "Start of level N — blinds X — duration Y
      // minutes."
      addAnnouncement(
        'Start of level $next — blinds ${extLevel.sb} / ${extLevel.bb}'
        '${extLevel.ante != null ? ", ante ${extLevel.ante}" : ""}'
        ' — ${extLevel.durationMins} minutes.',
        true,
      );
    }
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  /// Applies the extension level the admin has just approved (12-082).
  /// Returns false when there is nothing pending or this device is read-only.
  bool acceptLevelExtension() {
    final proposed = pendingLevelExtension;
    final game = _currentGame;
    if (proposed == null || game == null) return false;
    _forceClaimEditor();
    if (!_isGameAuthority) return false;
    pendingLevelExtension = null;
    _pushUndo();
    _currentGame = game.copyWith(
      structure: game.structure.copyWith(
        levels: [...game.structure.levels, proposed],
      ),
    );
    addAuditRecord(
      'structure_extend',
      'Approved extension level ${proposed.level}: '
      '${proposed.sb}/${proposed.bb} for ${proposed.durationMins} minutes.',
    );
    nextLevel(idempotencyKey: 'extend-${proposed.level}');
    return true;
  }

  /// Dismisses the proposal without changing the structure. The clock stays
  /// held so the admin can finish the tournament instead.
  void declineLevelExtension() {
    if (pendingLevelExtension == null) return;
    pendingLevelExtension = null;
    if (!_disposed) notifyListeners();
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
    if (!_disposed) notifyListeners();
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
    if (!_disposed) notifyListeners();
  }
}