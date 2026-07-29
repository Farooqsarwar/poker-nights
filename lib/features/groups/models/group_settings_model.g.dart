// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_settings_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GroupSettingsImpl _$$GroupSettingsImplFromJson(Map<String, dynamic> json) =>
    _$GroupSettingsImpl(
      groupId: json['groupId'] as String,
      status: json['status'] as String? ?? 'active',
      organizerFeePercent:
          (json['organizerFeePercent'] as num?)?.toDouble() ?? 0,
      allowGuestPlayers: json['allowGuestPlayers'] as bool? ?? false,
      maxGuestsPerPlayer: (json['maxGuestsPerPlayer'] as num?)?.toInt() ?? 4,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$GroupSettingsImplToJson(_$GroupSettingsImpl instance) =>
    <String, dynamic>{
      'groupId': instance.groupId,
      'status': instance.status,
      'organizerFeePercent': instance.organizerFeePercent,
      'allowGuestPlayers': instance.allowGuestPlayers,
      'maxGuestsPerPlayer': instance.maxGuestsPerPlayer,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
