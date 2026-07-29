import 'package:freezed_annotation/freezed_annotation.dart';

part 'cash_session_model.freezed.dart';
part 'cash_session_model.g.dart';

@freezed
class CashSession with _$CashSession {
  const factory CashSession({
    required String id,
    required String groupId,
    required String name,
    required int smallBlind,
    required int bigBlind,
    required String status,
    required DateTime createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    required List<CashPlayer> players,
    @Default(0) int totalIssued,
    @Default(0) int totalReturned,
  }) = _CashSession;

  factory CashSession.fromJson(Map<String, dynamic> json) => _$CashSessionFromJson(json);
}

@freezed
class CashPlayer with _$CashPlayer {
  const factory CashPlayer({
    required String participantId,
    required String name,
    required int buyIn,
    required int topUps,
    required int cashOut,
    @Default('active') String status,
  }) = _CashPlayer;

  factory CashPlayer.fromJson(Map<String, dynamic> json) => _$CashPlayerFromJson(json);
}
