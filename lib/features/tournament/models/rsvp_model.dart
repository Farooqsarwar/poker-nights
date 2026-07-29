import 'package:freezed_annotation/freezed_annotation.dart';

part 'rsvp_model.freezed.dart';
part 'rsvp_model.g.dart';

@freezed
sealed class RsvpStatus with _$RsvpStatus {
  const factory RsvpStatus.going() = RsvpGoing;
  const factory RsvpStatus.notGoing() = RsvpNotGoing;
  const factory RsvpStatus.maybe() = RsvpMaybe;
  const factory RsvpStatus.noResponse() = RsvpNoResponse;

  factory RsvpStatus.fromJson(Map<String, dynamic> json) => _$RsvpStatusFromJson(json);
}

@freezed
class RsvpEntry with _$RsvpEntry {
  const factory RsvpEntry({
    required String id,
    required String gameId,
    required String participantId,
    required String participantName,
    required RsvpStatus status,
    @Default(0) int guestCount,
    DateTime? respondedAt,
    DateTime? updatedAt,
  }) = _RsvpEntry;

  factory RsvpEntry.fromJson(Map<String, dynamic> json) => _$RsvpEntryFromJson(json);
}
