/// AppProvider: User data domain mixin.
///
/// Extracted verbatim from app_provider.dart. Do not change business logic.
part of 'app_provider.dart';

extension AppProviderUserData on AppProvider {
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

    // Addendum §3's free hosting tier. Loaded alongside the rest of the
    // user's data so the check-in and seating gates have it before anybody
    // reaches them.
    loadPremiumTier();

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
      // Mirror every group's notification outbox into this user's inbox
      // (free-plan fan-out — replaces the Cloud Function).
      _syncGroupOutboxSubs();
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
      if (!_disposed) notifyListeners();
    }, onError: (Object e) {
      debugPrint('groupsIndex stream error: $e');
      bootstrapDone();
    });

    _presetsSub?.cancel();
    _presetsSub = _repo.presetsStream(uid).listen((list) {
      _presets
        ..clear()
        ..addAll(list);
      if (!_disposed) notifyListeners();
    },
        onError: (Object e) => debugPrint('presets stream error: $e'));

    _chipSetsSub?.cancel();
    _chipSetsSub = _repo.chipSetsStream(uid).listen((list) {
      _savedChipSets
        ..clear()
        ..addAll(list);
      if (!_disposed) notifyListeners();
    },
        onError: (Object e) => debugPrint('chipSets stream error: $e'));

    _notificationsSub?.cancel();
    _notificationsSub = _repo.notificationsStream(uid).listen((list) {
      _deliverBrowserNotifications(list);
      _notifications = list;
      if (!_disposed) notifyListeners();
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
      if (!_disposed) notifyListeners();
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
      if (!_disposed) notifyListeners();
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
        position: finishPositionFromIndex(
          index: index,
          listLength: game.finishOrder.length,
        ),
        playerCount: game.finishOrder.length,
        knockouts: me.knockouts,
        finishedAt: DateTime.now(),
        eliminatedAtLevel: me.eliminatedAtLevel,
      ),
    ];
    _user = _user?.copyWith(stats: _statsFromResults(_myResults));
    if (!_disposed) notifyListeners();
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
            position: finishPositionFromIndex(
              index: index,
              listLength: game.finishOrder.length,
            ),
            playerCount: game.finishOrder.length,
            knockouts: me.knockouts,
            finishedAt: DateTime.now(),
            eliminatedAtLevel: me.eliminatedAtLevel,
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
      _gameChatSub,
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
    for (final s in _groupOutboxSubs.values) {
      s.cancel();
    }
    _groupOutboxSubs.clear();
    _outboxPrimed.clear();
    _mirrorCursors.clear();
    _mirroredOutboxIds.clear();
    _groupsSub = null;
    _bundleSub = null;
    _gameDocSub = null;
    _gameChatSub = null;
    _gameDocRetryTimer?.cancel();
    _gameChatRetryTimer?.cancel();
    _gameChatMessages = const [];
    _gameChatKey = null;
    _pendingOwnRsvp.clear();
    _rsvpReassertCount.clear();
    _pendingCheckIn.clear();
    _checkInLanded.clear();
    _adminVerdictByGroup.clear();
    _localGameDirty = false;
    _lastSavedSignature = null;
    _lastEditorHeartbeatAt = null;
    lastSaveError = null;
    lastRsvpError = null;
    _lookupSub = null;
    _presetsSub = null;
    _chipSetsSub = null;
    _notificationsSub = null;
    _requestsSub = null;
    _cashSub = null;
    _resultsSub = null;
    _pendingInvitesSub = null;
    _gameSaveDebounce?.cancel();
    _projectionDebounce?.cancel();
    _pendingGameSave = false;
    _syncedGameKey = null;
    _gameSyncPrimed = false;
    _currentGroupId = null;
    _bundleLoaded = false;
    _bundleReady = null;
    _userBootstrap = null;
    // Drop any group-scoped state from the previous session so a different
    // account signing in on this device never sees it.
    _currentGroup = AppProvider._kEmptyGroup;
    _notifications = const [];
    _cashHistory = const [];
    _myResults = const [];
    _resultsRecorded.clear();
    _lastPushedStatsKey = null;
    _seenNotificationIds.clear();
    _notificationsPrimed = false;
    // Tear down the guest identity on ANY sign-out path (auth-state listener,
    // session expiry, explicit logout) so the next account — or anonymous
    // guest — that uses this device never inherits the previous guest's name
    // (guest-session bleeding). The explicit `logout()` also clears these, but
    // this covers every other way a session can end.
    _guestSession = null;
    RecoveryService.clearGuestSession();
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
    _currentGroup = row ?? AppProvider._kEmptyGroup;

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
      // Keep the member's own not-yet-acked RSVP visible on the hub's game
      // cards too, not just the game screen (see [_pendingOwnRsvp]).
      final hydrated = _pendingOwnRsvp.isEmpty
          ? g
          : g.copyWith(
              games: g.games
                  .map((gm) => _withPendingCheckInOverlay(_withOwnRsvpOverlay(gm)))
                  .toList());
      _setGroup(hydrated);

      // The bundle is the first place a member's role becomes known, so retire
      // any stale local crash-resume snapshot here too.
      _dropRecoveryIfNotAuthority();
      // F-001 Fix: Keep the currently viewed game screen in sync for members
      // (and admins receiving RSVPs/Check-ins) without clobbering the admin's local timer.
      if (_currentGame != null) {
        if (isAdmin && (_pendingGameSave || _localGameDirty || _restoredFromRecovery)) {
          // Do not overwrite local edits with stale bundle data during debounce or recovery.
        } else {
          final updatedGame = hydrated.games.where((x) => x.id == _currentGame!.id).firstOrNull;
          if (updatedGame != null) {
            if (isAdmin) {
              // Same restore the game-doc stream applies, so both sources
              // produce an identical game for identical server state. Without
              // it the bundle copy (scrubbed) and the doc copy (restored)
              // alternated, the content signature flipped on every emit and
              // the admin stayed permanently "dirty" — which is what stopped
              // members' RSVPs from ever reaching the admin's screen.
              _currentGame = _restoreAdminPrivateFields(updatedGame).copyWith(
                secondsRemaining: _currentGame!.secondsRemaining,
                timerRunning: _currentGame!.timerRunning,
                levelEndTime: _currentGame!.levelEndTime,
              );
            } else {
              _currentGame = updatedGame;
            }
          }
        }
      }
      _bundleLoaded = true;
      markReady();
      // Catch results of games this device never followed live (e.g. the
      // player sat out or never opened the game screen).
      for (final finished in g.pastGames) {
        _maybeRecordOwnResult(finished);
      }
      if (!_disposed) notifyListeners();
    }, onError: (Object e) {
      debugPrint('groupBundle stream error: $e');
      markReady();
    });
    if (row?.ownerId == _user?.id) {
      _cashSub = _repo.completedCashSessionsStream(gid).listen((list) {
        _cashHistory = list;
        if (!_disposed) notifyListeners();
      }, onError: (Object e) => debugPrint('cashSessions stream error: $e'));
    }
  }

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

  /// Subscribes each group's notification outbox and mirrors unseen items into
  /// the signed-in user's own inbox — the free-plan replacement for a Cloud
  /// Function. Cancels subs for groups that were left.
  void _syncGroupOutboxSubs() {
    final wanted = {for (final g in _groups) g.id};
    for (final gid in [
      for (final k in _groupOutboxSubs.keys)
        if (!wanted.contains(k)) k,
    ]) {
      _groupOutboxSubs.remove(gid)?.cancel();
      _outboxPrimed.remove(gid);
    }
    for (final g in _groups) {
      if (_groupOutboxSubs.containsKey(g.id)) continue;
      final gid = g.id;
      _mirrorCursors[gid] ??= -1;
      _groupOutboxSubs[gid] = _repo.groupOutboxStream(gid).listen(
        (docs) => _mirrorOutbox(gid, docs),
        onError: (Object e) {
          debugPrint('outbox stream error: $e');
          // A brand-new listener can reach the server just ahead of a
          // just-committed joinGroup batch (the index doc that triggered
          // this subscription arrives via local-cache optimism before the
          // server has the matching membership row), so isMember(gid) is
          // transiently false. Retry once the write has had time to land.
          if (_isRetriablePermissionError(e)) {
            _groupOutboxSubs.remove(gid)?.cancel();
            Future.delayed(const Duration(milliseconds: 800), () {
              if (!_disposed) _syncGroupOutboxSubs();
            });
          }
        },
      );
    }
  }

  /// Copies staged group notifications into the user's own inbox. First
  /// emission is baselined silently (history); afterwards only items newer
  /// than the persisted cursor are mirrored — as unread.
  void _mirrorOutbox(String gid, List<OutboxNotification> docs) {
    final uid = _repo.currentUid;
    if (uid == null || !_backendUp) return;
    final primed = _outboxPrimed[gid] ?? false;
    var cursor = _mirrorCursors[gid] ?? -1;

    if (!primed) {
      // First-ever view of this group's outbox on this device: baseline
      // silently so a brand-new user's inbox isn't flooded with the group's
      // back-history. The flag is persisted, so this ONLY happens once — on
      // later app starts the cursor is restored and anything staged while
      // the app was closed IS delivered.
      _outboxPrimed[gid] = true;
      _persistPref('notifMirrorPrimed_$gid', true);
      for (final d in docs) {
        cursor = max(cursor, d.updatedAtMillis);
        _mirroredOutboxIds.add(d.id);
      }
    } else {
      for (final d in docs) {
        if (_mirroredOutboxIds.contains(d.id)) continue;
        _mirroredOutboxIds.add(d.id);
        if (d.updatedAtMillis <= cursor) continue;
        cursor = max(cursor, d.updatedAtMillis);
        if (!d.isFor(uid)) continue;
        unawaited(_repo
            .mirrorInboxNotification(uid, d.toAppNotification(read: false))
            .catchError((Object e) => debugPrint('mirror inbox failed: $e')));
      }
    }

    if (cursor != (_mirrorCursors[gid] ?? -1)) {
      _mirrorCursors[gid] = cursor;
      // No dots in the key — saveUserPref writes via a Firestore dot-path.
      _persistPref('notifMirrorCursor_$gid', cursor);
    }
  }

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
      final gid = g.id;
      _groupMembersSubs[gid] =
          _repo.groupMembersStream(gid).listen((members) {
        final i = _groups.indexWhere((x) => x.id == gid);
        if (i == -1) return;
        _groups = [..._groups]..[i] = _groups[i].copyWith(members: members);
        if (!_disposed) notifyListeners();
      }, onError: (Object e) {
        debugPrint('group members stream error: $e');
        // See _syncGroupOutboxSubs: a fresh listener can lose the race
        // against the server-side commit of a just-created membership row.
        if (_isRetriablePermissionError(e)) {
          _groupMembersSubs.remove(gid)?.cancel();
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!_disposed) _syncGroupMembersSubs();
          });
        }
      });
    }
  }

  /// A recovery snapshot is the ADMIN's crash-resume copy. On any other device
  /// it is stale local state that must never win over the server — and while
  /// [_restoredFromRecovery] is set it also blocks every remote adoption, which
  /// silently froze members on their own optimistic RSVP: the value survived a
  /// reload locally, never reached Firestore, and the next tap short-circuited
  /// on the "already selected" guard so nothing was ever written again.
  ///
  /// Called once the signed-in user's role is actually known.
  void _dropRecoveryIfNotAuthority() {
    if (!_restoredFromRecovery) return;
    // Role not resolved yet — decide later rather than throwing away a real
    // admin's in-progress tournament.
    if (_user == null || _currentGroup.id.isEmpty) return;
    if (isAdmin) return;
    debugPrint('recovery: dropping local snapshot (not the game authority)');
    _restoredFromRecovery = false;
    _recoveryTime = null;
    RecoveryService.clearGame();
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
    if (!_disposed) notifyListeners();
  }

  /// True if the locally recovered game state differs from the "cloud" state.
  /// Compares multiple fields to detect real conflicts, not just audit count.
  bool get hasOfflineConflict {
    if (_currentGame == null || !_restoredFromRecovery) return false;
    final cloudGame = _currentGroup.games
        .where((g) => g.id == _currentGame!.id)
        .firstOrNull;
    if (cloudGame == null) return false;
    return _currentGame!.revision > cloudGame.revision ||
        _currentGame!.auditHistory.length > cloudGame.auditHistory.length;
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
        _lastSavedGame = null;
        _syncGameToCloud();
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
    if (!_disposed) notifyListeners();
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
    if (!_disposed) notifyListeners();
  }

  List<({String id, String name, List<ChipColor> chips})> get savedChipSets =>
      _savedChipSets;

  void saveChipSet(String id, String name, List<ChipColor> chips) {
    final dupValues = chips.map((c) => c.value).toList();
    if (dupValues.toSet().length != dupValues.length) {
      throw const DuplicateChipValueException(
        'Two chip colours cannot share the same value.',
      );
    }
    final idx = _savedChipSets.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _savedChipSets[idx] = (id: id, name: name, chips: chips);
    } else {
      _savedChipSets.add((id: id, name: name, chips: chips));
    }
    if (!_disposed) notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null && id != AppProvider.seedChipSet.id) {
      unawaited(_repo.saveChipSet(uid, id, name, chips)
          .catchError((Object e) => debugPrint('saveChipSet failed: $e')));
    }
  }

  void deleteChipSet(String id) {
    if (id == 'cs-default') return; // protect default
    _savedChipSets.removeWhere((c) => c.id == id);
    if (!_disposed) notifyListeners();
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
    if (!_disposed) notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.updateUserProfile(uid, name: nextName, email: nextEmail)
          .catchError((Object e) => debugPrint('updateUserProfile failed: $e')));
    }
  }

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
    if (!_disposed) notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo.savePreset(uid, preset)
          .catchError((Object e) => debugPrint('savePreset failed: $e')));
    }
  }

  void deletePreset(String id) {
    _presets.removeWhere((p) => p.id == id);
    if (!_disposed) notifyListeners();
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
}