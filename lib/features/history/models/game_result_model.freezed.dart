// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_result_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GameResult _$GameResultFromJson(Map<String, dynamic> json) {
  return _GameResult.fromJson(json);
}

/// @nodoc
mixin _$GameResult {
  String get id => throw _privateConstructorUsedError;
  String get gameId => throw _privateConstructorUsedError;
  String get gameName => throw _privateConstructorUsedError;
  DateTime get completedAt => throw _privateConstructorUsedError;
  int get playerCount => throw _privateConstructorUsedError;
  List<FinalPosition> get positions => throw _privateConstructorUsedError;
  Map<String, int> get knockouts => throw _privateConstructorUsedError;
  int get totalPrizePool => throw _privateConstructorUsedError;
  int get organizerAmount => throw _privateConstructorUsedError;
  List<PayoutEntry> get payouts => throw _privateConstructorUsedError;

  /// Serializes this GameResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GameResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameResultCopyWith<GameResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameResultCopyWith<$Res> {
  factory $GameResultCopyWith(
    GameResult value,
    $Res Function(GameResult) then,
  ) = _$GameResultCopyWithImpl<$Res, GameResult>;
  @useResult
  $Res call({
    String id,
    String gameId,
    String gameName,
    DateTime completedAt,
    int playerCount,
    List<FinalPosition> positions,
    Map<String, int> knockouts,
    int totalPrizePool,
    int organizerAmount,
    List<PayoutEntry> payouts,
  });
}

/// @nodoc
class _$GameResultCopyWithImpl<$Res, $Val extends GameResult>
    implements $GameResultCopyWith<$Res> {
  _$GameResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? gameName = null,
    Object? completedAt = null,
    Object? playerCount = null,
    Object? positions = null,
    Object? knockouts = null,
    Object? totalPrizePool = null,
    Object? organizerAmount = null,
    Object? payouts = null,
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
            gameName: null == gameName
                ? _value.gameName
                : gameName // ignore: cast_nullable_to_non_nullable
                      as String,
            completedAt: null == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            playerCount: null == playerCount
                ? _value.playerCount
                : playerCount // ignore: cast_nullable_to_non_nullable
                      as int,
            positions: null == positions
                ? _value.positions
                : positions // ignore: cast_nullable_to_non_nullable
                      as List<FinalPosition>,
            knockouts: null == knockouts
                ? _value.knockouts
                : knockouts // ignore: cast_nullable_to_non_nullable
                      as Map<String, int>,
            totalPrizePool: null == totalPrizePool
                ? _value.totalPrizePool
                : totalPrizePool // ignore: cast_nullable_to_non_nullable
                      as int,
            organizerAmount: null == organizerAmount
                ? _value.organizerAmount
                : organizerAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            payouts: null == payouts
                ? _value.payouts
                : payouts // ignore: cast_nullable_to_non_nullable
                      as List<PayoutEntry>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GameResultImplCopyWith<$Res>
    implements $GameResultCopyWith<$Res> {
  factory _$$GameResultImplCopyWith(
    _$GameResultImpl value,
    $Res Function(_$GameResultImpl) then,
  ) = __$$GameResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String gameId,
    String gameName,
    DateTime completedAt,
    int playerCount,
    List<FinalPosition> positions,
    Map<String, int> knockouts,
    int totalPrizePool,
    int organizerAmount,
    List<PayoutEntry> payouts,
  });
}

/// @nodoc
class __$$GameResultImplCopyWithImpl<$Res>
    extends _$GameResultCopyWithImpl<$Res, _$GameResultImpl>
    implements _$$GameResultImplCopyWith<$Res> {
  __$$GameResultImplCopyWithImpl(
    _$GameResultImpl _value,
    $Res Function(_$GameResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GameResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? gameName = null,
    Object? completedAt = null,
    Object? playerCount = null,
    Object? positions = null,
    Object? knockouts = null,
    Object? totalPrizePool = null,
    Object? organizerAmount = null,
    Object? payouts = null,
  }) {
    return _then(
      _$GameResultImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        gameId: null == gameId
            ? _value.gameId
            : gameId // ignore: cast_nullable_to_non_nullable
                  as String,
        gameName: null == gameName
            ? _value.gameName
            : gameName // ignore: cast_nullable_to_non_nullable
                  as String,
        completedAt: null == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        playerCount: null == playerCount
            ? _value.playerCount
            : playerCount // ignore: cast_nullable_to_non_nullable
                  as int,
        positions: null == positions
            ? _value._positions
            : positions // ignore: cast_nullable_to_non_nullable
                  as List<FinalPosition>,
        knockouts: null == knockouts
            ? _value._knockouts
            : knockouts // ignore: cast_nullable_to_non_nullable
                  as Map<String, int>,
        totalPrizePool: null == totalPrizePool
            ? _value.totalPrizePool
            : totalPrizePool // ignore: cast_nullable_to_non_nullable
                  as int,
        organizerAmount: null == organizerAmount
            ? _value.organizerAmount
            : organizerAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        payouts: null == payouts
            ? _value._payouts
            : payouts // ignore: cast_nullable_to_non_nullable
                  as List<PayoutEntry>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GameResultImpl implements _GameResult {
  const _$GameResultImpl({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.completedAt,
    required this.playerCount,
    required final List<FinalPosition> positions,
    required final Map<String, int> knockouts,
    required this.totalPrizePool,
    this.organizerAmount = 0,
    required final List<PayoutEntry> payouts,
  }) : _positions = positions,
       _knockouts = knockouts,
       _payouts = payouts;

  factory _$GameResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameResultImplFromJson(json);

  @override
  final String id;
  @override
  final String gameId;
  @override
  final String gameName;
  @override
  final DateTime completedAt;
  @override
  final int playerCount;
  final List<FinalPosition> _positions;
  @override
  List<FinalPosition> get positions {
    if (_positions is EqualUnmodifiableListView) return _positions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_positions);
  }

  final Map<String, int> _knockouts;
  @override
  Map<String, int> get knockouts {
    if (_knockouts is EqualUnmodifiableMapView) return _knockouts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_knockouts);
  }

  @override
  final int totalPrizePool;
  @override
  @JsonKey()
  final int organizerAmount;
  final List<PayoutEntry> _payouts;
  @override
  List<PayoutEntry> get payouts {
    if (_payouts is EqualUnmodifiableListView) return _payouts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_payouts);
  }

  @override
  String toString() {
    return 'GameResult(id: $id, gameId: $gameId, gameName: $gameName, completedAt: $completedAt, playerCount: $playerCount, positions: $positions, knockouts: $knockouts, totalPrizePool: $totalPrizePool, organizerAmount: $organizerAmount, payouts: $payouts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.gameName, gameName) ||
                other.gameName == gameName) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.playerCount, playerCount) ||
                other.playerCount == playerCount) &&
            const DeepCollectionEquality().equals(
              other._positions,
              _positions,
            ) &&
            const DeepCollectionEquality().equals(
              other._knockouts,
              _knockouts,
            ) &&
            (identical(other.totalPrizePool, totalPrizePool) ||
                other.totalPrizePool == totalPrizePool) &&
            (identical(other.organizerAmount, organizerAmount) ||
                other.organizerAmount == organizerAmount) &&
            const DeepCollectionEquality().equals(other._payouts, _payouts));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    gameId,
    gameName,
    completedAt,
    playerCount,
    const DeepCollectionEquality().hash(_positions),
    const DeepCollectionEquality().hash(_knockouts),
    totalPrizePool,
    organizerAmount,
    const DeepCollectionEquality().hash(_payouts),
  );

  /// Create a copy of GameResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameResultImplCopyWith<_$GameResultImpl> get copyWith =>
      __$$GameResultImplCopyWithImpl<_$GameResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameResultImplToJson(this);
  }
}

abstract class _GameResult implements GameResult {
  const factory _GameResult({
    required final String id,
    required final String gameId,
    required final String gameName,
    required final DateTime completedAt,
    required final int playerCount,
    required final List<FinalPosition> positions,
    required final Map<String, int> knockouts,
    required final int totalPrizePool,
    final int organizerAmount,
    required final List<PayoutEntry> payouts,
  }) = _$GameResultImpl;

  factory _GameResult.fromJson(Map<String, dynamic> json) =
      _$GameResultImpl.fromJson;

  @override
  String get id;
  @override
  String get gameId;
  @override
  String get gameName;
  @override
  DateTime get completedAt;
  @override
  int get playerCount;
  @override
  List<FinalPosition> get positions;
  @override
  Map<String, int> get knockouts;
  @override
  int get totalPrizePool;
  @override
  int get organizerAmount;
  @override
  List<PayoutEntry> get payouts;

  /// Create a copy of GameResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameResultImplCopyWith<_$GameResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FinalPosition _$FinalPositionFromJson(Map<String, dynamic> json) {
  return _FinalPosition.fromJson(json);
}

/// @nodoc
mixin _$FinalPosition {
  String get playerId => throw _privateConstructorUsedError;
  String get playerName => throw _privateConstructorUsedError;
  int get position => throw _privateConstructorUsedError;

  /// Serializes this FinalPosition to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FinalPosition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FinalPositionCopyWith<FinalPosition> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FinalPositionCopyWith<$Res> {
  factory $FinalPositionCopyWith(
    FinalPosition value,
    $Res Function(FinalPosition) then,
  ) = _$FinalPositionCopyWithImpl<$Res, FinalPosition>;
  @useResult
  $Res call({String playerId, String playerName, int position});
}

/// @nodoc
class _$FinalPositionCopyWithImpl<$Res, $Val extends FinalPosition>
    implements $FinalPositionCopyWith<$Res> {
  _$FinalPositionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FinalPosition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? playerId = null,
    Object? playerName = null,
    Object? position = null,
  }) {
    return _then(
      _value.copyWith(
            playerId: null == playerId
                ? _value.playerId
                : playerId // ignore: cast_nullable_to_non_nullable
                      as String,
            playerName: null == playerName
                ? _value.playerName
                : playerName // ignore: cast_nullable_to_non_nullable
                      as String,
            position: null == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FinalPositionImplCopyWith<$Res>
    implements $FinalPositionCopyWith<$Res> {
  factory _$$FinalPositionImplCopyWith(
    _$FinalPositionImpl value,
    $Res Function(_$FinalPositionImpl) then,
  ) = __$$FinalPositionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String playerId, String playerName, int position});
}

/// @nodoc
class __$$FinalPositionImplCopyWithImpl<$Res>
    extends _$FinalPositionCopyWithImpl<$Res, _$FinalPositionImpl>
    implements _$$FinalPositionImplCopyWith<$Res> {
  __$$FinalPositionImplCopyWithImpl(
    _$FinalPositionImpl _value,
    $Res Function(_$FinalPositionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FinalPosition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? playerId = null,
    Object? playerName = null,
    Object? position = null,
  }) {
    return _then(
      _$FinalPositionImpl(
        playerId: null == playerId
            ? _value.playerId
            : playerId // ignore: cast_nullable_to_non_nullable
                  as String,
        playerName: null == playerName
            ? _value.playerName
            : playerName // ignore: cast_nullable_to_non_nullable
                  as String,
        position: null == position
            ? _value.position
            : position // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FinalPositionImpl implements _FinalPosition {
  const _$FinalPositionImpl({
    required this.playerId,
    required this.playerName,
    required this.position,
  });

  factory _$FinalPositionImpl.fromJson(Map<String, dynamic> json) =>
      _$$FinalPositionImplFromJson(json);

  @override
  final String playerId;
  @override
  final String playerName;
  @override
  final int position;

  @override
  String toString() {
    return 'FinalPosition(playerId: $playerId, playerName: $playerName, position: $position)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinalPositionImpl &&
            (identical(other.playerId, playerId) ||
                other.playerId == playerId) &&
            (identical(other.playerName, playerName) ||
                other.playerName == playerName) &&
            (identical(other.position, position) ||
                other.position == position));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, playerId, playerName, position);

  /// Create a copy of FinalPosition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FinalPositionImplCopyWith<_$FinalPositionImpl> get copyWith =>
      __$$FinalPositionImplCopyWithImpl<_$FinalPositionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FinalPositionImplToJson(this);
  }
}

abstract class _FinalPosition implements FinalPosition {
  const factory _FinalPosition({
    required final String playerId,
    required final String playerName,
    required final int position,
  }) = _$FinalPositionImpl;

  factory _FinalPosition.fromJson(Map<String, dynamic> json) =
      _$FinalPositionImpl.fromJson;

  @override
  String get playerId;
  @override
  String get playerName;
  @override
  int get position;

  /// Create a copy of FinalPosition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FinalPositionImplCopyWith<_$FinalPositionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PayoutEntry _$PayoutEntryFromJson(Map<String, dynamic> json) {
  return _PayoutEntry.fromJson(json);
}

/// @nodoc
mixin _$PayoutEntry {
  int get position => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;

  /// Serializes this PayoutEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PayoutEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PayoutEntryCopyWith<PayoutEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayoutEntryCopyWith<$Res> {
  factory $PayoutEntryCopyWith(
    PayoutEntry value,
    $Res Function(PayoutEntry) then,
  ) = _$PayoutEntryCopyWithImpl<$Res, PayoutEntry>;
  @useResult
  $Res call({int position, int amount});
}

/// @nodoc
class _$PayoutEntryCopyWithImpl<$Res, $Val extends PayoutEntry>
    implements $PayoutEntryCopyWith<$Res> {
  _$PayoutEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PayoutEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? position = null, Object? amount = null}) {
    return _then(
      _value.copyWith(
            position: null == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                      as int,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PayoutEntryImplCopyWith<$Res>
    implements $PayoutEntryCopyWith<$Res> {
  factory _$$PayoutEntryImplCopyWith(
    _$PayoutEntryImpl value,
    $Res Function(_$PayoutEntryImpl) then,
  ) = __$$PayoutEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int position, int amount});
}

/// @nodoc
class __$$PayoutEntryImplCopyWithImpl<$Res>
    extends _$PayoutEntryCopyWithImpl<$Res, _$PayoutEntryImpl>
    implements _$$PayoutEntryImplCopyWith<$Res> {
  __$$PayoutEntryImplCopyWithImpl(
    _$PayoutEntryImpl _value,
    $Res Function(_$PayoutEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayoutEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? position = null, Object? amount = null}) {
    return _then(
      _$PayoutEntryImpl(
        position: null == position
            ? _value.position
            : position // ignore: cast_nullable_to_non_nullable
                  as int,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PayoutEntryImpl implements _PayoutEntry {
  const _$PayoutEntryImpl({required this.position, required this.amount});

  factory _$PayoutEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$PayoutEntryImplFromJson(json);

  @override
  final int position;
  @override
  final int amount;

  @override
  String toString() {
    return 'PayoutEntry(position: $position, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayoutEntryImpl &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, position, amount);

  /// Create a copy of PayoutEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayoutEntryImplCopyWith<_$PayoutEntryImpl> get copyWith =>
      __$$PayoutEntryImplCopyWithImpl<_$PayoutEntryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PayoutEntryImplToJson(this);
  }
}

abstract class _PayoutEntry implements PayoutEntry {
  const factory _PayoutEntry({
    required final int position,
    required final int amount,
  }) = _$PayoutEntryImpl;

  factory _PayoutEntry.fromJson(Map<String, dynamic> json) =
      _$PayoutEntryImpl.fromJson;

  @override
  int get position;
  @override
  int get amount;

  /// Create a copy of PayoutEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayoutEntryImplCopyWith<_$PayoutEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
