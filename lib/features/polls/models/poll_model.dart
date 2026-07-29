import 'package:freezed_annotation/freezed_annotation.dart';

part 'poll_model.freezed.dart';
part 'poll_model.g.dart';

@freezed
class Poll with _$Poll {
  const factory Poll({
    required String id,
    required String groupId,
    required String question,
    required String createdBy,
    required DateTime createdAt,
    DateTime? closedAt,
    required List<PollOption> options,
    @Default(true) bool isActive,
  }) = _Poll;

  factory Poll.fromJson(Map<String, dynamic> json) => _$PollFromJson(json);
}

@freezed
class PollOption with _$PollOption {
  const factory PollOption({
    required String id,
    required String pollId,
    required String text,
    required int voteCount,
  }) = _PollOption;

  factory PollOption.fromJson(Map<String, dynamic> json) => _$PollOptionFromJson(json);
}
