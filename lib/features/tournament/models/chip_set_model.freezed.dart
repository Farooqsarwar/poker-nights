// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chip_set_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ChipSet _$ChipSetFromJson(Map<String, dynamic> json) {
  return _ChipSet.fromJson(json);
}

/// @nodoc
mixin _$ChipSet {
  String get id => throw _privateConstructorUsedError;
  String get groupId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get inventoryMode => throw _privateConstructorUsedError;
  List<ChipDenomination> get chips => throw _privateConstructorUsedError;

  /// Serializes this ChipSet to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChipSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChipSetCopyWith<ChipSet> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChipSetCopyWith<$Res> {
  factory $ChipSetCopyWith(ChipSet value, $Res Function(ChipSet) then) =
      _$ChipSetCopyWithImpl<$Res, ChipSet>;
  @useResult
  $Res call({
    String id,
    String groupId,
    String name,
    String inventoryMode,
    List<ChipDenomination> chips,
  });
}

/// @nodoc
class _$ChipSetCopyWithImpl<$Res, $Val extends ChipSet>
    implements $ChipSetCopyWith<$Res> {
  _$ChipSetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChipSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? name = null,
    Object? inventoryMode = null,
    Object? chips = null,
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
            inventoryMode: null == inventoryMode
                ? _value.inventoryMode
                : inventoryMode // ignore: cast_nullable_to_non_nullable
                      as String,
            chips: null == chips
                ? _value.chips
                : chips // ignore: cast_nullable_to_non_nullable
                      as List<ChipDenomination>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChipSetImplCopyWith<$Res> implements $ChipSetCopyWith<$Res> {
  factory _$$ChipSetImplCopyWith(
    _$ChipSetImpl value,
    $Res Function(_$ChipSetImpl) then,
  ) = __$$ChipSetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String groupId,
    String name,
    String inventoryMode,
    List<ChipDenomination> chips,
  });
}

/// @nodoc
class __$$ChipSetImplCopyWithImpl<$Res>
    extends _$ChipSetCopyWithImpl<$Res, _$ChipSetImpl>
    implements _$$ChipSetImplCopyWith<$Res> {
  __$$ChipSetImplCopyWithImpl(
    _$ChipSetImpl _value,
    $Res Function(_$ChipSetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChipSet
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? name = null,
    Object? inventoryMode = null,
    Object? chips = null,
  }) {
    return _then(
      _$ChipSetImpl(
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
        inventoryMode: null == inventoryMode
            ? _value.inventoryMode
            : inventoryMode // ignore: cast_nullable_to_non_nullable
                  as String,
        chips: null == chips
            ? _value._chips
            : chips // ignore: cast_nullable_to_non_nullable
                  as List<ChipDenomination>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChipSetImpl implements _ChipSet {
  const _$ChipSetImpl({
    required this.id,
    required this.groupId,
    required this.name,
    required this.inventoryMode,
    required final List<ChipDenomination> chips,
  }) : _chips = chips;

  factory _$ChipSetImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChipSetImplFromJson(json);

  @override
  final String id;
  @override
  final String groupId;
  @override
  final String name;
  @override
  final String inventoryMode;
  final List<ChipDenomination> _chips;
  @override
  List<ChipDenomination> get chips {
    if (_chips is EqualUnmodifiableListView) return _chips;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chips);
  }

  @override
  String toString() {
    return 'ChipSet(id: $id, groupId: $groupId, name: $name, inventoryMode: $inventoryMode, chips: $chips)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChipSetImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.inventoryMode, inventoryMode) ||
                other.inventoryMode == inventoryMode) &&
            const DeepCollectionEquality().equals(other._chips, _chips));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    groupId,
    name,
    inventoryMode,
    const DeepCollectionEquality().hash(_chips),
  );

  /// Create a copy of ChipSet
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChipSetImplCopyWith<_$ChipSetImpl> get copyWith =>
      __$$ChipSetImplCopyWithImpl<_$ChipSetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ChipSetImplToJson(this);
  }
}

abstract class _ChipSet implements ChipSet {
  const factory _ChipSet({
    required final String id,
    required final String groupId,
    required final String name,
    required final String inventoryMode,
    required final List<ChipDenomination> chips,
  }) = _$ChipSetImpl;

  factory _ChipSet.fromJson(Map<String, dynamic> json) = _$ChipSetImpl.fromJson;

  @override
  String get id;
  @override
  String get groupId;
  @override
  String get name;
  @override
  String get inventoryMode;
  @override
  List<ChipDenomination> get chips;

  /// Create a copy of ChipSet
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChipSetImplCopyWith<_$ChipSetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ChipDenomination _$ChipDenominationFromJson(Map<String, dynamic> json) {
  return _ChipDenomination.fromJson(json);
}

/// @nodoc
mixin _$ChipDenomination {
  String get color => throw _privateConstructorUsedError;
  String get colorName => throw _privateConstructorUsedError;
  int get value => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;

  /// Serializes this ChipDenomination to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ChipDenomination
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ChipDenominationCopyWith<ChipDenomination> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ChipDenominationCopyWith<$Res> {
  factory $ChipDenominationCopyWith(
    ChipDenomination value,
    $Res Function(ChipDenomination) then,
  ) = _$ChipDenominationCopyWithImpl<$Res, ChipDenomination>;
  @useResult
  $Res call({String color, String colorName, int value, int quantity});
}

/// @nodoc
class _$ChipDenominationCopyWithImpl<$Res, $Val extends ChipDenomination>
    implements $ChipDenominationCopyWith<$Res> {
  _$ChipDenominationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ChipDenomination
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? color = null,
    Object? colorName = null,
    Object? value = null,
    Object? quantity = null,
  }) {
    return _then(
      _value.copyWith(
            color: null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                      as String,
            colorName: null == colorName
                ? _value.colorName
                : colorName // ignore: cast_nullable_to_non_nullable
                      as String,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as int,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ChipDenominationImplCopyWith<$Res>
    implements $ChipDenominationCopyWith<$Res> {
  factory _$$ChipDenominationImplCopyWith(
    _$ChipDenominationImpl value,
    $Res Function(_$ChipDenominationImpl) then,
  ) = __$$ChipDenominationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String color, String colorName, int value, int quantity});
}

/// @nodoc
class __$$ChipDenominationImplCopyWithImpl<$Res>
    extends _$ChipDenominationCopyWithImpl<$Res, _$ChipDenominationImpl>
    implements _$$ChipDenominationImplCopyWith<$Res> {
  __$$ChipDenominationImplCopyWithImpl(
    _$ChipDenominationImpl _value,
    $Res Function(_$ChipDenominationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ChipDenomination
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? color = null,
    Object? colorName = null,
    Object? value = null,
    Object? quantity = null,
  }) {
    return _then(
      _$ChipDenominationImpl(
        color: null == color
            ? _value.color
            : color // ignore: cast_nullable_to_non_nullable
                  as String,
        colorName: null == colorName
            ? _value.colorName
            : colorName // ignore: cast_nullable_to_non_nullable
                  as String,
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as int,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ChipDenominationImpl implements _ChipDenomination {
  const _$ChipDenominationImpl({
    required this.color,
    required this.colorName,
    required this.value,
    required this.quantity,
  });

  factory _$ChipDenominationImpl.fromJson(Map<String, dynamic> json) =>
      _$$ChipDenominationImplFromJson(json);

  @override
  final String color;
  @override
  final String colorName;
  @override
  final int value;
  @override
  final int quantity;

  @override
  String toString() {
    return 'ChipDenomination(color: $color, colorName: $colorName, value: $value, quantity: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ChipDenominationImpl &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.colorName, colorName) ||
                other.colorName == colorName) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, color, colorName, value, quantity);

  /// Create a copy of ChipDenomination
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ChipDenominationImplCopyWith<_$ChipDenominationImpl> get copyWith =>
      __$$ChipDenominationImplCopyWithImpl<_$ChipDenominationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ChipDenominationImplToJson(this);
  }
}

abstract class _ChipDenomination implements ChipDenomination {
  const factory _ChipDenomination({
    required final String color,
    required final String colorName,
    required final int value,
    required final int quantity,
  }) = _$ChipDenominationImpl;

  factory _ChipDenomination.fromJson(Map<String, dynamic> json) =
      _$ChipDenominationImpl.fromJson;

  @override
  String get color;
  @override
  String get colorName;
  @override
  int get value;
  @override
  int get quantity;

  /// Create a copy of ChipDenomination
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ChipDenominationImplCopyWith<_$ChipDenominationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
