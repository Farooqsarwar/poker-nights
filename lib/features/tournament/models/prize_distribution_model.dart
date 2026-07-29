import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:poker_night/features/tournament/models/settlement_model.dart';

part 'prize_distribution_model.freezed.dart';
part 'prize_distribution_model.g.dart';

@freezed
class PrizeDistribution with _$PrizeDistribution {
  const factory PrizeDistribution({
    required int prizePool,
    required int organizerAmount,
    required int paidPlaces,
    required List<PayoutEntry> payouts,
  }) = _PrizeDistribution;

  factory PrizeDistribution.fromJson(Map<String, dynamic> json) => _$PrizeDistributionFromJson(json);
}

@freezed
class CashGameSettlement with _$CashGameSettlement {
  const factory CashGameSettlement({
    required String sessionId,
    required List<CashSettlementEntry> entries,
    required SettlementStatus status,
    DateTime? settledAt,
  }) = _CashGameSettlement;

  factory CashGameSettlement.fromJson(Map<String, dynamic> json) => _$CashGameSettlementFromJson(json);
}

@freezed
class CashSettlementEntry with _$CashSettlementEntry {
  const factory CashSettlementEntry({
    required String participantId,
    required String participantName,
    required int buyIn,
    required int topUps,
    required int cashOut,
    required int netResult,
  }) = _CashSettlementEntry;

  factory CashSettlementEntry.fromJson(Map<String, dynamic> json) => _$CashSettlementEntryFromJson(json);
}
