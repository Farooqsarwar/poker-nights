// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settlement_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SettlementStatus _$SettlementStatusFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'pending':
      return SettlementPending.fromJson(json);
    case 'confirmed':
      return SettlementConfirmed.fromJson(json);
    case 'disputed':
      return SettlementDisputed.fromJson(json);

    default:
      throw CheckedFromJsonException(
        json,
        'runtimeType',
        'SettlementStatus',
        'Invalid union type "${json['runtimeType']}"!',
      );
  }
}

/// @nodoc
mixin _$SettlementStatus {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function() confirmed,
    required TResult Function() disputed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function()? confirmed,
    TResult? Function()? disputed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function()? confirmed,
    TResult Function()? disputed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SettlementPending value) pending,
    required TResult Function(SettlementConfirmed value) confirmed,
    required TResult Function(SettlementDisputed value) disputed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SettlementPending value)? pending,
    TResult? Function(SettlementConfirmed value)? confirmed,
    TResult? Function(SettlementDisputed value)? disputed,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SettlementPending value)? pending,
    TResult Function(SettlementConfirmed value)? confirmed,
    TResult Function(SettlementDisputed value)? disputed,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Serializes this SettlementStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SettlementStatusCopyWith<$Res> {
  factory $SettlementStatusCopyWith(
    SettlementStatus value,
    $Res Function(SettlementStatus) then,
  ) = _$SettlementStatusCopyWithImpl<$Res, SettlementStatus>;
}

/// @nodoc
class _$SettlementStatusCopyWithImpl<$Res, $Val extends SettlementStatus>
    implements $SettlementStatusCopyWith<$Res> {
  _$SettlementStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SettlementStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$SettlementPendingImplCopyWith<$Res> {
  factory _$$SettlementPendingImplCopyWith(
    _$SettlementPendingImpl value,
    $Res Function(_$SettlementPendingImpl) then,
  ) = __$$SettlementPendingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$SettlementPendingImplCopyWithImpl<$Res>
    extends _$SettlementStatusCopyWithImpl<$Res, _$SettlementPendingImpl>
    implements _$$SettlementPendingImplCopyWith<$Res> {
  __$$SettlementPendingImplCopyWithImpl(
    _$SettlementPendingImpl _value,
    $Res Function(_$SettlementPendingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SettlementStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$SettlementPendingImpl implements SettlementPending {
  const _$SettlementPendingImpl({final String? $type})
    : $type = $type ?? 'pending';

  factory _$SettlementPendingImpl.fromJson(Map<String, dynamic> json) =>
      _$$SettlementPendingImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SettlementStatus.pending()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$SettlementPendingImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function() confirmed,
    required TResult Function() disputed,
  }) {
    return pending();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function()? confirmed,
    TResult? Function()? disputed,
  }) {
    return pending?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function()? confirmed,
    TResult Function()? disputed,
    required TResult orElse(),
  }) {
    if (pending != null) {
      return pending();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SettlementPending value) pending,
    required TResult Function(SettlementConfirmed value) confirmed,
    required TResult Function(SettlementDisputed value) disputed,
  }) {
    return pending(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SettlementPending value)? pending,
    TResult? Function(SettlementConfirmed value)? confirmed,
    TResult? Function(SettlementDisputed value)? disputed,
  }) {
    return pending?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SettlementPending value)? pending,
    TResult Function(SettlementConfirmed value)? confirmed,
    TResult Function(SettlementDisputed value)? disputed,
    required TResult orElse(),
  }) {
    if (pending != null) {
      return pending(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SettlementPendingImplToJson(this);
  }
}

abstract class SettlementPending implements SettlementStatus {
  const factory SettlementPending() = _$SettlementPendingImpl;

  factory SettlementPending.fromJson(Map<String, dynamic> json) =
      _$SettlementPendingImpl.fromJson;
}

/// @nodoc
abstract class _$$SettlementConfirmedImplCopyWith<$Res> {
  factory _$$SettlementConfirmedImplCopyWith(
    _$SettlementConfirmedImpl value,
    $Res Function(_$SettlementConfirmedImpl) then,
  ) = __$$SettlementConfirmedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$SettlementConfirmedImplCopyWithImpl<$Res>
    extends _$SettlementStatusCopyWithImpl<$Res, _$SettlementConfirmedImpl>
    implements _$$SettlementConfirmedImplCopyWith<$Res> {
  __$$SettlementConfirmedImplCopyWithImpl(
    _$SettlementConfirmedImpl _value,
    $Res Function(_$SettlementConfirmedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SettlementStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$SettlementConfirmedImpl implements SettlementConfirmed {
  const _$SettlementConfirmedImpl({final String? $type})
    : $type = $type ?? 'confirmed';

  factory _$SettlementConfirmedImpl.fromJson(Map<String, dynamic> json) =>
      _$$SettlementConfirmedImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SettlementStatus.confirmed()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SettlementConfirmedImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function() confirmed,
    required TResult Function() disputed,
  }) {
    return confirmed();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function()? confirmed,
    TResult? Function()? disputed,
  }) {
    return confirmed?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function()? confirmed,
    TResult Function()? disputed,
    required TResult orElse(),
  }) {
    if (confirmed != null) {
      return confirmed();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SettlementPending value) pending,
    required TResult Function(SettlementConfirmed value) confirmed,
    required TResult Function(SettlementDisputed value) disputed,
  }) {
    return confirmed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SettlementPending value)? pending,
    TResult? Function(SettlementConfirmed value)? confirmed,
    TResult? Function(SettlementDisputed value)? disputed,
  }) {
    return confirmed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SettlementPending value)? pending,
    TResult Function(SettlementConfirmed value)? confirmed,
    TResult Function(SettlementDisputed value)? disputed,
    required TResult orElse(),
  }) {
    if (confirmed != null) {
      return confirmed(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SettlementConfirmedImplToJson(this);
  }
}

abstract class SettlementConfirmed implements SettlementStatus {
  const factory SettlementConfirmed() = _$SettlementConfirmedImpl;

  factory SettlementConfirmed.fromJson(Map<String, dynamic> json) =
      _$SettlementConfirmedImpl.fromJson;
}

/// @nodoc
abstract class _$$SettlementDisputedImplCopyWith<$Res> {
  factory _$$SettlementDisputedImplCopyWith(
    _$SettlementDisputedImpl value,
    $Res Function(_$SettlementDisputedImpl) then,
  ) = __$$SettlementDisputedImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$SettlementDisputedImplCopyWithImpl<$Res>
    extends _$SettlementStatusCopyWithImpl<$Res, _$SettlementDisputedImpl>
    implements _$$SettlementDisputedImplCopyWith<$Res> {
  __$$SettlementDisputedImplCopyWithImpl(
    _$SettlementDisputedImpl _value,
    $Res Function(_$SettlementDisputedImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SettlementStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$SettlementDisputedImpl implements SettlementDisputed {
  const _$SettlementDisputedImpl({final String? $type})
    : $type = $type ?? 'disputed';

  factory _$SettlementDisputedImpl.fromJson(Map<String, dynamic> json) =>
      _$$SettlementDisputedImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SettlementStatus.disputed()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$SettlementDisputedImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function() confirmed,
    required TResult Function() disputed,
  }) {
    return disputed();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function()? confirmed,
    TResult? Function()? disputed,
  }) {
    return disputed?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function()? confirmed,
    TResult Function()? disputed,
    required TResult orElse(),
  }) {
    if (disputed != null) {
      return disputed();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SettlementPending value) pending,
    required TResult Function(SettlementConfirmed value) confirmed,
    required TResult Function(SettlementDisputed value) disputed,
  }) {
    return disputed(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SettlementPending value)? pending,
    TResult? Function(SettlementConfirmed value)? confirmed,
    TResult? Function(SettlementDisputed value)? disputed,
  }) {
    return disputed?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SettlementPending value)? pending,
    TResult Function(SettlementConfirmed value)? confirmed,
    TResult Function(SettlementDisputed value)? disputed,
    required TResult orElse(),
  }) {
    if (disputed != null) {
      return disputed(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SettlementDisputedImplToJson(this);
  }
}

abstract class SettlementDisputed implements SettlementStatus {
  const factory SettlementDisputed() = _$SettlementDisputedImpl;

  factory SettlementDisputed.fromJson(Map<String, dynamic> json) =
      _$SettlementDisputedImpl.fromJson;
}

TournamentSettlement _$TournamentSettlementFromJson(Map<String, dynamic> json) {
  return _TournamentSettlement.fromJson(json);
}

/// @nodoc
mixin _$TournamentSettlement {
  String get gameId => throw _privateConstructorUsedError;
  List<FinalPosition> get finalPositions => throw _privateConstructorUsedError;
  int get prizePool => throw _privateConstructorUsedError;
  int get organizerAmount => throw _privateConstructorUsedError;
  List<PayoutEntry> get payouts => throw _privateConstructorUsedError;
  SettlementStatus get status => throw _privateConstructorUsedError;
  DateTime? get settledAt => throw _privateConstructorUsedError;
  String? get settledBy => throw _privateConstructorUsedError;

  /// Serializes this TournamentSettlement to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TournamentSettlement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TournamentSettlementCopyWith<TournamentSettlement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TournamentSettlementCopyWith<$Res> {
  factory $TournamentSettlementCopyWith(
    TournamentSettlement value,
    $Res Function(TournamentSettlement) then,
  ) = _$TournamentSettlementCopyWithImpl<$Res, TournamentSettlement>;
  @useResult
  $Res call({
    String gameId,
    List<FinalPosition> finalPositions,
    int prizePool,
    int organizerAmount,
    List<PayoutEntry> payouts,
    SettlementStatus status,
    DateTime? settledAt,
    String? settledBy,
  });

  $SettlementStatusCopyWith<$Res> get status;
}

/// @nodoc
class _$TournamentSettlementCopyWithImpl<
  $Res,
  $Val extends TournamentSettlement
>
    implements $TournamentSettlementCopyWith<$Res> {
  _$TournamentSettlementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TournamentSettlement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gameId = null,
    Object? finalPositions = null,
    Object? prizePool = null,
    Object? organizerAmount = null,
    Object? payouts = null,
    Object? status = null,
    Object? settledAt = freezed,
    Object? settledBy = freezed,
  }) {
    return _then(
      _value.copyWith(
            gameId: null == gameId
                ? _value.gameId
                : gameId // ignore: cast_nullable_to_non_nullable
                      as String,
            finalPositions: null == finalPositions
                ? _value.finalPositions
                : finalPositions // ignore: cast_nullable_to_non_nullable
                      as List<FinalPosition>,
            prizePool: null == prizePool
                ? _value.prizePool
                : prizePool // ignore: cast_nullable_to_non_nullable
                      as int,
            organizerAmount: null == organizerAmount
                ? _value.organizerAmount
                : organizerAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            payouts: null == payouts
                ? _value.payouts
                : payouts // ignore: cast_nullable_to_non_nullable
                      as List<PayoutEntry>,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as SettlementStatus,
            settledAt: freezed == settledAt
                ? _value.settledAt
                : settledAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            settledBy: freezed == settledBy
                ? _value.settledBy
                : settledBy // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of TournamentSettlement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SettlementStatusCopyWith<$Res> get status {
    return $SettlementStatusCopyWith<$Res>(_value.status, (value) {
      return _then(_value.copyWith(status: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TournamentSettlementImplCopyWith<$Res>
    implements $TournamentSettlementCopyWith<$Res> {
  factory _$$TournamentSettlementImplCopyWith(
    _$TournamentSettlementImpl value,
    $Res Function(_$TournamentSettlementImpl) then,
  ) = __$$TournamentSettlementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String gameId,
    List<FinalPosition> finalPositions,
    int prizePool,
    int organizerAmount,
    List<PayoutEntry> payouts,
    SettlementStatus status,
    DateTime? settledAt,
    String? settledBy,
  });

  @override
  $SettlementStatusCopyWith<$Res> get status;
}

/// @nodoc
class __$$TournamentSettlementImplCopyWithImpl<$Res>
    extends _$TournamentSettlementCopyWithImpl<$Res, _$TournamentSettlementImpl>
    implements _$$TournamentSettlementImplCopyWith<$Res> {
  __$$TournamentSettlementImplCopyWithImpl(
    _$TournamentSettlementImpl _value,
    $Res Function(_$TournamentSettlementImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TournamentSettlement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gameId = null,
    Object? finalPositions = null,
    Object? prizePool = null,
    Object? organizerAmount = null,
    Object? payouts = null,
    Object? status = null,
    Object? settledAt = freezed,
    Object? settledBy = freezed,
  }) {
    return _then(
      _$TournamentSettlementImpl(
        gameId: null == gameId
            ? _value.gameId
            : gameId // ignore: cast_nullable_to_non_nullable
                  as String,
        finalPositions: null == finalPositions
            ? _value._finalPositions
            : finalPositions // ignore: cast_nullable_to_non_nullable
                  as List<FinalPosition>,
        prizePool: null == prizePool
            ? _value.prizePool
            : prizePool // ignore: cast_nullable_to_non_nullable
                  as int,
        organizerAmount: null == organizerAmount
            ? _value.organizerAmount
            : organizerAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        payouts: null == payouts
            ? _value._payouts
            : payouts // ignore: cast_nullable_to_non_nullable
                  as List<PayoutEntry>,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as SettlementStatus,
        settledAt: freezed == settledAt
            ? _value.settledAt
            : settledAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        settledBy: freezed == settledBy
            ? _value.settledBy
            : settledBy // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TournamentSettlementImpl implements _TournamentSettlement {
  const _$TournamentSettlementImpl({
    required this.gameId,
    required final List<FinalPosition> finalPositions,
    required this.prizePool,
    required this.organizerAmount,
    required final List<PayoutEntry> payouts,
    required this.status,
    this.settledAt,
    this.settledBy,
  }) : _finalPositions = finalPositions,
       _payouts = payouts;

  factory _$TournamentSettlementImpl.fromJson(Map<String, dynamic> json) =>
      _$$TournamentSettlementImplFromJson(json);

  @override
  final String gameId;
  final List<FinalPosition> _finalPositions;
  @override
  List<FinalPosition> get finalPositions {
    if (_finalPositions is EqualUnmodifiableListView) return _finalPositions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_finalPositions);
  }

  @override
  final int prizePool;
  @override
  final int organizerAmount;
  final List<PayoutEntry> _payouts;
  @override
  List<PayoutEntry> get payouts {
    if (_payouts is EqualUnmodifiableListView) return _payouts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_payouts);
  }

  @override
  final SettlementStatus status;
  @override
  final DateTime? settledAt;
  @override
  final String? settledBy;

  @override
  String toString() {
    return 'TournamentSettlement(gameId: $gameId, finalPositions: $finalPositions, prizePool: $prizePool, organizerAmount: $organizerAmount, payouts: $payouts, status: $status, settledAt: $settledAt, settledBy: $settledBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TournamentSettlementImpl &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            const DeepCollectionEquality().equals(
              other._finalPositions,
              _finalPositions,
            ) &&
            (identical(other.prizePool, prizePool) ||
                other.prizePool == prizePool) &&
            (identical(other.organizerAmount, organizerAmount) ||
                other.organizerAmount == organizerAmount) &&
            const DeepCollectionEquality().equals(other._payouts, _payouts) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.settledAt, settledAt) ||
                other.settledAt == settledAt) &&
            (identical(other.settledBy, settledBy) ||
                other.settledBy == settledBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    gameId,
    const DeepCollectionEquality().hash(_finalPositions),
    prizePool,
    organizerAmount,
    const DeepCollectionEquality().hash(_payouts),
    status,
    settledAt,
    settledBy,
  );

  /// Create a copy of TournamentSettlement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TournamentSettlementImplCopyWith<_$TournamentSettlementImpl>
  get copyWith =>
      __$$TournamentSettlementImplCopyWithImpl<_$TournamentSettlementImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TournamentSettlementImplToJson(this);
  }
}

abstract class _TournamentSettlement implements TournamentSettlement {
  const factory _TournamentSettlement({
    required final String gameId,
    required final List<FinalPosition> finalPositions,
    required final int prizePool,
    required final int organizerAmount,
    required final List<PayoutEntry> payouts,
    required final SettlementStatus status,
    final DateTime? settledAt,
    final String? settledBy,
  }) = _$TournamentSettlementImpl;

  factory _TournamentSettlement.fromJson(Map<String, dynamic> json) =
      _$TournamentSettlementImpl.fromJson;

  @override
  String get gameId;
  @override
  List<FinalPosition> get finalPositions;
  @override
  int get prizePool;
  @override
  int get organizerAmount;
  @override
  List<PayoutEntry> get payouts;
  @override
  SettlementStatus get status;
  @override
  DateTime? get settledAt;
  @override
  String? get settledBy;

  /// Create a copy of TournamentSettlement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TournamentSettlementImplCopyWith<_$TournamentSettlementImpl>
  get copyWith => throw _privateConstructorUsedError;
}

FinalPosition _$FinalPositionFromJson(Map<String, dynamic> json) {
  return _FinalPosition.fromJson(json);
}

/// @nodoc
mixin _$FinalPosition {
  int get position => throw _privateConstructorUsedError;
  String get participantId => throw _privateConstructorUsedError;
  String get participantName => throw _privateConstructorUsedError;
  int get payout => throw _privateConstructorUsedError;
  bool get isChop => throw _privateConstructorUsedError;
  int? get chopAmount => throw _privateConstructorUsedError;

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
  $Res call({
    int position,
    String participantId,
    String participantName,
    int payout,
    bool isChop,
    int? chopAmount,
  });
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
    Object? position = null,
    Object? participantId = null,
    Object? participantName = null,
    Object? payout = null,
    Object? isChop = null,
    Object? chopAmount = freezed,
  }) {
    return _then(
      _value.copyWith(
            position: null == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                      as int,
            participantId: null == participantId
                ? _value.participantId
                : participantId // ignore: cast_nullable_to_non_nullable
                      as String,
            participantName: null == participantName
                ? _value.participantName
                : participantName // ignore: cast_nullable_to_non_nullable
                      as String,
            payout: null == payout
                ? _value.payout
                : payout // ignore: cast_nullable_to_non_nullable
                      as int,
            isChop: null == isChop
                ? _value.isChop
                : isChop // ignore: cast_nullable_to_non_nullable
                      as bool,
            chopAmount: freezed == chopAmount
                ? _value.chopAmount
                : chopAmount // ignore: cast_nullable_to_non_nullable
                      as int?,
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
  $Res call({
    int position,
    String participantId,
    String participantName,
    int payout,
    bool isChop,
    int? chopAmount,
  });
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
    Object? position = null,
    Object? participantId = null,
    Object? participantName = null,
    Object? payout = null,
    Object? isChop = null,
    Object? chopAmount = freezed,
  }) {
    return _then(
      _$FinalPositionImpl(
        position: null == position
            ? _value.position
            : position // ignore: cast_nullable_to_non_nullable
                  as int,
        participantId: null == participantId
            ? _value.participantId
            : participantId // ignore: cast_nullable_to_non_nullable
                  as String,
        participantName: null == participantName
            ? _value.participantName
            : participantName // ignore: cast_nullable_to_non_nullable
                  as String,
        payout: null == payout
            ? _value.payout
            : payout // ignore: cast_nullable_to_non_nullable
                  as int,
        isChop: null == isChop
            ? _value.isChop
            : isChop // ignore: cast_nullable_to_non_nullable
                  as bool,
        chopAmount: freezed == chopAmount
            ? _value.chopAmount
            : chopAmount // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FinalPositionImpl implements _FinalPosition {
  const _$FinalPositionImpl({
    required this.position,
    required this.participantId,
    required this.participantName,
    required this.payout,
    this.isChop = false,
    this.chopAmount,
  });

  factory _$FinalPositionImpl.fromJson(Map<String, dynamic> json) =>
      _$$FinalPositionImplFromJson(json);

  @override
  final int position;
  @override
  final String participantId;
  @override
  final String participantName;
  @override
  final int payout;
  @override
  @JsonKey()
  final bool isChop;
  @override
  final int? chopAmount;

  @override
  String toString() {
    return 'FinalPosition(position: $position, participantId: $participantId, participantName: $participantName, payout: $payout, isChop: $isChop, chopAmount: $chopAmount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinalPositionImpl &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.participantId, participantId) ||
                other.participantId == participantId) &&
            (identical(other.participantName, participantName) ||
                other.participantName == participantName) &&
            (identical(other.payout, payout) || other.payout == payout) &&
            (identical(other.isChop, isChop) || other.isChop == isChop) &&
            (identical(other.chopAmount, chopAmount) ||
                other.chopAmount == chopAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    position,
    participantId,
    participantName,
    payout,
    isChop,
    chopAmount,
  );

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
    required final int position,
    required final String participantId,
    required final String participantName,
    required final int payout,
    final bool isChop,
    final int? chopAmount,
  }) = _$FinalPositionImpl;

  factory _FinalPosition.fromJson(Map<String, dynamic> json) =
      _$FinalPositionImpl.fromJson;

  @override
  int get position;
  @override
  String get participantId;
  @override
  String get participantName;
  @override
  int get payout;
  @override
  bool get isChop;
  @override
  int? get chopAmount;

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
