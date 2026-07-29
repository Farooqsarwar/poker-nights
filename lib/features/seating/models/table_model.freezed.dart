// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'table_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TableLayout _$TableLayoutFromJson(Map<String, dynamic> json) {
  return _TableLayout.fromJson(json);
}

/// @nodoc
mixin _$TableLayout {
  int get tableNo => throw _privateConstructorUsedError;
  List<SeatPosition> get seats => throw _privateConstructorUsedError;

  /// Serializes this TableLayout to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TableLayout
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TableLayoutCopyWith<TableLayout> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TableLayoutCopyWith<$Res> {
  factory $TableLayoutCopyWith(
    TableLayout value,
    $Res Function(TableLayout) then,
  ) = _$TableLayoutCopyWithImpl<$Res, TableLayout>;
  @useResult
  $Res call({int tableNo, List<SeatPosition> seats});
}

/// @nodoc
class _$TableLayoutCopyWithImpl<$Res, $Val extends TableLayout>
    implements $TableLayoutCopyWith<$Res> {
  _$TableLayoutCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TableLayout
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? tableNo = null, Object? seats = null}) {
    return _then(
      _value.copyWith(
            tableNo: null == tableNo
                ? _value.tableNo
                : tableNo // ignore: cast_nullable_to_non_nullable
                      as int,
            seats: null == seats
                ? _value.seats
                : seats // ignore: cast_nullable_to_non_nullable
                      as List<SeatPosition>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TableLayoutImplCopyWith<$Res>
    implements $TableLayoutCopyWith<$Res> {
  factory _$$TableLayoutImplCopyWith(
    _$TableLayoutImpl value,
    $Res Function(_$TableLayoutImpl) then,
  ) = __$$TableLayoutImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int tableNo, List<SeatPosition> seats});
}

/// @nodoc
class __$$TableLayoutImplCopyWithImpl<$Res>
    extends _$TableLayoutCopyWithImpl<$Res, _$TableLayoutImpl>
    implements _$$TableLayoutImplCopyWith<$Res> {
  __$$TableLayoutImplCopyWithImpl(
    _$TableLayoutImpl _value,
    $Res Function(_$TableLayoutImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TableLayout
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? tableNo = null, Object? seats = null}) {
    return _then(
      _$TableLayoutImpl(
        tableNo: null == tableNo
            ? _value.tableNo
            : tableNo // ignore: cast_nullable_to_non_nullable
                  as int,
        seats: null == seats
            ? _value._seats
            : seats // ignore: cast_nullable_to_non_nullable
                  as List<SeatPosition>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TableLayoutImpl implements _TableLayout {
  const _$TableLayoutImpl({
    required this.tableNo,
    required final List<SeatPosition> seats,
  }) : _seats = seats;

  factory _$TableLayoutImpl.fromJson(Map<String, dynamic> json) =>
      _$$TableLayoutImplFromJson(json);

  @override
  final int tableNo;
  final List<SeatPosition> _seats;
  @override
  List<SeatPosition> get seats {
    if (_seats is EqualUnmodifiableListView) return _seats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_seats);
  }

  @override
  String toString() {
    return 'TableLayout(tableNo: $tableNo, seats: $seats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TableLayoutImpl &&
            (identical(other.tableNo, tableNo) || other.tableNo == tableNo) &&
            const DeepCollectionEquality().equals(other._seats, _seats));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    tableNo,
    const DeepCollectionEquality().hash(_seats),
  );

  /// Create a copy of TableLayout
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TableLayoutImplCopyWith<_$TableLayoutImpl> get copyWith =>
      __$$TableLayoutImplCopyWithImpl<_$TableLayoutImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TableLayoutImplToJson(this);
  }
}

abstract class _TableLayout implements TableLayout {
  const factory _TableLayout({
    required final int tableNo,
    required final List<SeatPosition> seats,
  }) = _$TableLayoutImpl;

  factory _TableLayout.fromJson(Map<String, dynamic> json) =
      _$TableLayoutImpl.fromJson;

  @override
  int get tableNo;
  @override
  List<SeatPosition> get seats;

  /// Create a copy of TableLayout
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TableLayoutImplCopyWith<_$TableLayoutImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SeatPosition _$SeatPositionFromJson(Map<String, dynamic> json) {
  return _SeatPosition.fromJson(json);
}

/// @nodoc
mixin _$SeatPosition {
  int get seatNo => throw _privateConstructorUsedError;
  double get x => throw _privateConstructorUsedError;
  double get y => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;

  /// Serializes this SeatPosition to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SeatPosition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SeatPositionCopyWith<SeatPosition> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SeatPositionCopyWith<$Res> {
  factory $SeatPositionCopyWith(
    SeatPosition value,
    $Res Function(SeatPosition) then,
  ) = _$SeatPositionCopyWithImpl<$Res, SeatPosition>;
  @useResult
  $Res call({int seatNo, double x, double y, String label});
}

/// @nodoc
class _$SeatPositionCopyWithImpl<$Res, $Val extends SeatPosition>
    implements $SeatPositionCopyWith<$Res> {
  _$SeatPositionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SeatPosition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seatNo = null,
    Object? x = null,
    Object? y = null,
    Object? label = null,
  }) {
    return _then(
      _value.copyWith(
            seatNo: null == seatNo
                ? _value.seatNo
                : seatNo // ignore: cast_nullable_to_non_nullable
                      as int,
            x: null == x
                ? _value.x
                : x // ignore: cast_nullable_to_non_nullable
                      as double,
            y: null == y
                ? _value.y
                : y // ignore: cast_nullable_to_non_nullable
                      as double,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SeatPositionImplCopyWith<$Res>
    implements $SeatPositionCopyWith<$Res> {
  factory _$$SeatPositionImplCopyWith(
    _$SeatPositionImpl value,
    $Res Function(_$SeatPositionImpl) then,
  ) = __$$SeatPositionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int seatNo, double x, double y, String label});
}

/// @nodoc
class __$$SeatPositionImplCopyWithImpl<$Res>
    extends _$SeatPositionCopyWithImpl<$Res, _$SeatPositionImpl>
    implements _$$SeatPositionImplCopyWith<$Res> {
  __$$SeatPositionImplCopyWithImpl(
    _$SeatPositionImpl _value,
    $Res Function(_$SeatPositionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SeatPosition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seatNo = null,
    Object? x = null,
    Object? y = null,
    Object? label = null,
  }) {
    return _then(
      _$SeatPositionImpl(
        seatNo: null == seatNo
            ? _value.seatNo
            : seatNo // ignore: cast_nullable_to_non_nullable
                  as int,
        x: null == x
            ? _value.x
            : x // ignore: cast_nullable_to_non_nullable
                  as double,
        y: null == y
            ? _value.y
            : y // ignore: cast_nullable_to_non_nullable
                  as double,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SeatPositionImpl implements _SeatPosition {
  const _$SeatPositionImpl({
    required this.seatNo,
    required this.x,
    required this.y,
    required this.label,
  });

  factory _$SeatPositionImpl.fromJson(Map<String, dynamic> json) =>
      _$$SeatPositionImplFromJson(json);

  @override
  final int seatNo;
  @override
  final double x;
  @override
  final double y;
  @override
  final String label;

  @override
  String toString() {
    return 'SeatPosition(seatNo: $seatNo, x: $x, y: $y, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SeatPositionImpl &&
            (identical(other.seatNo, seatNo) || other.seatNo == seatNo) &&
            (identical(other.x, x) || other.x == x) &&
            (identical(other.y, y) || other.y == y) &&
            (identical(other.label, label) || other.label == label));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, seatNo, x, y, label);

  /// Create a copy of SeatPosition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SeatPositionImplCopyWith<_$SeatPositionImpl> get copyWith =>
      __$$SeatPositionImplCopyWithImpl<_$SeatPositionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SeatPositionImplToJson(this);
  }
}

abstract class _SeatPosition implements SeatPosition {
  const factory _SeatPosition({
    required final int seatNo,
    required final double x,
    required final double y,
    required final String label,
  }) = _$SeatPositionImpl;

  factory _SeatPosition.fromJson(Map<String, dynamic> json) =
      _$SeatPositionImpl.fromJson;

  @override
  int get seatNo;
  @override
  double get x;
  @override
  double get y;
  @override
  String get label;

  /// Create a copy of SeatPosition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SeatPositionImplCopyWith<_$SeatPositionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
