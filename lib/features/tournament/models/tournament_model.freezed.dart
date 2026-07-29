// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tournament_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TournamentModel _$TournamentModelFromJson(Map<String, dynamic> json) {
  return _TournamentModel.fromJson(json);
}

/// @nodoc
mixin _$TournamentModel {
  String get id => throw _privateConstructorUsedError;
  String get groupId => throw _privateConstructorUsedError;
  String get adminUserId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  DateTime get scheduledAt => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String get publicCode => throw _privateConstructorUsedError;
  TournamentSettings get settings => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  int get revision => throw _privateConstructorUsedError;

  /// Serializes this TournamentModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TournamentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TournamentModelCopyWith<TournamentModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TournamentModelCopyWith<$Res> {
  factory $TournamentModelCopyWith(
    TournamentModel value,
    $Res Function(TournamentModel) then,
  ) = _$TournamentModelCopyWithImpl<$Res, TournamentModel>;
  @useResult
  $Res call({
    String id,
    String groupId,
    String adminUserId,
    String name,
    DateTime scheduledAt,
    String? location,
    String status,
    String publicCode,
    TournamentSettings settings,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int revision,
  });

  $TournamentSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class _$TournamentModelCopyWithImpl<$Res, $Val extends TournamentModel>
    implements $TournamentModelCopyWith<$Res> {
  _$TournamentModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TournamentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? adminUserId = null,
    Object? name = null,
    Object? scheduledAt = null,
    Object? location = freezed,
    Object? status = null,
    Object? publicCode = null,
    Object? settings = null,
    Object? createdAt = freezed,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? revision = null,
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
            adminUserId: null == adminUserId
                ? _value.adminUserId
                : adminUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            scheduledAt: null == scheduledAt
                ? _value.scheduledAt
                : scheduledAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            location: freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            publicCode: null == publicCode
                ? _value.publicCode
                : publicCode // ignore: cast_nullable_to_non_nullable
                      as String,
            settings: null == settings
                ? _value.settings
                : settings // ignore: cast_nullable_to_non_nullable
                      as TournamentSettings,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            completedAt: freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            revision: null == revision
                ? _value.revision
                : revision // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }

  /// Create a copy of TournamentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TournamentSettingsCopyWith<$Res> get settings {
    return $TournamentSettingsCopyWith<$Res>(_value.settings, (value) {
      return _then(_value.copyWith(settings: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$TournamentModelImplCopyWith<$Res>
    implements $TournamentModelCopyWith<$Res> {
  factory _$$TournamentModelImplCopyWith(
    _$TournamentModelImpl value,
    $Res Function(_$TournamentModelImpl) then,
  ) = __$$TournamentModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String groupId,
    String adminUserId,
    String name,
    DateTime scheduledAt,
    String? location,
    String status,
    String publicCode,
    TournamentSettings settings,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int revision,
  });

  @override
  $TournamentSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class __$$TournamentModelImplCopyWithImpl<$Res>
    extends _$TournamentModelCopyWithImpl<$Res, _$TournamentModelImpl>
    implements _$$TournamentModelImplCopyWith<$Res> {
  __$$TournamentModelImplCopyWithImpl(
    _$TournamentModelImpl _value,
    $Res Function(_$TournamentModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TournamentModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? groupId = null,
    Object? adminUserId = null,
    Object? name = null,
    Object? scheduledAt = null,
    Object? location = freezed,
    Object? status = null,
    Object? publicCode = null,
    Object? settings = null,
    Object? createdAt = freezed,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? revision = null,
  }) {
    return _then(
      _$TournamentModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        groupId: null == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String,
        adminUserId: null == adminUserId
            ? _value.adminUserId
            : adminUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        scheduledAt: null == scheduledAt
            ? _value.scheduledAt
            : scheduledAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        location: freezed == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        publicCode: null == publicCode
            ? _value.publicCode
            : publicCode // ignore: cast_nullable_to_non_nullable
                  as String,
        settings: null == settings
            ? _value.settings
            : settings // ignore: cast_nullable_to_non_nullable
                  as TournamentSettings,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        completedAt: freezed == completedAt
            ? _value.completedAt
            : completedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        revision: null == revision
            ? _value.revision
            : revision // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TournamentModelImpl implements _TournamentModel {
  const _$TournamentModelImpl({
    required this.id,
    required this.groupId,
    required this.adminUserId,
    required this.name,
    required this.scheduledAt,
    this.location,
    required this.status,
    required this.publicCode,
    required this.settings,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.revision = 0,
  });

  factory _$TournamentModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TournamentModelImplFromJson(json);

  @override
  final String id;
  @override
  final String groupId;
  @override
  final String adminUserId;
  @override
  final String name;
  @override
  final DateTime scheduledAt;
  @override
  final String? location;
  @override
  final String status;
  @override
  final String publicCode;
  @override
  final TournamentSettings settings;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? startedAt;
  @override
  final DateTime? completedAt;
  @override
  @JsonKey()
  final int revision;

  @override
  String toString() {
    return 'TournamentModel(id: $id, groupId: $groupId, adminUserId: $adminUserId, name: $name, scheduledAt: $scheduledAt, location: $location, status: $status, publicCode: $publicCode, settings: $settings, createdAt: $createdAt, startedAt: $startedAt, completedAt: $completedAt, revision: $revision)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TournamentModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.adminUserId, adminUserId) ||
                other.adminUserId == adminUserId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.scheduledAt, scheduledAt) ||
                other.scheduledAt == scheduledAt) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.publicCode, publicCode) ||
                other.publicCode == publicCode) &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.revision, revision) ||
                other.revision == revision));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    groupId,
    adminUserId,
    name,
    scheduledAt,
    location,
    status,
    publicCode,
    settings,
    createdAt,
    startedAt,
    completedAt,
    revision,
  );

  /// Create a copy of TournamentModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TournamentModelImplCopyWith<_$TournamentModelImpl> get copyWith =>
      __$$TournamentModelImplCopyWithImpl<_$TournamentModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TournamentModelImplToJson(this);
  }
}

abstract class _TournamentModel implements TournamentModel {
  const factory _TournamentModel({
    required final String id,
    required final String groupId,
    required final String adminUserId,
    required final String name,
    required final DateTime scheduledAt,
    final String? location,
    required final String status,
    required final String publicCode,
    required final TournamentSettings settings,
    final DateTime? createdAt,
    final DateTime? startedAt,
    final DateTime? completedAt,
    final int revision,
  }) = _$TournamentModelImpl;

  factory _TournamentModel.fromJson(Map<String, dynamic> json) =
      _$TournamentModelImpl.fromJson;

  @override
  String get id;
  @override
  String get groupId;
  @override
  String get adminUserId;
  @override
  String get name;
  @override
  DateTime get scheduledAt;
  @override
  String? get location;
  @override
  String get status;
  @override
  String get publicCode;
  @override
  TournamentSettings get settings;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get startedAt;
  @override
  DateTime? get completedAt;
  @override
  int get revision;

  /// Create a copy of TournamentModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TournamentModelImplCopyWith<_$TournamentModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TournamentSettings _$TournamentSettingsFromJson(Map<String, dynamic> json) {
  return _TournamentSettings.fromJson(json);
}

/// @nodoc
mixin _$TournamentSettings {
  int get expectedPlayers => throw _privateConstructorUsedError;
  double get targetDurationHours => throw _privateConstructorUsedError;
  double get buyIn => throw _privateConstructorUsedError;
  double get koBounty => throw _privateConstructorUsedError;
  bool get rebuysEnabled => throw _privateConstructorUsedError;
  int get rebuyCloseLevel => throw _privateConstructorUsedError;
  bool get rebuyLimited => throw _privateConstructorUsedError;
  int get rebuyLimit => throw _privateConstructorUsedError;
  bool get addOnEnabled => throw _privateConstructorUsedError;
  double get addOnPrice => throw _privateConstructorUsedError;
  int get maxAddOnPerPlayer => throw _privateConstructorUsedError;
  String get anteMode => throw _privateConstructorUsedError;
  double get organizerPercentage => throw _privateConstructorUsedError;
  String? get chipSetId => throw _privateConstructorUsedError;
  String get chipInventoryMode => throw _privateConstructorUsedError;
  Map<String, int> get chipInventory => throw _privateConstructorUsedError;

  /// Serializes this TournamentSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TournamentSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TournamentSettingsCopyWith<TournamentSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TournamentSettingsCopyWith<$Res> {
  factory $TournamentSettingsCopyWith(
    TournamentSettings value,
    $Res Function(TournamentSettings) then,
  ) = _$TournamentSettingsCopyWithImpl<$Res, TournamentSettings>;
  @useResult
  $Res call({
    int expectedPlayers,
    double targetDurationHours,
    double buyIn,
    double koBounty,
    bool rebuysEnabled,
    int rebuyCloseLevel,
    bool rebuyLimited,
    int rebuyLimit,
    bool addOnEnabled,
    double addOnPrice,
    int maxAddOnPerPlayer,
    String anteMode,
    double organizerPercentage,
    String? chipSetId,
    String chipInventoryMode,
    Map<String, int> chipInventory,
  });
}

/// @nodoc
class _$TournamentSettingsCopyWithImpl<$Res, $Val extends TournamentSettings>
    implements $TournamentSettingsCopyWith<$Res> {
  _$TournamentSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TournamentSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? expectedPlayers = null,
    Object? targetDurationHours = null,
    Object? buyIn = null,
    Object? koBounty = null,
    Object? rebuysEnabled = null,
    Object? rebuyCloseLevel = null,
    Object? rebuyLimited = null,
    Object? rebuyLimit = null,
    Object? addOnEnabled = null,
    Object? addOnPrice = null,
    Object? maxAddOnPerPlayer = null,
    Object? anteMode = null,
    Object? organizerPercentage = null,
    Object? chipSetId = freezed,
    Object? chipInventoryMode = null,
    Object? chipInventory = null,
  }) {
    return _then(
      _value.copyWith(
            expectedPlayers: null == expectedPlayers
                ? _value.expectedPlayers
                : expectedPlayers // ignore: cast_nullable_to_non_nullable
                      as int,
            targetDurationHours: null == targetDurationHours
                ? _value.targetDurationHours
                : targetDurationHours // ignore: cast_nullable_to_non_nullable
                      as double,
            buyIn: null == buyIn
                ? _value.buyIn
                : buyIn // ignore: cast_nullable_to_non_nullable
                      as double,
            koBounty: null == koBounty
                ? _value.koBounty
                : koBounty // ignore: cast_nullable_to_non_nullable
                      as double,
            rebuysEnabled: null == rebuysEnabled
                ? _value.rebuysEnabled
                : rebuysEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            rebuyCloseLevel: null == rebuyCloseLevel
                ? _value.rebuyCloseLevel
                : rebuyCloseLevel // ignore: cast_nullable_to_non_nullable
                      as int,
            rebuyLimited: null == rebuyLimited
                ? _value.rebuyLimited
                : rebuyLimited // ignore: cast_nullable_to_non_nullable
                      as bool,
            rebuyLimit: null == rebuyLimit
                ? _value.rebuyLimit
                : rebuyLimit // ignore: cast_nullable_to_non_nullable
                      as int,
            addOnEnabled: null == addOnEnabled
                ? _value.addOnEnabled
                : addOnEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            addOnPrice: null == addOnPrice
                ? _value.addOnPrice
                : addOnPrice // ignore: cast_nullable_to_non_nullable
                      as double,
            maxAddOnPerPlayer: null == maxAddOnPerPlayer
                ? _value.maxAddOnPerPlayer
                : maxAddOnPerPlayer // ignore: cast_nullable_to_non_nullable
                      as int,
            anteMode: null == anteMode
                ? _value.anteMode
                : anteMode // ignore: cast_nullable_to_non_nullable
                      as String,
            organizerPercentage: null == organizerPercentage
                ? _value.organizerPercentage
                : organizerPercentage // ignore: cast_nullable_to_non_nullable
                      as double,
            chipSetId: freezed == chipSetId
                ? _value.chipSetId
                : chipSetId // ignore: cast_nullable_to_non_nullable
                      as String?,
            chipInventoryMode: null == chipInventoryMode
                ? _value.chipInventoryMode
                : chipInventoryMode // ignore: cast_nullable_to_non_nullable
                      as String,
            chipInventory: null == chipInventory
                ? _value.chipInventory
                : chipInventory // ignore: cast_nullable_to_non_nullable
                      as Map<String, int>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TournamentSettingsImplCopyWith<$Res>
    implements $TournamentSettingsCopyWith<$Res> {
  factory _$$TournamentSettingsImplCopyWith(
    _$TournamentSettingsImpl value,
    $Res Function(_$TournamentSettingsImpl) then,
  ) = __$$TournamentSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int expectedPlayers,
    double targetDurationHours,
    double buyIn,
    double koBounty,
    bool rebuysEnabled,
    int rebuyCloseLevel,
    bool rebuyLimited,
    int rebuyLimit,
    bool addOnEnabled,
    double addOnPrice,
    int maxAddOnPerPlayer,
    String anteMode,
    double organizerPercentage,
    String? chipSetId,
    String chipInventoryMode,
    Map<String, int> chipInventory,
  });
}

/// @nodoc
class __$$TournamentSettingsImplCopyWithImpl<$Res>
    extends _$TournamentSettingsCopyWithImpl<$Res, _$TournamentSettingsImpl>
    implements _$$TournamentSettingsImplCopyWith<$Res> {
  __$$TournamentSettingsImplCopyWithImpl(
    _$TournamentSettingsImpl _value,
    $Res Function(_$TournamentSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TournamentSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? expectedPlayers = null,
    Object? targetDurationHours = null,
    Object? buyIn = null,
    Object? koBounty = null,
    Object? rebuysEnabled = null,
    Object? rebuyCloseLevel = null,
    Object? rebuyLimited = null,
    Object? rebuyLimit = null,
    Object? addOnEnabled = null,
    Object? addOnPrice = null,
    Object? maxAddOnPerPlayer = null,
    Object? anteMode = null,
    Object? organizerPercentage = null,
    Object? chipSetId = freezed,
    Object? chipInventoryMode = null,
    Object? chipInventory = null,
  }) {
    return _then(
      _$TournamentSettingsImpl(
        expectedPlayers: null == expectedPlayers
            ? _value.expectedPlayers
            : expectedPlayers // ignore: cast_nullable_to_non_nullable
                  as int,
        targetDurationHours: null == targetDurationHours
            ? _value.targetDurationHours
            : targetDurationHours // ignore: cast_nullable_to_non_nullable
                  as double,
        buyIn: null == buyIn
            ? _value.buyIn
            : buyIn // ignore: cast_nullable_to_non_nullable
                  as double,
        koBounty: null == koBounty
            ? _value.koBounty
            : koBounty // ignore: cast_nullable_to_non_nullable
                  as double,
        rebuysEnabled: null == rebuysEnabled
            ? _value.rebuysEnabled
            : rebuysEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        rebuyCloseLevel: null == rebuyCloseLevel
            ? _value.rebuyCloseLevel
            : rebuyCloseLevel // ignore: cast_nullable_to_non_nullable
                  as int,
        rebuyLimited: null == rebuyLimited
            ? _value.rebuyLimited
            : rebuyLimited // ignore: cast_nullable_to_non_nullable
                  as bool,
        rebuyLimit: null == rebuyLimit
            ? _value.rebuyLimit
            : rebuyLimit // ignore: cast_nullable_to_non_nullable
                  as int,
        addOnEnabled: null == addOnEnabled
            ? _value.addOnEnabled
            : addOnEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        addOnPrice: null == addOnPrice
            ? _value.addOnPrice
            : addOnPrice // ignore: cast_nullable_to_non_nullable
                  as double,
        maxAddOnPerPlayer: null == maxAddOnPerPlayer
            ? _value.maxAddOnPerPlayer
            : maxAddOnPerPlayer // ignore: cast_nullable_to_non_nullable
                  as int,
        anteMode: null == anteMode
            ? _value.anteMode
            : anteMode // ignore: cast_nullable_to_non_nullable
                  as String,
        organizerPercentage: null == organizerPercentage
            ? _value.organizerPercentage
            : organizerPercentage // ignore: cast_nullable_to_non_nullable
                  as double,
        chipSetId: freezed == chipSetId
            ? _value.chipSetId
            : chipSetId // ignore: cast_nullable_to_non_nullable
                  as String?,
        chipInventoryMode: null == chipInventoryMode
            ? _value.chipInventoryMode
            : chipInventoryMode // ignore: cast_nullable_to_non_nullable
                  as String,
        chipInventory: null == chipInventory
            ? _value._chipInventory
            : chipInventory // ignore: cast_nullable_to_non_nullable
                  as Map<String, int>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TournamentSettingsImpl implements _TournamentSettings {
  const _$TournamentSettingsImpl({
    required this.expectedPlayers,
    required this.targetDurationHours,
    required this.buyIn,
    this.koBounty = 0,
    this.rebuysEnabled = true,
    this.rebuyCloseLevel = 6,
    this.rebuyLimited = false,
    this.rebuyLimit = 0,
    this.addOnEnabled = true,
    this.addOnPrice = 0,
    this.maxAddOnPerPlayer = 1,
    this.anteMode = 'off',
    this.organizerPercentage = 0,
    this.chipSetId,
    this.chipInventoryMode = 'exact',
    final Map<String, int> chipInventory = const {},
  }) : _chipInventory = chipInventory;

  factory _$TournamentSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$TournamentSettingsImplFromJson(json);

  @override
  final int expectedPlayers;
  @override
  final double targetDurationHours;
  @override
  final double buyIn;
  @override
  @JsonKey()
  final double koBounty;
  @override
  @JsonKey()
  final bool rebuysEnabled;
  @override
  @JsonKey()
  final int rebuyCloseLevel;
  @override
  @JsonKey()
  final bool rebuyLimited;
  @override
  @JsonKey()
  final int rebuyLimit;
  @override
  @JsonKey()
  final bool addOnEnabled;
  @override
  @JsonKey()
  final double addOnPrice;
  @override
  @JsonKey()
  final int maxAddOnPerPlayer;
  @override
  @JsonKey()
  final String anteMode;
  @override
  @JsonKey()
  final double organizerPercentage;
  @override
  final String? chipSetId;
  @override
  @JsonKey()
  final String chipInventoryMode;
  final Map<String, int> _chipInventory;
  @override
  @JsonKey()
  Map<String, int> get chipInventory {
    if (_chipInventory is EqualUnmodifiableMapView) return _chipInventory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_chipInventory);
  }

  @override
  String toString() {
    return 'TournamentSettings(expectedPlayers: $expectedPlayers, targetDurationHours: $targetDurationHours, buyIn: $buyIn, koBounty: $koBounty, rebuysEnabled: $rebuysEnabled, rebuyCloseLevel: $rebuyCloseLevel, rebuyLimited: $rebuyLimited, rebuyLimit: $rebuyLimit, addOnEnabled: $addOnEnabled, addOnPrice: $addOnPrice, maxAddOnPerPlayer: $maxAddOnPerPlayer, anteMode: $anteMode, organizerPercentage: $organizerPercentage, chipSetId: $chipSetId, chipInventoryMode: $chipInventoryMode, chipInventory: $chipInventory)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TournamentSettingsImpl &&
            (identical(other.expectedPlayers, expectedPlayers) ||
                other.expectedPlayers == expectedPlayers) &&
            (identical(other.targetDurationHours, targetDurationHours) ||
                other.targetDurationHours == targetDurationHours) &&
            (identical(other.buyIn, buyIn) || other.buyIn == buyIn) &&
            (identical(other.koBounty, koBounty) ||
                other.koBounty == koBounty) &&
            (identical(other.rebuysEnabled, rebuysEnabled) ||
                other.rebuysEnabled == rebuysEnabled) &&
            (identical(other.rebuyCloseLevel, rebuyCloseLevel) ||
                other.rebuyCloseLevel == rebuyCloseLevel) &&
            (identical(other.rebuyLimited, rebuyLimited) ||
                other.rebuyLimited == rebuyLimited) &&
            (identical(other.rebuyLimit, rebuyLimit) ||
                other.rebuyLimit == rebuyLimit) &&
            (identical(other.addOnEnabled, addOnEnabled) ||
                other.addOnEnabled == addOnEnabled) &&
            (identical(other.addOnPrice, addOnPrice) ||
                other.addOnPrice == addOnPrice) &&
            (identical(other.maxAddOnPerPlayer, maxAddOnPerPlayer) ||
                other.maxAddOnPerPlayer == maxAddOnPerPlayer) &&
            (identical(other.anteMode, anteMode) ||
                other.anteMode == anteMode) &&
            (identical(other.organizerPercentage, organizerPercentage) ||
                other.organizerPercentage == organizerPercentage) &&
            (identical(other.chipSetId, chipSetId) ||
                other.chipSetId == chipSetId) &&
            (identical(other.chipInventoryMode, chipInventoryMode) ||
                other.chipInventoryMode == chipInventoryMode) &&
            const DeepCollectionEquality().equals(
              other._chipInventory,
              _chipInventory,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    expectedPlayers,
    targetDurationHours,
    buyIn,
    koBounty,
    rebuysEnabled,
    rebuyCloseLevel,
    rebuyLimited,
    rebuyLimit,
    addOnEnabled,
    addOnPrice,
    maxAddOnPerPlayer,
    anteMode,
    organizerPercentage,
    chipSetId,
    chipInventoryMode,
    const DeepCollectionEquality().hash(_chipInventory),
  );

  /// Create a copy of TournamentSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TournamentSettingsImplCopyWith<_$TournamentSettingsImpl> get copyWith =>
      __$$TournamentSettingsImplCopyWithImpl<_$TournamentSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TournamentSettingsImplToJson(this);
  }
}

abstract class _TournamentSettings implements TournamentSettings {
  const factory _TournamentSettings({
    required final int expectedPlayers,
    required final double targetDurationHours,
    required final double buyIn,
    final double koBounty,
    final bool rebuysEnabled,
    final int rebuyCloseLevel,
    final bool rebuyLimited,
    final int rebuyLimit,
    final bool addOnEnabled,
    final double addOnPrice,
    final int maxAddOnPerPlayer,
    final String anteMode,
    final double organizerPercentage,
    final String? chipSetId,
    final String chipInventoryMode,
    final Map<String, int> chipInventory,
  }) = _$TournamentSettingsImpl;

  factory _TournamentSettings.fromJson(Map<String, dynamic> json) =
      _$TournamentSettingsImpl.fromJson;

  @override
  int get expectedPlayers;
  @override
  double get targetDurationHours;
  @override
  double get buyIn;
  @override
  double get koBounty;
  @override
  bool get rebuysEnabled;
  @override
  int get rebuyCloseLevel;
  @override
  bool get rebuyLimited;
  @override
  int get rebuyLimit;
  @override
  bool get addOnEnabled;
  @override
  double get addOnPrice;
  @override
  int get maxAddOnPerPlayer;
  @override
  String get anteMode;
  @override
  double get organizerPercentage;
  @override
  String? get chipSetId;
  @override
  String get chipInventoryMode;
  @override
  Map<String, int> get chipInventory;

  /// Create a copy of TournamentSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TournamentSettingsImplCopyWith<_$TournamentSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
