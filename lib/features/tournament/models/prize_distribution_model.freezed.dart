// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prize_distribution_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PrizeDistribution _$PrizeDistributionFromJson(Map<String, dynamic> json) {
  return _PrizeDistribution.fromJson(json);
}

/// @nodoc
mixin _$PrizeDistribution {
  int get prizePool => throw _privateConstructorUsedError;
  int get organizerAmount => throw _privateConstructorUsedError;
  int get paidPlaces => throw _privateConstructorUsedError;
  List<PayoutEntry> get payouts => throw _privateConstructorUsedError;

  /// Serializes this PrizeDistribution to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PrizeDistribution
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PrizeDistributionCopyWith<PrizeDistribution> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrizeDistributionCopyWith<$Res> {
  factory $PrizeDistributionCopyWith(
    PrizeDistribution value,
    $Res Function(PrizeDistribution) then,
  ) = _$PrizeDistributionCopyWithImpl<$Res, PrizeDistribution>;
  @useResult
  $Res call({
    int prizePool,
    int organizerAmount,
    int paidPlaces,
    List<PayoutEntry> payouts,
  });
}

/// @nodoc
class _$PrizeDistributionCopyWithImpl<$Res, $Val extends PrizeDistribution>
    implements $PrizeDistributionCopyWith<$Res> {
  _$PrizeDistributionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PrizeDistribution
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? prizePool = null,
    Object? organizerAmount = null,
    Object? paidPlaces = null,
    Object? payouts = null,
  }) {
    return _then(
      _value.copyWith(
            prizePool: null == prizePool
                ? _value.prizePool
                : prizePool // ignore: cast_nullable_to_non_nullable
                      as int,
            organizerAmount: null == organizerAmount
                ? _value.organizerAmount
                : organizerAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            paidPlaces: null == paidPlaces
                ? _value.paidPlaces
                : paidPlaces // ignore: cast_nullable_to_non_nullable
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
abstract class _$$PrizeDistributionImplCopyWith<$Res>
    implements $PrizeDistributionCopyWith<$Res> {
  factory _$$PrizeDistributionImplCopyWith(
    _$PrizeDistributionImpl value,
    $Res Function(_$PrizeDistributionImpl) then,
  ) = __$$PrizeDistributionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int prizePool,
    int organizerAmount,
    int paidPlaces,
    List<PayoutEntry> payouts,
  });
}

/// @nodoc
class __$$PrizeDistributionImplCopyWithImpl<$Res>
    extends _$PrizeDistributionCopyWithImpl<$Res, _$PrizeDistributionImpl>
    implements _$$PrizeDistributionImplCopyWith<$Res> {
  __$$PrizeDistributionImplCopyWithImpl(
    _$PrizeDistributionImpl _value,
    $Res Function(_$PrizeDistributionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PrizeDistribution
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? prizePool = null,
    Object? organizerAmount = null,
    Object? paidPlaces = null,
    Object? payouts = null,
  }) {
    return _then(
      _$PrizeDistributionImpl(
        prizePool: null == prizePool
            ? _value.prizePool
            : prizePool // ignore: cast_nullable_to_non_nullable
                  as int,
        organizerAmount: null == organizerAmount
            ? _value.organizerAmount
            : organizerAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        paidPlaces: null == paidPlaces
            ? _value.paidPlaces
            : paidPlaces // ignore: cast_nullable_to_non_nullable
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
class _$PrizeDistributionImpl implements _PrizeDistribution {
  const _$PrizeDistributionImpl({
    required this.prizePool,
    required this.organizerAmount,
    required this.paidPlaces,
    required final List<PayoutEntry> payouts,
  }) : _payouts = payouts;

  factory _$PrizeDistributionImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrizeDistributionImplFromJson(json);

  @override
  final int prizePool;
  @override
  final int organizerAmount;
  @override
  final int paidPlaces;
  final List<PayoutEntry> _payouts;
  @override
  List<PayoutEntry> get payouts {
    if (_payouts is EqualUnmodifiableListView) return _payouts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_payouts);
  }

  @override
  String toString() {
    return 'PrizeDistribution(prizePool: $prizePool, organizerAmount: $organizerAmount, paidPlaces: $paidPlaces, payouts: $payouts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrizeDistributionImpl &&
            (identical(other.prizePool, prizePool) ||
                other.prizePool == prizePool) &&
            (identical(other.organizerAmount, organizerAmount) ||
                other.organizerAmount == organizerAmount) &&
            (identical(other.paidPlaces, paidPlaces) ||
                other.paidPlaces == paidPlaces) &&
            const DeepCollectionEquality().equals(other._payouts, _payouts));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    prizePool,
    organizerAmount,
    paidPlaces,
    const DeepCollectionEquality().hash(_payouts),
  );

  /// Create a copy of PrizeDistribution
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PrizeDistributionImplCopyWith<_$PrizeDistributionImpl> get copyWith =>
      __$$PrizeDistributionImplCopyWithImpl<_$PrizeDistributionImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PrizeDistributionImplToJson(this);
  }
}

abstract class _PrizeDistribution implements PrizeDistribution {
  const factory _PrizeDistribution({
    required final int prizePool,
    required final int organizerAmount,
    required final int paidPlaces,
    required final List<PayoutEntry> payouts,
  }) = _$PrizeDistributionImpl;

  factory _PrizeDistribution.fromJson(Map<String, dynamic> json) =
      _$PrizeDistributionImpl.fromJson;

  @override
  int get prizePool;
  @override
  int get organizerAmount;
  @override
  int get paidPlaces;
  @override
  List<PayoutEntry> get payouts;

  /// Create a copy of PrizeDistribution
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PrizeDistributionImplCopyWith<_$PrizeDistributionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CashGameSettlement _$CashGameSettlementFromJson(Map<String, dynamic> json) {
  return _CashGameSettlement.fromJson(json);
}

/// @nodoc
mixin _$CashGameSettlement {
  String get sessionId => throw _privateConstructorUsedError;
  List<CashSettlementEntry> get entries => throw _privateConstructorUsedError;
  SettlementStatus get status => throw _privateConstructorUsedError;
  DateTime? get settledAt => throw _privateConstructorUsedError;

  /// Serializes this CashGameSettlement to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CashGameSettlement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CashGameSettlementCopyWith<CashGameSettlement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CashGameSettlementCopyWith<$Res> {
  factory $CashGameSettlementCopyWith(
    CashGameSettlement value,
    $Res Function(CashGameSettlement) then,
  ) = _$CashGameSettlementCopyWithImpl<$Res, CashGameSettlement>;
  @useResult
  $Res call({
    String sessionId,
    List<CashSettlementEntry> entries,
    SettlementStatus status,
    DateTime? settledAt,
  });

  $SettlementStatusCopyWith<$Res> get status;
}

/// @nodoc
class _$CashGameSettlementCopyWithImpl<$Res, $Val extends CashGameSettlement>
    implements $CashGameSettlementCopyWith<$Res> {
  _$CashGameSettlementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CashGameSettlement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? entries = null,
    Object? status = null,
    Object? settledAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            entries: null == entries
                ? _value.entries
                : entries // ignore: cast_nullable_to_non_nullable
                      as List<CashSettlementEntry>,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as SettlementStatus,
            settledAt: freezed == settledAt
                ? _value.settledAt
                : settledAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }

  /// Create a copy of CashGameSettlement
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
abstract class _$$CashGameSettlementImplCopyWith<$Res>
    implements $CashGameSettlementCopyWith<$Res> {
  factory _$$CashGameSettlementImplCopyWith(
    _$CashGameSettlementImpl value,
    $Res Function(_$CashGameSettlementImpl) then,
  ) = __$$CashGameSettlementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String sessionId,
    List<CashSettlementEntry> entries,
    SettlementStatus status,
    DateTime? settledAt,
  });

  @override
  $SettlementStatusCopyWith<$Res> get status;
}

/// @nodoc
class __$$CashGameSettlementImplCopyWithImpl<$Res>
    extends _$CashGameSettlementCopyWithImpl<$Res, _$CashGameSettlementImpl>
    implements _$$CashGameSettlementImplCopyWith<$Res> {
  __$$CashGameSettlementImplCopyWithImpl(
    _$CashGameSettlementImpl _value,
    $Res Function(_$CashGameSettlementImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CashGameSettlement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionId = null,
    Object? entries = null,
    Object? status = null,
    Object? settledAt = freezed,
  }) {
    return _then(
      _$CashGameSettlementImpl(
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        entries: null == entries
            ? _value._entries
            : entries // ignore: cast_nullable_to_non_nullable
                  as List<CashSettlementEntry>,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as SettlementStatus,
        settledAt: freezed == settledAt
            ? _value.settledAt
            : settledAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CashGameSettlementImpl implements _CashGameSettlement {
  const _$CashGameSettlementImpl({
    required this.sessionId,
    required final List<CashSettlementEntry> entries,
    required this.status,
    this.settledAt,
  }) : _entries = entries;

  factory _$CashGameSettlementImpl.fromJson(Map<String, dynamic> json) =>
      _$$CashGameSettlementImplFromJson(json);

  @override
  final String sessionId;
  final List<CashSettlementEntry> _entries;
  @override
  List<CashSettlementEntry> get entries {
    if (_entries is EqualUnmodifiableListView) return _entries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_entries);
  }

  @override
  final SettlementStatus status;
  @override
  final DateTime? settledAt;

  @override
  String toString() {
    return 'CashGameSettlement(sessionId: $sessionId, entries: $entries, status: $status, settledAt: $settledAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CashGameSettlementImpl &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            const DeepCollectionEquality().equals(other._entries, _entries) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.settledAt, settledAt) ||
                other.settledAt == settledAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    sessionId,
    const DeepCollectionEquality().hash(_entries),
    status,
    settledAt,
  );

  /// Create a copy of CashGameSettlement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CashGameSettlementImplCopyWith<_$CashGameSettlementImpl> get copyWith =>
      __$$CashGameSettlementImplCopyWithImpl<_$CashGameSettlementImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CashGameSettlementImplToJson(this);
  }
}

abstract class _CashGameSettlement implements CashGameSettlement {
  const factory _CashGameSettlement({
    required final String sessionId,
    required final List<CashSettlementEntry> entries,
    required final SettlementStatus status,
    final DateTime? settledAt,
  }) = _$CashGameSettlementImpl;

  factory _CashGameSettlement.fromJson(Map<String, dynamic> json) =
      _$CashGameSettlementImpl.fromJson;

  @override
  String get sessionId;
  @override
  List<CashSettlementEntry> get entries;
  @override
  SettlementStatus get status;
  @override
  DateTime? get settledAt;

  /// Create a copy of CashGameSettlement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CashGameSettlementImplCopyWith<_$CashGameSettlementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CashSettlementEntry _$CashSettlementEntryFromJson(Map<String, dynamic> json) {
  return _CashSettlementEntry.fromJson(json);
}

/// @nodoc
mixin _$CashSettlementEntry {
  String get participantId => throw _privateConstructorUsedError;
  String get participantName => throw _privateConstructorUsedError;
  int get buyIn => throw _privateConstructorUsedError;
  int get topUps => throw _privateConstructorUsedError;
  int get cashOut => throw _privateConstructorUsedError;
  int get netResult => throw _privateConstructorUsedError;

  /// Serializes this CashSettlementEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CashSettlementEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CashSettlementEntryCopyWith<CashSettlementEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CashSettlementEntryCopyWith<$Res> {
  factory $CashSettlementEntryCopyWith(
    CashSettlementEntry value,
    $Res Function(CashSettlementEntry) then,
  ) = _$CashSettlementEntryCopyWithImpl<$Res, CashSettlementEntry>;
  @useResult
  $Res call({
    String participantId,
    String participantName,
    int buyIn,
    int topUps,
    int cashOut,
    int netResult,
  });
}

/// @nodoc
class _$CashSettlementEntryCopyWithImpl<$Res, $Val extends CashSettlementEntry>
    implements $CashSettlementEntryCopyWith<$Res> {
  _$CashSettlementEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CashSettlementEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? participantId = null,
    Object? participantName = null,
    Object? buyIn = null,
    Object? topUps = null,
    Object? cashOut = null,
    Object? netResult = null,
  }) {
    return _then(
      _value.copyWith(
            participantId: null == participantId
                ? _value.participantId
                : participantId // ignore: cast_nullable_to_non_nullable
                      as String,
            participantName: null == participantName
                ? _value.participantName
                : participantName // ignore: cast_nullable_to_non_nullable
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
            netResult: null == netResult
                ? _value.netResult
                : netResult // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CashSettlementEntryImplCopyWith<$Res>
    implements $CashSettlementEntryCopyWith<$Res> {
  factory _$$CashSettlementEntryImplCopyWith(
    _$CashSettlementEntryImpl value,
    $Res Function(_$CashSettlementEntryImpl) then,
  ) = __$$CashSettlementEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String participantId,
    String participantName,
    int buyIn,
    int topUps,
    int cashOut,
    int netResult,
  });
}

/// @nodoc
class __$$CashSettlementEntryImplCopyWithImpl<$Res>
    extends _$CashSettlementEntryCopyWithImpl<$Res, _$CashSettlementEntryImpl>
    implements _$$CashSettlementEntryImplCopyWith<$Res> {
  __$$CashSettlementEntryImplCopyWithImpl(
    _$CashSettlementEntryImpl _value,
    $Res Function(_$CashSettlementEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CashSettlementEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? participantId = null,
    Object? participantName = null,
    Object? buyIn = null,
    Object? topUps = null,
    Object? cashOut = null,
    Object? netResult = null,
  }) {
    return _then(
      _$CashSettlementEntryImpl(
        participantId: null == participantId
            ? _value.participantId
            : participantId // ignore: cast_nullable_to_non_nullable
                  as String,
        participantName: null == participantName
            ? _value.participantName
            : participantName // ignore: cast_nullable_to_non_nullable
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
        netResult: null == netResult
            ? _value.netResult
            : netResult // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CashSettlementEntryImpl implements _CashSettlementEntry {
  const _$CashSettlementEntryImpl({
    required this.participantId,
    required this.participantName,
    required this.buyIn,
    required this.topUps,
    required this.cashOut,
    required this.netResult,
  });

  factory _$CashSettlementEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$CashSettlementEntryImplFromJson(json);

  @override
  final String participantId;
  @override
  final String participantName;
  @override
  final int buyIn;
  @override
  final int topUps;
  @override
  final int cashOut;
  @override
  final int netResult;

  @override
  String toString() {
    return 'CashSettlementEntry(participantId: $participantId, participantName: $participantName, buyIn: $buyIn, topUps: $topUps, cashOut: $cashOut, netResult: $netResult)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CashSettlementEntryImpl &&
            (identical(other.participantId, participantId) ||
                other.participantId == participantId) &&
            (identical(other.participantName, participantName) ||
                other.participantName == participantName) &&
            (identical(other.buyIn, buyIn) || other.buyIn == buyIn) &&
            (identical(other.topUps, topUps) || other.topUps == topUps) &&
            (identical(other.cashOut, cashOut) || other.cashOut == cashOut) &&
            (identical(other.netResult, netResult) ||
                other.netResult == netResult));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    participantId,
    participantName,
    buyIn,
    topUps,
    cashOut,
    netResult,
  );

  /// Create a copy of CashSettlementEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CashSettlementEntryImplCopyWith<_$CashSettlementEntryImpl> get copyWith =>
      __$$CashSettlementEntryImplCopyWithImpl<_$CashSettlementEntryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CashSettlementEntryImplToJson(this);
  }
}

abstract class _CashSettlementEntry implements CashSettlementEntry {
  const factory _CashSettlementEntry({
    required final String participantId,
    required final String participantName,
    required final int buyIn,
    required final int topUps,
    required final int cashOut,
    required final int netResult,
  }) = _$CashSettlementEntryImpl;

  factory _CashSettlementEntry.fromJson(Map<String, dynamic> json) =
      _$CashSettlementEntryImpl.fromJson;

  @override
  String get participantId;
  @override
  String get participantName;
  @override
  int get buyIn;
  @override
  int get topUps;
  @override
  int get cashOut;
  @override
  int get netResult;

  /// Create a copy of CashSettlementEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CashSettlementEntryImplCopyWith<_$CashSettlementEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
