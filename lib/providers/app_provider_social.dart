/// AppProvider: Social domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Chat & polls ──`). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderSocial on AppProvider {
  /// True when [userId] has exceeded the chat burst limit right now. The
  /// client matches the server-side throttle: at least
  /// [_chatMinSendGap] between messages (server enforces ~3750ms on the
  /// `rate_limits/chat-$uid` doc), so a compliant client never submits a burst
  /// the server would reject and silently drop.
  bool _chatRateLimited(String userId) {
    final now = DateTime.now();
    final times = _chatSendTimes.putIfAbsent(userId, () => <DateTime>[]);
    times.removeWhere((t) => now.difference(t) > AppProvider._chatBurstWindow);
    if (times.isEmpty) return false;
    if (times.length >= AppProvider._chatBurstLimit) return true;
    return now.difference(times.last) < AppProvider._chatMinSendGap;
  }

  void _recordChatSend(String userId) {
    _chatSendTimes.putIfAbsent(userId, () => <DateTime>[]).add(DateTime.now());
  }

  /// Marks an entire chat scope as read up to now so its unread counter
  /// resets. Callers (chat sheet / group hub screens) invoke this when the
  /// conversation becomes visible.
  void markChatRead(String scopeKey) {
    _chatLastRead[scopeKey] = DateTime.now();
    if (!_disposed) notifyListeners();
  }

  /// Unread count over one chat list: non-deleted messages authored by
  /// someone else, posted after the scope's last-read timestamp.
  int _unreadChatCount(String scopeKey, List<ChatMessage> messages) {
    final uid = _user?.id;
    if (uid == null) return 0;
    final lastRead = _chatLastRead[scopeKey];
    var count = 0;
    for (final m in messages) {
      if (m.deleted || m.authorId == uid) continue;
      if (lastRead != null && !m.timestamp.isAfter(lastRead)) continue;
      count++;
    }
    return count;
  }

  /// Number of unread group-chat messages for group [gid] (Tech Spec §14.1).
  int unreadGroupChatCount(String gid) =>
      _unreadChatCount('group:$gid', _currentGroup.chat);

  /// Number of unread messages in game [gid]'s chat (Tech Spec §14.1). Reads
  /// the current live game when it matches, otherwise the mirrored copy kept
  /// on the group bundle.
  int unreadGameChatCount(String gid) =>
      _unreadChatCount('game:$gid', gameChatMessages(gid));

  /// Sends a chat message. Returns a validation message when the message
  /// cannot be sent (empty, too long or rate limited), or null on success.
  String? sendChatMessage(String? gameId, String body) {
    if (_user == null) return null;
    // Spec §22: sanitize input before processing.
    final sanitized = Sanitization.sanitizeChat(body);
    if (sanitized.isEmpty) return 'Message cannot be empty.';
    if (sanitized.length > AppProvider.maxChatMessageLength) {
      return 'Message is too long — maximum ${AppProvider.maxChatMessageLength} characters.';
    }
    if (_chatRateLimited(_user!.id)) {
      return 'You are sending messages too quickly — wait a moment and try again.';
    }
    _recordChatSend(_user!.id);
    final isGameChat = gameId != null && _currentGame?.id == gameId;
    final msg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      authorId: _user!.id,
      authorName: _user!.name,
      body: sanitized,
      timestamp: DateTime.now(),
      deleted: false,
      gameId: isGameChat ? gameId : null,
    );
    if (isGameChat) {
      final ctx = _cloudGameContext;
      if (_backendUp && ctx != null) {
        // Per-game chat is its own subcollection the host and every member may
        // append to directly — no game-doc write (members are forbidden the
        // `chat` field) and no projection round-trip, so the message stays put.
        _gameChatMessages = [..._gameChatMessages, msg];
        unawaited(
          _repo
              .sendGameChatMessage(ctx.$1, ctx.$2, msg)
              .catchError((Object e) => debugPrint('sendGameChat failed: $e')),
        );
      } else {
        // Offline / mock mode — keep it on the local game model.
        _currentGame = _currentGame!.copyWith(
          chat: [..._currentGame!.chat, msg],
        );
      }
    } else {
      _setGroup(_currentGroup.copyWith(chat: [..._currentGroup.chat, msg]));
      _postGroupChat(msg);
    }

    // Fan out a push notification for this chat message (UAT 12-108/13-059).
    // The sender is excluded inside _fanOutPush so they don't banner themselves.
    pushNotification(
      AppNotification(
        id: 'chat-${msg.id}',
        title: isGameChat
            ? 'Game Chat: ${_currentGame?.settings.name ?? 'Live Game'}'
            : 'Group Chat: ${_currentGroup.name}',
        body: '${_user!.name}: $sanitized',
        timestamp: DateTime.now(),
        type: NotificationType.chat,
        link: isGameChat ? '/game/$gameId' : '/chat',
        read: false,
      ),
    );

    if (!_disposed) notifyListeners();
    return null;
  }

  /// Every visible message for a game's chat: the per-game chat subcollection
  /// merged with any pinned/system cards carried on the game document, sorted
  /// oldest-first so the chat view reads top-to-bottom.
  List<ChatMessage> gameChatMessages(String gameId) {
    final LiveGame? base = _currentGame?.id == gameId
        ? _currentGame
        : _currentGroup.games.where((g) => g.id == gameId).firstOrNull;
    final byId = <String, ChatMessage>{};
    for (final m in base?.chat ?? const <ChatMessage>[]) {
      byId[m.id] = m;
    }
    for (final m in _gameChatMessages) {
      byId[m.id] = m;
    }
    final list = byId.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  /// Persists a group-chat message to `groups/{gid}/chat` (fire-and-forget).
  void _postGroupChat(ChatMessage msg) {
    if (!_backendUp || _currentGroupId == null) return;
    unawaited(
      _repo
          .sendGroupChatMessage(_currentGroupId!, msg)
          .catchError((Object e) => debugPrint('sendGroupChat failed: $e')),
    );
  }

  /// Persists a poll create/update to `groups/{gid}/polls` (fire-and-forget).
  void _persistPoll(Poll poll) {
    if (!_backendUp || _currentGroupId == null) return;
    unawaited(
      _repo
          .savePoll(_currentGroupId!, poll)
          .catchError((Object e) => debugPrint('savePoll failed: $e')),
    );
  }

  void deleteMessage(String msgId) {
    final inGameChat = _gameChatMessages.any((m) => m.id == msgId);
    _setGroup(
      _currentGroup.copyWith(
        chat: _currentGroup.chat
            .map((m) => m.id == msgId ? m.copyWith(deleted: true) : m)
            .toList(),
      ),
    );
    final game = _currentGame;
    if (game != null) {
      _currentGame = game.copyWith(
        chat: game.chat
            .map((m) => m.id == msgId ? m.copyWith(deleted: true) : m)
            .toList(),
      );
    }
    if (inGameChat) {
      _gameChatMessages = _gameChatMessages
          .map((m) => m.id == msgId ? m.copyWith(deleted: true) : m)
          .toList();
    }
    if (!_disposed) notifyListeners();
    if (!_backendUp) return;
    final ctx = _cloudGameContext;
    if (inGameChat && ctx != null) {
      unawaited(
        _repo
            .markGameChatMessageDeleted(ctx.$1, ctx.$2, msgId)
            .catchError((Object e) => debugPrint('deleteGameChat failed: $e')),
      );
      return;
    }
    if (_currentGroupId != null) {
      unawaited(
        _repo
            .markChatMessageDeleted(_currentGroupId!, msgId)
            .catchError((Object e) => debugPrint('deleteMessage failed: $e')),
      );
    }
  }

  /// Creates a poll. Returns a validation message when the question or options
  /// are invalid (empty or duplicate options rejected — checklist 08-015/08-016),
  /// or null on success.
  String? createPoll(
    String question,
    List<String> options, {
    bool multi = false,
  }) {
    // Spec §22: sanitize all poll input.
    final trimmedQuestion = Sanitization.sanitizePollQuestion(question);
    final trimmed = options
        .map((o) => Sanitization.sanitizePollOption(o))
        .where((o) => o.isNotEmpty)
        .toList();
    if (trimmedQuestion.isEmpty) return 'Poll needs a question.';
    if (trimmed.length < 2) return 'Poll needs at least two options.';
    if (trimmed.length > 10) return 'Polls support at most ten options.';
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
      multi: multi,
    );
    _setGroup(_currentGroup.copyWith(polls: [..._currentGroup.polls, poll]));
    _persistPoll(poll);
    pushNotification(
      AppNotification(
        id: 'n-${DateTime.now().millisecondsSinceEpoch}',
        title: 'New poll',
        body: trimmedQuestion,
        type: NotificationType.admin,
        link: '/group',
        read: false,
        timestamp: DateTime.now(),
      ),
    );
    if (!_disposed) notifyListeners();
    return null;
  }

  /// Records a vote. For single-choice polls [selected] holds one option;
  /// for multi-choice polls it holds every option the member ticked.
  void votePoll(String pollId, List<String> selected) {
    final userId = _user?.id;
    if (userId == null) return;
    Poll? updated;
    _setGroup(
      _currentGroup.copyWith(
        polls: _currentGroup.polls.map((p) {
          if (p.id != pollId || p.closed) return p;
          final kept = p.multi
              ? selected
              : selected.isNotEmpty
              ? [selected.first]
              : <String>[];
          final newVotes = Map<String, List<String>>.from(p.votes);
          if (kept.isEmpty) {
            newVotes.remove(userId);
          } else {
            newVotes[userId] = kept;
          }
          updated = Poll(
            id: p.id,
            question: p.question,
            options: p.options,
            votes: newVotes,
            closed: p.closed,
            createdAt: p.createdAt,
            multi: p.multi,
          );
          return updated!;
        }).toList(),
      ),
    );
    if (updated != null) _persistPoll(updated!);
    if (!_disposed) notifyListeners();
  }

  /// Admin closes a poll so it no longer accepts votes (checklist 08-022/08-023).
  void closePoll(String pollId) {
    Poll? closedPoll;
    _setGroup(
      _currentGroup.copyWith(
        polls: _currentGroup.polls
            .map(
              (p) => p.id == pollId
                  ? (closedPoll = Poll(
                      id: p.id,
                      question: p.question,
                      options: p.options,
                      votes: p.votes,
                      closed: true,
                      createdAt: p.createdAt,
                      multi: p.multi,
                    ))
                  : p,
            )
            .toList(),
      ),
    );
    if (closedPoll != null) {
      final poll = closedPoll!;
      _persistPoll(poll);
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Poll closed',
          body: poll.question,
          type: NotificationType.admin,
          link: '/group',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
      // Tech Spec §14.2: "Results may suggest a matching tournament preset."
      // Surface a preset recommendation from the votes so an admin starting a
      // tournament from a poll-driven flow sees the suggestion up front.
      final signals = <num>[
        for (final entry in poll.optionCounts().entries)
          for (final m in RegExp(r'-?\d+(\.\d+)?').allMatches(entry.key))
            num.tryParse(m.group(0) ?? '') ?? 0,
      ];
      final suggestions = suggestPresets(
        expectedPlayers: poll.totalVotes,
        pollSignals: signals,
      );
      if (suggestions.isNotEmpty) {
        pushNotification(
          AppNotification(
            id: 'n-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Preset suggestion',
            body:
                '${poll.question} — consider preset '
                '${suggestions.map((p) => p.name).join(' or ')}?',
            type: NotificationType.admin,
            link: RoutePaths.createTournament,
            read: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    }
    if (!_disposed) notifyListeners();
  }

  /// Whether the RSVP change deadline (1 hour before scheduled start,
  /// 07-011/07-012, UAT-025) has passed for the current game.
  bool get rsvpCutoffPassed =>
      isAdmin ? false : (_currentGame?.settings.rsvpCutoffPassed ?? false);

  /// Sets (or clears) the signed-in member's RSVP for a game — the one open on
  /// screen, or any game in the current group (e.g. tapped from the chat invite
  /// card). Re-selecting the response the member already holds is a no-op; a
  /// different response is persisted and stays selected after the round-trip.
  void setRSVP(Rsvp? rsvp, {String? gameId}) {
    final userId = _user?.id;
    if (userId == null) return;
    _applyRsvpFor(userId, rsvp, gameId: gameId);
  }

  /// Admin-only override: corrects or reopens another member's RSVP (User
  /// Flow §3.1 "The admin may correct or reopen an RSVP when necessary").
  /// Persists through the exact same write paths as [setRSVP].
  void adminSetRSVP(String participantId, Rsvp? rsvp, {String? gameId}) {
    if (!isAdmin || participantId.isEmpty) return;
    _applyRsvpFor(participantId, rsvp, gameId: gameId, announce: false);
  }

  void _applyRsvpFor(
    String userId,
    Rsvp? rsvp, {
    String? gameId,
    bool announce = true,
  }) {
    final targetId = gameId ?? _currentGame?.id;
    if (targetId == null) return;

    final isCurrent = _currentGame?.id == targetId;
    final target = isCurrent
        ? _currentGame
        : _currentGroup.games.where((g) => g.id == targetId).firstOrNull;
    if (target == null) return;
    // Terminal states are blocking (spec §12): a cancelled or finished event
    // takes no further RSVPs — not even from the admin. Without this a member
    // whose screen predates the cancellation could still answer the invite,
    // and the write would resurrect activity on a dead game.
    if (target.status == LiveGameStatus.cancelled ||
        target.status == LiveGameStatus.completed) {
      return;
    }
    if (target.settings.rsvpCutoffPassed && !isAdmin) return;

    // No-op when the member already holds exactly this response — a tap on the
    // already-selected button must not churn a write or flicker the UI.
    //
    // But "already holds" must mean *the server* holds it, not just this
    // device: if local state drifted ahead (a write that never landed, or a
    // stale restored snapshot) this guard silently killed every retry tap and
    // the admin never saw the RSVP at all. `_lastSavedGame` is the last state
    // actually adopted from / written to Firestore, so it is the honest
    // reference.
    final mine = target.players.where((p) => p.id == userId).firstOrNull;
    final serverGame = _lastSavedGame?.id == targetId ? _lastSavedGame : null;
    final serverMine = serverGame?.players
        .where((p) => p.id == userId)
        .firstOrNull;
    final serverAgrees = serverGame == null || serverMine?.rsvp == rsvp;
    if (mine != null && mine.rsvp == rsvp) {
      if (serverAgrees && !_pendingOwnRsvp.containsKey(targetId)) return;
      debugPrint(
        'RSVP re-tap for $userId: local=${mine.rsvp?.name} '
        'server=${serverMine?.rsvp?.name} — forcing a write',
      );
    }

    // Destructive-shrink handling lives inside applyRsvp →
    // [_reconcileExcessGuestSlots]: unconfirmed excess guests are dropped
    // silently, while confirmed ones are kept and surfaced to the admin as a
    // conflict notification (checklist 07-015) — the member's change is never
    // hard-blocked (§7.1).

    LiveGame applyRsvp(LiveGame g) {
      final onRoster = g.players.any((p) => p.id == userId);
      // A member who joined the group *after* this game was created is not on
      // the seeded roster yet — add them when they answer the invite.
      final players = onRoster
          ? g.players
                .map((p) => p.id == userId ? p.copyWith(rsvp: rsvp) : p)
                .toList()
          : [...g.players, _memberAsPlayer(userId, rsvp)];
      var updated = g.copyWith(players: players);
      updated = _syncGuestSlots(updated, userId, rsvp?.guestCount ?? 0);
      updated = _reconcileExcessGuestSlots(
        updated,
        userId,
        rsvp?.guestCount ?? 0,
      );
      return updated;
    }

    final before = target;
    final after = applyRsvp(target);

    if (isCurrent) {
      _currentGame = after;
    }
    // All paths: hold the selection locally until a remote snapshot confirms
    // it. This prevents any lagging Firebase snapshot from reverting the
    // selection before the write round-trip completes (applies to admin too).
    _pendingOwnRsvp[targetId] = rsvp;

    if (!_isGameAuthority || !isCurrent) {
      // Members write only their own fields via dot-path. (An authority
      // RSVPing a game that isn't open on screen also patches directly — the
      // on-screen game's whole-doc save wouldn't cover it.)
      var patch = _rsvpDotPatch(before, after);
      if (patch.isEmpty && !serverAgrees) {
        // Local already displayed this answer, so the diff is empty, but the
        // server never received it. Write the field explicitly instead of
        // dropping the tap on the floor.
        patch = {'players.$userId.rsvp': rsvp?.name};
      }
      _persistOwnRsvpPatch(targetId, patch, rsvp);
    }
    // (authority + on-screen game: persisted by _syncGameToCloud's whole-doc
    // save when notifyListeners fires below.)

    // Notify the admin of RSVP changes (spec §8 notification triggers).
    if (announce && _currentGroup.ownerId != userId) {
      final name = mine?.name ?? _user?.name ?? '';
      final playerName = name.isEmpty ? 'A member' : name;
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'RSVP update',
          body: '$playerName is ${rsvp?.label ?? 'no response'}.',
          type: NotificationType.rsvp,
          link: '/invitation',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }

    // Keep the group's copy of the game in sync so hub badges update at once.
    _setGroup(
      _currentGroup.copyWith(
        games: _currentGroup.games
            .map((g) => g.id == targetId ? applyRsvp(g) : g)
            .toList(),
      ),
    );
    if (!_disposed) notifyListeners();
  }

  void _maybeReassertOwnCheckIn(LiveGame remote, String? writerId) {
    final uid = _user?.id;
    if (uid == null || _isGameAuthority) return;
    if (_pendingCheckIn[remote.id] != uid) return;
    if (writerId != null && writerId == _repo.deviceId) return;
    final serverMine = remote.players.where((p) => p.id == uid).firstOrNull;
    if (serverMine?.checkedIn == true) {
      _pendingCheckIn.remove(remote.id);
      _checkInLanded.remove(remote.id);
      _persistPref('pendingCheckIn', _pendingCheckIn);
      return; // server already agrees
    }
    if (serverMine?.checkedIn == false &&
        serverMine?.confirmed == false &&
        writerId != null &&
        _checkInLanded[remote.id] == true) {
      _pendingCheckIn.remove(remote.id);
      _checkInLanded.remove(remote.id);
      _persistPref('pendingCheckIn', _pendingCheckIn);
      if (_currentGame?.id == remote.id) {
        _currentGame = _withPendingCheckInOverlay(_withOwnRsvpOverlay(remote));
      }
      return; // admin cancelled this member's check-in — do not resurrect
    }
    final n = _checkInReassertCount[remote.id] ?? 0;
    if (n >= 3) return;
    _checkInReassertCount[remote.id] = n + 1;
    // If the server still has no row at all for this member, a narrow
    // `.checkedIn`/`.confirmed` dot-patch would create one missing every
    // other required field (name/id/rsvp/...), corrupting decode for every
    // client. Persist the full row in that case instead.
    if (serverMine == null) {
      final mine = _currentGame?.id == remote.id
          ? _currentGame!.players.where((p) => p.id == uid).firstOrNull
          : null;
      final full =
          mine ?? _memberAsPlayer(uid, Rsvp.going).copyWith(checkedIn: true);
      _persistOwnCheckInPatch(remote.id, {
        'players.$uid': playerToMap(full.copyWith(checkedIn: true, confirmed: false)),
      });
    } else {
      _persistOwnCheckInPatch(remote.id, {
        'players.$uid.checkedIn': true,
        'players.$uid.confirmed': false,
      });
    }
  }

  void _persistOwnCheckInPatch(String gameId, Map<String, dynamic> dotPaths) {
    if (dotPaths.isEmpty) return;
    unawaited(() async {
      const delaysMs = [0, 250, 500, 1000, 2000, 3500, 5000, 8000, 12000];
      for (var attempt = 0; attempt < delaysMs.length; attempt++) {
        if (delaysMs[attempt] > 0) {
          await Future<void>.delayed(Duration(milliseconds: delaysMs[attempt]));
        }
        final uid = _user?.id;
        if (uid == null || _pendingCheckIn[gameId] != uid) return;

        try {
          final gid = _currentGame?.groupId.isNotEmpty == true
              ? _currentGame!.groupId
              : _currentGroupId;
          if (gid != null) {
            await _repo.patchGame(gid, gameId, dotPaths);
            _checkInLanded[gameId] = true;
          }
          return;
        } catch (e) {
          debugPrint('CheckIn patch failed (attempt $attempt): $e');
        }
      }
    }());
  }

  void _persistOwnRsvpPatch(
    String gameId,
    Map<String, dynamic> dotPaths,
    Rsvp? targetRsvp,
  ) {
    if (dotPaths.isEmpty) {
      // before == after at field level — nothing to write. Logged because a
      // silent return here is indistinguishable from a successful save and
      // previously hid a whole class of "the tap did nothing" bugs.
      debugPrint('RSVP patch skipped for $gameId: diff produced no fields');
      return;
    }

    unawaited(() async {
      // Longer, gentler backoff: covers both a slow group-bundle resolve and
      // the post-login token gap without ever yanking the selection.
      const delaysMs = [0, 250, 500, 1000, 2000, 3500, 5000, 8000, 12000];
      var triedSelfJoin = false;
      Object? lastError;
      for (var attempt = 0; attempt < delaysMs.length; attempt++) {
        if (delaysMs[attempt] > 0) {
          await Future<void>.delayed(Duration(milliseconds: delaysMs[attempt]));
        }
        // A newer RSVP for this game supersedes this write.
        if (_pendingOwnRsvp[gameId] != targetRsvp) return;
        if (!_backendUp || _user == null) continue;

        // Re-resolve the group id every attempt — it may still be settling
        // immediately after login / navigation.
        final g = _currentGame?.id == gameId
            ? _currentGame
            : _currentGroup.games.where((x) => x.id == gameId).firstOrNull;
        final gid = (g != null && g.groupId.isNotEmpty)
            ? g.groupId
            : _currentGroupId;
        if (gid == null) {
          debugPrint(
            'RSVP patch waiting for group id (attempt ${attempt + 1})',
          );
          continue;
        }

        try {
          await _repo.patchGame(gid, gameId, dotPaths);
          if (lastRsvpError != null) {
            lastRsvpError = null;
            if (!_disposed) notifyListeners();
          }
          if (g != null) {
            unawaited(_publishProjections(g).catchError((Object _) {}));
          }
          return;
        } catch (e) {
          lastError = e;
          debugPrint('RSVP patch failed (attempt ${attempt + 1}): $e');
          if (_isRetriablePermissionError(e)) {
            await _nudgeAuthToken();
            // The game doc is member-gated. If this signed-in user reached the
            // game via a shared game code / link they were never added to the
            // group roster, so `isMember` is false and the write is denied.
            // Self-join the roster (rules allow a user to create their own
            // 'member' row) and try again.
            if (!triedSelfJoin && !isGuest) {
              triedSelfJoin = true;
              try {
                await _repo.joinGroup(gid, _user!);
                debugPrint(
                  'RSVP patch: self-joined group $gid roster, retrying',
                );
              } catch (joinErr) {
                debugPrint('RSVP patch: self-join failed: $joinErr');
              }
            }
          }
        }
      }
      final errorStr = (lastError ?? '').toString().toLowerCase();
      if (_isRetriablePermissionError(lastError ?? '')) {
        lastRsvpError =
            'RSVP not saved — you may not have write access to this game. Ask the host to add you to the group.';
      } else if (errorStr.contains('not-found') ||
          errorStr.contains('not found') ||
          errorStr.contains('conflict')) {
        lastRsvpError =
            'RSVP not saved — game document missing from server. Ask the host to open the game again.';
      } else if (errorStr.contains('quota-exceeded') ||
          errorStr.contains('resource-exhausted') ||
          errorStr.contains('quota')) {
        lastRsvpError =
            'RSVP not saved — database quota exceeded (free tier limit reached).';
      } else {
        lastRsvpError = 'RSVP save failed. Tap again to retry.';
      }
      _pendingOwnRsvp.remove(gameId);
      _rsvpReassertCount.remove(gameId);
      if (!_disposed) notifyListeners();
    }());
  }

  /// A roster [Player] for the signed-in member, from the group roster. Used
  /// when a member RSVPs to a game created before they joined the group.
  Player _memberAsPlayer(String userId, Rsvp? rsvp) {
    final m = _currentGroup.members.where((x) => x.id == userId).firstOrNull;
    return Player(
      id: userId,
      name: m?.name ?? _user?.name ?? '',
      isGuest: false,
      rsvp: rsvp,
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
  }

  /// Builds the dot-path patch describing an RSVP change: the member's own
  /// `players.{id}` entry plus the guest-slot rows their +N count creates,
  /// updates or removes. A member new to the roster is written whole; an
  /// existing one gets a field-level `players.{id}.rsvp` patch.
  Map<String, dynamic> _rsvpDotPatch(LiveGame before, LiveGame after) {
    final patch = <String, dynamic>{};
    final uid = _user?.id;

    final beforePlayer = before.players.where((p) => p.id == uid).firstOrNull;
    final afterPlayer = after.players.where((p) => p.id == uid).firstOrNull;
    if (afterPlayer != null) {
      if (beforePlayer == null) {
        patch['players.$uid'] = playerToMap(afterPlayer);
      } else if (afterPlayer.rsvp?.name != beforePlayer.rsvp?.name) {
        patch['players.$uid.rsvp'] = afterPlayer.rsvp?.name;
      }
    }

    final beforeSlots = {for (final s in before.guestSlots) s.id: s};
    for (var i = 0; i < after.guestSlots.length; i++) {
      final s = after.guestSlots[i];
      final old = beforeSlots[s.id];
      if (old == null) {
        patch['guestSlots.${s.id}'] = {...guestSlotToMap(s), 'orderIndex': i};
      } else if (old.guestName != s.guestName ||
          old.status != s.status ||
          old.slot != s.slot) {
        patch['guestSlots.${s.id}'] = {...guestSlotToMap(s), 'orderIndex': i};
      }
    }
    for (final s in before.guestSlots) {
      if (!after.guestSlots.any((n) => n.id == s.id)) {
        patch['guestSlots.${s.id}'] = FieldValue.delete();
      }
    }
    return patch;
  }

  /// Keeps the persisted [GuestSlot] records aligned with a member's "Going +N"
  /// RSVP count (checklist 07-014). Missing slots are created as unclaimed;
  /// slots beyond the new count that are still unclaimed are removed. Claimed
  /// slots are never deleted here — excess claims are handled by
  /// [_reconcileExcessGuestSlots].
  LiveGame _syncGuestSlots(LiveGame game, String userId, int newCount) {
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
        keep.add(
          GuestSlot(
            id: 'slot-${DateTime.now().millisecondsSinceEpoch}-$userId-$slot',
            inviterId: userId,
            slot: slot,
            status: GuestSlotStatus.unclaimed,
          ),
        );
      }
    }
    // Unclaimed slots beyond the new count are dropped; claimed ones remain.
    final rest = game.guestSlots
        .where(
          (s) =>
              s.inviterId != userId ||
              (s.inviterId == userId && s.slot > newCount && !s.available),
        )
        .toList();
    final slots = [
      ...rest,
      ...keep,
      ...claimed.where((s) => s.slot <= newCount),
    ];
    // Deduplicate (id-based) to be safe.
    final seen = <String>{};
    final merged = <GuestSlot>[];
    for (final s in slots) {
      if (seen.add(s.id)) merged.add(s);
    }
    return game.copyWith(guestSlots: merged);
  }

  /// Checklist 07-015 / 20-030 / 20-031: when a player lowers their guest
  /// count, unused guest slots beyond the new count are released safely.
  /// Unconfirmed requests are removed; guests already confirmed on an excess
  /// slot are kept but surfaced to the administrator as a conflict.
  LiveGame _reconcileExcessGuestSlots(
    LiveGame game,
    String userId,
    int newCount,
  ) {
    final excess = game.players
        .where(
          (p) =>
              p.isGuest &&
              p.inviterId == userId &&
              (p.guestSlot ?? 0) > newCount,
        )
        .toList();
    if (excess.isEmpty) return game;
    final confirmed = excess.where((p) => p.confirmed).toList();
    // Spec B3/L-20: Only remove UNCLAIMED (unconfirmed) excess guests.
    final unconfirmedExcessIds = excess
        .where((p) => !p.confirmed)
        .map((p) => p.id)
        .toSet();
    final unconfirmedExcessSlots = excess
        .where((p) => !p.confirmed)
        .map((p) => p.guestSlot)
        .toSet();
    final updated = game.copyWith(
      players: game.players
          .where((p) => !unconfirmedExcessIds.contains(p.id))
          .toList(),
      pendingGuests: game.pendingGuests
          .where((p) => !unconfirmedExcessIds.contains(p.id))
          .toList(),
      guestSlots: game.guestSlots
          .where(
            (s) =>
                !(s.inviterId == userId &&
                    unconfirmedExcessSlots.contains(s.slot)),
          )
          .toList(),
    );
    if (confirmed.isNotEmpty) {
      pushNotification(
        AppNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: 'RSVP reduced after guest check-in',
          body:
              '${confirmed.map((p) => p.name).join(', ')} '
              '${confirmed.length == 1 ? 'is' : 'are'} confirmed on a guest slot '
              'the inviter just removed. Review before seating.',
          type: NotificationType.admin,
          link: '/check-in',
          read: false,
          timestamp: DateTime.now(),
        ),
      );
    }
    return updated;
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
          body:
              'You haven\'t responded to ${target.settings.name} '
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
    if (!_disposed) notifyListeners();
  }
}
