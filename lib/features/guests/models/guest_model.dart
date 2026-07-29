import 'package:freezed_annotation/freezed_annotation.dart';

part 'guest_model.freezed.dart';
part 'guest_model.g.dart';

@freezed
class GuestModel with _$GuestModel {
  const factory GuestModel({
    required String id,
    required String gameId,
    required String inviterParticipantId,
    required int slotNo,
    required String name,
    required String confirmationState,
    int? tableNo,
    int? seatNo,
  }) = _GuestModel;

  factory GuestModel.fromJson(Map<String, dynamic> json) => _$GuestModelFromJson(json);
}
