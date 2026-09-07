/// AppProvider: Group domain mixin.
///
/// Extracted verbatim from app_provider.dart (`// ── Group ──`). Do not change business logic.
part of 'app_provider.dart';

extension AppProviderGroups on AppProvider {
  Group get currentGroup => _currentGroup;

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
  Future<Group?> createGroup(String name, {String icon = '♠️'}) async {
    final user = _user;
    if (!_backendUp || user == null) return null;
    final group = Group(
      id: 'grp-${DateTime.now().millisecondsSinceEpoch}',
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

  /// Owner-only: sets a member's role (Member / Co-Admin / Admin). Co-Admin
  /// can add members directly and grant rebuys; only Admin (or the owner)
  /// can advance the tournament or touch blinds/seating settings.
  void setGroupRole(String userId, GroupRole role) {
    if (_user?.id != _currentGroup.ownerId) return; // Only owner can do this
    if (userId == _currentGroup.ownerId) return; // Cannot change owner's role
    final demoted = <String>[];
    final members = _currentGroup.members.map((m) {
      if (m.id == userId) {
        return m.copyWith(
          isAdmin: role == GroupRole.admin,
          isCoAdmin: role == GroupRole.coAdmin,
        );
      }
      if (role == GroupRole.admin &&
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
        '${former.name} is no longer an admin — ${promoted.name} is now the group admin.',
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
            .setMemberRole(_currentGroup.id, id, GroupRole.coAdmin.storageValue)
            .catchError(
                (Object e) => debugPrint('setMemberRole (demote) failed: $e')));
      }
    }
  }

  /// Host/Admin or Co-Admin: adds a registered user directly to the group by
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

  /// Admin-only: sets (or clears, passing null) this tournament's override of
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