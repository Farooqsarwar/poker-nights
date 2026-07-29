import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_action_model.freezed.dart';
part 'player_action_model.g.dart';

@freezed
class GameAction with _$GameAction {
  const factory GameAction({
    required String id,
    required String gameId,
    required int sequence,
    required String actorUserId,
    required String type,
    required Map<String, dynamic> payload,
    required DateTime createdAt,
    String? reversedByActionId,
  }) = _GameAction;

  factory GameAction.fromJson(Map<String, dynamic> json) => _$GameActionFromJson(json);
}

enum ActionType {
  startGame,
  pauseGame,
  resumeGame,
  nextLevel,
  eliminate,
  rebuy,
  addOn,
  undo,
  correctResult,
  seatPlayer,
  finalTable,
  speedUp,
  slowDown,
  editLevels,
  completeGame;

  String get value => name;
}
