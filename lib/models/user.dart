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

enum UserRole { admin, player, guest }

/// The signed-in member.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.stats,
  });

  final String id;
  final String name;
  final String email;
  final bool isAdmin;
  final UserStats stats;

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
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      stats: stats ?? this.stats,
    );
  }
}
