import 'dart:convert';
import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/chip_color.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';
import '../models/user.dart';

extension UserStatsJson on UserStats {
  static UserStats fromJson(Map<String, dynamic> json) => UserStats(
        played: json['played'] as int,
        wins: json['wins'] as int,
        podium: json['podium'] as int,
        avgFinish: (json['avgFinish'] as num).toDouble(),
        knockouts: json['knockouts'] as int,
      );
  Map<String, dynamic> toJson() => {
        'played': played,
        'wins': wins,
        'podium': podium,
        'avgFinish': avgFinish,
        'knockouts': knockouts,
      };
}

extension AppUserJson on AppUser {
  static AppUser fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        isAdmin: json['isAdmin'] as bool,
        stats: UserStatsJson.fromJson(json['stats'] as Map<String, dynamic>),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'isAdmin': isAdmin,
        'stats': UserStatsJson(stats).toJson(),
      };
}

extension ChipColorJson on ChipColor {
  static ChipColor fromJson(Map<String, dynamic> json) => ChipColor(
        color: json['color'] as String,
        hex: json['hex'] as int,
        value: json['value'] as int,
        quantity: json['quantity'] as int,
      );
  Map<String, dynamic> toJson() => {
        'color': color,
        'hex': hex,
        'value': value,
        'quantity': quantity,
      };
}

// Minimal implementation just to satisfy the requirement
// for other models we can use similar logic if needed.
