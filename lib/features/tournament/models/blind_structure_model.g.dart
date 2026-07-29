// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blind_structure_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BlindStructureImpl _$$BlindStructureImplFromJson(Map<String, dynamic> json) =>
    _$BlindStructureImpl(
      levels: (json['levels'] as List<dynamic>)
          .map((e) => BlindLevel.fromJson(e as Map<String, dynamic>))
          .toList(),
      startingStack: (json['startingStack'] as num).toInt(),
      startingStackChips: (json['startingStackChips'] as num).toInt(),
      rebuyStack: (json['rebuyStack'] as num).toInt(),
      addOnStack: (json['addOnStack'] as num).toInt(),
      anteActivationLevel: (json['anteActivationLevel'] as num).toInt(),
      predictedFinishLevel: (json['predictedFinishLevel'] as num).toInt(),
      chipPlanSummary: json['chipPlanSummary'] as String,
      chipExchanges: (json['chipExchanges'] as List<dynamic>)
          .map((e) => ChipExchange.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$BlindStructureImplToJson(
  _$BlindStructureImpl instance,
) => <String, dynamic>{
  'levels': instance.levels,
  'startingStack': instance.startingStack,
  'startingStackChips': instance.startingStackChips,
  'rebuyStack': instance.rebuyStack,
  'addOnStack': instance.addOnStack,
  'anteActivationLevel': instance.anteActivationLevel,
  'predictedFinishLevel': instance.predictedFinishLevel,
  'chipPlanSummary': instance.chipPlanSummary,
  'chipExchanges': instance.chipExchanges,
};

_$BlindLevelImpl _$$BlindLevelImplFromJson(Map<String, dynamic> json) =>
    _$BlindLevelImpl(
      level: (json['level'] as num).toInt(),
      smallBlind: (json['smallBlind'] as num).toInt(),
      bigBlind: (json['bigBlind'] as num).toInt(),
      ante: (json['ante'] as num).toInt(),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      label: json['label'] as String? ?? '',
    );

Map<String, dynamic> _$$BlindLevelImplToJson(_$BlindLevelImpl instance) =>
    <String, dynamic>{
      'level': instance.level,
      'smallBlind': instance.smallBlind,
      'bigBlind': instance.bigBlind,
      'ante': instance.ante,
      'durationMinutes': instance.durationMinutes,
      'label': instance.label,
    };

_$ChipExchangeImpl _$$ChipExchangeImplFromJson(Map<String, dynamic> json) =>
    _$ChipExchangeImpl(
      atLevel: (json['atLevel'] as num).toInt(),
      instruction: json['instruction'] as String,
    );

Map<String, dynamic> _$$ChipExchangeImplToJson(_$ChipExchangeImpl instance) =>
    <String, dynamic>{
      'atLevel': instance.atLevel,
      'instruction': instance.instruction,
    };
