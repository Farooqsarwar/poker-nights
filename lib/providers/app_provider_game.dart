/// AppProvider: Game domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Game ──`). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderGame on AppProvider {
  LiveGame? get currentGame => _currentGame;

  bool get canUndo {
    if (_undoStack.isEmpty || _currentGame == null) return false;
    final lastState = _undoStack.last;
    if (lastState == null) return false;
    // Undo is unsafe if a subsequent action modified the game state outside the stack
    return _currentGame!.revision == lastState.revision + 1;
  }

  /// Human-readable description of the most recent reversible action, used
  /// by the Undo confirmation ("Undo shows the action that will be reversed"
  /// — User Flow spec §12.6).
  String? get lastActionSummary {
    final history = _currentGame?.auditHistory;
    if (history == null || history.isEmpty) return null;
    return history.last.details;
  }

  void _pushUndo() {
    if (_currentGame == null) return;
    if (_undoStack.length >= AppProvider._maxUndoDepth) _undoStack.removeAt(0);
    _undoStack.add(_currentGame);
    _saveUndoStack();
  }

  void _clearUndoStack() {
    _undoStack.clear();
  }

  void _saveUndoStack() {
    final game = _currentGame;
    if (game == null) return;
    final stack = _undoStack.whereType<LiveGame>().toList();
    _repo.saveUndoStack(game.groupId, game.id, stack).catchError((Object e) {
      debugPrint('saveUndoStack failed: $e');
    });
  }

  void setCurrentGame(LiveGame game) {
    _clearUndoStack();
    // Re-apply the member's not-yet-acked RSVP / check-in so navigating into a
    // game never shows a stale bundle copy that drops a pending selection.
    _currentGame = _withPendingCheckInOverlay(_withOwnRsvpOverlay(game));
    if (!_disposed) notifyListeners();

    // Asynchronously load private sidecar data and undo stack if admin
    if (isAdmin) {
      _repo
          .loadPrivateGameData(game.groupId, game.id)
          .then((privateData) {
            if (_currentGame?.id == game.id && privateData != null) {
              _currentGame = _currentGame!.copyWith(
                settings: _currentGame!.settings.copyWith(
                  organizerPct:
                      (privateData['organizerPct'] as num?)?.toInt() ??
                      _currentGame!.settings.organizerPct,
                ),
                players: _restorePrivatePlayerFinancials(
                  _currentGame!.players,
                  privateData['players'],
                ),
                // Admin-only audit timeline (User Flow §11) — it no longer
                // travels in the game document, so a host opening the game on
                // a new device restores it from the sidecar.
                auditHistory: privateData['auditHistory'] is List
                    ? [
                        for (final e in privateData['auditHistory'] as List)
                          auditRecordFromMap(Map<String, dynamic>.from(e as Map)),
                      ]
                    : _currentGame!.auditHistory,
                rebuyRequests: privateData['rebuyRequests'] is List
                    ? List<String>.from(privateData['rebuyRequests'] as List)
                    : _currentGame!.rebuyRequests,
                addOnRequests: privateData['addOnRequests'] is List
                    ? List<String>.from(privateData['addOnRequests'] as List)
                    : _currentGame!.addOnRequests,
                structure: _currentGame!.structure.copyWith(
                  prizes: privateData['prizes'] != null
                      ? (privateData['prizes'] as List)
                            .map(
                              (e) =>
                                  Prize(place: e['place'], amount: e['amount']),
                            )
                            .toList()
                      : _currentGame!.structure.prizes,
                  organizerAmount:
                      (privateData['organizerAmount'] as num?)?.toInt() ??
                      _currentGame!.structure.organizerAmount,
                ),
              );
              if (!_disposed) notifyListeners();
            }
          })
          .catchError((Object e) {
            debugPrint('Failed to load private sidecar: $e');
          });

      if (game.status.isActiveLive) {
        _repo
            .loadUndoStack(game.groupId, game.id)
            .then((stack) {
              if (_currentGame?.id == game.id) {
                _undoStack.clear();
                _undoStack.addAll(stack);
                if (!_disposed) notifyListeners();
              }
            })
            .catchError((Object e) {
              debugPrint('Failed to load undo stack: $e');
            });
      }
    }
  }

  /// Merges per-player financial fields (rebuys / reEntries / hasAddOn /
  /// knockouts) back from the admin-only private sidecar, so an admin reload
  /// keeps the true figures even though the public game doc carries them
  /// scrubbed for non-authority readers (User Flow §2.3/§5.6).
  List<Player> _restorePrivatePlayerFinancials(
    List<Player> current,
    Object? raw,
  ) {
    if (raw is! List) return current;
    final saved = <String, Player>{};
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        final p = playerFromMap(Map<String, dynamic>.from(e));
        saved[p.id] = p;
      } catch (_) {}
    }
    if (saved.isEmpty) return current;
    return current.map((p) {
      final r = saved[p.id];
      if (r == null) return p;
      return p.copyWith(
        rebuys: r.rebuys,
        reEntries: r.reEntries,
        hasAddOn: r.hasAddOn,
        knockouts: r.knockouts,
      );
    }).toList();
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
      id: Formatters.secureId('game'), // 19-007: ids must not be guessable
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
    if (!_disposed) notifyListeners();
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
    _forceClaimEditor();
    final wasPublished = _currentGame?.status == LiveGameStatus.published;
    _currentGame = _currentGame!.copyWith(status: status);
    // Client feedback (07-018): inside the 30-minute window before start the
    // AI refreshes the stacks/blinds/levels estimate from the expected count.
    if (status == LiveGameStatus.checkin)
      generateFinalStructure(currentGame!.confirmedCount);
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
    if (!_disposed) notifyListeners();
  }

  /// Cancels the tournament. Requires a reason: it is recorded in the audit
  /// log and members are notified (spec §12, checklist 10-042). Blocking —
  /// once cancelled the game cannot be started again.
  void cancelGame(String reason) {
    if (!isAdmin) return;
    forceEditorClaim = true;
    _forceClaimEditor();
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
    final pinnedCard = _currentGroup.chat
        .where((c) => c.pinned && c.gameId == game.id && !c.deleted)
        .firstOrNull;
    if (pinnedCard != null) {
      deleteMessage(pinnedCard.id);
    }
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
    // Mirror into the group LAST: the audit record and the announcement above
    // mutate `_currentGame`, so syncing before them left the group's copy (the
    // one the hub's upcoming list renders) on a pre-cancel snapshot.
    _syncGroupGame();
    if (!_disposed) notifyListeners();
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
    final koText = game.settings.koEnabled && game.settings.koAmount > 0
        ? 'KO Bounty: ${game.settings.koAmount}'
        : null;

    final card = ChatMessage(
      id: 'pinned-${DateTime.now().millisecondsSinceEpoch}',
      authorId: _user!.id,
      authorName: _user!.name,
      body:
          '${game.settings.name} — ${game.settings.date} at ${game.settings.time}\n'
          'Buy-in: ${game.settings.buyIn} · Code: ${game.publicCode}\n'
          '$anteText · $rebuyText · $addonText'
          '${koText == null ? "" : " · $koText"}',
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
    if (_backendUp) {
      unawaited(_repo.upsertGameCodes(_currentGame!));
    }
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
    if (!_disposed) notifyListeners();
  }

  /// Whether two chip inventories are the same tray of physical chips.
  ///
  /// [ChipColor] has a value equality, but the lists arrive in whatever order
  /// the editor left them in, so a plain `==` on the lists would report a
  /// reordering as a change and regenerate the structure for nothing.
  bool _sameChipSet(List<ChipColor> a, List<ChipColor> b) {
    if (a.length != b.length) return false;
    final sortedA = [...a]..sort((x, y) => x.value - y.value);
    final sortedB = [...b]..sort((x, y) => x.value - y.value);
    for (var i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
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
    // The structure only depends on players, buy-in, duration, the chip
    // inventory and the ante/rebuy rules; cosmetic fields
    // (name/date/time/location/privacy) keep the structure.
    //
    // `chipSet` was missing from this list, so once chips became editable
    // after publish (User Flow 4.5) a host could change their tray and the
    // app would keep planning stacks out of chips they no longer had.
    final affectsStructure =
        prev.players != s.players ||
        !_sameChipSet(prev.chipSet, s.chipSet) ||
        prev.expectedPlayersOverride != s.expectedPlayersOverride ||
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
    if (!_sameChipSet(prev.chipSet, s.chipSet)) {
      edits.add('chip set → ${s.chipSetName} (${s.chipSet.length} colours)');
    }
    if (prev.expectedPlayersOverride != s.expectedPlayersOverride) {
      edits.add(
        s.expectedPlayersOverride == null
            ? 'expected players → follow RSVPs'
            : 'expected players → ${s.expectedPlayersOverride}',
      );
    }
    if (prev.locationPrivate != s.locationPrivate) {
      edits.add(s.locationPrivate ? 'address hidden' : 'address visible');
    }

    if (affectsStructure) {
      if (game.structure.levels.isEmpty &&
          !(game.status == LiveGameStatus.ready)) {
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
            // `s.players` is the ROSTER at this point in the lifecycle, not
            // a confirmed head-count, so an override must replace it outright
            // rather than being floored by it — otherwise a host planning a
            // small game inside a large group would silently get the group's
            // size. `generateFinalStructure` floors by actual check-ins,
            // which is the only figure an override may not undercut.
            players: s.expectedPlayersOverride != null
                ? max(2, s.expectedPlayersOverride!)
                : s.players,
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
          clearSpeedRecommendation: true,
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
    if (!_disposed) notifyListeners();
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
    final anteText = s.anteEnabled ? 'Ante: L${s.anteAfterLevel}+' : 'No ante';
    final rebuyText = s.rebuysCloseLevel > 0
        ? 'Rebuys: until L${s.rebuysCloseLevel}'
        : 'No rebuys';
    final addonText = s.addOn ? 'Add-on: Yes' : 'No add-on';
    final koText = s.koEnabled && s.koAmount > 0
        ? 'KO Bounty: ${s.koAmount}'
        : null;
    final card = ChatMessage(
      id: 'pinned-${DateTime.now().millisecondsSinceEpoch}',
      authorId: _user!.id,
      authorName: _user!.name,
      body:
          '${s.name} — ${s.date} at ${s.time}\n'
          'Buy-in: ${s.buyIn} · Code: ${game.publicCode}\n'
          '$anteText · $rebuyText · $addonText'
          '${koText == null ? "" : " · $koText"}\n'
          'Updated: $newestChangeLogEntry',
      timestamp: DateTime.now(),
      deleted: false,
      pinned: true,
      gameId: game.id,
    );
    _currentGame = game.copyWith(chat: [...game.chat, card]);
    _setGroup(_currentGroup.copyWith(chat: [..._currentGroup.chat, card]));
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
  ({
    int organizerAmount,
    int prizePool,
    List<Prize> prizes,
    int roundingRemainder,
  })
  previewSettlementPrizes(int addOnCount) {
    final game = _currentGame;
    if (game == null) {
      return (
        organizerAmount: 0,
        prizePool: 0,
        prizes: const [],
        roundingRemainder: 0,
      );
    }
    final s = game.settings;
    final confirmedCount = game.players.where((p) => p.confirmed).length;
    final rebuys = game.players.fold<int>(0, (sum, p) => sum + p.rebuys);
    final reEntries = game.players.fold<int>(0, (sum, p) => sum + p.reEntries);
    final addOns = game.players.where((p) => p.hasAddOn).length + addOnCount;

    final gross = TournamentEngine.grossEligibleFor(
      confirmedCount: confirmedCount,
      buyIn: s.buyIn,
      totalRebuys: rebuys,
      effectiveRebuyCost: s.effectiveRebuyCost,
      totalReEntries: reEntries,
      addOnEnabled: s.addOn,
      totalAddOns: addOns,
      effectiveAddOnCost: s.effectiveAddOnCost,
    );
    final int roundingUnit = TournamentEngine.roundingUnitFor(s.buyIn);

    return TournamentEngine.recalculatePrizes(
      gross,
      confirmedCount,
      s.organizerPct.toDouble(),
      forcePaidPlaces: s.forcePaidPlaces,
      roundingUnit: roundingUnit,
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
    if (!_disposed) notifyListeners();
  }
}
