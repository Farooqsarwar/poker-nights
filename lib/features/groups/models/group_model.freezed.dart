// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GroupModel _$GroupModelFromJson(Map<String, dynamic> json) {
  return _GroupModel.fromJson(json);
}

/// @nodoc
mixin _$GroupModel {
  String get id => throw _privateConstructorUsedError;
  String get ownerUserId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get joinCode => throw _privateConstructorUsedError;
  DateTime? get codeRotatedAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  int get memberCount => throw _privateConstructorUsedError;

  /// Serializes this GroupModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupModelCopyWith<GroupModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupModelCopyWith<$Res> {
  factory $GroupModelCopyWith(
    GroupModel value,
    $Res Function(GroupModel) then,
  ) = _$GroupModelCopyWithImpl<$Res, GroupModel>;
  @useResult
  $Res call({
    String id,
    String ownerUserId,
    String name,
    String joinCode,
    DateTime? codeRotatedAt,
    DateTime createdAt,
    int memberCount,
  });
}

/// @nodoc
class _$GroupModelCopyWithImpl<$Res, $Val extends GroupModel>
    implements $GroupModelCopyWith<$Res> {
  _$GroupModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerUserId = null,
    Object? name = null,
    Object? joinCode = null,
    Object? codeRotatedAt = freezed,
    Object? createdAt = null,
    Object? memberCount = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerUserId: null == ownerUserId
                ? _value.ownerUserId
                : ownerUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            joinCode: null == joinCode
                ? _value.joinCode
                : joinCode // ignore: cast_nullable_to_non_nullable
                      as String,
            codeRotatedAt: freezed == codeRotatedAt
                ? _value.codeRotatedAt
                : codeRotatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            memberCount: null == memberCount
                ? _value.memberCount
                : memberCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupModelImplCopyWith<$Res>
    implements $GroupModelCopyWith<$Res> {
  factory _$$GroupModelImplCopyWith(
    _$GroupModelImpl value,
    $Res Function(_$GroupModelImpl) then,
  ) = __$$GroupModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String ownerUserId,
    String name,
    String joinCode,
    DateTime? codeRotatedAt,
    DateTime createdAt,
    int memberCount,
  });
}

/// @nodoc
class __$$GroupModelImplCopyWithImpl<$Res>
    extends _$GroupModelCopyWithImpl<$Res, _$GroupModelImpl>
    implements _$$GroupModelImplCopyWith<$Res> {
  __$$GroupModelImplCopyWithImpl(
    _$GroupModelImpl _value,
    $Res Function(_$GroupModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? ownerUserId = null,
    Object? name = null,
    Object? joinCode = null,
    Object? codeRotatedAt = freezed,
    Object? createdAt = null,
    Object? memberCount = null,
  }) {
    return _then(
      _$GroupModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerUserId: null == ownerUserId
            ? _value.ownerUserId
            : ownerUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        joinCode: null == joinCode
            ? _value.joinCode
            : joinCode // ignore: cast_nullable_to_non_nullable
                  as String,
        codeRotatedAt: freezed == codeRotatedAt
            ? _value.codeRotatedAt
            : codeRotatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        memberCount: null == memberCount
            ? _value.memberCount
            : memberCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GroupModelImpl implements _GroupModel {
  const _$GroupModelImpl({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.joinCode,
    this.codeRotatedAt,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory _$GroupModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$GroupModelImplFromJson(json);

  @override
  final String id;
  @override
  final String ownerUserId;
  @override
  final String name;
  @override
  final String joinCode;
  @override
  final DateTime? codeRotatedAt;
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final int memberCount;

  @override
  String toString() {
    return 'GroupModel(id: $id, ownerUserId: $ownerUserId, name: $name, joinCode: $joinCode, codeRotatedAt: $codeRotatedAt, createdAt: $createdAt, memberCount: $memberCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.ownerUserId, ownerUserId) ||
                other.ownerUserId == ownerUserId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.joinCode, joinCode) ||
                other.joinCode == joinCode) &&
            (identical(other.codeRotatedAt, codeRotatedAt) ||
                other.codeRotatedAt == codeRotatedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.memberCount, memberCount) ||
                other.memberCount == memberCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    ownerUserId,
    name,
    joinCode,
    codeRotatedAt,
    createdAt,
    memberCount,
  );

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupModelImplCopyWith<_$GroupModelImpl> get copyWith =>
      __$$GroupModelImplCopyWithImpl<_$GroupModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GroupModelImplToJson(this);
  }
}

abstract class _GroupModel implements GroupModel {
  const factory _GroupModel({
    required final String id,
    required final String ownerUserId,
    required final String name,
    required final String joinCode,
    final DateTime? codeRotatedAt,
    required final DateTime createdAt,
    final int memberCount,
  }) = _$GroupModelImpl;

  factory _GroupModel.fromJson(Map<String, dynamic> json) =
      _$GroupModelImpl.fromJson;

  @override
  String get id;
  @override
  String get ownerUserId;
  @override
  String get name;
  @override
  String get joinCode;
  @override
  DateTime? get codeRotatedAt;
  @override
  DateTime get createdAt;
  @override
  int get memberCount;

  /// Create a copy of GroupModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupModelImplCopyWith<_$GroupModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GroupMembership _$GroupMembershipFromJson(Map<String, dynamic> json) {
  return _GroupMembership.fromJson(json);
}

/// @nodoc
mixin _$GroupMembership {
  String get groupId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime get joinedAt => throw _privateConstructorUsedError;

  /// Serializes this GroupMembership to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GroupMembership
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupMembershipCopyWith<GroupMembership> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupMembershipCopyWith<$Res> {
  factory $GroupMembershipCopyWith(
    GroupMembership value,
    $Res Function(GroupMembership) then,
  ) = _$GroupMembershipCopyWithImpl<$Res, GroupMembership>;
  @useResult
  $Res call({
    String groupId,
    String userId,
    String role,
    String status,
    DateTime joinedAt,
  });
}

/// @nodoc
class _$GroupMembershipCopyWithImpl<$Res, $Val extends GroupMembership>
    implements $GroupMembershipCopyWith<$Res> {
  _$GroupMembershipCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupMembership
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? userId = null,
    Object? role = null,
    Object? status = null,
    Object? joinedAt = null,
  }) {
    return _then(
      _value.copyWith(
            groupId: null == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            joinedAt: null == joinedAt
                ? _value.joinedAt
                : joinedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupMembershipImplCopyWith<$Res>
    implements $GroupMembershipCopyWith<$Res> {
  factory _$$GroupMembershipImplCopyWith(
    _$GroupMembershipImpl value,
    $Res Function(_$GroupMembershipImpl) then,
  ) = __$$GroupMembershipImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String groupId,
    String userId,
    String role,
    String status,
    DateTime joinedAt,
  });
}

/// @nodoc
class __$$GroupMembershipImplCopyWithImpl<$Res>
    extends _$GroupMembershipCopyWithImpl<$Res, _$GroupMembershipImpl>
    implements _$$GroupMembershipImplCopyWith<$Res> {
  __$$GroupMembershipImplCopyWithImpl(
    _$GroupMembershipImpl _value,
    $Res Function(_$GroupMembershipImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupMembership
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? userId = null,
    Object? role = null,
    Object? status = null,
    Object? joinedAt = null,
  }) {
    return _then(
      _$GroupMembershipImpl(
        groupId: null == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        joinedAt: null == joinedAt
            ? _value.joinedAt
            : joinedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GroupMembershipImpl implements _GroupMembership {
  const _$GroupMembershipImpl({
    required this.groupId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  factory _$GroupMembershipImpl.fromJson(Map<String, dynamic> json) =>
      _$$GroupMembershipImplFromJson(json);

  @override
  final String groupId;
  @override
  final String userId;
  @override
  final String role;
  @override
  final String status;
  @override
  final DateTime joinedAt;

  @override
  String toString() {
    return 'GroupMembership(groupId: $groupId, userId: $userId, role: $role, status: $status, joinedAt: $joinedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupMembershipImpl &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, groupId, userId, role, status, joinedAt);

  /// Create a copy of GroupMembership
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupMembershipImplCopyWith<_$GroupMembershipImpl> get copyWith =>
      __$$GroupMembershipImplCopyWithImpl<_$GroupMembershipImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$GroupMembershipImplToJson(this);
  }
}

abstract class _GroupMembership implements GroupMembership {
  const factory _GroupMembership({
    required final String groupId,
    required final String userId,
    required final String role,
    required final String status,
    required final DateTime joinedAt,
  }) = _$GroupMembershipImpl;

  factory _GroupMembership.fromJson(Map<String, dynamic> json) =
      _$GroupMembershipImpl.fromJson;

  @override
  String get groupId;
  @override
  String get userId;
  @override
  String get role;
  @override
  String get status;
  @override
  DateTime get joinedAt;

  /// Create a copy of GroupMembership
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupMembershipImplCopyWith<_$GroupMembershipImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
