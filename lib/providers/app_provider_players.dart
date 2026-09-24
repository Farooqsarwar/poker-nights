/// AppProvider: Players domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Player management ──` + `// ── Guest session ──`). Do not change business logic.
part of 'app_provider.dart';

/// §25.4b. The three gameplay events a per-player undo may reverse.
///
/// `Remove player` is deliberately absent: the spec calls it "a roster
/// correction, not a gameplay event" and rules it out of this path explicitly.
enum PlayerActionKind { rebuy, addOn, bust }

extension AppProviderPlayers on AppProvider {
  void eliminatePlayer(String playerId, {String? koRecipientId, String? idempotencyKey}) {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    final (rev, key) =
        _claimIdempotency(idempotencyKey ?? '', action: 'eliminatePlayer', target: playerId);
    if (rev == null) return; // replayed action — already applied
    _pushUndo();
    final active = _currentGame!.players
        .where((p) => p.active && !p.eliminated)
        .toList();
    final pos = active.length;
    final bounty = _currentGame!.settings.koEnabled
        ? _currentGame!.settings.koAmount
        : 0;
    // §25.5 / §3: "at each elimination, also check the survivors' current
    // stacks against their stored lowestStackBB and update if this is a new
    // low." Only meaningful for a player the host has actually entered a
    // [Player.stack] for — most nights that will be nobody, and the recap
    // stays honestly empty rather than inventing a sample.
    final currentBB = _currentGame!.currentLevelData?.bb ?? 0;
    final updated = _currentGame!.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(
          eliminated: true,
          active: false,
          eliminationPos: pos,
          eliminatedAtLevel: _currentGame!.currentLevel,
          table: 0,
          seat: 0,
        );
      }
      var next = p;
      // Optional single knockout recipient (technical §11.3). The bounty
      // chips transfer from the eliminated player, so total chips in play
      // is unchanged — only the recipient's knockout count increases.
      if (koRecipientId != null && p.id == koRecipientId) {
        next = next.copyWith(knockouts: next.knockouts + 1);
      }
      if (next.active && !next.eliminated) {
        final sampled = sampledLowestStackBB(
          existing: next.lowestStackBB,
          stack: next.stack,
          currentBB: currentBB,
        );
        if (sampled != next.lowestStackBB) {
          next = next.copyWith(lowestStackBB: sampled);
        }
      }
      return next;
    }).toList();
    final remaining = updated.where((p) => p.active).length;
    // Final table redraw only fires for multi-table events (spec §7 and BR-020: "If a
    // multi-table event hits <= 9 players, a complete random redraw occurs.
    // Single table events do NOT trigger a redraw."). Seat-based single source of
    // truth — matches admin_dashboard's hadMultipleTables, so the auto-trigger
    // and the manual "Final Table Reached!" prompt can never disagree.
    final multiTableEvent = _currentGame!.players.any((p) => p.table > 1);
    final redrawNotCompleted = !_currentGame!.finalTableRedrawCompleted;
    if (remaining <= 9 && multiTableEvent && redrawNotCompleted) {
      _currentGame = _currentGame!.copyWith(
        players: updated,
        status: LiveGameStatus.finaltable,
        timerRunning: false,
        revision: rev,
        lastIdempotencyKey: key,
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
      _currentGame = _currentGame!.copyWith(
        players: updated,
        revision: rev,
        lastIdempotencyKey: key,
      );
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
    // Spec 14: elimination records the finishing position and a timestamp.
    addAuditRecord(
      'elimination',
      '${p.name} eliminated'
          '${p.eliminationPos != null ? ' in position ${p.eliminationPos}' : ''}'
          '${koRecipientId != null && bounty > 0 ? ' — $bounty bounty awarded' : ''}.',
    );
  }

  /// Manual trigger for final table state (small tournaments that never
  /// auto-transition because they started with ≤9 players).
  void triggerFinalTable() {
    _forceClaimEditor();
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
    if (!_disposed) notifyListeners();
  }

  /// Explicitly corrects a past elimination without using Undo (which is unsafe
  /// if dependent actions occurred). Adds a compensating audit action.
  void correctElimination(String playerId) {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    if (_currentGame == null) return;

    // We intentionally bypass `_pushUndo()` for audit preservation,
    // but the spec says "never delete audit history", so we just append.
    final (rev, key) = _claimIdempotency('', action: 'correct-elim-$playerId');
    if (rev == null) return;
    
    final players = _currentGame!.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(
          eliminated: false,
          clearEliminationPos: true,
          active: true,
        );
      }
      return p;
    }).toList();

    _currentGame = _currentGame!.copyWith(players: players, revision: rev, lastIdempotencyKey: key);
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
  void grantRebuy(String playerId, {String? idempotencyKey}) {
    final game = _currentGame;
    if (game == null || !canGrantRebuys) return;
    final (rev, idemKey) =
        _claimIdempotency(idempotencyKey ?? '', action: 'grantRebuy', target: playerId);
    if (rev == null) return; // replayed action — already applied
    if (!game.settings.rebuys || game.rebuysClosed) return;
    final player = game.players.where((p) => p.id == playerId).firstOrNull;
    if (player == null || !player.eliminated) return;
    final rebuyLimit = game.settings.rebuyLimit;
    if (rebuyLimit != null && player.rebuys >= rebuyLimit) {
      lastRsvpError = '${player.name} has already used their $rebuyLimit '
          'rebuy${rebuyLimit == 1 ? '' : 's'}.';
      if (!_disposed) notifyListeners();
      return;
    }

    _pushUndo();
    final rebuyStack = game.structure.rebuyStack;
    _currentGame = game.copyWith(
      players: game.players
          .map((p) => p.id == playerId
              ? p.copyWith(
                  rebuys: p.rebuys + 1,
                  eliminated: false,
                  clearEliminationPos: true,
                  active: true,
                )
              : p)
          .toList(),
      totalChipsInPlay: game.totalChipsInPlay + rebuyStack,
      rebuyRequests: game.rebuyRequests.where((id) => id != playerId).toList(),
      revision: rev,
      lastIdempotencyKey: idemKey,
    );
    // Recalculate prize pool/prizes after money enters the game.
    // This updates only prizePool, organizerAmount and prizes on the structure,
    // leaving blind levels and any manual edits completely intact.
    _updatePrizePool();
    // Spec sections 14 and 29: every live operational action creates a
    // timestamped activity-log record. Money entering the game without one was
    // the largest gap in the log.
    addAuditRecord(
      'rebuy',
      '${player.name} rebought for ${game.settings.effectiveRebuyCost} '
          '(rebuy ${player.rebuys + 1}) — $rebuyStack chips added.',
    );
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
    _queueOrPatchRequest('rebuyReq', playerId);
    if (!_disposed) notifyListeners();
  }

  /// Delivers a member's rebuy / add-on request to the admin device.
  ///
  /// A non-authority device posts it to `requests/{gameId}/items`, which only
  /// a group admin may list, instead of array-unioning its own id into the
  /// game document. The arrays used to live there, and every member could read
  /// them — i.e. see who had asked for a rebuy (User Flow section 5.6 /
  /// section 22). The admin's `_consumeRequests` loop applies the queued item
  /// to the authoritative game, so the end state is unchanged.
  void _queueOrPatchRequest(String kind, String playerId) {
    if (_isGameAuthority) return; // already applied locally by the authority
    final game = _currentGame;
    if (game == null || !_backendUp || game.groupId.isEmpty) return;
    unawaited(
      _repo
          .pushRequest(
            gameId: game.id,
            kind: kind,
            payload: {'gid': game.groupId, 'playerId': playerId},
            idempotencyKey: '$kind-$playerId',
          )
          .catchError((Object e) => debugPrint('pushRequest($kind) failed: $e')),
    );
  }


  void cancelRebuyRequest(String playerId) {
    _currentGame = _currentGame!.copyWith(
      rebuyRequests: _currentGame!.rebuyRequests
          .where((id) => id != playerId)
          .toList(),
    );
    _queueOrPatchRequest('rebuyCancelReq', playerId);
    if (!_disposed) notifyListeners();
  }

  /// Records a re-entry (checklist §12.5): a separate, secondary option that
  /// grants the approved entry stack and is tracked independently of rebuys
  /// (12-046/12-047). Closes with late registration/rebuys (12-049), which is
  /// enforced by only showing the action while rebuys are still open.
  void grantReEntry(String playerId, {String? idempotencyKey}) {
    final game = _currentGame;
    if (game == null || !canGrantRebuys) return;
    final (rev, idemKey) =
        _claimIdempotency(idempotencyKey ?? '', action: 'grantReEntry', target: playerId);
    if (rev == null) return; // replayed action — already applied
    final player = game.players.where((p) => p.id == playerId).firstOrNull;
    if (player == null || !player.eliminated) return;
    if (!game.canReEnter(player)) return;

    _pushUndo();
    final entryStack = game.structure.startingStack;
    _currentGame = game.copyWith(
      players: game.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(
                    reEntries: p.reEntries + 1,
                    eliminated: false,
                    clearEliminationPos: true,
                    active: true,
                  )
                : p,
          )
          .toList(),
      totalChipsInPlay: game.totalChipsInPlay + entryStack,
      revision: rev,
      lastIdempotencyKey: idemKey,
    );
    _updatePrizePool();
  }

  /// §3's [Player.stack]: the host's manual, spot-check chip count for one
  /// player. Not gameplay-advancing on its own — it only feeds §25.5's
  /// low-water-mark sample at the NEXT elimination — so it is not idempotency-
  /// guarded or undo-tracked the way rebuys/add-ons/eliminations are; a host
  /// correcting a mistyped count should not need Undo for it.
  void updatePlayerStack(String playerId, int? stack) {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    final game = _currentGame;
    if (game == null) return;
    _currentGame = game.copyWith(
      players: [
        for (final p in game.players)
          if (p.id == playerId)
            stack == null
                ? p.copyWith(clearStack: true)
                : p.copyWith(stack: stack)
          else
            p,
      ],
    );
    if (!_disposed) notifyListeners();
  }

  void grantAddOn(String playerId, {String? idempotencyKey}) {
    final game = _currentGame;
    if (game == null || !canGrantRebuys) return;
    final (rev, idemKey) =
        _claimIdempotency(idempotencyKey ?? '', action: 'grantAddOn', target: playerId);
    if (rev == null) return; // replayed action — already applied
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
      revision: rev,
      lastIdempotencyKey: idemKey,
    );
    // Recalculate prize pool/prizes after money enters the game.
    _updatePrizePool();
    addAuditRecord(
      'addon',
      '${player.name} took the add-on for '
          '${game.settings.effectiveAddOnCost} — $addOnStack chips added.',
    );
  }

  /// Registers a player's request for an add-on from the live view. The admin
  /// approves it during the settlement flow, which clears the request.
  void requestAddOn(String playerId) {
    if (_currentGame!.addOnRequests.contains(playerId)) return;
    _currentGame = _currentGame!.copyWith(
      addOnRequests: [..._currentGame!.addOnRequests, playerId],
    );
    _queueOrPatchRequest('addOnReq', playerId);
    if (!_disposed) notifyListeners();
  }

  void cancelAddOnRequest(String playerId) {
    _currentGame = _currentGame!.copyWith(
      addOnRequests: _currentGame!.addOnRequests
          .where((id) => id != playerId)
          .toList(),
    );
    _queueOrPatchRequest('addOnCancelReq', playerId);
    if (!_disposed) notifyListeners();
  }

  void undoLast() {
    if (_undoStack.isEmpty) {
      addAnnouncement('Nothing to undo.', false);
      return;
    }
    final previous = _undoStack.removeLast();
    if (previous == null) return;
    _currentGame = previous;
    _saveUndoStack(); // <-- newly added sidecar persistence
    if (!_disposed) notifyListeners();
    addAnnouncement('Last action undone.', false);
  }

  // ── §25.4b per-player undo ─────────────────────────────────────────────────
  //
  // Spec deviation #13: "Per-player undo is filtered removal, not a stack pop —
  // a host correcting one player's last action shouldn't have to also undo
  // everyone else's actions taken since."
  //
  // The spec's algorithm walks a typed event stack and removes one entry. This
  // app's undo stack is not that: `_undoStack` is `List<LiveGame?>`, whole-game
  // snapshots, and §32.5 says the storage does NOT change — only the traversal
  // does. You cannot filter one player's event out of a snapshot, because a
  // snapshot is not a set of events. So the inverse is applied DIRECTLY to the
  // live game here, which produces the state the spec's `applyInverse` would,
  // and [undoLast]'s snapshot stack is left completely alone — undoing one
  // player's rebuy no longer rolls back everyone else's evening.
  //
  // What the direct inverse cannot recover is noted at each branch below.

  /// Reverse-chronological search for the last gameplay event belonging to one
  /// player, using the audit timeline — the only per-action record this app
  /// keeps (§14/§29: "every live operational action creates a timestamped
  /// activity-log record"). Returns the audit record and the kind it maps to.
  ///
  /// The acting player's name always opens the detail line in every one of the
  /// three writers ([grantRebuy], [grantAddOn], [eliminatePlayer]), so the
  /// prefix match is exact rather than a substring scan. Two players sharing a
  /// display name would be ambiguous; the state fallback below covers the case
  /// where the timeline is unavailable at all.
  (AuditRecord, PlayerActionKind)? _lastPlayerAuditEvent(Player p) {
    final history = _currentGame?.auditHistory;
    if (history == null) return null;
    for (final rec in history.reversed) {
      if (!rec.details.startsWith('${p.name} ')) continue;
      switch (rec.type) {
        case 'rebuy':
          return (rec, PlayerActionKind.rebuy);
        case 'addon':
          return (rec, PlayerActionKind.addOn);
        case 'elimination':
          return (rec, PlayerActionKind.bust);
      }
    }
    return null;
  }

  /// What a per-player undo would reverse for [playerId], or null when there
  /// is nothing of theirs to reverse. Pure — the UI can label its button with
  /// this before the host commits.
  ({PlayerActionKind kind, String summary})? lastUndoablePlayerAction(
    String playerId,
  ) {
    final game = _currentGame;
    if (game == null) return null;
    final p = game.players.where((x) => x.id == playerId).firstOrNull;
    if (p == null) return null;

    final event = _lastPlayerAuditEvent(p);
    if (event != null) {
      return (kind: event.$2, summary: event.$1.details);
    }
    // Fallback: the audit timeline is an admin-only sidecar and can be empty
    // (a co-admin device that has not loaded it, or a restored session). State
    // still tells us which events happened, just not their order, so fall back
    // to the order the spec's own list implies — the most consequential first.
    if (p.eliminated) {
      return (kind: PlayerActionKind.bust, summary: '${p.name} eliminated.');
    }
    if (p.hasAddOn) {
      return (kind: PlayerActionKind.addOn, summary: '${p.name} took the add-on.');
    }
    if (p.rebuys > 0) {
      return (kind: PlayerActionKind.rebuy, summary: '${p.name} rebought.');
    }
    return null;
  }

  /// Pulls the knocker-out's name back out of an elimination audit line.
  ///
  /// [eliminatePlayer] writes "X eliminated by Y — N bounty awarded.", and the
  /// knockout credit lives only on the recipient's counter — there is no field
  /// on the eliminated player recording who busted them. Reading the line this
  /// module wrote itself is the only way to give the credit back; without it,
  /// undoing a bust would silently leave a phantom knockout on the books.
  String? _knockerOutNameFrom(String details, String playerName) {
    const marker = ' eliminated by ';
    final start = details.indexOf(marker, playerName.length);
    if (start < 0) return null;
    final from = start + marker.length;
    final dash = details.indexOf(' —', from);
    final name = (dash < 0 ? details.substring(from) : details.substring(from, dash))
        .trim();
    return name.isEmpty || name == '?' ? null : name;
  }

  /// §25.4b. Reverses ONE player's last gameplay action — rebuy, add-on or
  /// bust — leaving every other player's actions since then untouched.
  ///
  /// `Remove player` is deliberately not reversible here: §25.4b calls it "a
  /// roster correction, not a gameplay event". Use the normal add-player path.
  ///
  /// Returns a summary of what was reversed, or null when there was nothing.
  String? undoLastPlayerAction(String playerId) {
    _forceClaimEditor();
    if (!_isGameAuthority) return null;
    final game = _currentGame;
    if (game == null) return null;
    final p = game.players.where((x) => x.id == playerId).firstOrNull;
    if (p == null) return null;
    final action = lastUndoablePlayerAction(playerId);
    if (action == null) return null;

    final (rev, key) = _claimIdempotency(
      '',
      action: 'undoLastPlayerAction',
      target: playerId,
    );
    if (rev == null) return null;
    _pushUndo();

    var chipsBack = 0;
    String summary;
    var players = game.players;

    switch (action.kind) {
      case PlayerActionKind.rebuy:
        if (p.rebuys <= 0) return null;
        // The chips come off at the CURRENT rebuy stack. A host who edited the
        // structure between the rebuy and the correction would see a small
        // discrepancy — the snapshot stack cannot tell us the old figure
        // either, and the alternative is leaving the chips in play forever.
        chipsBack = game.structure.rebuyStack;
        players = [
          for (final x in game.players)
            if (x.id == playerId) x.copyWith(rebuys: x.rebuys - 1) else x,
        ];
        // Note the player is NOT re-eliminated. §25.4b lists the inverse as
        // "decrement rebuys" only, and the common correction is a rebuy
        // credited to the wrong person — who was never out in the first place.
        summary = '${p.name}\'s last rebuy reversed '
            '($chipsBack chips removed).';
      case PlayerActionKind.addOn:
        if (!p.hasAddOn) return null;
        chipsBack = game.structure.addOnStack;
        players = [
          for (final x in game.players)
            if (x.id == playerId) x.copyWith(hasAddOn: false) else x,
        ];
        summary = '${p.name}\'s add-on reversed ($chipsBack chips removed).';
      case PlayerActionKind.bust:
        if (!p.eliminated) return null;
        final koName = _knockerOutNameFrom(action.summary, p.name);
        var creditReturned = false;
        players = game.players.map((x) {
          if (x.id == playerId) {
            return x.copyWith(
              eliminated: false,
              active: true,
              clearEliminationPos: true,
              clearEliminatedAtLevel: true,
            );
          }
          // Only the FIRST match gives the credit back, so a duplicate display
          // name cannot cost two people a knockout for one reversal.
          if (!creditReturned &&
              koName != null &&
              x.name == koName &&
              x.knockouts > 0) {
            creditReturned = true;
            return x.copyWith(knockouts: x.knockouts - 1);
          }
          return x;
        }).toList();
        // The seat is NOT restored: `eliminatePlayer` zeroes table and seat and
        // the snapshot is gone, so the host re-seats from the Seating tab —
        // the same path a late arrival uses.
        summary = '${p.name} un-eliminated'
            '${creditReturned ? ", knockout credit returned to $koName" : ''}.';
    }

    _currentGame = game.copyWith(
      players: players,
      totalChipsInPlay: (game.totalChipsInPlay - chipsBack).clamp(0, 99999999),
      revision: rev,
      lastIdempotencyKey: key,
    );
    // Money left the game, so the pool and the prizes move with it.
    _updatePrizePool();
    addAuditRecord('undo_player_action', summary);
    addAnnouncement(summary, false);
    _syncGroupGame();
    if (!_disposed) notifyListeners();
    return summary;
  }

  void requestCheckIn(String playerId) {
    final requester = _currentGame!.players
        .where((p) => p.id == playerId)
        .firstOrNull;
    // Blocking terminal states (spec §12) — the door is shut for good. A
    // member (or an admin) whose screen predates the cancellation could
    // otherwise still check in and resurrect activity on a dead game.
    if (_currentGame!.status == LiveGameStatus.cancelled) {
      addAnnouncement('This tournament has been cancelled.', false);
      return;
    }
    if (_currentGame!.status == LiveGameStatus.completed) {
      addAnnouncement('This tournament has finished.', false);
      return;
    }
    if (_currentGame!.registrationClosed) {
      addAnnouncement('Late registration has closed.', false);
      return;
    }
    // A member with no roster row yet (joined the group after this game was
    // seeded, or never answered the invite) gets one created here, implicitly
    // "Going" + checked in. This MUST persist as a single whole-row write
    // below — a narrow `players.{id}.checkedIn` dot-patch against a row that
    // doesn't exist server-side yet creates a map with ONLY that field,
    // missing `name`/`id`/etc., which then throws a null-cast when any
    // client decodes the game doc (corrupting reads for everyone).
    final isNewRow = requester == null;
    final newPlayer = isNewRow
        ? _memberAsPlayer(playerId, Rsvp.going).copyWith(
            checkedIn: true,
            confirmed: false,
          )
        : null;
    _currentGame = _currentGame!.copyWith(
      players: isNewRow
          ? [..._currentGame!.players, newPlayer!]
          : _currentGame!.players
                .map(
                  (p) => p.id == playerId
                      ? p.copyWith(checkedIn: true, confirmed: false)
                      : p,
                )
                .toList(),
    );

    final gameId = _currentGame?.id;
    if (gameId != null) {
      _pendingCheckIn[gameId] = playerId;
      _checkInLanded[gameId] = false;
      _persistPref('pendingCheckIn', _pendingCheckIn);
    }

    if (!_isGameAuthority) {
      final gameId = _currentGame?.id;
      if (gameId != null && _backendUp) {
        _persistOwnCheckInPatch(
          gameId,
          isNewRow
              ? {'players.$playerId': playerToMap(newPlayer!)}
              : {
                  'players.$playerId.checkedIn': true,
                  'players.$playerId.confirmed': false,
                },
        );
      }
    }
    // Admin path: whole-doc save via _syncGameToCloud handles persistence.

    // Tell the host somebody is at the door.
    //
    // This used to be gated on `_user?.id != playerId`, but BOTH call sites
    // are the member checking THEMSELVES in — so the condition was never true
    // and the host was never notified at all. They only found out by happening
    // to have the check-in screen open. Address it to the group's admins so
    // the requester's own inbox stays clean.
    final requesterName =
        requester?.name ??
        (playerId == _user?.id
            ? (_user?.name ?? 'A member')
            : _currentGroup.members
                      .where((m) => m.id == playerId)
                      .firstOrNull
                      ?.name ??
                  'A member');
    final hostIds = <String>{
      if (_currentGroup.ownerId.isNotEmpty) _currentGroup.ownerId,
      for (final m in _currentGroup.members)
        if (m.isAdmin) m.id,
    }..remove(playerId);
    if (hostIds.isNotEmpty) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Check-in request',
          body: '$requesterName is waiting to be checked in.',
          type: NotificationType.game,
          link: '/check-in',
          read: false,
          timestamp: DateTime.now(),
          audience: hostIds.toList(),
        ),
      );
    }
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  void checkInPlayer(String playerId) {
    _forceClaimEditor();
    // Blocking terminal states (spec §12) — the door is shut for good. A
    // member (or an admin) whose screen predates the cancellation could
    // otherwise still check in and resurrect activity on a dead game.
    if (_currentGame!.status == LiveGameStatus.cancelled) {
      addAnnouncement('This tournament has been cancelled.', false);
      return;
    }
    if (_currentGame!.status == LiveGameStatus.completed) {
      addAnnouncement('This tournament has finished.', false);
      return;
    }
    if (_currentGame!.registrationClosed) {
      addAnnouncement('Late registration has closed.', false);
      return;
    }
    // Addendum §3 and §4: free hosting is one table, up to nine active
    // players. Checked HERE rather than only in the UI, because the screens
    // are not the only way in -- a kiosk, a self-check-in or a later caller
    // would otherwise walk straight past the limit.
    final alreadyIn = _currentGame!.players
        .where((p) => p.checkedIn && p.confirmed && p.id != playerId)
        .length;
    if (!canHostPlayers(alreadyIn + 1)) {
      lastRsvpError = Entitlements.hostingBlockedReason(
        premiumTier,
        alreadyIn + 1,
      );
      if (!_disposed) notifyListeners();
      return;
    }

    // §25.1a. Eligibility only — the chip bonus itself cannot be computed
    // until the starting stack is final, which happens at Start
    // ([AppProviderTimer.startTimer]), not here. A player who checks in,
    // cancels, and checks in again after the cutoff loses eligibility, since
    // this is recomputed fresh every call rather than sticking once true.
    final settings = _currentGame!.settings;
    final earlyArrivalBonusEligible = isEarlyArrivalEligible(
      bonusEnabled: settings.earlyArrivalBonusEnabled,
      scheduledStart: settings.scheduledStart,
      now: _serverNow,
      cutoffMins: settings.effectiveEarlyArrivalCutoffMins,
    );

    _pushUndo();
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(
                    checkedIn: true,
                    confirmed: true,
                    // §8.1's no-show gate flips a flag instead of deleting the
                    // row precisely so "the seat stays reserved so a late
                    // arrival can still be added normally". Clearing
                    // `confirmed` alone left them half-in: they counted in
                    // `confirmedCount`, so their buy-in entered `grossEligible`,
                    // but `LiveGame.activePlayers` is `active && !eliminated`,
                    // so they could not be seated, eliminated, or seen by
                    // `isOnBubble`. The game took their money and refused them
                    // a chair. Both flags have to come back.
                    noShow: false,
                    active: true,
                    earlyArrivalBonusEligible: earlyArrivalBonusEligible,
                  )
                : p,
          )
          .toList(),
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  void cancelCheckIn(String playerId) {
    _forceClaimEditor();
    _currentGame = _currentGame!.copyWith(
      players: _currentGame!.players
          .map(
            (p) => p.id == playerId
                ? p.copyWith(checkedIn: false, confirmed: false)
                : p,
          )
          .toList(),
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  /// Closes door check-in (spec §4.7). Once closed, the host is prompted to
  /// start the tournament and no further walk-ins are accepted.
  void closeCheckIn() {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    _currentGame = _currentGame!.copyWith(
      checkInClosed: true,
      status: LiveGameStatus.ready,
    );
    _syncGroupGame();
    addAnnouncement(
      'Check-in is now closed. No more players may join unless re-opened.',
      false,
    );
    if (!_disposed) notifyListeners();
  }

  void reopenCheckIn() {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    _currentGame = _currentGame!.copyWith(
      checkInClosed: false,
      status: LiveGameStatus.checkin,
    );
    _syncGroupGame();
    addAnnouncement('Check-in re-opened.', false);
    if (!_disposed) notifyListeners();
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
    _forceClaimEditor();
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
    if (game.registrationClosed) {
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
    if (!_disposed) notifyListeners();
    return null;
  }

  void confirmGuest(String guestId) {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
    _pushUndo();
    final game = _currentGame!;
    final guest = game.players.where((p) => p.id == guestId).firstOrNull;

    // #3: Only confirm a guest that actually exists. Never add chips for a
    // phantom row (e.g. a stale Accept tap that raced a state change).
    if (guest == null) return;

    // #4: Late-registration re-check at confirm time — no new stacks once
    // rebuys have closed while the game is live. Mirrors the guard applied
    // when the guest request first arrived (_applyQueuedGuestCheckIn) so the
    // admin cannot confirm a late guest the event no longer accepts.
    if (game.registrationClosed) {
      addAnnouncement(
        'Late registration is closed — ${guest.name} cannot be confirmed now.',
        false,
      );
      return;
    }

    // Auto-seat late arrivals so a confirmed guest is never stranded under
    // "Unseated" (late-join black hole): pick the least-loaded table that
    // still has a free seat and place them instantly. Null when seating has
    // not been generated yet or every table is at capacity — the guest stays
    // at table 0 for the admin to place via the Seating tab.
    final autoSeat = guest.table <= 0 ? _findFreeSeat(game) : null;

    final updated = game.players
        .map(
          (p) => p.id == guestId
              ? p.copyWith(
                  confirmed: true,
                  checkedIn: true,
                  active: true,
                  // §8.1: a guest dropped by the no-show gate is being seated
                  // again here, so the flag that dropped them has to clear too
                  // — `active` alone leaves `noShow` lying to every count that
                  // reads it (expected attendance, the gate itself on a later
                  // Start).
                  noShow: false,
                  table: autoSeat?.table ?? p.table,
                  seat: autoSeat?.seat ?? p.seat,
                )
              : p,
        )
        .toList();

    final extraChips = game.structure.startingStack;
    final inviterId = guest.inviterId;
    final guestSlot = guest.guestSlot;
    final canTagSlot = inviterId != null && guestSlot != null;

    _currentGame = game.copyWith(
      players: updated,
      pendingGuests: game.pendingGuests.where((p) => p.id != guestId).toList(),
      totalChipsInPlay: game.totalChipsInPlay + extraChips,
      // A late-arrival auto-seat changes the physical layout, so the seating
      // confirmation no longer holds (the admin re-confirms once settled).
      seatingConfirmed:
          autoSeat == null ? game.seatingConfirmed : false,
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

    // #2: Close the server-side slot-claim lifecycle once the guest is
    // confirmed and their slot is tagged checked-in. The confirmed seat is
    // still protected against re-claims by the guestSlots.checkedIn state, but
    // the claim-lock doc no longer lingers, so a future host correction
    // (removePlayer/rejectGuest) can re-open the seat without a stale lock.
    if (canTagSlot && _backendUp) {
      _repo
          .releaseSlotClaim(_currentGame!.id, inviterId, guestSlot)
          .catchError((_) {});
    }

    final seatLabel = autoSeat == null
        ? ''
        : ' (Table ${autoSeat.table}, Seat ${autoSeat.seat})';
    addAnnouncement(
      'Guest confirmed and seated$seatLabel.',
      false,
    );
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

  /// Admin rejects a pending guest request — the guest is removed from the
  /// players list and no longer sits at the table (07-026). Their slot is
  /// freed so another guest can claim it.
  void rejectGuest(String guestId) {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
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
                          clearGuestName: true,
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

  /// Picks a seat for a late arrival once seating exists: the least-loaded
  /// table that still has a free seat (seats are 1-based, capacity comes from
  /// [AppProvider.effectiveTableSettings]). Returns null when no table is set
  /// up yet or every table is at capacity so late guests with nowhere legal
  /// to sit stay at table 0 for a manual placement instead of overflowing a
  /// table silently.
  ({int table, int seat})? _findFreeSeat(LiveGame game) {
    final maxPerTable = effectiveTableSettings.maxPerTable.clamp(2, 999);
    final seated = game.players
        .where((p) => p.active && p.table > 0 && !p.eliminated)
        .toList();
    if (seated.isEmpty) return null;
    final tableIds = seated.map((p) => p.table).toSet().toList()..sort();

    int playerCount(int table) =>
        seated.where((p) => p.table == table).length;

    // Prefer tables below capacity; only overflow the least-loaded table when
    // every existing table is full.
    final withCapacity = tableIds.where((t) => playerCount(t) < maxPerTable).toList();
    final pool = withCapacity.isEmpty ? tableIds : withCapacity;

    var bestTable = pool.first;
    var bestCount = 1 << 30;
    for (final t in pool) {
      final count = playerCount(t);
      if (count < bestCount) {
        bestCount = count;
        bestTable = t;
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
  /// recover the request after a refresh (checklist 07-030).
  ///
  /// Resolves the slot and returns one of:
  ///  * [GuestCheckInStatus.booked] — the slot was free and has now been
  ///    booked with [name];
  ///  * [GuestCheckInStatus.confirmed] — the slot was already booked under
  ///    [name] (the guest re-identified and resumed);
  ///  * [GuestCheckInStatus.taken] — the slot is booked under a different
  ///    name (message explains the conflict);
  ///  * [GuestCheckInStatus.failed] — a transient/validation failure.
  Future<GuestCheckInResult> requestGuestCheckIn(
      String name, String inviterId, int slot) async {
    final game = _currentGame;
    if (game == null) {
      return const GuestCheckInResult(
        GuestCheckInStatus.failed,
        message: 'No active game found.',
      );
    }

    // Late registration closes permanently once the rebuy window shuts (User
    // Flow §3.2/§10.3, Tech Spec §21/§12.5): reject the booking before the
    // optimistic reserve so the guest never sees a phantom "booked" slot.
    if (game.registrationClosed) {
      return const GuestCheckInResult(
        GuestCheckInStatus.failed,
        message: 'Late registration has closed - no new players can be added.',
      );
    }

    final session = _guestSession;
    // A guest's own booking lives in the request queue and, on a guest device,
    // the game is seen through the guest projection which strips pendingGuests.
    // So the slot may not look booked here even though THIS device reserved it.
    // Trust the device-local session: if the same person re-enters the same
    // name on the same inviter+slot, it's a re-identification, not a new claim —
    // never a spurious "this slot is for someone else". Falls through otherwise
    // so a genuinely different person is still blocked / redirected.
    if (session != null &&
        session.gameId == game.id &&
        session.inviterId == inviterId &&
        session.slot == slot &&
        session.name.trim().toLowerCase() == name.trim().toLowerCase()) {
      _saveGuestSession(session);
      return const GuestCheckInResult(GuestCheckInStatus.confirmed);
    }

    final existingSlot = game.guestSlots
        .where((s) => s.inviterId == inviterId && s.slot == slot)
        .firstOrNull;
    final claimedPlayer = game.players.where(
      (p) => p.isGuest && p.inviterId == inviterId && p.guestSlot == slot,
    ).firstOrNull;

    final isReserved =
        (existingSlot != null && !existingSlot.available) || claimedPlayer != null;

    if (isReserved) {
      final claimedName = claimedPlayer?.name ?? existingSlot?.guestName;
      final matches = claimedName != null &&
          claimedName.trim().toLowerCase() == name.trim().toLowerCase();
      if (matches) {
        // Re-identification successful — this is the guest's own slot.
        _saveGuestSession(
          GuestSession(
            gameId: game.id,
            name: claimedName,
            inviterId: inviterId,
            slot: slot,
          ),
        );
        return const GuestCheckInResult(GuestCheckInStatus.confirmed);
      }
      // The slot belongs to someone else — never overwrite their booking.
      return const GuestCheckInResult(
        GuestCheckInStatus.taken,
        message:
            'This slot is not booked on your name — it is reserved for someone else.',
      );
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
            'name': sanitizedName,
            'inviterId': inviterId,
            'slot': slot,
            // Lets security rules verify only group admins consume requests.
            'gid': game.groupId,
            // Binds this claim to the anonymous caller's own auth uid so the
            // rules can reject claims that spoof another guest or device.
            'ownerUid': _repo.currentUid,
          },
        );
        if (err != null) {
          return GuestCheckInResult(
            GuestCheckInStatus.taken,
            message: err,
          );
        }
      } catch (e) {
        debugPrint('reserveGuestSlotTx(guestCheckIn) failed: $e');
        return const GuestCheckInResult(
          GuestCheckInStatus.failed,
          message: 'Could not reach the host. Check your connection.',
        );
      }
    }

    // The guest stays pending until the host confirms them at check-in
    // (spec §6 "waiting for admin confirmation", checklist 07-027/07-028).
    // Apply the pending guest locally (online AND offline) so this device
    // shows the booking instead of collapsing to "rejected" while the host's
    // request queue still holds the claim.
    _pushUndo();
    final guest = Player(
      id: guestId,
      name: sanitizedName,
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
        name: sanitizedName,
        // Claim + check-in request are one step in this flow (spec §6.3–6.5).
        requested: true,
      ),
    );
    if (!_disposed) notifyListeners();
    return const GuestCheckInResult(GuestCheckInStatus.booked);
  }

  /// Signs this device in anonymously so guests can read public projections
  /// and write to the request queue without an account. A no-op when a real
  /// account is already signed in — never replaces an authenticated session.
  Future<void> ensureGuestAuth() async {
    if (!_backendUp) return;
    if (_repo.currentUser != null) return;
    await signInAsGuest();
  }

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
    if (!_disposed) notifyListeners();
  }

  /// Assign table + seat numbers to every checked-in player (spec §12.1).
  /// Tables are capped at [effectiveTableSettings.maxPerTable] (configurable
  /// per group, overridable per tournament — defaults to 10); once checked-in
  /// count exceeds that, multiple balanced tables are created automatically.
  /// Every player gets exactly one unique (table, seat) — no duplicates.
  void generateSeating(TableSeatingMode mode) {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
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
    // §11.4 / §26.1: a shootout's Stage A structure was generated for exactly
    // `effectiveShootoutTables` independent tables, and the blind/chip math
    // assumed that many seats per table. Seating already handles multiple
    // tables under one shared clock, so a shootout only needs the table
    // COUNT pinned to what the structure assumed -- not independent clocks --
    // which is why this reads the setting directly rather than re-deriving a
    // count from `maxPerTable`. Once Stage B has been started (host-triggered
    // via `startShootoutFinalTable`, never automatic per boundary #9), the
    // split is gone and everyone belongs on the single final table, so this
    // no longer applies.
    final isShootoutStageA =
        game.settings.effectiveFormat == TournamentFormat.shootout &&
            game.shootoutStage != ShootoutStage.stageB;
    // Addendum §3: multi-table hosting is Premium. A free night stays on one
    // table, which is also why nine is the boundary -- the seating model is
    // 1-9 on one table and 10 becomes 5+5.
    //
    // The check-in and late-player gates should have stopped a free field
    // reaching ten, so this is a backstop rather than the primary limit: it
    // keeps a free tournament on one table even if players arrived by some
    // path those gates do not cover.
    final tableCount = isShootoutStageA
        ? max(1, game.settings.effectiveShootoutTables)
        : (canHostPlayers(count) ? (count / maxPerTable).ceil() : 1);
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
    // Spec 14: generating or re-randomising seats is a live operational
    // action. An announcement is not a log entry — the draw has to be
    // reconstructable afterwards.
    addAuditRecord(
      'seating',
      'Seating drawn (${mode.name}): ${assignments.length} players across '
          '$tableCount table${tableCount == 1 ? '' : 's'}'
          '${dealer != null ? ', ${dealer.name} deals first' : ''}.',
    );
    if (!_disposed) notifyListeners();
  }

  /// Marks the generated physical seating as confirmed before play starts
  /// (checklist 13-013). Seats remain editable afterwards via the move flow.
  void confirmSeating() {
    final game = _currentGame;
    if (game == null) return;
    _forceClaimEditor();
    if (!_isGameAuthority) {
      if (isAdmin) {
        // Another admin device owns the edit role — don't silently no-op.
        addAnnouncement(
          'Another device is editing this game. Changes here are not saved.',
          false,
        );
      }
      return;
    }
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
    if (!_disposed) notifyListeners();
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
    if (!_disposed) notifyListeners();
  }

  /// Clears the pending recommendation without changing any seats (13-020).
  void dismissSeatMove() {
    if (_pendingSeatMove == null) return;
    _pendingSeatMove = null;
    if (!_disposed) notifyListeners();
  }

  /// Applies the confirmed recommendation: the player moves, source and
  /// destination seats update consistently (13-018/13-019).
  void confirmSeatMove() {
    _forceClaimEditor();
    if (!_isGameAuthority) return;
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
      if (!_disposed) notifyListeners();
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
    if (!_disposed) notifyListeners();
  }
}
