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

enum UserRole { host, player, guest }

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
  });

  final String id;
  final String name;
  final String email;
  final bool isAdmin;
  final UserStats stats;
  final List<String> fcmTokens;

  /// True when this membership holds the elevated "Co-host" role: can add
  /// members directly and grant rebuys, but cannot advance the tournament or
  /// touch blinds/seating settings (Host-only). Mutually exclusive
  /// with [isAdmin] in practice — a member's group role is one of
  /// member/co-host/host, never more than one at a time.
  final bool isCoAdmin;

  String get initials {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    bool? isAdmin,
    UserStats? stats,
    List<String>? fcmTokens,
    bool? isCoAdmin,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      stats: stats ?? this.stats,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      isCoAdmin: isCoAdmin ?? this.isCoAdmin,
    );
  }
}
