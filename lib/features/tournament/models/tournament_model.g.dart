// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tournament_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TournamentModelImpl _$$TournamentModelImplFromJson(
  Map<String, dynamic> json,
) => _$TournamentModelImpl(
  id: json['id'] as String,
  groupId: json['groupId'] as String,
  adminUserId: json['adminUserId'] as String,
  name: json['name'] as String,
  scheduledAt: DateTime.parse(json['scheduledAt'] as String),
  location: json['location'] as String?,
  status: json['status'] as String,
  publicCode: json['publicCode'] as String,
  settings: TournamentSettings.fromJson(
    json['settings'] as Map<String, dynamic>,
  ),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  startedAt: json['startedAt'] == null
      ? null
      : DateTime.parse(json['startedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  revision: (json['revision'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$TournamentModelImplToJson(
  _$TournamentModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'groupId': instance.groupId,
  'adminUserId': instance.adminUserId,
  'name': instance.name,
  'scheduledAt': instance.scheduledAt.toIso8601String(),
  'location': instance.location,
  'status': instance.status,
  'publicCode': instance.publicCode,
  'settings': instance.settings,
  'createdAt': instance.createdAt?.toIso8601String(),
  'startedAt': instance.startedAt?.toIso8601String(),
  'completedAt': instance.completedAt?.toIso8601String(),
  'revision': instance.revision,
};

_$TournamentSettingsImpl _$$TournamentSettingsImplFromJson(
  Map<String, dynamic> json,
) => _$TournamentSettingsImpl(
  expectedPlayers: (json['expectedPlayers'] as num).toInt(),
  targetDurationHours: (json['targetDurationHours'] as num).toDouble(),
  buyIn: (json['buyIn'] as num).toDouble(),
  koBounty: (json['koBounty'] as num?)?.toDouble() ?? 0,
  rebuysEnabled: json['rebuysEnabled'] as bool? ?? true,
  rebuyCloseLevel: (json['rebuyCloseLevel'] as num?)?.toInt() ?? 6,
  rebuyLimited: json['rebuyLimited'] as bool? ?? false,
  rebuyLimit: (json['rebuyLimit'] as num?)?.toInt() ?? 0,
  addOnEnabled: json['addOnEnabled'] as bool? ?? true,
  addOnPrice: (json['addOnPrice'] as num?)?.toDouble() ?? 0,
  maxAddOnPerPlayer: (json['maxAddOnPerPlayer'] as num?)?.toInt() ?? 1,
  anteMode: json['anteMode'] as String? ?? 'off',
  organizerPercentage: (json['organizerPercentage'] as num?)?.toDouble() ?? 0,
  chipSetId: json['chipSetId'] as String?,
  chipInventoryMode: json['chipInventoryMode'] as String? ?? 'exact',
  chipInventory:
      (json['chipInventory'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
);

Map<String, dynamic> _$$TournamentSettingsImplToJson(
  _$TournamentSettingsImpl instance,
) => <String, dynamic>{
  'expectedPlayers': instance.expectedPlayers,
  'targetDurationHours': instance.targetDurationHours,
  'buyIn': instance.buyIn,
  'koBounty': instance.koBounty,
  'rebuysEnabled': instance.rebuysEnabled,
  'rebuyCloseLevel': instance.rebuyCloseLevel,
  'rebuyLimited': instance.rebuyLimited,
  'rebuyLimit': instance.rebuyLimit,
  'addOnEnabled': instance.addOnEnabled,
  'addOnPrice': instance.addOnPrice,
  'maxAddOnPerPlayer': instance.maxAddOnPerPlayer,
  'anteMode': instance.anteMode,
  'organizerPercentage': instance.organizerPercentage,
  'chipSetId': instance.chipSetId,
  'chipInventoryMode': instance.chipInventoryMode,
  'chipInventory': instance.chipInventory,
};
