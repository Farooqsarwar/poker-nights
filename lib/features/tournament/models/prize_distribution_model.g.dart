// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prize_distribution_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PrizeDistributionImpl _$$PrizeDistributionImplFromJson(
  Map<String, dynamic> json,
) => _$PrizeDistributionImpl(
  prizePool: (json['prizePool'] as num).toInt(),
  organizerAmount: (json['organizerAmount'] as num).toInt(),
  paidPlaces: (json['paidPlaces'] as num).toInt(),
  payouts: (json['payouts'] as List<dynamic>)
      .map((e) => PayoutEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$$PrizeDistributionImplToJson(
  _$PrizeDistributionImpl instance,
) => <String, dynamic>{
  'prizePool': instance.prizePool,
  'organizerAmount': instance.organizerAmount,
  'paidPlaces': instance.paidPlaces,
  'payouts': instance.payouts,
};

_$CashGameSettlementImpl _$$CashGameSettlementImplFromJson(
  Map<String, dynamic> json,
) => _$CashGameSettlementImpl(
  sessionId: json['sessionId'] as String,
  entries: (json['entries'] as List<dynamic>)
      .map((e) => CashSettlementEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  status: SettlementStatus.fromJson(json['status'] as Map<String, dynamic>),
  settledAt: json['settledAt'] == null
      ? null
      : DateTime.parse(json['settledAt'] as String),
);

Map<String, dynamic> _$$CashGameSettlementImplToJson(
  _$CashGameSettlementImpl instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'entries': instance.entries,
  'status': instance.status,
  'settledAt': instance.settledAt?.toIso8601String(),
};

_$CashSettlementEntryImpl _$$CashSettlementEntryImplFromJson(
  Map<String, dynamic> json,
) => _$CashSettlementEntryImpl(
  participantId: json['participantId'] as String,
  participantName: json['participantName'] as String,
  buyIn: (json['buyIn'] as num).toInt(),
  topUps: (json['topUps'] as num).toInt(),
  cashOut: (json['cashOut'] as num).toInt(),
  netResult: (json['netResult'] as num).toInt(),
);

Map<String, dynamic> _$$CashSettlementEntryImplToJson(
  _$CashSettlementEntryImpl instance,
) => <String, dynamic>{
  'participantId': instance.participantId,
  'participantName': instance.participantName,
  'buyIn': instance.buyIn,
  'topUps': instance.topUps,
  'cashOut': instance.cashOut,
  'netResult': instance.netResult,
};
