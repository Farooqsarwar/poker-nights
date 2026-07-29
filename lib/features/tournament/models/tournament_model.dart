import 'package:freezed_annotation/freezed_annotation.dart';

part 'tournament_model.freezed.dart';
part 'tournament_model.g.dart';

@freezed
class TournamentModel with _$TournamentModel {
  const factory TournamentModel({
    required String id,
    required String groupId,
    required String adminUserId,
    required String name,
    required DateTime scheduledAt,
    String? location,
    required String status,
    required String publicCode,
    required TournamentSettings settings,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    @Default(0) int revision,
  }) = _TournamentModel;

  factory TournamentModel.fromJson(Map<String, dynamic> json) => _$TournamentModelFromJson(json);
}

@freezed
class TournamentSettings with _$TournamentSettings {
  const factory TournamentSettings({
    required int expectedPlayers,
    required double targetDurationHours,
    required double buyIn,
    @Default(0) double koBounty,
    @Default(true) bool rebuysEnabled,
    @Default(6) int rebuyCloseLevel,
    @Default(false) bool rebuyLimited,
    @Default(0) int rebuyLimit,
    @Default(true) bool addOnEnabled,
    @Default(0) double addOnPrice,
    @Default(1) int maxAddOnPerPlayer,
    @Default('off') String anteMode,
    @Default(0) double organizerPercentage,
    String? chipSetId,
    @Default('exact') String chipInventoryMode,
    @Default({}) Map<String, int> chipInventory,
  }) = _TournamentSettings;

  factory TournamentSettings.fromJson(Map<String, dynamic> json) => _$TournamentSettingsFromJson(json);
}

enum TournamentStatus {
  draft,
  published,
  active,
  paused,
  completed,
  cancelled;

  String get value => name;
  static TournamentStatus fromString(String s) => TournamentStatus.values.firstWhere((e) => e.name == s, orElse: () => TournamentStatus.draft);
}
