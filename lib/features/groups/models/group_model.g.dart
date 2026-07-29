// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GroupModelImpl _$$GroupModelImplFromJson(Map<String, dynamic> json) =>
    _$GroupModelImpl(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String,
      name: json['name'] as String,
      joinCode: json['joinCode'] as String,
      codeRotatedAt: json['codeRotatedAt'] == null
          ? null
          : DateTime.parse(json['codeRotatedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$GroupModelImplToJson(_$GroupModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ownerUserId': instance.ownerUserId,
      'name': instance.name,
      'joinCode': instance.joinCode,
      'codeRotatedAt': instance.codeRotatedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'memberCount': instance.memberCount,
    };

_$GroupMembershipImpl _$$GroupMembershipImplFromJson(
  Map<String, dynamic> json,
) => _$GroupMembershipImpl(
  groupId: json['groupId'] as String,
  userId: json['userId'] as String,
  role: json['role'] as String,
  status: json['status'] as String,
  joinedAt: DateTime.parse(json['joinedAt'] as String),
);

Map<String, dynamic> _$$GroupMembershipImplToJson(
  _$GroupMembershipImpl instance,
) => <String, dynamic>{
  'groupId': instance.groupId,
  'userId': instance.userId,
  'role': instance.role,
  'status': instance.status,
  'joinedAt': instance.joinedAt.toIso8601String(),
};
