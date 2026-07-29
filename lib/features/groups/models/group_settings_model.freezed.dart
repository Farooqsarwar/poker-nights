// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_settings_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GroupSettings _$GroupSettingsFromJson(Map<String, dynamic> json) {
  return _GroupSettings.fromJson(json);
}

/// @nodoc
mixin _$GroupSettings {
  String get groupId => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  double get organizerFeePercent => throw _privateConstructorUsedError;
  bool get allowGuestPlayers => throw _privateConstructorUsedError;
  int get maxGuestsPerPlayer => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this GroupSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GroupSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupSettingsCopyWith<GroupSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupSettingsCopyWith<$Res> {
  factory $GroupSettingsCopyWith(
    GroupSettings value,
    $Res Function(GroupSettings) then,
  ) = _$GroupSettingsCopyWithImpl<$Res, GroupSettings>;
  @useResult
  $Res call({
    String groupId,
    String status,
    double organizerFeePercent,
    bool allowGuestPlayers,
    int maxGuestsPerPlayer,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$GroupSettingsCopyWithImpl<$Res, $Val extends GroupSettings>
    implements $GroupSettingsCopyWith<$Res> {
  _$GroupSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? status = null,
    Object? organizerFeePercent = null,
    Object? allowGuestPlayers = null,
    Object? maxGuestsPerPlayer = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            groupId: null == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            organizerFeePercent: null == organizerFeePercent
                ? _value.organizerFeePercent
                : organizerFeePercent // ignore: cast_nullable_to_non_nullable
                      as double,
            allowGuestPlayers: null == allowGuestPlayers
                ? _value.allowGuestPlayers
                : allowGuestPlayers // ignore: cast_nullable_to_non_nullable
                      as bool,
            maxGuestsPerPlayer: null == maxGuestsPerPlayer
                ? _value.maxGuestsPerPlayer
                : maxGuestsPerPlayer // ignore: cast_nullable_to_non_nullable
                      as int,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GroupSettingsImplCopyWith<$Res>
    implements $GroupSettingsCopyWith<$Res> {
  factory _$$GroupSettingsImplCopyWith(
    _$GroupSettingsImpl value,
    $Res Function(_$GroupSettingsImpl) then,
  ) = __$$GroupSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String groupId,
    String status,
    double organizerFeePercent,
    bool allowGuestPlayers,
    int maxGuestsPerPlayer,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$GroupSettingsImplCopyWithImpl<$Res>
    extends _$GroupSettingsCopyWithImpl<$Res, _$GroupSettingsImpl>
    implements _$$GroupSettingsImplCopyWith<$Res> {
  __$$GroupSettingsImplCopyWithImpl(
    _$GroupSettingsImpl _value,
    $Res Function(_$GroupSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GroupSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? groupId = null,
    Object? status = null,
    Object? organizerFeePercent = null,
    Object? allowGuestPlayers = null,
    Object? maxGuestsPerPlayer = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$GroupSettingsImpl(
        groupId: null == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        organizerFeePercent: null == organizerFeePercent
            ? _value.organizerFeePercent
            : organizerFeePercent // ignore: cast_nullable_to_non_nullable
                  as double,
        allowGuestPlayers: null == allowGuestPlayers
            ? _value.allowGuestPlayers
            : allowGuestPlayers // ignore: cast_nullable_to_non_nullable
                  as bool,
        maxGuestsPerPlayer: null == maxGuestsPerPlayer
            ? _value.maxGuestsPerPlayer
            : maxGuestsPerPlayer // ignore: cast_nullable_to_non_nullable
                  as int,
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
class _$GroupSettingsImpl implements _GroupSettings {
  const _$GroupSettingsImpl({
    required this.groupId,
    this.status = 'active',
    this.organizerFeePercent = 0,
    this.allowGuestPlayers = false,
    this.maxGuestsPerPlayer = 4,
    this.updatedAt,
  });

  factory _$GroupSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$GroupSettingsImplFromJson(json);

  @override
  final String groupId;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey()
  final double organizerFeePercent;
  @override
  @JsonKey()
  final bool allowGuestPlayers;
  @override
  @JsonKey()
  final int maxGuestsPerPlayer;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'GroupSettings(groupId: $groupId, status: $status, organizerFeePercent: $organizerFeePercent, allowGuestPlayers: $allowGuestPlayers, maxGuestsPerPlayer: $maxGuestsPerPlayer, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupSettingsImpl &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.organizerFeePercent, organizerFeePercent) ||
                other.organizerFeePercent == organizerFeePercent) &&
            (identical(other.allowGuestPlayers, allowGuestPlayers) ||
                other.allowGuestPlayers == allowGuestPlayers) &&
            (identical(other.maxGuestsPerPlayer, maxGuestsPerPlayer) ||
                other.maxGuestsPerPlayer == maxGuestsPerPlayer) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    groupId,
    status,
    organizerFeePercent,
    allowGuestPlayers,
    maxGuestsPerPlayer,
    updatedAt,
  );

  /// Create a copy of GroupSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupSettingsImplCopyWith<_$GroupSettingsImpl> get copyWith =>
      __$$GroupSettingsImplCopyWithImpl<_$GroupSettingsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GroupSettingsImplToJson(this);
  }
}

abstract class _GroupSettings implements GroupSettings {
  const factory _GroupSettings({
    required final String groupId,
    final String status,
    final double organizerFeePercent,
    final bool allowGuestPlayers,
    final int maxGuestsPerPlayer,
    final DateTime? updatedAt,
  }) = _$GroupSettingsImpl;

  factory _GroupSettings.fromJson(Map<String, dynamic> json) =
      _$GroupSettingsImpl.fromJson;

  @override
  String get groupId;
  @override
  String get status;
  @override
  double get organizerFeePercent;
  @override
  bool get allowGuestPlayers;
  @override
  int get maxGuestsPerPlayer;
  @override
  DateTime? get updatedAt;

  /// Create a copy of GroupSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupSettingsImplCopyWith<_$GroupSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
