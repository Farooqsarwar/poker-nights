import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_settings_model.freezed.dart';
part 'group_settings_model.g.dart';

@freezed
class GroupSettings with _$GroupSettings {
  const factory GroupSettings({
    required String groupId,
    @Default('active') String status,
    @Default(0) double organizerFeePercent,
    @Default(false) bool allowGuestPlayers,
    @Default(4) int maxGuestsPerPlayer,
    DateTime? updatedAt,
  }) = _GroupSettings;

  factory GroupSettings.fromJson(Map<String, dynamic> json) => _$GroupSettingsFromJson(json);
}
