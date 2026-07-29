// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'check_in_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CheckInStatus _$CheckInStatusFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'pending':
      return CheckInPending.fromJson(json);
    case 'checkedIn':
      return CheckInCheckedIn.fromJson(json);
    case 'noShow':
      return CheckInNoShow.fromJson(json);

    default:
      throw CheckedFromJsonException(
        json,
        'runtimeType',
        'CheckInStatus',
        'Invalid union type "${json['runtimeType']}"!',
      );
  }
}

/// @nodoc
mixin _$CheckInStatus {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function() checkedIn,
    required TResult Function() noShow,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function()? checkedIn,
    TResult? Function()? noShow,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function()? checkedIn,
    TResult Function()? noShow,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckInPending value) pending,
    required TResult Function(CheckInCheckedIn value) checkedIn,
    required TResult Function(CheckInNoShow value) noShow,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckInPending value)? pending,
    TResult? Function(CheckInCheckedIn value)? checkedIn,
    TResult? Function(CheckInNoShow value)? noShow,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckInPending value)? pending,
    TResult Function(CheckInCheckedIn value)? checkedIn,
    TResult Function(CheckInNoShow value)? noShow,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Serializes this CheckInStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckInStatusCopyWith<$Res> {
  factory $CheckInStatusCopyWith(
    CheckInStatus value,
    $Res Function(CheckInStatus) then,
  ) = _$CheckInStatusCopyWithImpl<$Res, CheckInStatus>;
}

/// @nodoc
class _$CheckInStatusCopyWithImpl<$Res, $Val extends CheckInStatus>
    implements $CheckInStatusCopyWith<$Res> {
  _$CheckInStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckInStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$CheckInPendingImplCopyWith<$Res> {
  factory _$$CheckInPendingImplCopyWith(
    _$CheckInPendingImpl value,
    $Res Function(_$CheckInPendingImpl) then,
  ) = __$$CheckInPendingImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$CheckInPendingImplCopyWithImpl<$Res>
    extends _$CheckInStatusCopyWithImpl<$Res, _$CheckInPendingImpl>
    implements _$$CheckInPendingImplCopyWith<$Res> {
  __$$CheckInPendingImplCopyWithImpl(
    _$CheckInPendingImpl _value,
    $Res Function(_$CheckInPendingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckInStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$CheckInPendingImpl implements CheckInPending {
  const _$CheckInPendingImpl({final String? $type})
    : $type = $type ?? 'pending';

  factory _$CheckInPendingImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckInPendingImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'CheckInStatus.pending()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$CheckInPendingImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function() checkedIn,
    required TResult Function() noShow,
  }) {
    return pending();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function()? checkedIn,
    TResult? Function()? noShow,
  }) {
    return pending?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function()? checkedIn,
    TResult Function()? noShow,
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
    required TResult Function(CheckInPending value) pending,
    required TResult Function(CheckInCheckedIn value) checkedIn,
    required TResult Function(CheckInNoShow value) noShow,
  }) {
    return pending(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckInPending value)? pending,
    TResult? Function(CheckInCheckedIn value)? checkedIn,
    TResult? Function(CheckInNoShow value)? noShow,
  }) {
    return pending?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckInPending value)? pending,
    TResult Function(CheckInCheckedIn value)? checkedIn,
    TResult Function(CheckInNoShow value)? noShow,
    required TResult orElse(),
  }) {
    if (pending != null) {
      return pending(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckInPendingImplToJson(this);
  }
}

abstract class CheckInPending implements CheckInStatus {
  const factory CheckInPending() = _$CheckInPendingImpl;

  factory CheckInPending.fromJson(Map<String, dynamic> json) =
      _$CheckInPendingImpl.fromJson;
}

/// @nodoc
abstract class _$$CheckInCheckedInImplCopyWith<$Res> {
  factory _$$CheckInCheckedInImplCopyWith(
    _$CheckInCheckedInImpl value,
    $Res Function(_$CheckInCheckedInImpl) then,
  ) = __$$CheckInCheckedInImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$CheckInCheckedInImplCopyWithImpl<$Res>
    extends _$CheckInStatusCopyWithImpl<$Res, _$CheckInCheckedInImpl>
    implements _$$CheckInCheckedInImplCopyWith<$Res> {
  __$$CheckInCheckedInImplCopyWithImpl(
    _$CheckInCheckedInImpl _value,
    $Res Function(_$CheckInCheckedInImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckInStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$CheckInCheckedInImpl implements CheckInCheckedIn {
  const _$CheckInCheckedInImpl({final String? $type})
    : $type = $type ?? 'checkedIn';

  factory _$CheckInCheckedInImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckInCheckedInImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'CheckInStatus.checkedIn()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$CheckInCheckedInImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function() checkedIn,
    required TResult Function() noShow,
  }) {
    return checkedIn();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function()? checkedIn,
    TResult? Function()? noShow,
  }) {
    return checkedIn?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function()? checkedIn,
    TResult Function()? noShow,
    required TResult orElse(),
  }) {
    if (checkedIn != null) {
      return checkedIn();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckInPending value) pending,
    required TResult Function(CheckInCheckedIn value) checkedIn,
    required TResult Function(CheckInNoShow value) noShow,
  }) {
    return checkedIn(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckInPending value)? pending,
    TResult? Function(CheckInCheckedIn value)? checkedIn,
    TResult? Function(CheckInNoShow value)? noShow,
  }) {
    return checkedIn?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckInPending value)? pending,
    TResult Function(CheckInCheckedIn value)? checkedIn,
    TResult Function(CheckInNoShow value)? noShow,
    required TResult orElse(),
  }) {
    if (checkedIn != null) {
      return checkedIn(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckInCheckedInImplToJson(this);
  }
}

abstract class CheckInCheckedIn implements CheckInStatus {
  const factory CheckInCheckedIn() = _$CheckInCheckedInImpl;

  factory CheckInCheckedIn.fromJson(Map<String, dynamic> json) =
      _$CheckInCheckedInImpl.fromJson;
}

/// @nodoc
abstract class _$$CheckInNoShowImplCopyWith<$Res> {
  factory _$$CheckInNoShowImplCopyWith(
    _$CheckInNoShowImpl value,
    $Res Function(_$CheckInNoShowImpl) then,
  ) = __$$CheckInNoShowImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$CheckInNoShowImplCopyWithImpl<$Res>
    extends _$CheckInStatusCopyWithImpl<$Res, _$CheckInNoShowImpl>
    implements _$$CheckInNoShowImplCopyWith<$Res> {
  __$$CheckInNoShowImplCopyWithImpl(
    _$CheckInNoShowImpl _value,
    $Res Function(_$CheckInNoShowImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckInStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
@JsonSerializable()
class _$CheckInNoShowImpl implements CheckInNoShow {
  const _$CheckInNoShowImpl({final String? $type}) : $type = $type ?? 'noShow';

  factory _$CheckInNoShowImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckInNoShowImplFromJson(json);

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'CheckInStatus.noShow()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$CheckInNoShowImpl);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() pending,
    required TResult Function() checkedIn,
    required TResult Function() noShow,
  }) {
    return noShow();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? pending,
    TResult? Function()? checkedIn,
    TResult? Function()? noShow,
  }) {
    return noShow?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? pending,
    TResult Function()? checkedIn,
    TResult Function()? noShow,
    required TResult orElse(),
  }) {
    if (noShow != null) {
      return noShow();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckInPending value) pending,
    required TResult Function(CheckInCheckedIn value) checkedIn,
    required TResult Function(CheckInNoShow value) noShow,
  }) {
    return noShow(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckInPending value)? pending,
    TResult? Function(CheckInCheckedIn value)? checkedIn,
    TResult? Function(CheckInNoShow value)? noShow,
  }) {
    return noShow?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckInPending value)? pending,
    TResult Function(CheckInCheckedIn value)? checkedIn,
    TResult Function(CheckInNoShow value)? noShow,
    required TResult orElse(),
  }) {
    if (noShow != null) {
      return noShow(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckInNoShowImplToJson(this);
  }
}

abstract class CheckInNoShow implements CheckInStatus {
  const factory CheckInNoShow() = _$CheckInNoShowImpl;

  factory CheckInNoShow.fromJson(Map<String, dynamic> json) =
      _$CheckInNoShowImpl.fromJson;
}

CheckInRecord _$CheckInRecordFromJson(Map<String, dynamic> json) {
  return _CheckInRecord.fromJson(json);
}

/// @nodoc
mixin _$CheckInRecord {
  String get id => throw _privateConstructorUsedError;
  String get gameId => throw _privateConstructorUsedError;
  String get participantId => throw _privateConstructorUsedError;
  String get participantName => throw _privateConstructorUsedError;
  CheckInStatus get status => throw _privateConstructorUsedError;
  DateTime? get checkedInAt => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Serializes this CheckInRecord to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CheckInRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CheckInRecordCopyWith<CheckInRecord> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckInRecordCopyWith<$Res> {
  factory $CheckInRecordCopyWith(
    CheckInRecord value,
    $Res Function(CheckInRecord) then,
  ) = _$CheckInRecordCopyWithImpl<$Res, CheckInRecord>;
  @useResult
  $Res call({
    String id,
    String gameId,
    String participantId,
    String participantName,
    CheckInStatus status,
    DateTime? checkedInAt,
    String? note,
  });

  $CheckInStatusCopyWith<$Res> get status;
}

/// @nodoc
class _$CheckInRecordCopyWithImpl<$Res, $Val extends CheckInRecord>
    implements $CheckInRecordCopyWith<$Res> {
  _$CheckInRecordCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckInRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? participantId = null,
    Object? participantName = null,
    Object? status = null,
    Object? checkedInAt = freezed,
    Object? note = freezed,
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
                      as CheckInStatus,
            checkedInAt: freezed == checkedInAt
                ? _value.checkedInAt
                : checkedInAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of CheckInRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CheckInStatusCopyWith<$Res> get status {
    return $CheckInStatusCopyWith<$Res>(_value.status, (value) {
      return _then(_value.copyWith(status: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CheckInRecordImplCopyWith<$Res>
    implements $CheckInRecordCopyWith<$Res> {
  factory _$$CheckInRecordImplCopyWith(
    _$CheckInRecordImpl value,
    $Res Function(_$CheckInRecordImpl) then,
  ) = __$$CheckInRecordImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String gameId,
    String participantId,
    String participantName,
    CheckInStatus status,
    DateTime? checkedInAt,
    String? note,
  });

  @override
  $CheckInStatusCopyWith<$Res> get status;
}

/// @nodoc
class __$$CheckInRecordImplCopyWithImpl<$Res>
    extends _$CheckInRecordCopyWithImpl<$Res, _$CheckInRecordImpl>
    implements _$$CheckInRecordImplCopyWith<$Res> {
  __$$CheckInRecordImplCopyWithImpl(
    _$CheckInRecordImpl _value,
    $Res Function(_$CheckInRecordImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckInRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? participantId = null,
    Object? participantName = null,
    Object? status = null,
    Object? checkedInAt = freezed,
    Object? note = freezed,
  }) {
    return _then(
      _$CheckInRecordImpl(
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
                  as CheckInStatus,
        checkedInAt: freezed == checkedInAt
            ? _value.checkedInAt
            : checkedInAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CheckInRecordImpl implements _CheckInRecord {
  const _$CheckInRecordImpl({
    required this.id,
    required this.gameId,
    required this.participantId,
    required this.participantName,
    required this.status,
    this.checkedInAt,
    this.note,
  });

  factory _$CheckInRecordImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckInRecordImplFromJson(json);

  @override
  final String id;
  @override
  final String gameId;
  @override
  final String participantId;
  @override
  final String participantName;
  @override
  final CheckInStatus status;
  @override
  final DateTime? checkedInAt;
  @override
  final String? note;

  @override
  String toString() {
    return 'CheckInRecord(id: $id, gameId: $gameId, participantId: $participantId, participantName: $participantName, status: $status, checkedInAt: $checkedInAt, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckInRecordImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.participantId, participantId) ||
                other.participantId == participantId) &&
            (identical(other.participantName, participantName) ||
                other.participantName == participantName) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.checkedInAt, checkedInAt) ||
                other.checkedInAt == checkedInAt) &&
            (identical(other.note, note) || other.note == note));
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
    checkedInAt,
    note,
  );

  /// Create a copy of CheckInRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckInRecordImplCopyWith<_$CheckInRecordImpl> get copyWith =>
      __$$CheckInRecordImplCopyWithImpl<_$CheckInRecordImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckInRecordImplToJson(this);
  }
}

abstract class _CheckInRecord implements CheckInRecord {
  const factory _CheckInRecord({
    required final String id,
    required final String gameId,
    required final String participantId,
    required final String participantName,
    required final CheckInStatus status,
    final DateTime? checkedInAt,
    final String? note,
  }) = _$CheckInRecordImpl;

  factory _CheckInRecord.fromJson(Map<String, dynamic> json) =
      _$CheckInRecordImpl.fromJson;

  @override
  String get id;
  @override
  String get gameId;
  @override
  String get participantId;
  @override
  String get participantName;
  @override
  CheckInStatus get status;
  @override
  DateTime? get checkedInAt;
  @override
  String? get note;

  /// Create a copy of CheckInRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckInRecordImplCopyWith<_$CheckInRecordImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
