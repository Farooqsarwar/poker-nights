/// AppProvider: Group domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Group ──`). Do not change business logic.
part of 'app_provider.dart';

/// What the invite screen shows before someone joins (E6). Comes from the
/// public `joinCodes` doc, so it is readable with only the code.
class GroupInvitePreview {
  const GroupInvitePreview({
    required this.gid,
    required this.name,
    required this.icon,
    this.hostName,
    this.memberCount,
    this.gamesPlayed,
  });

  final String gid;
  final String name;
  final String icon;
  final String? hostName;
  final int? memberCount;
  final int? gamesPlayed;
}

extension AppProviderGroups on AppProvider {
  Group get currentGroup => _currentGroup;

  /// True when the signed-in user already belongs to [gid].
  bool isMemberOfGroup(String gid) => _groups.any((g) => g.id == gid);

  /// Looks up the group behind an invite [code] without joining it. Null when
  /// the code is unknown, is not a group code, or the lookup failed.
  Future<GroupInvitePreview?> previewInvite(String code) async {
    if (!_backendUp) return null;
    try {
      final data = await _repo.peekJoinCode(code);
      if (data == null) return null;
      final gid = data['gid'] as String?;
      final gameId = data['gameId'] as String?;
      if (gid == null || (gameId != null && gameId.isNotEmpty)) return null;
      return GroupInvitePreview(
        gid: gid,
        name: (data['name'] as String?) ?? '',
        icon: (data['icon'] as String?) ?? '♠',
        hostName: data['hostName'] as String?,
        memberCount: (data['memberCount'] as num?)?.toInt(),
        gamesPlayed: (data['gamesPlayed'] as num?)?.toInt(),
      );
    } catch (e) {
      debugPrint('previewInvite failed: $e');
      return null;
    }
  }

  /// Host-side: keeps the invite preview's member and game counts current.
  /// Skipped when nothing changed since the last write.
  void _syncInvitePreview(Group g) {
    final uid = _repo.currentUid;
    if (!_backendUp || uid == null || g.joinCode.isEmpty) return;
    if (g.ownerId != uid) return;
    final host = g.members.where((m) => m.id == g.ownerId).firstOrNull;
    final hostName = host?.name ?? _user?.name ?? '';
    final played = g.pastGames.length;
    final key =
        '${g.joinCode}|${g.name}|${g.icon}|$hostName|${g.members.length}|$played';
    if (key == _lastInvitePreviewKey) return;
    _lastInvitePreviewKey = key;
    unawaited(_repo
        .updateInvitePreview(
          g.joinCode,
          name: g.name,
          icon: g.icon,
          hostName: hostName,
          memberCount: g.members.length,
          gamesPlayed: played,
        )
        .catchError((Object e) {
      _lastInvitePreviewKey = null;
      debugPrint('updateInvitePreview failed: $e');
    }));
  }

  /// Id of the selected group — set the instant a group is chosen, even before
  /// its live bundle has loaded (unlike `currentGroup.id`, which lags).
  String? get currentGroupId => _currentGroupId;

  /// True once a real group bundle is subscribed (id is non-empty).
  bool get hasCurrentGroup => _currentGroupId != null;

  List<Group> get groups => List.unmodifiable(_groups);

  /// Groups ordered pinned-first then alphabetically (client feedback: the
  /// sidebar lists all groups, pinnable, not a single slot).
  List<Group> get orderedGroups {
    final sorted = [..._groups]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    sorted.sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
    return sorted;
  }

  /// Replaces [currentGroup] everywhere it lives so the sidebar list and the
  /// group hub always reflect the same state.
  void _setGroup(Group group) {
    _currentGroup = group;
    final i = _groups.indexWhere((g) => g.id == group.id);
    _groups = i == -1 ? [..._groups, group] : ([..._groups]..[i] = group);
  }

  /// Selects the group hub target and subscribes its live Firestore bundle.
  void setCurrentGroup(Group group) => _selectGroup(group.id);

  /// Joins a group by its invite code. Returns false when the code is
  /// unknown or the request failed.
  Future<bool> joinGroup(String code) async {
    final user = _user;
    if (!_backendUp || user == null) return false;
    try {
      final gid = await _repo.joinByCode(code, user);
      if (gid == null) return false;
      _subscribeUserData(); // refresh the index with the new row promptly
      _selectGroup(gid);
      if (!_disposed) notifyListeners();
      // Wait for the group's live bundle (members, games, chat, polls,
      // settings) so the caller navigates into a fully-populated hub that then
      // keeps updating in real time — not an empty shell.
      await groupReady.timeout(const Duration(seconds: 10), onTimeout: () {});
      if (!_disposed) notifyListeners();
      return true;
    } catch (e) {
      debugPrint('joinGroup failed: $e');
      return false;
    }
  }

  /// Creates a new group with this account as owner. Returns null when the
  /// caller is unauthenticated or the write failed.
  Future<Group?> createGroup(String name, {String icon = '♠'}) async {
    final user = _user;
    if (!_backendUp || user == null) return null;
    final group = Group(
      id: Formatters.secureId('grp'), // 19-007: ids must not be guessable
      name: name,
      joinCode: Formatters.generateCode(),
      ownerId: user.id,
      members: [user],
      games: const [],
      chat: const [],
      polls: const [],
      notifications: const [],
      icon: icon,
    );
    try {
      await _repo.createGroup(group, user);
    } catch (e) {
      debugPrint('createGroup failed: $e');
      return null;
    }
    _subscribeUserData();
    _selectGroup(group.id);
    if (!_disposed) notifyListeners();
    return group;
  }

  /// Pins/unpins a group so it floats to the top of the sidebar's group list.
  void togglePinGroup(Group group) {
    _setGroup(group.copyWith(pinned: !group.pinned));
    if (!_disposed) notifyListeners();
    final uid = _repo.currentUid;
    if (_backendUp && uid != null) {
      unawaited(_repo
          .updateGroupIndex(uid, group.id, pinned: !group.pinned)
          .catchError((Object e) =>
              debugPrint('updateGroupIndex(pinned) failed: $e')));
    }
  }

  /// Owner-only: sets a member's role (Member / Co-host / Host). Co-host
  /// can add members directly and grant rebuys; only Host (or the owner)
  /// can advance the tournament or touch blinds/seating settings.
  void setGroupRole(String userId, GroupRole role) {
    if (_user?.id != _currentGroup.ownerId) return; // Only owner can do this
    if (userId == _currentGroup.ownerId) return; // Cannot change owner's role
    final demoted = <String>[];
    final members = _currentGroup.members.map((m) {
      if (m.id == userId) {
        return m.copyWith(
          isAdmin: role == GroupRole.host,
          isCoAdmin: role == GroupRole.coHost,
        );
      }
      if (role == GroupRole.host &&
          m.isAdmin &&
          m.id != _currentGroup.ownerId) {
        demoted.add(m.id);
        return m.copyWith(isAdmin: false, isCoAdmin: true);
      }
      return m;
    }).toList();
    _setGroup(_currentGroup.copyWith(members: members));
    if (demoted.isNotEmpty) {
      final promoted = _currentGroup.members.firstWhere((m) => m.id == userId);
      final former = _currentGroup.members.firstWhere(
          (m) => m.id == demoted.first);
      addAnnouncement(
        '${former.name} is no longer the host — ${promoted.name} is now the group host.',
        true,
      );
    }
    if (!_disposed) notifyListeners();
    if (_backendUp) {
      unawaited(_repo
          .setMemberRole(_currentGroup.id, userId, role.storageValue)
          .catchError(
              (Object e) => debugPrint('setMemberRole failed: $e')));
      for (final id in demoted) {
        unawaited(_repo
            .setMemberRole(_currentGroup.id, id, GroupRole.coHost.storageValue)
            .catchError(
                (Object e) => debugPrint('setMemberRole (demote) failed: $e')));
      }
    }
  }

  /// Host or Co-host: adds a registered user directly to the group by
  /// email, without going through an invite link/QR/join code. Returns null
  /// on success, or a friendly error message for the UI.
  Future<String?> addMemberByEmail(String email) async {
    if (!canManageMembers) return 'Only the Host can add members.';
    if (!_backendUp) return 'You are offline.';
    final trimmed = email.trim();
    if (trimmed.isEmpty) return 'Enter an email address.';
    AppUser? found;
    try {
      found = await _repo.findUserByEmail(trimmed);
    } catch (e) {
      debugPrint('findUserByEmail failed: $e');
      return 'Could not look up that email. Please try again.';
    }
    if (found == null) {
      return 'No account found for that email. Ask them to sign up '
          '(or open the app once) first, then try again.';
    }
    if (found.id == _user?.id) {
      return "You're already in this group.";
    }
    if (_currentGroup.members.any((m) => m.id == found!.id)) {
      return '${found.name.isEmpty ? 'That user' : found.name} is already in this group.';
    }
    try {
      await _repo.addMemberToGroup(
        _currentGroup.id,
        found,
        groupName: _currentGroup.name,
        groupIcon: _currentGroup.icon,
      );
    } catch (e) {
      debugPrint('addMemberByEmail failed: $e');
      return 'Could not add that member. Please try again.';
    }
    return null;
  }

  /// Owner-only: updates the group's default table-capacity/randomization
  /// settings. Individual tournaments may still override this
  /// ([updateTournamentTableSettings]).
  void updateGroupTableSettings(TableSettings settings) {
    if (_user?.id != _currentGroup.ownerId) return;
    _setGroup(_currentGroup.copyWith(tableSettings: settings));
    if (!_disposed) notifyListeners();
    if (_backendUp) {
      unawaited(_repo
          .updateGroupTableSettings(_currentGroup.id, settings)
          .catchError((Object e) =>
              debugPrint('updateGroupTableSettings failed: $e')));
    }
  }

  /// Owner-only: points the group at one of the owner's saved chip sets, or
  /// clears the pointer by passing null (the Standard box).
  ///
  /// B10 keeps a pointer rather than a copy of the chips, so this is the only
  /// thing that has to be written: editing a set in F5 reaches every group
  /// pointing at it without touching the group at all.
  void setGroupDefaultChipSet(String? id) {
    if (_user?.id != _currentGroup.ownerId) return;
    if (_currentGroup.defaultChipSetId == id) return;
    _setGroup(_currentGroup.copyWith(
      defaultChipSetId: id,
      clearDefaultChipSetId: id == null,
    ));
    if (!_disposed) notifyListeners();
    if (_backendUp) {
      unawaited(_repo
          .updateGroupDefaultChipSet(_currentGroup.id, id)
          .catchError((Object e) =>
              debugPrint('setGroupDefaultChipSet failed: $e')));
    }
  }

  /// Host-only: sets (or clears, passing null) this tournament's override of
  /// the group's default table settings.
  void updateTournamentTableSettings(TableSettings? override) {
    final game = _currentGame;
    if (game == null || !isAdmin) return;
    _currentGame = game.copyWith(
      settings: game.settings.copyWith(
        tableSettingsOverride: override,
        clearTableSettingsOverride: override == null,
      ),
    );
    _syncGroupGame();
    if (!_disposed) notifyListeners();
  }

  /// Owner-only: removes a member from the current group.
  void removeMember(String userId) {
    if (_user?.id != _currentGroup.ownerId) return;
    if (userId == _currentGroup.ownerId) return;
    final members =
        _currentGroup.members.where((m) => m.id != userId).toList();
    _setGroup(_currentGroup.copyWith(members: members));
    if (!_disposed) notifyListeners();
    if (_backendUp) {
      unawaited(_repo
          .deleteMember(_currentGroup.id, userId)
          .catchError(
              (Object e) => debugPrint('deleteMember failed: $e')));
    }
  }

  /// Transfers ownership of the current group to another member.
  /// Only callable by the current owner. Safe no-op for non-owners.
  Future<void> transferGroupOwnership(String newOwnerId) async {
    final userId = _user?.id;
    final gid = _currentGroup.id;
    if (userId == null || userId != _currentGroup.ownerId) return;
    if (newOwnerId == userId || newOwnerId.isEmpty) return;
    final newOwner = _currentGroup.members
        .where((m) => m.id == newOwnerId)
        .firstOrNull;
    if (newOwner == null) return;
    if (_backendUp) {
      await _repo
          .transferGroupOwnership(gid, userId, newOwnerId, newOwner.name)
          .catchError(
            (Object e) => debugPrint('transferOwnership failed: $e'),
          );
    }
  }

  /// Non-owner members may leave a group voluntarily.
  /// B9: retires the group's join code and issues a new one.
  ///
  /// Owner-scoped, like the other group settings. Returns false when there is
  /// no backend to write to or every candidate code was taken, so the UI can
  /// leave the code alone rather than showing a new one that does not work.
  Future<bool> rerollGroupJoinCode() async {
    final user = _user;
    if (user == null || user.id != _currentGroup.ownerId) return false;
    if (!_backendUp) return false;

    final gid = _currentGroup.id;
    final oldCode = _currentGroup.joinCode;
    // Codes are 6 characters from a 32-character alphabet, so a clash is
    // rare; eight draws is generous and still instant.
    for (var attempt = 0; attempt < 8; attempt++) {
      final candidate = Formatters.generateCode();
      if (candidate.toUpperCase() == oldCode.toUpperCase()) continue;
      try {
        final ok = await _repo.rerollGroupJoinCode(
          gid: gid,
          oldCode: oldCode,
          newCode: candidate,
          name: _currentGroup.name,
          icon: _currentGroup.icon,
          hostName: user.name,
          memberCount: _currentGroup.members.length,
          gamesPlayed: _currentGroup.games.length,
        );
        if (!ok) continue;
        _setGroup(_currentGroup.copyWith(joinCode: candidate));
        if (!_disposed) notifyListeners();
        return true;
      } catch (e) {
        debugPrint('rerollGroupJoinCode failed: $e');
        return false;
      }
    }
    return false;
  }

  /// B9: deletes the group for good. Owner-only.
  ///
  /// A host cannot leave their own group, so this is the only way out of one
  /// and it is not reversible -- the UI says so before calling it. Returns
  /// whether the delete was started, so a caller can hold the dialog open and
  /// report a refusal instead of pretending it worked.
  Future<bool> deleteGroup() async {
    final userId = _user?.id;
    if (userId == null || userId != _currentGroup.ownerId) return false;

    final gid = _currentGroup.id;
    final code = _currentGroup.joinCode;
    if (_backendUp && gid.isNotEmpty) {
      try {
        await _repo.deleteGroupRecursive(gid, joinCode: code);
      } catch (e) {
        debugPrint('deleteGroup failed: $e');
        return false;
      }
    }

    // Same teardown as leaving, taken from the session's point of view: the
    // group is gone, so the bundle watching it has to stop either way.
    _bundleSub?.cancel();
    _bundleSub = null;
    _cashSub?.cancel();
    _cashSub = null;
    _currentGroupId = null;
    _bundleLoaded = false;
    _bundleReady = null;
    _groups = _groups.where((g) => g.id != gid).toList();
    final next = orderedGroups.firstOrNull;
    if (next != null) {
      _selectGroup(next.id);
    } else {
      _currentGroup = AppProvider._kEmptyGroup;
    }
    if (!_disposed) notifyListeners();
    return true;
  }

  void leaveGroup() {
    final userId = _user?.id;
    if (userId == null || userId == _currentGroup.ownerId) return;
    final leftGid = _currentGroup.id;
    if (_backendUp && leftGid.isNotEmpty) {
      unawaited(_repo
          .deleteMember(leftGid, userId)
          .catchError(
              (Object e) => debugPrint('leaveGroup deleteMember failed: $e')));
    }
    // Drop the left group locally and switch the hub to another group (or an
    // empty state) straight away, tearing down its now-inaccessible bundle.
    _bundleSub?.cancel();
    _bundleSub = null;
    _cashSub?.cancel();
    _cashSub = null;
    _currentGroupId = null;
    _bundleLoaded = false;
    _bundleReady = null;
    _groups = _groups.where((g) => g.id != leftGid).toList();
    final next = orderedGroups.firstOrNull;
    if (next != null) {
      _selectGroup(next.id);
    } else {
      _currentGroup = AppProvider._kEmptyGroup;
    }
    if (!_disposed) notifyListeners();
  }
}