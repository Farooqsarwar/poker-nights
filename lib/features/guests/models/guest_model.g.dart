// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guest_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GuestModelImpl _$$GuestModelImplFromJson(Map<String, dynamic> json) =>
    _$GuestModelImpl(
      id: json['id'] as String,
      gameId: json['gameId'] as String,
      inviterParticipantId: json['inviterParticipantId'] as String,
      slotNo: (json['slotNo'] as num).toInt(),
      name: json['name'] as String,
      confirmationState: json['confirmationState'] as String,
      tableNo: (json['tableNo'] as num?)?.toInt(),
      seatNo: (json['seatNo'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$GuestModelImplToJson(_$GuestModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gameId': instance.gameId,
      'inviterParticipantId': instance.inviterParticipantId,
      'slotNo': instance.slotNo,
      'name': instance.name,
      'confirmationState': instance.confirmationState,
      'tableNo': instance.tableNo,
      'seatNo': instance.seatNo,
    };
