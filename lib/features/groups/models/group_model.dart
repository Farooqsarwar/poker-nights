import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_model.freezed.dart';
part 'group_model.g.dart';

@freezed
class GroupModel with _$GroupModel {
  const factory GroupModel({
    required String id,
    required String ownerUserId,
    required String name,
    required String joinCode,
    DateTime? codeRotatedAt,
    required DateTime createdAt,
    @Default(0) int memberCount,
  }) = _GroupModel;

  factory GroupModel.fromJson(Map<String, dynamic> json) => _$GroupModelFromJson(json);
}

@freezed
class GroupMembership with _$GroupMembership {
  const factory GroupMembership({
    required String groupId,
    required String userId,
    required String role,
    required String status,
    required DateTime joinedAt,
  }) = _GroupMembership;

  factory GroupMembership.fromJson(Map<String, dynamic> json) => _$GroupMembershipFromJson(json);
}
