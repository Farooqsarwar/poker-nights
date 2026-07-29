// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chip_set_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChipSetImpl _$$ChipSetImplFromJson(Map<String, dynamic> json) =>
    _$ChipSetImpl(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      name: json['name'] as String,
      inventoryMode: json['inventoryMode'] as String,
      chips: (json['chips'] as List<dynamic>)
          .map((e) => ChipDenomination.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$ChipSetImplToJson(_$ChipSetImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'name': instance.name,
      'inventoryMode': instance.inventoryMode,
      'chips': instance.chips,
    };

_$ChipDenominationImpl _$$ChipDenominationImplFromJson(
  Map<String, dynamic> json,
) => _$ChipDenominationImpl(
  color: json['color'] as String,
  colorName: json['colorName'] as String,
  value: (json['value'] as num).toInt(),
  quantity: (json['quantity'] as num).toInt(),
);

Map<String, dynamic> _$$ChipDenominationImplToJson(
  _$ChipDenominationImpl instance,
) => <String, dynamic>{
  'color': instance.color,
  'colorName': instance.colorName,
  'value': instance.value,
  'quantity': instance.quantity,
};
