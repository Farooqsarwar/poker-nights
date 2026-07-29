import 'package:freezed_annotation/freezed_annotation.dart';

part 'settlement_model.freezed.dart';
part 'settlement_model.g.dart';

@freezed
sealed class SettlementStatus with _$SettlementStatus {
  const factory SettlementStatus.pending() = SettlementPending;
  const factory SettlementStatus.confirmed() = SettlementConfirmed;
  const factory SettlementStatus.disputed() = SettlementDisputed;

  factory SettlementStatus.fromJson(Map<String, dynamic> json) => _$SettlementStatusFromJson(json);
}

@freezed
class TournamentSettlement with _$TournamentSettlement {
  const factory TournamentSettlement({
    required String gameId,
    required List<FinalPosition> finalPositions,
    required int prizePool,
    required int organizerAmount,
    required List<PayoutEntry> payouts,
    required SettlementStatus status,
    DateTime? settledAt,
    String? settledBy,
  }) = _TournamentSettlement;

  factory TournamentSettlement.fromJson(Map<String, dynamic> json) => _$TournamentSettlementFromJson(json);
}

@freezed
class FinalPosition with _$FinalPosition {
  const factory FinalPosition({
    required int position,
    required String participantId,
    required String participantName,
    required int payout,
    @Default(false) bool isChop,
    int? chopAmount,
  }) = _FinalPosition;

  factory FinalPosition.fromJson(Map<String, dynamic> json) => _$FinalPositionFromJson(json);
}

@freezed
class PayoutEntry with _$PayoutEntry {
  const factory PayoutEntry({
    required int position,
    required int amount,
  }) = _PayoutEntry;

  factory PayoutEntry.fromJson(Map<String, dynamic> json) => _$PayoutEntryFromJson(json);
}
