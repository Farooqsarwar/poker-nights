// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CheckInPendingImpl _$$CheckInPendingImplFromJson(Map<String, dynamic> json) =>
    _$CheckInPendingImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$CheckInPendingImplToJson(
  _$CheckInPendingImpl instance,
) => <String, dynamic>{'runtimeType': instance.$type};

_$CheckInCheckedInImpl _$$CheckInCheckedInImplFromJson(
  Map<String, dynamic> json,
) => _$CheckInCheckedInImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$CheckInCheckedInImplToJson(
  _$CheckInCheckedInImpl instance,
) => <String, dynamic>{'runtimeType': instance.$type};

_$CheckInNoShowImpl _$$CheckInNoShowImplFromJson(Map<String, dynamic> json) =>
    _$CheckInNoShowImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$CheckInNoShowImplToJson(_$CheckInNoShowImpl instance) =>
    <String, dynamic>{'runtimeType': instance.$type};

_$CheckInRecordImpl _$$CheckInRecordImplFromJson(Map<String, dynamic> json) =>
    _$CheckInRecordImpl(
      id: json['id'] as String,
      gameId: json['gameId'] as String,
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      status: CheckInStatus.fromJson(json['status'] as Map<String, dynamic>),
      checkedInAt: json['checkedInAt'] == null
          ? null
          : DateTime.parse(json['checkedInAt'] as String),
      note: json['note'] as String?,
    );

Map<String, dynamic> _$$CheckInRecordImplToJson(_$CheckInRecordImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gameId': instance.gameId,
      'participantId': instance.participantId,
      'participantName': instance.participantName,
      'status': instance.status,
      'checkedInAt': instance.checkedInAt?.toIso8601String(),
      'note': instance.note,
    };
