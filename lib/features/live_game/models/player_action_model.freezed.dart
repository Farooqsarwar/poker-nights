// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_action_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GameAction _$GameActionFromJson(Map<String, dynamic> json) {
  return _GameAction.fromJson(json);
}

/// @nodoc
mixin _$GameAction {
  String get id => throw _privateConstructorUsedError;
  String get gameId => throw _privateConstructorUsedError;
  int get sequence => throw _privateConstructorUsedError;
  String get actorUserId => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  Map<String, dynamic> get payload => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String? get reversedByActionId => throw _privateConstructorUsedError;

  /// Serializes this GameAction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GameAction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameActionCopyWith<GameAction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameActionCopyWith<$Res> {
  factory $GameActionCopyWith(
    GameAction value,
    $Res Function(GameAction) then,
  ) = _$GameActionCopyWithImpl<$Res, GameAction>;
  @useResult
  $Res call({
    String id,
    String gameId,
    int sequence,
    String actorUserId,
    String type,
    Map<String, dynamic> payload,
    DateTime createdAt,
    String? reversedByActionId,
  });
}

/// @nodoc
class _$GameActionCopyWithImpl<$Res, $Val extends GameAction>
    implements $GameActionCopyWith<$Res> {
  _$GameActionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameAction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? sequence = null,
    Object? actorUserId = null,
    Object? type = null,
    Object? payload = null,
    Object? createdAt = null,
    Object? reversedByActionId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            gameId: null == gameId
                ? _value.gameId
                : gameId // ignore: cast_nullable_to_non_nullable
                      as String,
            sequence: null == sequence
                ? _value.sequence
                : sequence // ignore: cast_nullable_to_non_nullable
                      as int,
            actorUserId: null == actorUserId
                ? _value.actorUserId
                : actorUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            payload: null == payload
                ? _value.payload
                : payload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            reversedByActionId: freezed == reversedByActionId
                ? _value.reversedByActionId
                : reversedByActionId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GameActionImplCopyWith<$Res>
    implements $GameActionCopyWith<$Res> {
  factory _$$GameActionImplCopyWith(
    _$GameActionImpl value,
    $Res Function(_$GameActionImpl) then,
  ) = __$$GameActionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String gameId,
    int sequence,
    String actorUserId,
    String type,
    Map<String, dynamic> payload,
    DateTime createdAt,
    String? reversedByActionId,
  });
}

/// @nodoc
class __$$GameActionImplCopyWithImpl<$Res>
    extends _$GameActionCopyWithImpl<$Res, _$GameActionImpl>
    implements _$$GameActionImplCopyWith<$Res> {
  __$$GameActionImplCopyWithImpl(
    _$GameActionImpl _value,
    $Res Function(_$GameActionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GameAction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? sequence = null,
    Object? actorUserId = null,
    Object? type = null,
    Object? payload = null,
    Object? createdAt = null,
    Object? reversedByActionId = freezed,
  }) {
    return _then(
      _$GameActionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        gameId: null == gameId
            ? _value.gameId
            : gameId // ignore: cast_nullable_to_non_nullable
                  as String,
        sequence: null == sequence
            ? _value.sequence
            : sequence // ignore: cast_nullable_to_non_nullable
                  as int,
        actorUserId: null == actorUserId
            ? _value.actorUserId
            : actorUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        payload: null == payload
            ? _value._payload
            : payload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        reversedByActionId: freezed == reversedByActionId
            ? _value.reversedByActionId
            : reversedByActionId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GameActionImpl implements _GameAction {
  const _$GameActionImpl({
    required this.id,
    required this.gameId,
    required this.sequence,
    required this.actorUserId,
    required this.type,
    required final Map<String, dynamic> payload,
    required this.createdAt,
    this.reversedByActionId,
  }) : _payload = payload;

  factory _$GameActionImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameActionImplFromJson(json);

  @override
  final String id;
  @override
  final String gameId;
  @override
  final int sequence;
  @override
  final String actorUserId;
  @override
  final String type;
  final Map<String, dynamic> _payload;
  @override
  Map<String, dynamic> get payload {
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_payload);
  }

  @override
  final DateTime createdAt;
  @override
  final String? reversedByActionId;

  @override
  String toString() {
    return 'GameAction(id: $id, gameId: $gameId, sequence: $sequence, actorUserId: $actorUserId, type: $type, payload: $payload, createdAt: $createdAt, reversedByActionId: $reversedByActionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameActionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.sequence, sequence) ||
                other.sequence == sequence) &&
            (identical(other.actorUserId, actorUserId) ||
                other.actorUserId == actorUserId) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._payload, _payload) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.reversedByActionId, reversedByActionId) ||
                other.reversedByActionId == reversedByActionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    gameId,
    sequence,
    actorUserId,
    type,
    const DeepCollectionEquality().hash(_payload),
    createdAt,
    reversedByActionId,
  );

  /// Create a copy of GameAction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameActionImplCopyWith<_$GameActionImpl> get copyWith =>
      __$$GameActionImplCopyWithImpl<_$GameActionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameActionImplToJson(this);
  }
}

abstract class _GameAction implements GameAction {
  const factory _GameAction({
    required final String id,
    required final String gameId,
    required final int sequence,
    required final String actorUserId,
    required final String type,
    required final Map<String, dynamic> payload,
    required final DateTime createdAt,
    final String? reversedByActionId,
  }) = _$GameActionImpl;

  factory _GameAction.fromJson(Map<String, dynamic> json) =
      _$GameActionImpl.fromJson;

  @override
  String get id;
  @override
  String get gameId;
  @override
  int get sequence;
  @override
  String get actorUserId;
  @override
  String get type;
  @override
  Map<String, dynamic> get payload;
  @override
  DateTime get createdAt;
  @override
  String? get reversedByActionId;

  /// Create a copy of GameAction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameActionImplCopyWith<_$GameActionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
