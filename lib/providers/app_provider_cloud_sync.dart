/// AppProvider: Cloud sync domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Cloud sync plumbing ──`). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderCloudSync on AppProvider {
  DateTime get lastSync => _lastSync;

  /// Tracks which active-game document this device mirrors. When the key
  /// changes the old doc subscription is replaced and a fresh baseline is
  /// awaited before further remote adoptions.
  void _syncGameToCloud() {
    if (!_backendUp) return;
    _claimEditorIfNeeded();
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
      _gameDocRetryTimer?.cancel();
      _gameSaveDebounce?.cancel();
    _projectionDebounce?.cancel();
      _pendingGameSave = false;
      _localGameDirty = false;
      _lastSavedSignature = null;
      if (key != null && game != null && gid != null) {
        if (isGuest) {
          // Guests have no read access to the game doc — they follow the
          // sanitized publicGames projection (world-readable, no token gap).
          _gameDocSub = _repo.publicGameStream(game.id).listen((doc) {
            final payload = doc['guest'] as Map<String, dynamic>?;
            if (payload == null) return;
            _adoptRemoteMap(payload);
          }, onError: (Object e) => debugPrint('publicGameStream error: $e'));
        } else {
          // Admin authority reads the doc as admin; plain members follow the
          // raw doc too (rules gate it to isMember; figures are scrubbed in
          // saveGame). Both are auth-gated, so retry through the post-login
          // token-propagation gap instead of dying on the first denial.
          final asAdmin = _isGameAuthority;
          _subscribeGameDoc(key, gid, game.id, asAdmin: asAdmin);
        }
      }
    }

    // Per-game chat subcollection — followed by the host and every member so
    // messages appear immediately and survive the game-doc sync (see
    // [_gameChatMessages]).
    if (key != _gameChatKey) {
      _gameChatKey = key;
      _gameChatSub?.cancel();
      _gameChatSub = null;
      _gameChatRetryTimer?.cancel();
      _gameChatMessages = const [];
      if (key != null && game != null && gid != null && !isGuest) {
        _subscribeGameChat(key, gid, game.id);
      }
    }

    if (game == null || gid == null || _user == null) return;
    // Whole-document writes are reserved for the admin/authority device
    // (locked architecture §writes). Members patch their own fields and
    // guests use the request queue instead.
    if (!_isGameAuthority) return;
    // Content (not identity) check: a bundle re-emit hands back a fresh
    // LiveGame instance every time, so `identical` was perpetually false and
    // the admin was perpetually "dirty" — which blocked `_adoptRemoteMap` and
    // froze the admin's view. Only a real content change schedules a save.
    if (identical(_lastSavedGame, game)) return;
    final sig = _gameSignature(game);
    if (sig == _lastSavedSignature) return;
    // Mark the local game dirty NOW (not when the timer fires) so any remote
    // snapshot arriving during the debounce window is held off in
    // [_adoptRemoteMap] / the group-bundle handler instead of clobbering this
    // un-persisted edit.
    _localGameDirty = true;
    _gameSaveDebounce?.cancel();
    _projectionDebounce?.cancel();
    final effectiveGid = game.groupId.isNotEmpty ? game.groupId : gid;
    // Short debounce: the save queue ([_drainGameSaveQueue]) already coalesces
    // and serialises bursts, so a long wait only widens the window where a
    // concurrent remote write is invisible. Keep it tight for real-time feel.
    _gameSaveDebounce = Timer(const Duration(milliseconds: 250), () {
      final g = _currentGame;
      if (g == null || _user == null) return;
      _pendingLatestSave = g;
      _pendingGameSave = true;
      unawaited(_drainGameSaveQueue(effectiveGid));
    });
  }

  /// Serializes whole-document game saves so rapid admin actions (pause /
  /// resume, check-in accept, level changes) can never land out of order.
  /// Only one `.set()` runs at a time and the freshest snapshot always wins,
  /// so a slower earlier write can no longer clobber a newer one (the
  /// "tap 2-3-5 times then it works" / self-resume-pause symptom).
  Future<void> _drainGameSaveQueue(String effectiveGid) async {
    if (_gameSaveInFlight) return;
    _gameSaveInFlight = true;
    try {
      do {
        final target = _pendingLatestSave;
        _pendingLatestSave = null;
        if (target == null || _user == null) break;
        final g = _currentGame;
        // Prefer the very latest authoritative state for this game.
        final freshest = (g != null && g.id == target.id) ? g : target;
        if (identical(_lastSavedGame, freshest)) continue;
        var toWrite = freshest.groupId.isNotEmpty
            ? freshest
            : freshest.copyWith(groupId: effectiveGid);
        // A member RSVP / guest-slot patch may have committed to the server
        // while this edit was debouncing (adoption was held off by
        // [_localGameDirty]). The whole-doc `.set()` below would silently
        // overwrite it, so fold those member-owned fields back in first.
        toWrite = await _reconcileMemberOwnedFields(toWrite);
        // Retry with backoff exactly like the member RSVP patch: right after a
        // web login the admin's writes are rejected with permission-denied
        // until the fresh auth token reaches the Firestore SDK. Previously the
        // first failure was rethrown out of an `unawaited(...)` call, which
        // both dropped the admin's edit and surfaced as an unhandled async
        // error in the console.
        const delaysMs = [0, 300, 800, 1800, 4000, 8000];
        var saved = false;
        Object? lastError;
        for (var attempt = 0; attempt < delaysMs.length && !saved; attempt++) {
          if (delaysMs[attempt] > 0) {
            await Future<void>.delayed(
                Duration(milliseconds: delaysMs[attempt]));
          }
          if (_user == null) break;
          var step = 'saveGame';
          try {
            await _repo.saveGame(toWrite, viewerId: _user?.id);
            step = 'publishProjections';
            await _publishProjections(toWrite);
            _lastSavedGame = toWrite;
            _lastSavedSignature = _gameSignature(toWrite);
            saved = true;
            if (lastSaveError != null) {
              lastSaveError = null;
              notifyListeners();
            }
          } catch (e) {
            lastError = e;
            debugPrint('$step failed (attempt ${attempt + 1}) '
                'gid=${toWrite.groupId} game=${toWrite.id} '
                'uid=${_user?.id} isAdmin=$isAdmin '
                'authority=$_isGameAuthority: $e');
            if (_isRetriablePermissionError(e)) await _nudgeAuthToken();
          }
        }
        if (!saved) {
          // Never rethrow out of this fire-and-forget drain — surface it
          // instead so the admin sees that their change did not persist.
          final errorStr = (lastError ?? '').toString().toLowerCase();
          if (_isRetriablePermissionError(lastError ?? '')) {
            lastSaveError = 'Changes not saved — this account does not have admin write access to this game.';
          } else if (errorStr.contains('quota-exceeded') || errorStr.contains('resource-exhausted') || errorStr.contains('quota')) {
            lastSaveError = 'Changes not saved — database quota exceeded (free tier limit reached).';
          } else {
            lastSaveError = 'Changes could not be saved. Check your connection.';
          }
          notifyListeners();
          break;
        }
      } while (_pendingLatestSave != null);
    } finally {
      _gameSaveInFlight = false;
      if (_pendingLatestSave == null) {
        _pendingGameSave = false;
        // Nothing left to write — local state now matches (or has been
        // superseded by) what is on the server, so remote snapshots may flow
        // through again.
        _localGameDirty = false;
      }
    }
  }

  /// Folds member-owned fields (per-player RSVP, guest slots, member-created
  /// guest rows) from the current server document back into [game] before an
  /// authority whole-doc save, so a member RSVP that committed during the
  /// debounce window is not silently overwritten. Best-effort: any failure or
  /// an in-progress admin RSVP change for this game leaves [game] untouched.
  Future<LiveGame> _reconcileMemberOwnedFields(LiveGame game) async {
    if (!_backendUp || game.groupId.isEmpty) return game;
    try {
      final raw = await _repo.gameDocOnce(game.groupId, game.id);
      if (raw == null) return game;
      final remote = liveGameFromFirestoreDoc(Map<String, dynamic>.from(raw));
      if (remote.id != game.id) return game;
      return mergeMemberOwnedFields(game, remote, adminId: _user?.id);
    } catch (e) {
      debugPrint('reconcileMemberOwnedFields failed: $e');
      return game;
    }
  }

  /// True when the signed-in user holds the elevated Co-Admin role in the
  /// current group. Currently a cosmetic badge (permissions are restricted to 
  /// admin-only until multi-admin support is fully implemented).
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

  /// True only for the single "active editor" admin device — the one that may
  /// write the whole game document. Guests and plain members never qualify.
  /// The editor role lives in [LiveGame.editorDeviceId]: the first admin
  /// device to open a live game claims it, which prevents two admin sessions
  /// from racing whole-document writes (the seating-confirm revert bug).
  bool get _isGameAuthority =>
      isAdmin &&
      _currentGame != null &&
      (_currentGame!.editorDeviceId.isNotEmpty &&
          _currentGame!.editorDeviceId == _repo.deviceId);

  /// Single-active-editor claim (multi-device save fix). The first admin
  /// device to touch a live game becomes the whole-document writer and
  /// persists its device id; every other admin device stops writing the whole
  /// doc so a stale session can't clobber a fresh state (e.g. a confirmed
  /// seating plan). Never steals from an active editor.
  void _claimEditorIfNeeded() {
    final game = _currentGame;
    if (game == null || _user == null || !isAdmin || !_backendUp) return;
    final editor = game.editorDeviceId;
    final now = DateTime.now();
    final claimedAt = game.editorClaimedAt;
    final sameDevice = editor == _repo.deviceId;
    final stale = editor.isNotEmpty &&
        claimedAt != null &&
        now.difference(claimedAt) > AppProvider._editorClaimStaleWindow;
    // Another live editor is actively writing — stay read-only.
    if (editor.isNotEmpty && !sameDevice && !stale) return;
    if (sameDevice) {
      // Heartbeat: ours. Persist the last-active stamp so other admin devices
      // don't judge us stale — but as a TARGETED, THROTTLED field patch, never
      // by mutating `_currentGame` (that made every notifyListeners() schedule
      // a full-document `.set()`, which continuously clobbered members' RSVP /
      // guest-slot writes — the "RSVP not persistent" bug).
      final due = _lastEditorHeartbeatAt == null ||
          now.difference(_lastEditorHeartbeatAt!) > AppProvider._editorHeartbeatInterval;
      if (due) {
        _lastEditorHeartbeatAt = now;
        _patchActiveGame({'editorClaimedAt': now.toIso8601String()});
      }
      return;
    }
    _currentGame = game.copyWith(
      editorDeviceId: _repo.deviceId,
      editorClaimedAt: now,
    );
    _lastEditorHeartbeatAt = now;
    _syncGroupGame();
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
    } catch (e) {
      debugPrint('publishProjections failed: $e');
      rethrow;
    }
  }

  /// Opens the request-queue subscription once this device qualifies as
  /// authority for the active game. Re-evaluated on every provider change so
  /// late-loading membership flips it on at the right moment.
  void _ensureRequestsSubscription() {
    if (!_backendUp || _currentGame == null || !_isGameAuthority) return;
    if (_requestsSub != null) return;
    final gameId = _currentGame!.id;
    _requestsSub = _repo.requestsStream(gameId, _currentGame!.groupId).listen(
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
    final name = Sanitization.sanitizeName((payload['name'] as String?) ?? 'Guest');
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
    
    // Alert the admin that a guest is waiting
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Guest Arrived',
        body: '$name is waiting to be checked in.',
        type: NotificationType.admin,
        link: '/game/${game.id}/check-in',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
    
    return null;
  }

  /// Subscribes the raw game doc for a signed-in admin/member, re-subscribing
  /// with backoff if the stream errors (the post-login token gap). [key] pins
  /// the attempt to the current [_syncedGameKey] so a stale retry is dropped
  /// once the active game changes.
  void _subscribeGameDoc(String key, String gid, String gameId,
      {required bool asAdmin}) {
    var attempt = 0;
    void go() {
      if (_syncedGameKey != key) return;
      _gameDocSub?.cancel();
      _gameDocSub = _repo
          .gameDocSnapshots(gid, gameId, isAdmin: asAdmin)
          .listen(_adoptRemoteGame, onError: (Object e) {
        debugPrint('gameDoc stream error${asAdmin ? '' : ' (member)'}: $e');
        if (_syncedGameKey != key || attempt >= 8) return;
        if (_isRetriablePermissionError(e)) unawaited(_nudgeAuthToken());
        final delayMs = 400 * (1 << (attempt > 5 ? 5 : attempt));
        attempt++;
        _gameDocRetryTimer?.cancel();
        _gameDocRetryTimer = Timer(Duration(milliseconds: delayMs), go);
      });
    }

    go();
  }

  /// Per-game chat subscription with the same post-login backoff retry.
  void _subscribeGameChat(String key, String gid, String gameId) {
    var attempt = 0;
    void go() {
      if (_gameChatKey != key) return;
      _gameChatSub?.cancel();
      _gameChatSub = _repo.gameChatStream(gid, gameId).listen((msgs) {
        _gameChatMessages = msgs;
        notifyListeners();
      }, onError: (Object e) {
        debugPrint('gameChat stream error: $e');
        if (_gameChatKey != key || attempt >= 8) return;
        if (_isRetriablePermissionError(e)) unawaited(_nudgeAuthToken());
        final delayMs = 400 * (1 << (attempt > 5 ? 5 : attempt));
        attempt++;
        _gameChatRetryTimer?.cancel();
        _gameChatRetryTimer = Timer(Duration(milliseconds: delayMs), go);
      });
    }

    go();
  }

  /// Adopts a remote game document unless it is our own latency-compensated
  /// write or the ack of a write we just made (echo prevention, locked
  /// architecture §reads).
  void _adoptRemoteGame(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (!snap.exists || data == null) return;
    if (snap.metadata.hasPendingWrites) return;
    _adoptRemoteMap(data);
  }

  /// Re-attaches the admin-only figures that `saveGame` scrubs out of the
  /// public game document (organizer cut, prize amounts, per-player financial
  /// counters) using the copy already held locally.
  ///
  /// EVERY path that rebuilds `_currentGame` from a server document must run
  /// this — `_adoptRemoteMap` (game-doc stream) and the group-bundle handler
  /// alike. When only one of them did, the two sources produced structurally
  /// different games for the same server state, which flipped the content
  /// signature on every bundle emit, left the admin permanently "dirty", and
  /// blocked the game-doc snapshot carrying a member's new RSVP.
  LiveGame _restoreAdminPrivateFields(LiveGame remote) {
    final local = _currentGame;
    if (!isAdmin || local == null) return remote;
    return restoreAdminPrivateFields(remote, local);
  }

  void _adoptRemoteMap(Map<String, dynamic> data) {
    if (!_gameSyncPrimed) {
      _gameSyncPrimed = true;
    } else if (data['writerId'] == _repo.deviceId) {
      return;
    }
    // A non-authority device must never let a local crash-resume snapshot win
    // over the server, so retire it before the guard below consults the flag.
    _dropRecoveryIfNotAuthority();
    // Hold off adopting remote state only while this device has a REAL
    // un-persisted authority edit (`_localGameDirty` is now content-based) or a
    // save in flight — otherwise a snapshot would revert the optimistic change.
    // The bare debounce-timer state is deliberately NOT checked: it is
    // rescheduled on every notify and would permanently block adoption.
    if (_pendingGameSave ||
        _localGameDirty ||
        _gameSaveInFlight ||
        _restoredFromRecovery) {
      return;
    }
    try {
      var remote = liveGameFromFirestoreDoc(Map<String, dynamic>.from(data));
      if (_currentGame?.id != remote.id) return;
      
      // Preserve private fields that are scrubbed from the public remote stream
      remote = _restoreAdminPrivateFields(remote);

      _currentGame = _withPendingCheckInOverlay(_withOwnRsvpOverlay(remote));
      _lastSavedGame = remote;
      // Adopted state is, by definition, in sync with the server — record its
      // signature so `_syncGameToCloud` doesn't immediately re-flag it dirty
      // and re-save it (the admin-side feedback loop). If an overlay changed
      // the content, the signature differs and the authority still saves it.
      _lastSavedSignature = _gameSignature(remote);
      // Crash-resume snapshots are the admin's (see [_dropRecoveryIfNotAuthority]).
      if (isAdmin) RecoveryService.saveGame(remote);
      // A foreign writer (e.g. the admin's whole-doc save) may have wiped this
      // member's just-written RSVP — re-write it rather than only masking it
      // with the overlay, so a page reload keeps the selection.
      _maybeReassertOwnRsvp(remote, data['writerId'] as String?);
      _maybeReassertOwnCheckIn(remote, data['writerId'] as String?);
      // Another device may have settled the tournament — record my result.
      _maybeRecordOwnResult(remote);
      if (_isGameAuthority) {
        // Fire-and-forget, but explicitly swallowed: `_publishProjections`
        // rethrows, and an un-caught rethrow out of a stream callback surfaced
        // as an unhandled async error (the RethrownDartError stack dumps).
        _projectionDebounce?.cancel();
        _projectionDebounce = Timer(const Duration(milliseconds: 1500), () {
          if (_currentGame != null) {
            unawaited(_publishProjections(_currentGame!).catchError((Object _) {}));
          }
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('remote game decode failed: $e');
    }
  }

  /// When a snapshot NOT written by this device still doesn't reflect this
  /// member's pending RSVP, re-issue the field patch (up to 3×). Purely
  /// masking it with [_pendingOwnRsvp] would keep the selection visible this
  /// session but lose it on reload.
  void _maybeReassertOwnRsvp(LiveGame remote, String? writerId) {
    final uid = _user?.id;
    if (uid == null || _isGameAuthority) return;
    if (!_pendingOwnRsvp.containsKey(remote.id)) return;
    if (writerId != null && writerId == _repo.deviceId) return;
    final want = _pendingOwnRsvp[remote.id];
    final serverMine = remote.players.where((p) => p.id == uid).firstOrNull;
    if (serverMine?.rsvp == want) return; // server already agrees
    final n = _rsvpReassertCount[remote.id] ?? 0;
    if (n >= 3) return;
    _rsvpReassertCount[remote.id] = n + 1;
    debugPrint('RSVP re-assert #${n + 1} for ${remote.id} '
        '(server=${serverMine?.rsvp?.name}, want=${want?.name})');
    final after = _withOwnRsvpOverlay(remote);
    _persistOwnRsvpPatch(remote.id, _rsvpDotPatch(remote, after), want);
  }

  /// Re-applies the member's own pending RSVP (see [_pendingOwnRsvp]) on top of
  /// a freshly adopted remote game, and drops the overlay once the remote
  /// agrees. No-op for the authority (they write the whole doc) and when
  /// there is no overlay for this game.
  LiveGame _withOwnRsvpOverlay(LiveGame game) {
    if (!_pendingOwnRsvp.containsKey(game.id)) return game;
    final uid = _user?.id;
    if (uid == null) return game;
    final want = _pendingOwnRsvp[game.id];
    final mine = game.players.where((p) => p.id == uid).firstOrNull;
    if (mine?.rsvp == want) {
      // The remote has caught up with the member's own selection — done.
      _pendingOwnRsvp.remove(game.id);
      _rsvpReassertCount.remove(game.id);
      return game;
    }
    final players = game.players.any((p) => p.id == uid)
        ? game.players
            .map((p) => p.id == uid ? p.copyWith(rsvp: want) : p)
            .toList()
        : [...game.players, _memberAsPlayer(uid, want)];
    var updated = game.copyWith(players: players);
    updated = _syncGuestSlots(updated, uid, want?.guestCount ?? 0);
    return updated;
  }

  LiveGame _withPendingCheckInOverlay(LiveGame game) {
    if (_pendingCheckIn.isEmpty) return game;
    final pendingPlayerId = _pendingCheckIn[game.id];
    if (pendingPlayerId == null) return game;
    var updated = game;
    final updatedPlayers = game.players.map((p) {
      if (pendingPlayerId == p.id) {
        if (p.checkedIn && p.confirmed) {
          _pendingCheckIn.remove(game.id);
          _checkInLanded.remove(game.id);
          return p;
        }
        return p.copyWith(checkedIn: true, confirmed: false);
      }
      return p;
    }).toList();
    return updated.copyWith(players: updatedPlayers);
  }
}