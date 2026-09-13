/// AppProvider: Tournament domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Late registration ──` + structure/completion). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderTournament on AppProvider {
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
    // Same free-hosting limit as check-in (addendum §3). A late arrival is
    // still an active player.
    final active =
        _currentGame!.players.where((p) => p.active && !p.eliminated).length;
    if (!canHostPlayers(active + 1)) {
      lastRsvpError =
          Entitlements.hostingBlockedReason(premiumTier, active + 1);
      if (!_disposed) notifyListeners();
      return;
    }
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
    // Spec 14: a late player is a live operational action — seat and time
    // both recorded.
    addAuditRecord(
      'late_player',
      '${player.name} joined during late registration — '
          'table $table seat $seat, ${game.structure.startingStack} chips.',
    );
    if (!_disposed) notifyListeners();
  }

  /// Completely removes a player from the active tournament.
  /// Deducts starting stack, rebuys, and add-ons from total chips.
  /// Recalculates prize pool and distribution.
  void removePlayer(String playerId) {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    if (_currentGame == null) return;
    _pushUndo();
    final game = _currentGame!;
    final p = game.players.where((pl) => pl.id == playerId).firstOrNull;
    if (p == null) return;

    int chipsToRemove = game.structure.startingStack;
    if (p.rebuys > 0) {
      chipsToRemove += p.rebuys * game.structure.rebuyStack;
    }
    if (p.reEntries > 0) {
      chipsToRemove += p.reEntries * game.structure.startingStack;
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
    if (!_disposed) notifyListeners();
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

    final grossEligible = TournamentEngine.grossEligibleFor(
      confirmedCount: confirmedCount,
      buyIn: s.buyIn,
      totalRebuys: totalRebuys,
      effectiveRebuyCost: s.effectiveRebuyCost,
      totalReEntries: totalReEntries,
      addOnEnabled: s.addOn,
      totalAddOns: totalAddOns,
      effectiveAddOnCost: s.effectiveAddOnCost,
    );

    // Delegate the organizer-cut and prize-split maths to the shared helper in
    // TournamentEngine so the rules stay consistent everywhere.
    final int roundingUnit = TournamentEngine.roundingUnitFor(s.buyIn);

    final recalculated = TournamentEngine.recalculatePrizes(
      grossEligible,
      confirmedCount,
      s.effectiveOrganizerPct.toDouble(),
      forcePaidPlaces: s.forcePaidPlaces,
      roundingUnit: roundingUnit,
    );

    // Patch only the financial fields; levels and all other structure data
    // remain exactly as they were (including any StructureEditor overrides).
    _currentGame = game.copyWith(
      structure: structure.copyWith(
        prizePool: recalculated.prizePool,
        organizerAmount: recalculated.organizerAmount,
        roundingRemainder: recalculated.roundingRemainder,
        prizes: recalculated.prizes,
      ),
    );
  }

  /// Manually overrides the number of paid places and recalculates prizes.
  void overridePaidPlaces(int? count) {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
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
    if (!_disposed) notifyListeners();
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

  /// Applies a speed-up / slow-down to FUTURE levels only (spec §4.14, §8.6).
  ///
  /// Returns a human-readable summary of what changed, or an explanation of
  /// why nothing changed. Never returns silently: "I pressed it and nothing
  /// happened" was indistinguishable between "not the authority device",
  /// "already at the duration limit" and "applied, but only future levels
  /// moved so the visible timer and current blinds stayed put" — which is the
  /// correct behaviour and the most common case.
  String acceptSpeedRecommendation({SpeedRecommendation? rec}) {
    _forceClaimEditor();
    if (!_isGameAuthority) {
      final why =
          'Speed change ignored — this device is not the active editor '
          '(isAdmin=$isAdmin, editorDeviceId=${_currentGame?.editorDeviceId}, '
          'thisDevice=${_repo.deviceId}).';
      debugPrint('acceptSpeedRecommendation: $why');
      return why;
    }
    final game = _currentGame;
    if (game == null) {
      debugPrint('acceptSpeedRecommendation: no current game.');
      return 'No active game.';
    }
    final recommendation = rec ?? game.speedRecommendation;
    if (recommendation == null) {
      debugPrint('acceptSpeedRecommendation: no recommendation to apply.');
      return 'No speed recommendation to apply.';
    }
    _pushUndo();
    final structure = game.structure;
    final isSpeedUp = recommendation == SpeedRecommendation.speedUp;
    final newDuration = isSpeedUp
        ? structure.levelDuration - 5
        : structure.levelDuration + 5;
    final clamped = newDuration < 10
        ? 10
        : (newDuration > 20 ? 20 : newDuration);

    final pastLevels = structure.levels.where((l) => l.level <= game.currentLevel).toList();
    var futureLevels = structure.levels.where((l) => l.level > game.currentLevel).toList();

    if (futureLevels.isNotEmpty) {
      final chips = game.settings.chipSet;

      if (isSpeedUp) {
        // 1. Advance ante
        int? firstAnteIdx;
        for (var i = 0; i < futureLevels.length; i++) {
          if (futureLevels[i].ante != null) {
            firstAnteIdx = i;
            break;
          }
        }
        if (firstAnteIdx != null && firstAnteIdx > 0) {
          final moveUp = firstAnteIdx > 1 ? 2 : 1;
          final anteVal = futureLevels[firstAnteIdx].ante;
          futureLevels[firstAnteIdx - moveUp] = BlindLevel(
            level: futureLevels[firstAnteIdx - moveUp].level,
            sb: futureLevels[firstAnteIdx - moveUp].sb,
            bb: futureLevels[firstAnteIdx - moveUp].bb,
            ante: anteVal,
            durationMins: clamped,
          );
        }

        // 2. Increase future blinds (steepen curve)
        futureLevels = futureLevels.map((l) {
          final newBB = TournamentEngine.snapToPracticalBlind(l.bb * 1.25, chips);
          final newSB = TournamentEngine.snapToPracticalBlind(newBB / 2, chips);
          return BlindLevel(
            level: l.level,
            sb: newSB,
            bb: newBB,
            ante: l.ante,
            durationMins: clamped,
          );
        }).toList();
      } else {
        // Slow down
        // 1. Delay ante
        int? firstAnteIdx;
        for (var i = 0; i < futureLevels.length; i++) {
          if (futureLevels[i].ante != null) {
            firstAnteIdx = i;
            break;
          }
        }
        if (firstAnteIdx != null && firstAnteIdx < futureLevels.length - 1) {
          futureLevels[firstAnteIdx] = BlindLevel(
            level: futureLevels[firstAnteIdx].level,
            sb: futureLevels[firstAnteIdx].sb,
            bb: futureLevels[firstAnteIdx].bb,
            ante: null,
            durationMins: clamped,
          );
        }

        // 2. Insert intermediate level if steep jump exists
        bool inserted = false;
        final newFuture = <BlindLevel>[];
        for (var i = 0; i < futureLevels.length; i++) {
          final current = futureLevels[i];
          newFuture.add(BlindLevel(
            level: current.level,
            sb: current.sb,
            bb: current.bb,
            ante: current.ante,
            durationMins: clamped,
          ));
          if (!inserted && i < futureLevels.length - 1) {
            final next = futureLevels[i + 1];
            if (next.bb >= current.bb * 2) {
              final midBB = TournamentEngine.snapToPracticalBlind(current.bb * 1.5, chips);
              final midSB = TournamentEngine.snapToPracticalBlind(midBB / 2, chips);
              newFuture.add(BlindLevel(
                level: 0, // will re-index later
                sb: midSB,
                bb: midBB,
                ante: current.ante,
                durationMins: clamped,
              ));
              inserted = true;
            }
          }
        }
        futureLevels = newFuture;
      }
    }

    // Re-index all levels sequentially to ensure no gaps
    final allLevels = [...pastLevels, ...futureLevels];
    for (var i = 0; i < allLevels.length; i++) {
      final l = allLevels[i];
      allLevels[i] = BlindLevel(
        level: i + 1,
        sb: l.sb,
        bb: l.bb,
        ante: l.ante,
        durationMins: l.level > game.currentLevel ? clamped : l.durationMins,
      );
    }

    // Diagnostics: exactly what the press did to the structure.
    final oldFuture = structure.levels
        .where((l) => l.level > game.currentLevel)
        .toList();
    final newFuture =
        allLevels.where((l) => l.level > game.currentLevel).toList();
    final durationChanged = clamped != structure.levelDuration;
    final blindsChanged = oldFuture.length != newFuture.length ||
        [
          for (var i = 0; i < oldFuture.length && i < newFuture.length; i++)
            if (oldFuture[i].bb != newFuture[i].bb ||
                oldFuture[i].sb != newFuture[i].sb ||
                oldFuture[i].ante != newFuture[i].ante)
              i,
        ].isNotEmpty;
    final levelsAdded = newFuture.length - oldFuture.length;
    debugPrint(
      'acceptSpeedRecommendation(${recommendation.name}): '
      'currentLevel=${game.currentLevel} '
      'levelDuration ${structure.levelDuration}->$clamped '
      '(changed=$durationChanged) '
      'futureLevels ${oldFuture.length}->${newFuture.length} '
      'blindsChanged=$blindsChanged '
      'firstFutureBB ${oldFuture.isEmpty ? "-" : oldFuture.first.bb}'
      '->${newFuture.isEmpty ? "-" : newFuture.first.bb}',
    );

    if (oldFuture.isEmpty) {
      debugPrint('acceptSpeedRecommendation: no future levels to change.');
      return 'No future levels left to change — this is the last level.';
    }
    if (!durationChanged && !blindsChanged) {
      // Both ends of the allowed 10/15/20 range hit this: speeding up at 10
      // minutes or slowing down at 20 clamps back to the same value, and the
      // blind snap can land on the same practical amount.
      final atLimit = recommendation == SpeedRecommendation.speedUp ? 10 : 20;
      debugPrint(
        'acceptSpeedRecommendation: no-op — already at the '
        '$atLimit-minute limit and blinds snapped unchanged.',
      );
      return 'No change — future levels are already at the '
          '$atLimit-minute limit and the blinds could not move further '
          'with these chips.';
    }

    _currentGame = game.copyWith(
      speedRecommendation: null,
      clearSpeedRecommendation: true,
      structure: structure.copyWith(
        levelDuration: clamped,
        levels: allLevels,
      ),
    );

    final parts = <String>[
      if (durationChanged)
        'future levels ${structure.levelDuration} -> $clamped min',
      if (blindsChanged) 'future blinds adjusted',
      if (levelsAdded > 0)
        '$levelsAdded intermediate level${levelsAdded == 1 ? '' : 's'} inserted',
    ];
    final summary = parts.join(', ');
    addAuditRecord(
      recommendation == SpeedRecommendation.speedUp ? 'speed_up' : 'slow_down',
      '${recommendation == SpeedRecommendation.speedUp ? "Sped up" : "Slowed down"}: '
      '$summary. Level ${game.currentLevel} and all completed levels unchanged.',
    );
    addAnnouncement(
      recommendation == SpeedRecommendation.speedUp
          ? 'Structure sped up from the next level.'
          : 'Structure slowed down from the next level.',
      false,
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
    return 'Applied: $summary. The current level is unchanged — '
        'the new pace starts at level ${game.currentLevel + 1}.';
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
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    final game = _currentGame;
    if (game == null) return;
    _currentGame = game.copyWith(structureConfirmed: true);
    addAuditRecord(
      'structure_confirm',
      'Structure confirmed: stack ${game.structure.startingStack}, '
          '${game.structure.levels.length} levels of ${game.structure.levelDuration}m.',
    );
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Structure ready',
        body: '${_currentGame!.settings.name} - final structure has been generated and locked.',
        type: NotificationType.game,
        link: '/structure-review',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
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
    _forceClaimEditor();
    _pushUndo();
    // Check-in opens with nobody checked in yet, so `confirmedCount` is 0 at
    // that moment. A 0-player structure is meaningless (and used to divide by
    // zero inside the chip planner). Fall back to the expected head-count from
    // RSVPs, then to the configured field size, and never below a two-handed
    // game.
    final expected = confirmedCount > 0
        ? confirmedCount
        : (game.goingWithGuestsCount > 0
            ? game.goingWithGuestsCount
            : game.settings.players);
    // Section 6's precedence: Locked beats the admin override, which beats
    // the RSVP-derived figure. When the host has said "prepare for 20", plan
    // for 20 — but never for fewer people than have already checked in, since
    // those are standing in the room holding a buy-in.
    final locked = game.settings.lockedExpectedPlayers;
    final override = game.settings.expectedPlayersOverride;
    final stated = locked ?? override;
    final planned =
        stated != null ? max(stated, confirmedCount) : expected;
    final count = planned < 2 ? 2 : planned;
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
        organizerPct: s.effectiveOrganizerPct,
        rebuyCost: s.rebuyCost,
        addOnCost: s.addOnCost,
        breaks: s.breaks,
      ),
    );
    // Addendum acceptance criterion 10: the engine may move the rebuy cutoff
    // while optimising, and that choice has to reach the settings that gate
    // rebuys live -- otherwise it is a number in a structure nobody reads.
    final withRebuyClose = structure.rebuysCloseLevel > 0
        ? s.copyWith(rebuysCloseLevel: structure.rebuysCloseLevel)
        : s;

    _currentGame = game.copyWith(
      settings: withRebuyClose,
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
    if (!_disposed) notifyListeners();
  }

  /// The head-count physical preparation should be based on (section 6).
  ///
  /// Section 6 orders these deliberately. Locked wins when set, because the
  /// host has already counted chips into stacks against it; otherwise the
  /// admin override; otherwise the RSVP-derived figure. Actual checked-in is
  /// a separate thing and drives the start CTA, not the preparation.
  int plannedHeadcount(LiveGame game) {
    final locked = game.settings.lockedExpectedPlayers;
    if (locked != null) return locked;
    final override = game.settings.expectedPlayersOverride;
    if (override != null) return override;
    return expectedPlayersFromRsvps(game);
  }

  /// Freezes the expected count for physical preparation (section 6).
  ///
  /// Passing null locks whatever the current planning figure is, which is the
  /// normal case: the host has decided and wants it held still.
  void lockExpectedPlayers([int? count]) {
    final game = _currentGame;
    if (game == null) return;
    final value = count ?? plannedHeadcount(game);
    if (value < 2) return;
    _pushUndo();
    _currentGame = game.copyWith(
      settings: game.settings.copyWith(lockedExpectedPlayers: value),
    );
    addAuditRecord(
      'headcount_lock',
      'Expected players locked at $value for chip preparation.',
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  /// Releases the freeze so the count tracks RSVPs again (section 6).
  void unlockExpectedPlayers() {
    final game = _currentGame;
    if (game == null || game.settings.lockedExpectedPlayers == null) return;
    _pushUndo();
    final was = game.settings.lockedExpectedPlayers;
    _currentGame = game.copyWith(
      settings: game.settings.copyWith(clearLockedExpectedPlayers: true),
    );
    addAuditRecord(
      'headcount_unlock',
      'Expected players unlocked (was $was) — following RSVPs again.',
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  /// How far RSVPs have drifted from a locked preparation (section 6).
  ///
  /// Section 6: "late RSVP changes do not silently reshuffle the locked
  /// preparation." They do not change anything — they surface here so the host
  /// can decide whether to re-lock. Positive means more people than prepared
  /// for. Null when nothing is locked.
  int? lockedHeadcountDrift(LiveGame game) {
    final locked = game.settings.lockedExpectedPlayers;
    if (locked == null) return null;
    return expectedPlayersFromRsvps(game) - locked;
  }

  /// How many future levels a Recalculate would discard.
  ///
  /// Specification sections 11 and 29 forbid silently overwriting manual
  /// edits, so the caller asks this first and puts the number in front of the
  /// host before doing anything.
  int manuallyEditedFutureLevels() {
    final game = _currentGame;
    if (game == null) return 0;
    return game.structure.levels
        .where((l) => l.level > game.currentLevel && l.manuallyEdited)
        .length;
  }

  /// Rebuilds the structure from current settings and attendance.
  ///
  /// [keepManualLevels] preserves hand-tuned future levels through the rebuild
  /// (sections 11, 29). It defaults to true: losing a manual edit must be a
  /// deliberate choice, never the path of least resistance. The UI asks which
  /// the host wants whenever `manuallyEditedFutureLevels()` is non-zero.
  void recalculateStructure({bool keepManualLevels = true}) {
    final game = _currentGame;
    if (game == null) return;
    _pushUndo();

    // Snapshot the hand-tuned future levels BEFORE the rebuild replaces them.
    final preserved = keepManualLevels
        ? {
            for (final l in game.structure.levels)
              if (l.level > game.currentLevel && l.manuallyEdited) l.level: l,
          }
        : const <int, BlindLevel>{};

    final confirmed = game.players.where((p) => p.confirmed).length;
    final derived =
        confirmed >= 2 ? confirmed : expectedPlayersFromRsvps(game);
    // Same precedence as `generateFinalStructure`: Locked, then the admin
    // override, then the derived figure — floored at whoever is confirmed.
    final stated = game.settings.lockedExpectedPlayers ??
        game.settings.expectedPlayersOverride;
    final count = stated != null ? max(stated, confirmed) : derived;
    _recalculateWithPlayers(count < 2 ? 2 : count);

    if (preserved.isEmpty) return;
    // Re-apply by level NUMBER. A rebuild can change how many levels there
    // are, so an edit whose level no longer exists is dropped rather than
    // appended somewhere it was never meant to be — and the host is told.
    final rebuilt = _currentGame!.structure;
    final restored = [
      for (final l in rebuilt.levels)
        if (l.level > _currentGame!.currentLevel && preserved.containsKey(l.level))
          preserved[l.level]!
        else
          l,
    ];
    final kept = restored.where((l) => l.manuallyEdited).length;
    final lost = preserved.length - kept;
    _currentGame = _currentGame!.copyWith(
      structure: _structureWithLevels(rebuilt, restored),
    );
    addAuditRecord(
      'structure_recalculate',
      'Structure recalculated for $count players. '
          '$kept manual level${kept == 1 ? '' : 's'} preserved'
          '${lost > 0 ? ', $lost dropped (no longer in the schedule)' : ''}.',
    );
    if (!_disposed) notifyListeners();
  }

  /// Technical section 17 offers THREE actions on the generated estimate:
  /// Regenerate, **Edit** and Confirm. The blind schedule had an editor;
  /// the starting stack had none, so a host who liked the structure but
  /// wanted a rounder stack could only Recalculate — which rebuilds
  /// everything and discards every manual blind edit. That is the "if I want
  /// to adjust something I have to start over" the client reported.
  ///
  /// This edits in place: blinds, level lengths, prizes and paid places are
  /// untouched, and section 21's rule holds — attendance is not disturbed, so
  /// nobody loses an RSVP or a check-in.
  ///
  /// Returns a human summary, or null when nothing changed.
  String? adjustStructure({required int startingStack}) {
    final game = _currentGame;
    if (game == null) return null;
    final s = game.structure;

    // Once play has started the stacks in front of people are physical facts.
    if (game.stacksLocked) {
      return 'The starting stack is frozen once play has begun.';
    }
    if (startingStack <= 0 || startingStack == s.startingStack) return null;
    _pushUndo();

    final openingSb = s.levels.isNotEmpty ? s.levels.first.sb : 0;
    final openingBb = s.levels.isNotEmpty ? s.levels.first.bb : 0;

    List<ChipPlanEntry> planFor(int stack) => TournamentEngine.chipPlanAtLevel(
          stack: stack,
          chips: game.settings.chipSet,
          currentBB: openingBb,
          playersRemaining: game.settings.players,
        );

    final addOnStack = s.addOnStack > 0 ? startingStack : 0;
    final structure = s.copyWith(
      startingStack: startingStack,
      chipPlan: planFor(startingStack),
      rebuyStack: startingStack,
      rebuyChipPlan: planFor(startingStack),
      addOnStack: addOnStack,
      addOnChipPlan: addOnStack > 0 ? planFor(addOnStack) : s.addOnChipPlan,
    );

    _currentGame = game.copyWith(
      structure: structure,
      totalChipsInPlay: startingStack * game.settings.players,
      // Editing invalidates a previous confirmation — the host has to look at
      // what they changed before it is locked in (section 17).
      structureConfirmed: false,
    );

    addAuditRecord(
      'structure_edit',
      'Starting stack edited: ${s.startingStack} -> $startingStack.',
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();

    final blindNote = openingSb > 0
        ? ' Opening blinds stay at $openingSb/$openingBb — recalculate if you '
            'want them rebuilt around the new stack.'
        : '';
    return 'Starting stack is now $startingStack.$blindNote';
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
        organizerPct: newSettings.effectiveOrganizerPct,
        rebuyCost: newSettings.rebuyCost,
        addOnCost: newSettings.addOnCost,
        breaks: newSettings.breaks,
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
      clearSpeedRecommendation: true,
    );
    addAnnouncement(
      'Structure recalculated for $count confirmed player${count != 1 ? 's' : ''}.',
      true,
    );
  }

  /// Applies admin edits to future levels (the structure editor modal).
  /// The active and already-finished levels are left untouched.
  /// Shared validation for blind-level durations (allowed: 10/15/20 min).
  /// Returns null when valid, otherwise the rejection message.
  String? _validateLevelDuration(int durationMins) {
    if (durationMins != 10 && durationMins != 15 && durationMins != 20) {
      return 'Level duration must be 10, 15 or 20 minutes.';
    }
    return null;
  }

  void applyLevelEdits(List<LevelEdit> edits) {
    final game = _currentGame;
    if (game == null || edits.isEmpty) return;
    for (final e in edits) {
      if (_validateLevelDuration(e.durationMins) != null ||
          e.sb <= 0 ||
          e.bb <= e.sb) {
        return;
      }
    }
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
    for (final l in futureLevels) {
      if (_validateLevelDuration(l.durationMins) != null ||
          l.sb <= 0 ||
          l.bb <= l.sb) {
        return;
      }
    }
    _pushUndo();
    // Keep all completed levels PLUS the currently active level.
    final prefix = game.structure.levels.take(game.currentLevel).toList();
    // Renumber sequentially so inserting a level shifts the rest correctly.
    //
    // Everything arriving here came out of the structure editor, so it is by
    // definition a manual edit (specification sections 11 and 29). The marker
    // is what stops Recalculate from throwing it away without asking, and what
    // the UI badges.
    var n = game.currentLevel + 1;
    final renumbered = [
      for (final l in futureLevels)
        BlindLevel(
          level: n++,
          sb: l.sb,
          bb: l.bb,
          ante: l.ante,
          durationMins: l.durationMins,
          manuallyEdited: true,
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
    final durationProblem = _validateLevelDuration(durationMins);
    if (durationProblem != null) return durationProblem;
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
    // Guard against re-entrant redraws: the seats and dealer were already
    // drawn on a previous confirm (e.g. a stale tap racing a state change),
    // so refuse to re-randomize the table/dealer.
    if (_currentGame!.finalTableRedrawCompleted) return;
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
    // RESUME the paused level — do not restart it.
    //
    // 13-030 says play resumes after the admin confirms seating, and 12-013
    // says the timer must not gain material time. The redraw fires mid-level
    // on an elimination, so rewriting `secondsRemaining` to a full level
    // handed the table however much of the level was left, every time.
    final remaining = _currentGame!.currentSecondsRemaining(
      _serverTimeOffset ?? Duration.zero,
    );
    final currentLevelData = _currentGame!.currentLevelData;
    final durationMins =
        currentLevelData?.durationMins ?? _currentGame!.structure.levelDuration;
    final resumeSeconds = remaining > 0 ? remaining : durationMins * 60;
    _currentGame = _currentGame!.copyWith(
      players: players,
      status: LiveGameStatus.running,
      timerRunning: true,
      finalTableRedrawCompleted: true,
      dealerPlayerId: dealer?.id,
      // Uses the server-calibrated clock (like every other timer reset) so the
      // countdown stays in sync across all connected devices.
      secondsRemaining: resumeSeconds,
      levelEndTime: _serverNow.add(Duration(seconds: resumeSeconds)),
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
    final paidPlaces = game.structure.prizes.isEmpty
        ? activeCount
        : game.structure.prizes.length;
    for (var place = 1; place <= min(paidPlaces, activeCount); place++) {
      if (!placeHolders.containsKey(place)) {
        return 'Paid place $place has no player assigned.';
      }
    }
    return null;
  }

  /// Updates the payout prizes (for custom deals/chops before finalizing results).
  void updatePrizes(List<Prize> customPrizes) {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    if (_currentGame == null) return;
    _pushUndo();
    _currentGame = _currentGame!.copyWith(
      structure: _currentGame!.structure.copyWith(
        prizes: customPrizes,
      ),
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  bool recordFinishOrder(List<String> order) {
    _forceClaimEditor();
    final game = _currentGame;
    if (game == null) return false;
    final error = _validateCompletionState(game, order);
    if (error != null) {
      _completionError = error;
      addAnnouncement(error, false);
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Incomplete results warning',
          body: 'Cannot end tournament: $error',
          type: NotificationType.system,
          link: '/result-podium',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
      if (!_disposed) notifyListeners();
      return false;
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
    return true;
  }

  /// Live add-on chip recommendation (09-032, User Flow section 4.13) and the
  /// rebuy composition for the CURRENT level (10-041 / 10-043).
  int get recommendedAddOnStack {
    final game = _currentGame;
    if (game == null) return 0;
    return TournamentEngine.recommendedAddOnStack(
      startingStack: game.structure.startingStack,
      totalChipsInPlay: game.totalChipsInPlay,
      playersRemaining: game.activePlayers.length,
      currentBB: game.currentLevelData?.bb ?? game.structure.levels.first.bb,
      chips: game.settings.chipSet,
    );
  }

  /// Physical composition of a rebuy handed out right now — same total value,
  /// fewer obsolete small chips as the blinds grow.
  List<ChipPlanEntry> get liveRebuyChipPlan {
    final game = _currentGame;
    if (game == null) return const [];
    return TournamentEngine.chipPlanAtLevel(
      stack: game.structure.rebuyStack,
      chips: game.settings.chipSet,
      currentBB: game.currentLevelData?.bb ?? game.structure.levels.first.bb,
      // Without a real head-count the divisor falls back to 1, letting a
      // single rebuy plan lay claim to the entire box — the host would be
      // told to hand over chips that are already in other people's stacks.
      playersRemaining: game.activePlayers.length,
    );
  }

  /// Composition of the recommended add-on at the current level.
  List<ChipPlanEntry> get liveAddOnChipPlan {
    final game = _currentGame;
    if (game == null) return const [];
    return TournamentEngine.chipPlanAtLevel(
      stack: recommendedAddOnStack,
      chips: game.settings.chipSet,
      currentBB: game.currentLevelData?.bb ?? game.structure.levels.first.bb,
      // Every active player may take one add-on, so the box has to stretch
      // that far — not to a single stack.
      playersRemaining: game.activePlayers.length,
    );
  }

  /// Applies the recommended add-on chip amount to the live structure so
  /// `grantAddOn` hands out that many chips (09-032). The PRICE stays the
  /// admin's own input.
  void applyRecommendedAddOnStack() {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    final game = _currentGame;
    if (game == null) return;
    final recommended = recommendedAddOnStack;
    if (recommended <= 0 || recommended == game.structure.addOnStack) return;
    _currentGame = game.copyWith(
      structure: game.structure.copyWith(addOnStack: recommended),
    );
    addAuditRecord(
      'addon_stack',
      'Add-on chip amount set to $recommended from the live table.',
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
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
    if (!_disposed) notifyListeners();
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
    if (!_disposed) notifyListeners();
  }
}
