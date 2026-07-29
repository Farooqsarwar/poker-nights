// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cash_session_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CashSession _$CashSessionFromJson(Map<String, dynamic> json) {
  return _CashSession.fromJson(json);
}

/// @nodoc
mixin _$CashSession {
  String get id => throw _privateConstructorUsedError;
  String get groupId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get smallBlind => throw _privateConstructorUsedError;
  int get bigBlind => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  List<CashPlayer> get players => throw _privateConstructorUsedError;
  int get totalIssued => throw _privateConstructorUsedError;
  int get totalReturned => throw _privateConstructorUsedError;

  /// Serializes this CashSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CashSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CashSessionCopyWith<CashSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CashSessionCopyWith<$Res> {
  factory $CashSessionCopyWith(
    CashSession value,
    $Res Function(CashSession) then,
  ) = _$CashSessionCopyWithImpl<$Res, CashSession>;
  @useResult
  $Res call({
    String id,
    String groupId,
    String name,
    int smallBlind,
    int bigBlind,
    String status,
    DateTime createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    List<CashPlayer> players,
    int totalIssued,
    int totalReturned,
  });
}

/// @nodoc
class _$CashSessionCopyWithImpl<$Res, $Val extends CashSession>
    implements $CashSessionCopyWith<$Res> {
  _$CashSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CashSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? name = null,
    Object? smallBlind = null,
    Object? bigBlind = null,
    Object? status = null,
    Object? createdAt = null,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? players = null,
    Object? totalIssued = null,
    Object? totalReturned = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            groupId: null == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            smallBlind: null == smallBlind
                ? _value.smallBlind
                : smallBlind // ignore: cast_nullable_to_non_nullable
                      as int,
            bigBlind: null == bigBlind
                ? _value.bigBlind
                : bigBlind // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            completedAt: freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            players: null == players
                ? _value.players
                : players // ignore: cast_nullable_to_non_nullable
                      as List<CashPlayer>,
            totalIssued: null == totalIssued
                ? _value.totalIssued
                : totalIssued // ignore: cast_nullable_to_non_nullable
                      as int,
            totalReturned: null == totalReturned
                ? _value.totalReturned
                : totalReturned // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CashSessionImplCopyWith<$Res>
    implements $CashSessionCopyWith<$Res> {
  factory _$$CashSessionImplCopyWith(
    _$CashSessionImpl value,
    $Res Function(_$CashSessionImpl) then,
  ) = __$$CashSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String groupId,
    String name,
    int smallBlind,
    int bigBlind,
    String status,
    DateTime createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    List<CashPlayer> players,
    int totalIssued,
    int totalReturned,
  });
}

/// @nodoc
class __$$CashSessionImplCopyWithImpl<$Res>
    extends _$CashSessionCopyWithImpl<$Res, _$CashSessionImpl>
    implements _$$CashSessionImplCopyWith<$Res> {
  __$$CashSessionImplCopyWithImpl(
    _$CashSessionImpl _value,
    $Res Function(_$CashSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CashSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? name = null,
    Object? smallBlind = null,
    Object? bigBlind = null,
    Object? status = null,
    Object? createdAt = null,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? players = null,
    Object? totalIssued = null,
    Object? totalReturned = null,
  }) {
    return _then(
      _$CashSessionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        groupId: null == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        smallBlind: null == smallBlind
            ? _value.smallBlind
            : smallBlind // ignore: cast_nullable_to_non_nullable
                  as int,
        bigBlind: null == bigBlind
            ? _value.bigBlind
            : bigBlind // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        completedAt: freezed == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        players: null == players
            ? _value._players
            : players // ignore: cast_nullable_to_non_nullable
                  as List<CashPlayer>,
        totalIssued: null == totalIssued
            ? _value.totalIssued
            : totalIssued // ignore: cast_nullable_to_non_nullable
                  as int,
        totalReturned: null == totalReturned
            ? _value.totalReturned
            : totalReturned // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CashSessionImpl implements _CashSession {
  const _$CashSessionImpl({
    required this.id,
    required this.groupId,
    required this.name,
    required this.smallBlind,
    required this.bigBlind,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required final List<CashPlayer> players,
    this.totalIssued = 0,
    this.totalReturned = 0,
  }) : _players = players;

  factory _$CashSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$CashSessionImplFromJson(json);

  @override
  final String id;
  @override
  final String groupId;
  @override
  final String name;
  @override
  final int smallBlind;
  @override
  final int bigBlind;
  @override
  final String status;
  @override
  final DateTime createdAt;
  @override
  final DateTime? startedAt;
  @override
  final DateTime? completedAt;
  final List<CashPlayer> _players;
  @override
  List<CashPlayer> get players {
    if (_players is EqualUnmodifiableListView) return _players;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_players);
  }

  @override
  @JsonKey()
  final int totalIssued;
  @override
  @JsonKey()
  final int totalReturned;

  @override
  String toString() {
    return 'CashSession(id: $id, groupId: $groupId, name: $name, smallBlind: $smallBlind, bigBlind: $bigBlind, status: $status, createdAt: $createdAt, startedAt: $startedAt, completedAt: $completedAt, players: $players, totalIssued: $totalIssued, totalReturned: $totalReturned)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CashSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.smallBlind, smallBlind) ||
                other.smallBlind == smallBlind) &&
            (identical(other.bigBlind, bigBlind) ||
                other.bigBlind == bigBlind) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            const DeepCollectionEquality().equals(other._players, _players) &&
            (identical(other.totalIssued, totalIssued) ||
                other.totalIssued == totalIssued) &&
            (identical(other.totalReturned, totalReturned) ||
                other.totalReturned == totalReturned));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    groupId,
    name,
    smallBlind,
    bigBlind,
    status,
    createdAt,
    startedAt,
    completedAt,
    const DeepCollectionEquality().hash(_players),
    totalIssued,
    totalReturned,
  );

  /// Create a copy of CashSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CashSessionImplCopyWith<_$CashSessionImpl> get copyWith =>
      __$$CashSessionImplCopyWithImpl<_$CashSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CashSessionImplToJson(this);
  }
}

abstract class _CashSession implements CashSession {
  const factory _CashSession({
    required final String id,
    required final String groupId,
    required final String name,
    required final int smallBlind,
    required final int bigBlind,
    required final String status,
    required final DateTime createdAt,
    final DateTime? startedAt,
    final DateTime? completedAt,
    required final List<CashPlayer> players,
    final int totalIssued,
    final int totalReturned,
  }) = _$CashSessionImpl;

  factory _CashSession.fromJson(Map<String, dynamic> json) =
      _$CashSessionImpl.fromJson;

  @override
  String get id;
  @override
  String get groupId;
  @override
  String get name;
  @override
  int get smallBlind;
  @override
  int get bigBlind;
  @override
  String get status;
  @override
  DateTime get createdAt;
  @override
  DateTime? get startedAt;
  @override
  DateTime? get completedAt;
  @override
  List<CashPlayer> get players;
  @override
  int get totalIssued;
  @override
  int get totalReturned;

  /// Create a copy of CashSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CashSessionImplCopyWith<_$CashSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CashPlayer _$CashPlayerFromJson(Map<String, dynamic> json) {
  return _CashPlayer.fromJson(json);
}

/// @nodoc
mixin _$CashPlayer {
  String get participantId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get buyIn => throw _privateConstructorUsedError;
  int get topUps => throw _privateConstructorUsedError;
  int get cashOut => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;

  /// Serializes this CashPlayer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CashPlayer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CashPlayerCopyWith<CashPlayer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CashPlayerCopyWith<$Res> {
  factory $CashPlayerCopyWith(
    CashPlayer value,
    $Res Function(CashPlayer) then,
  ) = _$CashPlayerCopyWithImpl<$Res, CashPlayer>;
  @useResult
  $Res call({
    String participantId,
    String name,
    int buyIn,
    int topUps,
    int cashOut,
    String status,
  });
}

/// @nodoc
class _$CashPlayerCopyWithImpl<$Res, $Val extends CashPlayer>
    implements $CashPlayerCopyWith<$Res> {
  _$CashPlayerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CashPlayer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? participantId = null,
    Object? name = null,
    Object? buyIn = null,
    Object? topUps = null,
    Object? cashOut = null,
    Object? status = null,
  }) {
    return _then(
      _value.copyWith(
            participantId: null == participantId
                ? _value.participantId
                : participantId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            buyIn: null == buyIn
                ? _value.buyIn
                : buyIn // ignore: cast_nullable_to_non_nullable
                      as int,
            topUps: null == topUps
                ? _value.topUps
                : topUps // ignore: cast_nullable_to_non_nullable
                      as int,
            cashOut: null == cashOut
                ? _value.cashOut
                : cashOut // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CashPlayerImplCopyWith<$Res>
    implements $CashPlayerCopyWith<$Res> {
  factory _$$CashPlayerImplCopyWith(
    _$CashPlayerImpl value,
    $Res Function(_$CashPlayerImpl) then,
  ) = __$$CashPlayerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String participantId,
    String name,
    int buyIn,
    int topUps,
    int cashOut,
    String status,
  });
}

/// @nodoc
class __$$CashPlayerImplCopyWithImpl<$Res>
    extends _$CashPlayerCopyWithImpl<$Res, _$CashPlayerImpl>
    implements _$$CashPlayerImplCopyWith<$Res> {
  __$$CashPlayerImplCopyWithImpl(
    _$CashPlayerImpl _value,
    $Res Function(_$CashPlayerImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CashPlayer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? participantId = null,
    Object? name = null,
    Object? buyIn = null,
    Object? topUps = null,
    Object? cashOut = null,
    Object? status = null,
  }) {
    return _then(
      _$CashPlayerImpl(
        participantId: null == participantId
            ? _value.participantId
            : participantId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        buyIn: null == buyIn
            ? _value.buyIn
            : buyIn // ignore: cast_nullable_to_non_nullable
                  as int,
        topUps: null == topUps
            ? _value.topUps
            : topUps // ignore: cast_nullable_to_non_nullable
                  as int,
        cashOut: null == cashOut
            ? _value.cashOut
            : cashOut // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CashPlayerImpl implements _CashPlayer {
  const _$CashPlayerImpl({
    required this.participantId,
    required this.name,
    required this.buyIn,
    required this.topUps,
    required this.cashOut,
    this.status = 'active',
  });

  factory _$CashPlayerImpl.fromJson(Map<String, dynamic> json) =>
      _$$CashPlayerImplFromJson(json);

  @override
  final String participantId;
  @override
  final String name;
  @override
  final int buyIn;
  @override
  final int topUps;
  @override
  final int cashOut;
  @override
  @JsonKey()
  final String status;

  @override
  String toString() {
    return 'CashPlayer(participantId: $participantId, name: $name, buyIn: $buyIn, topUps: $topUps, cashOut: $cashOut, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CashPlayerImpl &&
            (identical(other.participantId, participantId) ||
                other.participantId == participantId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.buyIn, buyIn) || other.buyIn == buyIn) &&
            (identical(other.topUps, topUps) || other.topUps == topUps) &&
            (identical(other.cashOut, cashOut) || other.cashOut == cashOut) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    participantId,
    name,
    buyIn,
    topUps,
    cashOut,
    status,
  );

  /// Create a copy of CashPlayer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CashPlayerImplCopyWith<_$CashPlayerImpl> get copyWith =>
      __$$CashPlayerImplCopyWithImpl<_$CashPlayerImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CashPlayerImplToJson(this);
  }
}

abstract class _CashPlayer implements CashPlayer {
  const factory _CashPlayer({
    required final String participantId,
    required final String name,
    required final int buyIn,
    required final int topUps,
    required final int cashOut,
    final String status,
  }) = _$CashPlayerImpl;

  factory _CashPlayer.fromJson(Map<String, dynamic> json) =
      _$CashPlayerImpl.fromJson;

  @override
  String get participantId;
  @override
  String get name;
  @override
  int get buyIn;
  @override
  int get topUps;
  @override
  int get cashOut;
  @override
  String get status;

  /// Create a copy of CashPlayer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CashPlayerImplCopyWith<_$CashPlayerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
