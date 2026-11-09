import 'package:flutter/foundation.dart' show listEquals;

/// Aggregated stats shown on the profile and home dashboard.
class UserStats {
  const UserStats({
    required this.played,
    required this.wins,
    required this.podium,
    required this.avgFinish,
    required this.knockouts,
  });

  final int played;
  final int wins;
  final int podium;
  final double avgFinish;
  final int knockouts;
}

/// A member's role within a specific group. The owner always has full Host
/// authority regardless of this value (tracked separately via
/// `Group.ownerId`). Mirrors the `role` string stored in Firestore
/// (`member` / `coadmin` / `admin` — the wire format is unchanged so existing
/// documents keep reading correctly; only the Dart-side names and the
/// user-facing labels changed. "Admin" is not a role in this app: it is
/// always host or co-host).
///
/// - [host]: Host — full control (members, roles, tournaments, blinds,
///   table-split settings).
/// - [coHost]: Co-host — can add members directly and grant rebuys, but
///   cannot advance the tournament or touch blinds/seating settings (D15:
///   exactly one co-host role, never structure/payouts/organiser
///   contribution).
/// - [member]: normal member — chat, polls/RSVP, joins tournaments, sees
///   their seat once assigned.
enum GroupRole { member, coHost, host }

extension GroupRoleStorage on GroupRole {
  String get storageValue => switch (this) {
        GroupRole.member => 'member',
        GroupRole.coHost => 'coadmin',
        GroupRole.host => 'admin',
      };

  static GroupRole fromStorage(String? value) => switch (value) {
        'admin' => GroupRole.host,
        'coadmin' => GroupRole.coHost,
        _ => GroupRole.member,
      };

  String get label => switch (this) {
        GroupRole.host => 'Host',
        GroupRole.coHost => 'Co-host',
        GroupRole.member => 'Member',
      };
}

/// The signed-in member.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.stats,
    this.fcmTokens = const [],
    this.isCoAdmin = false,
    this.blockedUserIds = const [],
    this.organizerContributionAccepted = false,
    this.country = 'US',
    this.is18Plus = true,
  });

  final String id;
  final String name;
  final String email;
  /// Legacy storage flag: true = host role in the legacy global sense.
  /// Authority is per-group (ownerId/GroupRole); do not use alone for
  /// per-tournament gates — resolve via roleIn()/permissions instead.
  @Deprecated('Use roleIn()/permissions per-group instead')
  final bool isAdmin;
  final UserStats stats;
  final List<String> fcmTokens;
  final bool organizerContributionAccepted;
  final String country;
  final bool is18Plus;

  /// Members this member has blocked — spec §E10 (3) "Moderation": "**Block**
  /// — on a member's row or message: **Block {name}** hides their messages and
  /// polls for the blocker everywhere (stored on the blocker's user document)
  /// until unblocked in Settings → Blocked".
  ///
  /// A block is a VIEW filter scoped to this one document. Nothing is deleted:
  /// the blocked member's messages stay in `…/chat` and stay visible to
  /// everyone else, and the blocked member is never told (H3's FAQ sells Block
  /// as "hide their messages", not as a removal). Host, co-host and member may
  /// all block; guests may not (§E6's matrix, "Report a chat message · block a
  /// member": host ✓, co-host ✓, member ✓, guest —, TV —).
  final List<String> blockedUserIds;

  /// True when this membership holds the elevated "Co-host" role: can add
  /// members directly and grant rebuys, but cannot advance the tournament or
  /// touch blinds/seating settings (Host-only). Mutually exclusive
  /// with [isAdmin] in practice — a member's group role is one of
  /// member/co-host/host, never more than one at a time.
  final bool isCoAdmin;

  /// Spec D15: Role resolution per group context.
  GroupRole get defaultRole =>
      isAdmin ? GroupRole.host : (isCoAdmin ? GroupRole.coHost : GroupRole.member);

  /// Resolves the user's role inside [group], honouring group ownership and membership.
  GroupRole roleIn(dynamic group) {
    if (group != null) {
      try {
        if (group.ownerId == id) return GroupRole.host;
        final members = group.members as Iterable?;
        if (members != null) {
          for (final m in members) {
            if (m.id == id) {
              return m.isAdmin == true
                  ? GroupRole.host
                  : (m.isCoAdmin == true ? GroupRole.coHost : GroupRole.member);
            }
          }
        }
      } catch (_) {}
    }
    return defaultRole;
  }

  String get initials {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  /// True when [userId] is on this member's block list. An empty id is never
  /// blocked: an authorless message is a system card, and a blank id in the
  /// list would otherwise hide every one of them.
  bool isBlocked(String userId) =>
      userId.isNotEmpty && blockedUserIds.contains(userId);

  /// True once anybody has been blocked — the header entry point for the
  /// "Blocked members" list is only worth showing when this is true.
  bool get hasBlockedUsers => blockedUserIds.isNotEmpty;

  /// This member with [userId] blocked, or **this same instance** when the
  /// call changes nothing, so a caller can tell a real change from a no-op
  /// with `identical` and skip the write.
  ///
  /// No-ops, all per §E10/E6: an empty id, your own id (blocking yourself would
  /// only hide your own messages, and §E6 gives a guest no blocking right at
  /// all), and a member who is already blocked.
  AppUser withBlocked(String userId) {
    if (userId.isEmpty || userId == id || isBlocked(userId)) return this;
    return copyWith(blockedUserIds: [...blockedUserIds, userId]);
  }

  /// This member with [userId] removed from the block list, or this same
  /// instance when they were not blocked.
  AppUser withoutBlocked(String userId) {
    if (!isBlocked(userId)) return this;
    return copyWith(
      blockedUserIds: blockedUserIds
          .where((id) => id != userId)
          .toList(growable: false),
    );
  }

  /// This member with the whole block list replaced by [ids] — the sign-in
  /// restore of the list stored on the profile document (§E10 (3)).
  ///
  /// The stored list is normalised on the way in: blanks, duplicates and your
  /// own id are dropped, so a hand-edited or half-migrated document cannot put
  /// the member in a state the UI cannot undo. Returns this same instance when
  /// the normalised list already matches, so an unchanged restore writes
  /// nothing back.
  AppUser withBlockedList(Iterable<String> ids) {
    final seen = <String>[];
    for (final candidate in ids) {
      if (candidate.isEmpty || candidate == id || seen.contains(candidate)) {
        continue;
      }
      seen.add(candidate);
    }
    if (listEquals(seen, blockedUserIds)) return this;
    return copyWith(blockedUserIds: seen);
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    bool? isAdmin,
    UserStats? stats,
    List<String>? fcmTokens,
    bool? isCoAdmin,
    List<String>? blockedUserIds,
    bool? organizerContributionAccepted,
    String? country,
    bool? is18Plus,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      stats: stats ?? this.stats,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      isCoAdmin: isCoAdmin ?? this.isCoAdmin,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      organizerContributionAccepted:
          organizerContributionAccepted ?? this.organizerContributionAccepted,
      country: country ?? this.country,
      is18Plus: is18Plus ?? this.is18Plus,
    );
  }
}
