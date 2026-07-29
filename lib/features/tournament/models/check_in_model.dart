import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_in_model.freezed.dart';
part 'check_in_model.g.dart';

@freezed
sealed class CheckInStatus with _$CheckInStatus {
  const factory CheckInStatus.pending() = CheckInPending;
  const factory CheckInStatus.checkedIn() = CheckInCheckedIn;
  const factory CheckInStatus.noShow() = CheckInNoShow;

  factory CheckInStatus.fromJson(Map<String, dynamic> json) => _$CheckInStatusFromJson(json);
}

@freezed
class CheckInRecord with _$CheckInRecord {
  const factory CheckInRecord({
    required String id,
    required String gameId,
    required String participantId,
    required String participantName,
    required CheckInStatus status,
    DateTime? checkedInAt,
    String? note,
  }) = _CheckInRecord;

  factory CheckInRecord.fromJson(Map<String, dynamic> json) => _$CheckInRecordFromJson(json);
}
