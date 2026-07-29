// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rsvp_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RsvpStatus _$RsvpStatusFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'going':
      return RsvpGoing.fromJson(json);
    case 'notGoing':
      return RsvpNotGoing.fromJson(json);
    case 'maybe':
      return RsvpMaybe.fromJson(json);
    case 'noResponse':
      return RsvpNoResponse.fromJson(json);

    default:
      throw CheckedFromJsonException(
        json,
        'runtimeType',
        'RsvpStatus',
        'Invalid union type "${json['runtimeType']}"!',
      );
  }
}

/// @nodoc
mixin _$RsvpStatus {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() going,
    required TResult Function() notGoing,
    required TResult Function() maybe,
    required TResult Function() noResponse,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? going,
    TResult? Function()? notGoing,
    TResult? Function()? maybe,
    TResult? Function()? noResponse,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? going,
    TResult Function()? notGoing,
    TResult Function()? maybe,
    TResult Function()? noResponse,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RsvpGoing value) going,
    required TResult Function(RsvpNotGoing value) notGoing,
    required TResult Function(RsvpMaybe value) maybe,
    required TResult Function(RsvpNoResponse value) noResponse,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RsvpGoing value)? going,
    TResult? Function(RsvpNotGoing value)? notGoing,
    TResult? Function(RsvpMaybe value)? maybe,
    TResult? Function(RsvpNoResponse value)? noResponse,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RsvpGoing value)? going,
    TResult Function(RsvpNotGoing value)? notGoing,
    TResult Function(RsvpMaybe value)? maybe,
    TResult Function(RsvpNoResponse value)? noResponse,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Serializes this RsvpStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RsvpStatusCopyWith<$Res> {
  factory $RsvpStatusCopyWith(
    RsvpStatus value,
    $Res Function(RsvpStatus) then,
  ) = _$RsvpStatusCopyWithImpl<$Res, RsvpStatus>;
}

/// @nodoc
class _$RsvpStatusCopyWithImpl<$Res, $Val extends RsvpStatus>
    implements $RsvpStatusCopyWith<$Res> {
  _$RsvpStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RsvpStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$RsvpGoingImplCopyWith<$Res> {
  factory _$$RsvpGoingImplCopyWith(
    _$RsvpGoingImpl value,
    $Res Function(_$RsvpGoingImpl) then,
  ) = __$$RsvpGoingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$RsvpGoingImplCopyWithImpl<$Res>
    extends _$RsvpStatusCopyWithImpl<$Res, _$RsvpGoingImpl>
    implements _$$RsvpGoingImplCopyWith<$Res> {
  __$$RsvpGoingImplCopyWithImpl(
    _$RsvpGoingImpl _value,
    $Res Function(_$RsvpGoingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RsvpStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$RsvpGoingImpl implements RsvpGoing {
  const _$RsvpGoingImpl({final String? $type}) : $type = $type ?? 'going';

  factory _$RsvpGoingImpl.fromJson(Map<String, dynamic> json) =>
      _$$RsvpGoingImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'RsvpStatus.going()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$RsvpGoingImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() going,
    required TResult Function() notGoing,
    required TResult Function() maybe,
    required TResult Function() noResponse,
  }) {
    return going();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? going,
    TResult? Function()? notGoing,
    TResult? Function()? maybe,
    TResult? Function()? noResponse,
  }) {
    return going?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? going,
    TResult Function()? notGoing,
    TResult Function()? maybe,
    TResult Function()? noResponse,
    required TResult orElse(),
  }) {
    if (going != null) {
      return going();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RsvpGoing value) going,
    required TResult Function(RsvpNotGoing value) notGoing,
    required TResult Function(RsvpMaybe value) maybe,
    required TResult Function(RsvpNoResponse value) noResponse,
  }) {
    return going(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RsvpGoing value)? going,
    TResult? Function(RsvpNotGoing value)? notGoing,
    TResult? Function(RsvpMaybe value)? maybe,
    TResult? Function(RsvpNoResponse value)? noResponse,
  }) {
    return going?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RsvpGoing value)? going,
    TResult Function(RsvpNotGoing value)? notGoing,
    TResult Function(RsvpMaybe value)? maybe,
    TResult Function(RsvpNoResponse value)? noResponse,
    required TResult orElse(),
  }) {
    if (going != null) {
      return going(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$RsvpGoingImplToJson(this);
  }
}

abstract class RsvpGoing implements RsvpStatus {
  const factory RsvpGoing() = _$RsvpGoingImpl;

  factory RsvpGoing.fromJson(Map<String, dynamic> json) =
      _$RsvpGoingImpl.fromJson;
}

/// @nodoc
abstract class _$$RsvpNotGoingImplCopyWith<$Res> {
  factory _$$RsvpNotGoingImplCopyWith(
    _$RsvpNotGoingImpl value,
    $Res Function(_$RsvpNotGoingImpl) then,
  ) = __$$RsvpNotGoingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$RsvpNotGoingImplCopyWithImpl<$Res>
    extends _$RsvpStatusCopyWithImpl<$Res, _$RsvpNotGoingImpl>
    implements _$$RsvpNotGoingImplCopyWith<$Res> {
  __$$RsvpNotGoingImplCopyWithImpl(
    _$RsvpNotGoingImpl _value,
    $Res Function(_$RsvpNotGoingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RsvpStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$RsvpNotGoingImpl implements RsvpNotGoing {
  const _$RsvpNotGoingImpl({final String? $type}) : $type = $type ?? 'notGoing';

  factory _$RsvpNotGoingImpl.fromJson(Map<String, dynamic> json) =>
      _$$RsvpNotGoingImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'RsvpStatus.notGoing()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$RsvpNotGoingImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() going,
    required TResult Function() notGoing,
    required TResult Function() maybe,
    required TResult Function() noResponse,
  }) {
    return notGoing();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? going,
    TResult? Function()? notGoing,
    TResult? Function()? maybe,
    TResult? Function()? noResponse,
  }) {
    return notGoing?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? going,
    TResult Function()? notGoing,
    TResult Function()? maybe,
    TResult Function()? noResponse,
    required TResult orElse(),
  }) {
    if (notGoing != null) {
      return notGoing();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RsvpGoing value) going,
    required TResult Function(RsvpNotGoing value) notGoing,
    required TResult Function(RsvpMaybe value) maybe,
    required TResult Function(RsvpNoResponse value) noResponse,
  }) {
    return notGoing(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RsvpGoing value)? going,
    TResult? Function(RsvpNotGoing value)? notGoing,
    TResult? Function(RsvpMaybe value)? maybe,
    TResult? Function(RsvpNoResponse value)? noResponse,
  }) {
    return notGoing?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RsvpGoing value)? going,
    TResult Function(RsvpNotGoing value)? notGoing,
    TResult Function(RsvpMaybe value)? maybe,
    TResult Function(RsvpNoResponse value)? noResponse,
    required TResult orElse(),
  }) {
    if (notGoing != null) {
      return notGoing(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$RsvpNotGoingImplToJson(this);
  }
}

abstract class RsvpNotGoing implements RsvpStatus {
  const factory RsvpNotGoing() = _$RsvpNotGoingImpl;

  factory RsvpNotGoing.fromJson(Map<String, dynamic> json) =
      _$RsvpNotGoingImpl.fromJson;
}

/// @nodoc
abstract class _$$RsvpMaybeImplCopyWith<$Res> {
  factory _$$RsvpMaybeImplCopyWith(
    _$RsvpMaybeImpl value,
    $Res Function(_$RsvpMaybeImpl) then,
  ) = __$$RsvpMaybeImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$RsvpMaybeImplCopyWithImpl<$Res>
    extends _$RsvpStatusCopyWithImpl<$Res, _$RsvpMaybeImpl>
    implements _$$RsvpMaybeImplCopyWith<$Res> {
  __$$RsvpMaybeImplCopyWithImpl(
    _$RsvpMaybeImpl _value,
    $Res Function(_$RsvpMaybeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RsvpStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$RsvpMaybeImpl implements RsvpMaybe {
  const _$RsvpMaybeImpl({final String? $type}) : $type = $type ?? 'maybe';

  factory _$RsvpMaybeImpl.fromJson(Map<String, dynamic> json) =>
      _$$RsvpMaybeImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'RsvpStatus.maybe()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$RsvpMaybeImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() going,
    required TResult Function() notGoing,
    required TResult Function() maybe,
    required TResult Function() noResponse,
  }) {
    return maybe();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? going,
    TResult? Function()? notGoing,
    TResult? Function()? maybe,
    TResult? Function()? noResponse,
  }) {
    return maybe?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? going,
    TResult Function()? notGoing,
    TResult Function()? maybe,
    TResult Function()? noResponse,
    required TResult orElse(),
  }) {
    if (maybe != null) {
      return maybe();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RsvpGoing value) going,
    required TResult Function(RsvpNotGoing value) notGoing,
    required TResult Function(RsvpMaybe value) maybe,
    required TResult Function(RsvpNoResponse value) noResponse,
  }) {
    return maybe(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RsvpGoing value)? going,
    TResult? Function(RsvpNotGoing value)? notGoing,
    TResult? Function(RsvpMaybe value)? maybe,
    TResult? Function(RsvpNoResponse value)? noResponse,
  }) {
    return maybe?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RsvpGoing value)? going,
    TResult Function(RsvpNotGoing value)? notGoing,
    TResult Function(RsvpMaybe value)? maybe,
    TResult Function(RsvpNoResponse value)? noResponse,
    required TResult orElse(),
  }) {
    if (maybe != null) {
      return maybe(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$RsvpMaybeImplToJson(this);
  }
}

abstract class RsvpMaybe implements RsvpStatus {
  const factory RsvpMaybe() = _$RsvpMaybeImpl;

  factory RsvpMaybe.fromJson(Map<String, dynamic> json) =
      _$RsvpMaybeImpl.fromJson;
}

/// @nodoc
abstract class _$$RsvpNoResponseImplCopyWith<$Res> {
  factory _$$RsvpNoResponseImplCopyWith(
    _$RsvpNoResponseImpl value,
    $Res Function(_$RsvpNoResponseImpl) then,
  ) = __$$RsvpNoResponseImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$RsvpNoResponseImplCopyWithImpl<$Res>
    extends _$RsvpStatusCopyWithImpl<$Res, _$RsvpNoResponseImpl>
    implements _$$RsvpNoResponseImplCopyWith<$Res> {
  __$$RsvpNoResponseImplCopyWithImpl(
    _$RsvpNoResponseImpl _value,
    $Res Function(_$RsvpNoResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RsvpStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$RsvpNoResponseImpl implements RsvpNoResponse {
  const _$RsvpNoResponseImpl({final String? $type})
    : $type = $type ?? 'noResponse';

  factory _$RsvpNoResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$RsvpNoResponseImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'RsvpStatus.noResponse()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$RsvpNoResponseImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() going,
    required TResult Function() notGoing,
    required TResult Function() maybe,
    required TResult Function() noResponse,
  }) {
    return noResponse();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? going,
    TResult? Function()? notGoing,
    TResult? Function()? maybe,
    TResult? Function()? noResponse,
  }) {
    return noResponse?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? going,
    TResult Function()? notGoing,
    TResult Function()? maybe,
    TResult Function()? noResponse,
    required TResult orElse(),
  }) {
    if (noResponse != null) {
      return noResponse();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(RsvpGoing value) going,
    required TResult Function(RsvpNotGoing value) notGoing,
    required TResult Function(RsvpMaybe value) maybe,
    required TResult Function(RsvpNoResponse value) noResponse,
  }) {
    return noResponse(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(RsvpGoing value)? going,
    TResult? Function(RsvpNotGoing value)? notGoing,
    TResult? Function(RsvpMaybe value)? maybe,
    TResult? Function(RsvpNoResponse value)? noResponse,
  }) {
    return noResponse?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(RsvpGoing value)? going,
    TResult Function(RsvpNotGoing value)? notGoing,
    TResult Function(RsvpMaybe value)? maybe,
    TResult Function(RsvpNoResponse value)? noResponse,
    required TResult orElse(),
  }) {
    if (noResponse != null) {
      return noResponse(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$RsvpNoResponseImplToJson(this);
  }
}

abstract class RsvpNoResponse implements RsvpStatus {
  const factory RsvpNoResponse() = _$RsvpNoResponseImpl;

  factory RsvpNoResponse.fromJson(Map<String, dynamic> json) =
      _$RsvpNoResponseImpl.fromJson;
}

RsvpEntry _$RsvpEntryFromJson(Map<String, dynamic> json) {
  return _RsvpEntry.fromJson(json);
}

/// @nodoc
mixin _$RsvpEntry {
  String get id => throw _privateConstructorUsedError;
  String get gameId => throw _privateConstructorUsedError;
  String get participantId => throw _privateConstructorUsedError;
  String get participantName => throw _privateConstructorUsedError;
  RsvpStatus get status => throw _privateConstructorUsedError;
  int get guestCount => throw _privateConstructorUsedError;
  DateTime? get respondedAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this RsvpEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RsvpEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RsvpEntryCopyWith<RsvpEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RsvpEntryCopyWith<$Res> {
  factory $RsvpEntryCopyWith(RsvpEntry value, $Res Function(RsvpEntry) then) =
      _$RsvpEntryCopyWithImpl<$Res, RsvpEntry>;
  @useResult
  $Res call({
    String id,
    String gameId,
    String participantId,
    String participantName,
    RsvpStatus status,
    int guestCount,
    DateTime? respondedAt,
    DateTime? updatedAt,
  });

  $RsvpStatusCopyWith<$Res> get status;
}

/// @nodoc
class _$RsvpEntryCopyWithImpl<$Res, $Val extends RsvpEntry>
    implements $RsvpEntryCopyWith<$Res> {
  _$RsvpEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RsvpEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? participantId = null,
    Object? participantName = null,
    Object? status = null,
    Object? guestCount = null,
    Object? respondedAt = freezed,
    Object? updatedAt = freezed,
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
            participantId: null == participantId
                ? _value.participantId
                : participantId // ignore: cast_nullable_to_non_nullable
                      as String,
            participantName: null == participantName
                ? _value.participantName
                : participantName // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as RsvpStatus,
            guestCount: null == guestCount
                ? _value.guestCount
                : guestCount // ignore: cast_nullable_to_non_nullable
                      as int,
            respondedAt: freezed == respondedAt
                ? _value.respondedAt
                : respondedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }

  /// Create a copy of RsvpEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RsvpStatusCopyWith<$Res> get status {
    return $RsvpStatusCopyWith<$Res>(_value.status, (value) {
      return _then(_value.copyWith(status: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RsvpEntryImplCopyWith<$Res>
    implements $RsvpEntryCopyWith<$Res> {
  factory _$$RsvpEntryImplCopyWith(
    _$RsvpEntryImpl value,
    $Res Function(_$RsvpEntryImpl) then,
  ) = __$$RsvpEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String gameId,
    String participantId,
    String participantName,
    RsvpStatus status,
    int guestCount,
    DateTime? respondedAt,
    DateTime? updatedAt,
  });

  @override
  $RsvpStatusCopyWith<$Res> get status;
}

/// @nodoc
class __$$RsvpEntryImplCopyWithImpl<$Res>
    extends _$RsvpEntryCopyWithImpl<$Res, _$RsvpEntryImpl>
    implements _$$RsvpEntryImplCopyWith<$Res> {
  __$$RsvpEntryImplCopyWithImpl(
    _$RsvpEntryImpl _value,
    $Res Function(_$RsvpEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RsvpEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? participantId = null,
    Object? participantName = null,
    Object? status = null,
    Object? guestCount = null,
    Object? respondedAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$RsvpEntryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        gameId: null == gameId
            ? _value.gameId
            : gameId // ignore: cast_nullable_to_non_nullable
                  as String,
        participantId: null == participantId
            ? _value.participantId
            : participantId // ignore: cast_nullable_to_non_nullable
                  as String,
        participantName: null == participantName
            ? _value.participantName
            : participantName // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as RsvpStatus,
        guestCount: null == guestCount
            ? _value.guestCount
            : guestCount // ignore: cast_nullable_to_non_nullable
                  as int,
        respondedAt: freezed == respondedAt
            ? _value.respondedAt
            : respondedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RsvpEntryImpl implements _RsvpEntry {
  const _$RsvpEntryImpl({
    required this.id,
    required this.gameId,
    required this.participantId,
    required this.participantName,
    required this.status,
    this.guestCount = 0,
    this.respondedAt,
    this.updatedAt,
  });

  factory _$RsvpEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$RsvpEntryImplFromJson(json);

  @override
  final String id;
  @override
  final String gameId;
  @override
  final String participantId;
  @override
  final String participantName;
  @override
  final RsvpStatus status;
  @override
  @JsonKey()
  final int guestCount;
  @override
  final DateTime? respondedAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'RsvpEntry(id: $id, gameId: $gameId, participantId: $participantId, participantName: $participantName, status: $status, guestCount: $guestCount, respondedAt: $respondedAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RsvpEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.participantId, participantId) ||
                other.participantId == participantId) &&
            (identical(other.participantName, participantName) ||
                other.participantName == participantName) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.guestCount, guestCount) ||
                other.guestCount == guestCount) &&
            (identical(other.respondedAt, respondedAt) ||
                other.respondedAt == respondedAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    gameId,
    participantId,
    participantName,
    status,
    guestCount,
    respondedAt,
    updatedAt,
  );

  /// Create a copy of RsvpEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RsvpEntryImplCopyWith<_$RsvpEntryImpl> get copyWith =>
      __$$RsvpEntryImplCopyWithImpl<_$RsvpEntryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RsvpEntryImplToJson(this);
  }
}

abstract class _RsvpEntry implements RsvpEntry {
  const factory _RsvpEntry({
    required final String id,
    required final String gameId,
    required final String participantId,
    required final String participantName,
    required final RsvpStatus status,
    final int guestCount,
    final DateTime? respondedAt,
    final DateTime? updatedAt,
  }) = _$RsvpEntryImpl;

  factory _RsvpEntry.fromJson(Map<String, dynamic> json) =
      _$RsvpEntryImpl.fromJson;

  @override
  String get id;
  @override
  String get gameId;
  @override
  String get participantId;
  @override
  String get participantName;
  @override
  RsvpStatus get status;
  @override
  int get guestCount;
  @override
  DateTime? get respondedAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of RsvpEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RsvpEntryImplCopyWith<_$RsvpEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
