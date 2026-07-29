import 'package:freezed_annotation/freezed_annotation.dart';

part 'blind_structure_model.freezed.dart';
part 'blind_structure_model.g.dart';

@freezed
class BlindStructure with _$BlindStructure {
  const factory BlindStructure({
    required List<BlindLevel> levels,
    required int startingStack,
    required int startingStackChips,
    required int rebuyStack,
    required int addOnStack,
    required int anteActivationLevel,
    required int predictedFinishLevel,
    required String chipPlanSummary,
    required List<ChipExchange> chipExchanges,
  }) = _BlindStructure;

  factory BlindStructure.fromJson(Map<String, dynamic> json) => _$BlindStructureFromJson(json);
}

@freezed
class BlindLevel with _$BlindLevel {
  const factory BlindLevel({
    required int level,
    required int smallBlind,
    required int bigBlind,
    required int ante,
    required int durationMinutes,
    @Default('') String label,
  }) = _BlindLevel;

  factory BlindLevel.fromJson(Map<String, dynamic> json) => _$BlindLevelFromJson(json);
}

@freezed
class ChipExchange with _$ChipExchange {
  const factory ChipExchange({
    required int atLevel,
    required String instruction,
  }) = _ChipExchange;

  factory ChipExchange.fromJson(Map<String, dynamic> json) => _$ChipExchangeFromJson(json);
}
