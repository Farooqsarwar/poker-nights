// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TableLayoutImpl _$$TableLayoutImplFromJson(Map<String, dynamic> json) =>
    _$TableLayoutImpl(
      tableNo: (json['tableNo'] as num).toInt(),
      seats: (json['seats'] as List<dynamic>)
          .map((e) => SeatPosition.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$TableLayoutImplToJson(_$TableLayoutImpl instance) =>
    <String, dynamic>{'tableNo': instance.tableNo, 'seats': instance.seats};

_$SeatPositionImpl _$$SeatPositionImplFromJson(Map<String, dynamic> json) =>
    _$SeatPositionImpl(
      seatNo: (json['seatNo'] as num).toInt(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      label: json['label'] as String,
    );

Map<String, dynamic> _$$SeatPositionImplToJson(_$SeatPositionImpl instance) =>
    <String, dynamic>{
      'seatNo': instance.seatNo,
      'x': instance.x,
      'y': instance.y,
      'label': instance.label,
    };
