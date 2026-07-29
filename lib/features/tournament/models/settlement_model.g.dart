// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settlement_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SettlementPendingImpl _$$SettlementPendingImplFromJson(
  Map<String, dynamic> json,
) => _$SettlementPendingImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$SettlementPendingImplToJson(
  _$SettlementPendingImpl instance,
) => <String, dynamic>{'runtimeType': instance.$type};

_$SettlementConfirmedImpl _$$SettlementConfirmedImplFromJson(
  Map<String, dynamic> json,
) => _$SettlementConfirmedImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$SettlementConfirmedImplToJson(
  _$SettlementConfirmedImpl instance,
) => <String, dynamic>{'runtimeType': instance.$type};

_$SettlementDisputedImpl _$$SettlementDisputedImplFromJson(
  Map<String, dynamic> json,
) => _$SettlementDisputedImpl($type: json['runtimeType'] as String?);

Map<String, dynamic> _$$SettlementDisputedImplToJson(
  _$SettlementDisputedImpl instance,
) => <String, dynamic>{'runtimeType': instance.$type};

_$TournamentSettlementImpl _$$TournamentSettlementImplFromJson(
  Map<String, dynamic> json,
) => _$TournamentSettlementImpl(
  gameId: json['gameId'] as String,
  finalPositions: (json['finalPositions'] as List<dynamic>)
      .map((e) => FinalPosition.fromJson(e as Map<String, dynamic>))
      .toList(),
  prizePool: (json['prizePool'] as num).toInt(),
  organizerAmount: (json['organizerAmount'] as num).toInt(),
  payouts: (json['payouts'] as List<dynamic>)
      .map((e) => PayoutEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  status: SettlementStatus.fromJson(json['status'] as Map<String, dynamic>),
  settledAt: json['settledAt'] == null
      ? null
      : DateTime.parse(json['settledAt'] as String),
  settledBy: json['settledBy'] as String?,
);

Map<String, dynamic> _$$TournamentSettlementImplToJson(
  _$TournamentSettlementImpl instance,
) => <String, dynamic>{
  'gameId': instance.gameId,
  'finalPositions': instance.finalPositions,
  'prizePool': instance.prizePool,
  'organizerAmount': instance.organizerAmount,
  'payouts': instance.payouts,
  'status': instance.status,
  'settledAt': instance.settledAt?.toIso8601String(),
  'settledBy': instance.settledBy,
};

_$FinalPositionImpl _$$FinalPositionImplFromJson(Map<String, dynamic> json) =>
    _$FinalPositionImpl(
      position: (json['position'] as num).toInt(),
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      payout: (json['payout'] as num).toInt(),
      isChop: json['isChop'] as bool? ?? false,
      chopAmount: (json['chopAmount'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$FinalPositionImplToJson(_$FinalPositionImpl instance) =>
    <String, dynamic>{
      'position': instance.position,
      'participantId': instance.participantId,
      'participantName': instance.participantName,
      'payout': instance.payout,
      'isChop': instance.isChop,
      'chopAmount': instance.chopAmount,
    };

_$PayoutEntryImpl _$$PayoutEntryImplFromJson(Map<String, dynamic> json) =>
    _$PayoutEntryImpl(
      position: (json['position'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
    );

Map<String, dynamic> _$$PayoutEntryImplToJson(_$PayoutEntryImpl instance) =>
    <String, dynamic>{'position': instance.position, 'amount': instance.amount};
