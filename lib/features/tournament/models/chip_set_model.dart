import 'package:freezed_annotation/freezed_annotation.dart';

part 'chip_set_model.freezed.dart';
part 'chip_set_model.g.dart';

@freezed
class ChipSet with _$ChipSet {
  const factory ChipSet({
    required String id,
    required String groupId,
    required String name,
    required String inventoryMode,
    required List<ChipDenomination> chips,
  }) = _ChipSet;

  factory ChipSet.fromJson(Map<String, dynamic> json) => _$ChipSetFromJson(json);
}

@freezed
class ChipDenomination with _$ChipDenomination {
  const factory ChipDenomination({
    required String color,
    required String colorName,
    required int value,
    required int quantity,
  }) = _ChipDenomination;

  factory ChipDenomination.fromJson(Map<String, dynamic> json) => _$ChipDenominationFromJson(json);
}
