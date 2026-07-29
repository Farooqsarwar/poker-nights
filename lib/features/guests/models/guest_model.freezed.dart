// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'guest_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GuestModel _$GuestModelFromJson(Map<String, dynamic> json) {
  return _GuestModel.fromJson(json);
}

/// @nodoc
mixin _$GuestModel {
  String get id => throw _privateConstructorUsedError;
  String get gameId => throw _privateConstructorUsedError;
  String get inviterParticipantId => throw _privateConstructorUsedError;
  int get slotNo => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get confirmationState => throw _privateConstructorUsedError;
  int? get tableNo => throw _privateConstructorUsedError;
  int? get seatNo => throw _privateConstructorUsedError;

  /// Serializes this GuestModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GuestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GuestModelCopyWith<GuestModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GuestModelCopyWith<$Res> {
  factory $GuestModelCopyWith(
    GuestModel value,
    $Res Function(GuestModel) then,
  ) = _$GuestModelCopyWithImpl<$Res, GuestModel>;
  @useResult
  $Res call({
    String id,
    String gameId,
    String inviterParticipantId,
    int slotNo,
    String name,
    String confirmationState,
    int? tableNo,
    int? seatNo,
  });
}

/// @nodoc
class _$GuestModelCopyWithImpl<$Res, $Val extends GuestModel>
    implements $GuestModelCopyWith<$Res> {
  _$GuestModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GuestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? inviterParticipantId = null,
    Object? slotNo = null,
    Object? name = null,
    Object? confirmationState = null,
    Object? tableNo = freezed,
    Object? seatNo = freezed,
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
            inviterParticipantId: null == inviterParticipantId
                ? _value.inviterParticipantId
                : inviterParticipantId // ignore: cast_nullable_to_non_nullable
                      as String,
            slotNo: null == slotNo
                ? _value.slotNo
                : slotNo // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            confirmationState: null == confirmationState
                ? _value.confirmationState
                : confirmationState // ignore: cast_nullable_to_non_nullable
                      as String,
            tableNo: freezed == tableNo
                ? _value.tableNo
                : tableNo // ignore: cast_nullable_to_non_nullable
                      as int?,
            seatNo: freezed == seatNo
                ? _value.seatNo
                : seatNo // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GuestModelImplCopyWith<$Res>
    implements $GuestModelCopyWith<$Res> {
  factory _$$GuestModelImplCopyWith(
    _$GuestModelImpl value,
    $Res Function(_$GuestModelImpl) then,
  ) = __$$GuestModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String gameId,
    String inviterParticipantId,
    int slotNo,
    String name,
    String confirmationState,
    int? tableNo,
    int? seatNo,
  });
}

/// @nodoc
class __$$GuestModelImplCopyWithImpl<$Res>
    extends _$GuestModelCopyWithImpl<$Res, _$GuestModelImpl>
    implements _$$GuestModelImplCopyWith<$Res> {
  __$$GuestModelImplCopyWithImpl(
    _$GuestModelImpl _value,
    $Res Function(_$GuestModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GuestModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameId = null,
    Object? inviterParticipantId = null,
    Object? slotNo = null,
    Object? name = null,
    Object? confirmationState = null,
    Object? tableNo = freezed,
    Object? seatNo = freezed,
  }) {
    return _then(
      _$GuestModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        gameId: null == gameId
            ? _value.gameId
            : gameId // ignore: cast_nullable_to_non_nullable
                  as String,
        inviterParticipantId: null == inviterParticipantId
            ? _value.inviterParticipantId
            : inviterParticipantId // ignore: cast_nullable_to_non_nullable
                  as String,
        slotNo: null == slotNo
            ? _value.slotNo
            : slotNo // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        confirmationState: null == confirmationState
            ? _value.confirmationState
            : confirmationState // ignore: cast_nullable_to_non_nullable
                  as String,
        tableNo: freezed == tableNo
            ? _value.tableNo
            : tableNo // ignore: cast_nullable_to_non_nullable
                  as int?,
        seatNo: freezed == seatNo
            ? _value.seatNo
            : seatNo // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GuestModelImpl implements _GuestModel {
  const _$GuestModelImpl({
    required this.id,
    required this.gameId,
    required this.inviterParticipantId,
    required this.slotNo,
    required this.name,
    required this.confirmationState,
    this.tableNo,
    this.seatNo,
  });

  factory _$GuestModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$GuestModelImplFromJson(json);

  @override
  final String id;
  @override
  final String gameId;
  @override
  final String inviterParticipantId;
  @override
  final int slotNo;
  @override
  final String name;
  @override
  final String confirmationState;
  @override
  final int? tableNo;
  @override
  final int? seatNo;

  @override
  String toString() {
    return 'GuestModel(id: $id, gameId: $gameId, inviterParticipantId: $inviterParticipantId, slotNo: $slotNo, name: $name, confirmationState: $confirmationState, tableNo: $tableNo, seatNo: $seatNo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GuestModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.inviterParticipantId, inviterParticipantId) ||
                other.inviterParticipantId == inviterParticipantId) &&
            (identical(other.slotNo, slotNo) || other.slotNo == slotNo) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.confirmationState, confirmationState) ||
                other.confirmationState == confirmationState) &&
            (identical(other.tableNo, tableNo) || other.tableNo == tableNo) &&
            (identical(other.seatNo, seatNo) || other.seatNo == seatNo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    gameId,
    inviterParticipantId,
    slotNo,
    name,
    confirmationState,
    tableNo,
    seatNo,
  );

  /// Create a copy of GuestModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GuestModelImplCopyWith<_$GuestModelImpl> get copyWith =>
      __$$GuestModelImplCopyWithImpl<_$GuestModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GuestModelImplToJson(this);
  }
}

abstract class _GuestModel implements GuestModel {
  const factory _GuestModel({
    required final String id,
    required final String gameId,
    required final String inviterParticipantId,
    required final int slotNo,
    required final String name,
    required final String confirmationState,
    final int? tableNo,
    final int? seatNo,
  }) = _$GuestModelImpl;

  factory _GuestModel.fromJson(Map<String, dynamic> json) =
      _$GuestModelImpl.fromJson;

  @override
  String get id;
  @override
  String get gameId;
  @override
  String get inviterParticipantId;
  @override
  int get slotNo;
  @override
  String get name;
  @override
  String get confirmationState;
  @override
  int? get tableNo;
  @override
  int? get seatNo;

  /// Create a copy of GuestModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GuestModelImplCopyWith<_$GuestModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
