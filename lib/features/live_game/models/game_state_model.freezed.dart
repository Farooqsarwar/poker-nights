// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_state_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

GameState _$GameStateFromJson(Map<String, dynamic> json) {
  return _GameState.fromJson(json);
}

/// @nodoc
mixin _$GameState {
  String get gameId => throw _privateConstructorUsedError;
  int get currentLevel => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  DateTime? get pausedAt => throw _privateConstructorUsedError;
  int get pausedRemainingSeconds => throw _privateConstructorUsedError;
  String? get resumedAt => throw _privateConstructorUsedError;
  BlindLevelData get currentBlinds => throw _privateConstructorUsedError;
  BlindLevelData get nextBlinds => throw _privateConstructorUsedError;
  int get playersRemaining => throw _privateConstructorUsedError;
  int get playersTotal => throw _privateConstructorUsedError;
  int get averageStack => throw _privateConstructorUsedError;
  int get totalChips => throw _privateConstructorUsedError;
  int get prizePool => throw _privateConstructorUsedError;
  bool get anteActive => throw _privateConstructorUsedError;
  List<PlayerState> get players => throw _privateConstructorUsedError;
  List<TableState> get tables => throw _privateConstructorUsedError;
  int get revision => throw _privateConstructorUsedError;
  DateTime get lastUpdated => throw _privateConstructorUsedError;

  /// Serializes this GameState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameStateCopyWith<GameState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameStateCopyWith<$Res> {
  factory $GameStateCopyWith(GameState value, $Res Function(GameState) then) =
      _$GameStateCopyWithImpl<$Res, GameState>;
  @useResult
  $Res call({
    String gameId,
    int currentLevel,
    String status,
    DateTime? startedAt,
    DateTime? pausedAt,
    int pausedRemainingSeconds,
    String? resumedAt,
    BlindLevelData currentBlinds,
    BlindLevelData nextBlinds,
    int playersRemaining,
    int playersTotal,
    int averageStack,
    int totalChips,
    int prizePool,
    bool anteActive,
    List<PlayerState> players,
    List<TableState> tables,
    int revision,
    DateTime lastUpdated,
  });

  $BlindLevelDataCopyWith<$Res> get currentBlinds;
  $BlindLevelDataCopyWith<$Res> get nextBlinds;
}

/// @nodoc
class _$GameStateCopyWithImpl<$Res, $Val extends GameState>
    implements $GameStateCopyWith<$Res> {
  _$GameStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gameId = null,
    Object? currentLevel = null,
    Object? status = null,
    Object? startedAt = freezed,
    Object? pausedAt = freezed,
    Object? pausedRemainingSeconds = null,
    Object? resumedAt = freezed,
    Object? currentBlinds = null,
    Object? nextBlinds = null,
    Object? playersRemaining = null,
    Object? playersTotal = null,
    Object? averageStack = null,
    Object? totalChips = null,
    Object? prizePool = null,
    Object? anteActive = null,
    Object? players = null,
    Object? tables = null,
    Object? revision = null,
    Object? lastUpdated = null,
  }) {
    return _then(
      _value.copyWith(
            gameId: null == gameId
                ? _value.gameId
                : gameId // ignore: cast_nullable_to_non_nullable
                      as String,
            currentLevel: null == currentLevel
                ? _value.currentLevel
                : currentLevel // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            startedAt: freezed == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            pausedAt: freezed == pausedAt
                ? _value.pausedAt
                : pausedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            pausedRemainingSeconds: null == pausedRemainingSeconds
                ? _value.pausedRemainingSeconds
                : pausedRemainingSeconds // ignore: cast_nullable_to_non_nullable
                      as int,
            resumedAt: freezed == resumedAt
                ? _value.resumedAt
                : resumedAt // ignore: cast_nullable_to_non_nullable
                      as String?,
            currentBlinds: null == currentBlinds
                ? _value.currentBlinds
                : currentBlinds // ignore: cast_nullable_to_non_nullable
                      as BlindLevelData,
            nextBlinds: null == nextBlinds
                ? _value.nextBlinds
                : nextBlinds // ignore: cast_nullable_to_non_nullable
                      as BlindLevelData,
            playersRemaining: null == playersRemaining
                ? _value.playersRemaining
                : playersRemaining // ignore: cast_nullable_to_non_nullable
                      as int,
            playersTotal: null == playersTotal
                ? _value.playersTotal
                : playersTotal // ignore: cast_nullable_to_non_nullable
                      as int,
            averageStack: null == averageStack
                ? _value.averageStack
                : averageStack // ignore: cast_nullable_to_non_nullable
                      as int,
            totalChips: null == totalChips
                ? _value.totalChips
                : totalChips // ignore: cast_nullable_to_non_nullable
                      as int,
            prizePool: null == prizePool
                ? _value.prizePool
                : prizePool // ignore: cast_nullable_to_non_nullable
                      as int,
            anteActive: null == anteActive
                ? _value.anteActive
                : anteActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            players: null == players
                ? _value.players
                : players // ignore: cast_nullable_to_non_nullable
                      as List<PlayerState>,
            tables: null == tables
                ? _value.tables
                : tables // ignore: cast_nullable_to_non_nullable
                      as List<TableState>,
            revision: null == revision
                ? _value.revision
                : revision // ignore: cast_nullable_to_non_nullable
                      as int,
            lastUpdated: null == lastUpdated
                ? _value.lastUpdated
                : lastUpdated // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BlindLevelDataCopyWith<$Res> get currentBlinds {
    return $BlindLevelDataCopyWith<$Res>(_value.currentBlinds, (value) {
      return _then(_value.copyWith(currentBlinds: value) as $Val);
    });
  }

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BlindLevelDataCopyWith<$Res> get nextBlinds {
    return $BlindLevelDataCopyWith<$Res>(_value.nextBlinds, (value) {
      return _then(_value.copyWith(nextBlinds: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GameStateImplCopyWith<$Res>
    implements $GameStateCopyWith<$Res> {
  factory _$$GameStateImplCopyWith(
    _$GameStateImpl value,
    $Res Function(_$GameStateImpl) then,
  ) = __$$GameStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String gameId,
    int currentLevel,
    String status,
    DateTime? startedAt,
    DateTime? pausedAt,
    int pausedRemainingSeconds,
    String? resumedAt,
    BlindLevelData currentBlinds,
    BlindLevelData nextBlinds,
    int playersRemaining,
    int playersTotal,
    int averageStack,
    int totalChips,
    int prizePool,
    bool anteActive,
    List<PlayerState> players,
    List<TableState> tables,
    int revision,
    DateTime lastUpdated,
  });

  @override
  $BlindLevelDataCopyWith<$Res> get currentBlinds;
  @override
  $BlindLevelDataCopyWith<$Res> get nextBlinds;
}

/// @nodoc
class __$$GameStateImplCopyWithImpl<$Res>
    extends _$GameStateCopyWithImpl<$Res, _$GameStateImpl>
    implements _$$GameStateImplCopyWith<$Res> {
  __$$GameStateImplCopyWithImpl(
    _$GameStateImpl _value,
    $Res Function(_$GameStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? gameId = null,
    Object? currentLevel = null,
    Object? status = null,
    Object? startedAt = freezed,
    Object? pausedAt = freezed,
    Object? pausedRemainingSeconds = null,
    Object? resumedAt = freezed,
    Object? currentBlinds = null,
    Object? nextBlinds = null,
    Object? playersRemaining = null,
    Object? playersTotal = null,
    Object? averageStack = null,
    Object? totalChips = null,
    Object? prizePool = null,
    Object? anteActive = null,
    Object? players = null,
    Object? tables = null,
    Object? revision = null,
    Object? lastUpdated = null,
  }) {
    return _then(
      _$GameStateImpl(
        gameId: null == gameId
            ? _value.gameId
            : gameId // ignore: cast_nullable_to_non_nullable
                  as String,
        currentLevel: null == currentLevel
            ? _value.currentLevel
            : currentLevel // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        startedAt: freezed == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        pausedAt: freezed == pausedAt
            ? _value.pausedAt
            : pausedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        pausedRemainingSeconds: null == pausedRemainingSeconds
            ? _value.pausedRemainingSeconds
            : pausedRemainingSeconds // ignore: cast_nullable_to_non_nullable
                  as int,
        resumedAt: freezed == resumedAt
            ? _value.resumedAt
            : resumedAt // ignore: cast_nullable_to_non_nullable
                  as String?,
        currentBlinds: null == currentBlinds
            ? _value.currentBlinds
            : currentBlinds // ignore: cast_nullable_to_non_nullable
                  as BlindLevelData,
        nextBlinds: null == nextBlinds
            ? _value.nextBlinds
            : nextBlinds // ignore: cast_nullable_to_non_nullable
                  as BlindLevelData,
        playersRemaining: null == playersRemaining
            ? _value.playersRemaining
            : playersRemaining // ignore: cast_nullable_to_non_nullable
                  as int,
        playersTotal: null == playersTotal
            ? _value.playersTotal
            : playersTotal // ignore: cast_nullable_to_non_nullable
                  as int,
        averageStack: null == averageStack
            ? _value.averageStack
            : averageStack // ignore: cast_nullable_to_non_nullable
                  as int,
        totalChips: null == totalChips
            ? _value.totalChips
            : totalChips // ignore: cast_nullable_to_non_nullable
                  as int,
        prizePool: null == prizePool
            ? _value.prizePool
            : prizePool // ignore: cast_nullable_to_non_nullable
                  as int,
        anteActive: null == anteActive
            ? _value.anteActive
            : anteActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        players: null == players
            ? _value._players
            : players // ignore: cast_nullable_to_non_nullable
                  as List<PlayerState>,
        tables: null == tables
            ? _value._tables
            : tables // ignore: cast_nullable_to_non_nullable
                  as List<TableState>,
        revision: null == revision
            ? _value.revision
            : revision // ignore: cast_nullable_to_non_nullable
                  as int,
        lastUpdated: null == lastUpdated
            ? _value.lastUpdated
            : lastUpdated // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GameStateImpl implements _GameState {
  const _$GameStateImpl({
    required this.gameId,
    required this.currentLevel,
    required this.status,
    required this.startedAt,
    required this.pausedAt,
    required this.pausedRemainingSeconds,
    required this.resumedAt,
    required this.currentBlinds,
    required this.nextBlinds,
    required this.playersRemaining,
    required this.playersTotal,
    required this.averageStack,
    required this.totalChips,
    required this.prizePool,
    required this.anteActive,
    required final List<PlayerState> players,
    required final List<TableState> tables,
    required this.revision,
    required this.lastUpdated,
  }) : _players = players,
       _tables = tables;

  factory _$GameStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameStateImplFromJson(json);

  @override
  final String gameId;
  @override
  final int currentLevel;
  @override
  final String status;
  @override
  final DateTime? startedAt;
  @override
  final DateTime? pausedAt;
  @override
  final int pausedRemainingSeconds;
  @override
  final String? resumedAt;
  @override
  final BlindLevelData currentBlinds;
  @override
  final BlindLevelData nextBlinds;
  @override
  final int playersRemaining;
  @override
  final int playersTotal;
  @override
  final int averageStack;
  @override
  final int totalChips;
  @override
  final int prizePool;
  @override
  final bool anteActive;
  final List<PlayerState> _players;
  @override
  List<PlayerState> get players {
    if (_players is EqualUnmodifiableListView) return _players;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_players);
  }

  final List<TableState> _tables;
  @override
  List<TableState> get tables {
    if (_tables is EqualUnmodifiableListView) return _tables;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tables);
  }

  @override
  final int revision;
  @override
  final DateTime lastUpdated;

  @override
  String toString() {
    return 'GameState(gameId: $gameId, currentLevel: $currentLevel, status: $status, startedAt: $startedAt, pausedAt: $pausedAt, pausedRemainingSeconds: $pausedRemainingSeconds, resumedAt: $resumedAt, currentBlinds: $currentBlinds, nextBlinds: $nextBlinds, playersRemaining: $playersRemaining, playersTotal: $playersTotal, averageStack: $averageStack, totalChips: $totalChips, prizePool: $prizePool, anteActive: $anteActive, players: $players, tables: $tables, revision: $revision, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameStateImpl &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.currentLevel, currentLevel) ||
                other.currentLevel == currentLevel) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.pausedAt, pausedAt) ||
                other.pausedAt == pausedAt) &&
            (identical(other.pausedRemainingSeconds, pausedRemainingSeconds) ||
                other.pausedRemainingSeconds == pausedRemainingSeconds) &&
            (identical(other.resumedAt, resumedAt) ||
                other.resumedAt == resumedAt) &&
            (identical(other.currentBlinds, currentBlinds) ||
                other.currentBlinds == currentBlinds) &&
            (identical(other.nextBlinds, nextBlinds) ||
                other.nextBlinds == nextBlinds) &&
            (identical(other.playersRemaining, playersRemaining) ||
                other.playersRemaining == playersRemaining) &&
            (identical(other.playersTotal, playersTotal) ||
                other.playersTotal == playersTotal) &&
            (identical(other.averageStack, averageStack) ||
                other.averageStack == averageStack) &&
            (identical(other.totalChips, totalChips) ||
                other.totalChips == totalChips) &&
            (identical(other.prizePool, prizePool) ||
                other.prizePool == prizePool) &&
            (identical(other.anteActive, anteActive) ||
                other.anteActive == anteActive) &&
            const DeepCollectionEquality().equals(other._players, _players) &&
            const DeepCollectionEquality().equals(other._tables, _tables) &&
            (identical(other.revision, revision) ||
                other.revision == revision) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    gameId,
    currentLevel,
    status,
    startedAt,
    pausedAt,
    pausedRemainingSeconds,
    resumedAt,
    currentBlinds,
    nextBlinds,
    playersRemaining,
    playersTotal,
    averageStack,
    totalChips,
    prizePool,
    anteActive,
    const DeepCollectionEquality().hash(_players),
    const DeepCollectionEquality().hash(_tables),
    revision,
    lastUpdated,
  ]);

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameStateImplCopyWith<_$GameStateImpl> get copyWith =>
      __$$GameStateImplCopyWithImpl<_$GameStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameStateImplToJson(this);
  }
}

abstract class _GameState implements GameState {
  const factory _GameState({
    required final String gameId,
    required final int currentLevel,
    required final String status,
    required final DateTime? startedAt,
    required final DateTime? pausedAt,
    required final int pausedRemainingSeconds,
    required final String? resumedAt,
    required final BlindLevelData currentBlinds,
    required final BlindLevelData nextBlinds,
    required final int playersRemaining,
    required final int playersTotal,
    required final int averageStack,
    required final int totalChips,
    required final int prizePool,
    required final bool anteActive,
    required final List<PlayerState> players,
    required final List<TableState> tables,
    required final int revision,
    required final DateTime lastUpdated,
  }) = _$GameStateImpl;

  factory _GameState.fromJson(Map<String, dynamic> json) =
      _$GameStateImpl.fromJson;

  @override
  String get gameId;
  @override
  int get currentLevel;
  @override
  String get status;
  @override
  DateTime? get startedAt;
  @override
  DateTime? get pausedAt;
  @override
  int get pausedRemainingSeconds;
  @override
  String? get resumedAt;
  @override
  BlindLevelData get currentBlinds;
  @override
  BlindLevelData get nextBlinds;
  @override
  int get playersRemaining;
  @override
  int get playersTotal;
  @override
  int get averageStack;
  @override
  int get totalChips;
  @override
  int get prizePool;
  @override
  bool get anteActive;
  @override
  List<PlayerState> get players;
  @override
  List<TableState> get tables;
  @override
  int get revision;
  @override
  DateTime get lastUpdated;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameStateImplCopyWith<_$GameStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BlindLevelData _$BlindLevelDataFromJson(Map<String, dynamic> json) {
  return _BlindLevelData.fromJson(json);
}

/// @nodoc
mixin _$BlindLevelData {
  int get smallBlind => throw _privateConstructorUsedError;
  int get bigBlind => throw _privateConstructorUsedError;
  int get ante => throw _privateConstructorUsedError;

  /// Serializes this BlindLevelData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BlindLevelData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BlindLevelDataCopyWith<BlindLevelData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BlindLevelDataCopyWith<$Res> {
  factory $BlindLevelDataCopyWith(
    BlindLevelData value,
    $Res Function(BlindLevelData) then,
  ) = _$BlindLevelDataCopyWithImpl<$Res, BlindLevelData>;
  @useResult
  $Res call({int smallBlind, int bigBlind, int ante});
}

/// @nodoc
class _$BlindLevelDataCopyWithImpl<$Res, $Val extends BlindLevelData>
    implements $BlindLevelDataCopyWith<$Res> {
  _$BlindLevelDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BlindLevelData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? smallBlind = null,
    Object? bigBlind = null,
    Object? ante = null,
  }) {
    return _then(
      _value.copyWith(
            smallBlind: null == smallBlind
                ? _value.smallBlind
                : smallBlind // ignore: cast_nullable_to_non_nullable
                      as int,
            bigBlind: null == bigBlind
                ? _value.bigBlind
                : bigBlind // ignore: cast_nullable_to_non_nullable
                      as int,
            ante: null == ante
                ? _value.ante
                : ante // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BlindLevelDataImplCopyWith<$Res>
    implements $BlindLevelDataCopyWith<$Res> {
  factory _$$BlindLevelDataImplCopyWith(
    _$BlindLevelDataImpl value,
    $Res Function(_$BlindLevelDataImpl) then,
  ) = __$$BlindLevelDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int smallBlind, int bigBlind, int ante});
}

/// @nodoc
class __$$BlindLevelDataImplCopyWithImpl<$Res>
    extends _$BlindLevelDataCopyWithImpl<$Res, _$BlindLevelDataImpl>
    implements _$$BlindLevelDataImplCopyWith<$Res> {
  __$$BlindLevelDataImplCopyWithImpl(
    _$BlindLevelDataImpl _value,
    $Res Function(_$BlindLevelDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BlindLevelData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? smallBlind = null,
    Object? bigBlind = null,
    Object? ante = null,
  }) {
    return _then(
      _$BlindLevelDataImpl(
        smallBlind: null == smallBlind
            ? _value.smallBlind
            : smallBlind // ignore: cast_nullable_to_non_nullable
                  as int,
        bigBlind: null == bigBlind
            ? _value.bigBlind
            : bigBlind // ignore: cast_nullable_to_non_nullable
                  as int,
        ante: null == ante
            ? _value.ante
            : ante // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BlindLevelDataImpl implements _BlindLevelData {
  const _$BlindLevelDataImpl({
    required this.smallBlind,
    required this.bigBlind,
    required this.ante,
  });

  factory _$BlindLevelDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$BlindLevelDataImplFromJson(json);

  @override
  final int smallBlind;
  @override
  final int bigBlind;
  @override
  final int ante;

  @override
  String toString() {
    return 'BlindLevelData(smallBlind: $smallBlind, bigBlind: $bigBlind, ante: $ante)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BlindLevelDataImpl &&
            (identical(other.smallBlind, smallBlind) ||
                other.smallBlind == smallBlind) &&
            (identical(other.bigBlind, bigBlind) ||
                other.bigBlind == bigBlind) &&
            (identical(other.ante, ante) || other.ante == ante));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, smallBlind, bigBlind, ante);

  /// Create a copy of BlindLevelData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BlindLevelDataImplCopyWith<_$BlindLevelDataImpl> get copyWith =>
      __$$BlindLevelDataImplCopyWithImpl<_$BlindLevelDataImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BlindLevelDataImplToJson(this);
  }
}

abstract class _BlindLevelData implements BlindLevelData {
  const factory _BlindLevelData({
    required final int smallBlind,
    required final int bigBlind,
    required final int ante,
  }) = _$BlindLevelDataImpl;

  factory _BlindLevelData.fromJson(Map<String, dynamic> json) =
      _$BlindLevelDataImpl.fromJson;

  @override
  int get smallBlind;
  @override
  int get bigBlind;
  @override
  int get ante;

  /// Create a copy of BlindLevelData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BlindLevelDataImplCopyWith<_$BlindLevelDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PlayerState _$PlayerStateFromJson(Map<String, dynamic> json) {
  return _PlayerState.fromJson(json);
}

/// @nodoc
mixin _$PlayerState {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get tableNo => throw _privateConstructorUsedError;
  int get seatNo => throw _privateConstructorUsedError;
  int get stack => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  bool get isGuest => throw _privateConstructorUsedError;
  int? get finishPosition => throw _privateConstructorUsedError;

  /// Serializes this PlayerState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlayerStateCopyWith<PlayerState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlayerStateCopyWith<$Res> {
  factory $PlayerStateCopyWith(
    PlayerState value,
    $Res Function(PlayerState) then,
  ) = _$PlayerStateCopyWithImpl<$Res, PlayerState>;
  @useResult
  $Res call({
    String id,
    String name,
    int tableNo,
    int seatNo,
    int stack,
    String status,
    bool isGuest,
    int? finishPosition,
  });
}

/// @nodoc
class _$PlayerStateCopyWithImpl<$Res, $Val extends PlayerState>
    implements $PlayerStateCopyWith<$Res> {
  _$PlayerStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? tableNo = null,
    Object? seatNo = null,
    Object? stack = null,
    Object? status = null,
    Object? isGuest = null,
    Object? finishPosition = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            tableNo: null == tableNo
                ? _value.tableNo
                : tableNo // ignore: cast_nullable_to_non_nullable
                      as int,
            seatNo: null == seatNo
                ? _value.seatNo
                : seatNo // ignore: cast_nullable_to_non_nullable
                      as int,
            stack: null == stack
                ? _value.stack
                : stack // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            isGuest: null == isGuest
                ? _value.isGuest
                : isGuest // ignore: cast_nullable_to_non_nullable
                      as bool,
            finishPosition: freezed == finishPosition
                ? _value.finishPosition
                : finishPosition // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlayerStateImplCopyWith<$Res>
    implements $PlayerStateCopyWith<$Res> {
  factory _$$PlayerStateImplCopyWith(
    _$PlayerStateImpl value,
    $Res Function(_$PlayerStateImpl) then,
  ) = __$$PlayerStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    int tableNo,
    int seatNo,
    int stack,
    String status,
    bool isGuest,
    int? finishPosition,
  });
}

/// @nodoc
class __$$PlayerStateImplCopyWithImpl<$Res>
    extends _$PlayerStateCopyWithImpl<$Res, _$PlayerStateImpl>
    implements _$$PlayerStateImplCopyWith<$Res> {
  __$$PlayerStateImplCopyWithImpl(
    _$PlayerStateImpl _value,
    $Res Function(_$PlayerStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? tableNo = null,
    Object? seatNo = null,
    Object? stack = null,
    Object? status = null,
    Object? isGuest = null,
    Object? finishPosition = freezed,
  }) {
    return _then(
      _$PlayerStateImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        tableNo: null == tableNo
            ? _value.tableNo
            : tableNo // ignore: cast_nullable_to_non_nullable
                  as int,
        seatNo: null == seatNo
            ? _value.seatNo
            : seatNo // ignore: cast_nullable_to_non_nullable
                  as int,
        stack: null == stack
            ? _value.stack
            : stack // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        isGuest: null == isGuest
            ? _value.isGuest
            : isGuest // ignore: cast_nullable_to_non_nullable
                  as bool,
        finishPosition: freezed == finishPosition
            ? _value.finishPosition
            : finishPosition // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlayerStateImpl implements _PlayerState {
  const _$PlayerStateImpl({
    required this.id,
    required this.name,
    required this.tableNo,
    required this.seatNo,
    required this.stack,
    required this.status,
    this.isGuest = false,
    this.finishPosition,
  });

  factory _$PlayerStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlayerStateImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final int tableNo;
  @override
  final int seatNo;
  @override
  final int stack;
  @override
  final String status;
  @override
  @JsonKey()
  final bool isGuest;
  @override
  final int? finishPosition;

  @override
  String toString() {
    return 'PlayerState(id: $id, name: $name, tableNo: $tableNo, seatNo: $seatNo, stack: $stack, status: $status, isGuest: $isGuest, finishPosition: $finishPosition)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayerStateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.tableNo, tableNo) || other.tableNo == tableNo) &&
            (identical(other.seatNo, seatNo) || other.seatNo == seatNo) &&
            (identical(other.stack, stack) || other.stack == stack) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isGuest, isGuest) || other.isGuest == isGuest) &&
            (identical(other.finishPosition, finishPosition) ||
                other.finishPosition == finishPosition));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    tableNo,
    seatNo,
    stack,
    status,
    isGuest,
    finishPosition,
  );

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayerStateImplCopyWith<_$PlayerStateImpl> get copyWith =>
      __$$PlayerStateImplCopyWithImpl<_$PlayerStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlayerStateImplToJson(this);
  }
}

abstract class _PlayerState implements PlayerState {
  const factory _PlayerState({
    required final String id,
    required final String name,
    required final int tableNo,
    required final int seatNo,
    required final int stack,
    required final String status,
    final bool isGuest,
    final int? finishPosition,
  }) = _$PlayerStateImpl;

  factory _PlayerState.fromJson(Map<String, dynamic> json) =
      _$PlayerStateImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  int get tableNo;
  @override
  int get seatNo;
  @override
  int get stack;
  @override
  String get status;
  @override
  bool get isGuest;
  @override
  int? get finishPosition;

  /// Create a copy of PlayerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayerStateImplCopyWith<_$PlayerStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TableState _$TableStateFromJson(Map<String, dynamic> json) {
  return _TableState.fromJson(json);
}

/// @nodoc
mixin _$TableState {
  int get tableNo => throw _privateConstructorUsedError;
  List<SeatState> get seats => throw _privateConstructorUsedError;
  int get playerCount => throw _privateConstructorUsedError;

  /// Serializes this TableState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TableState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TableStateCopyWith<TableState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TableStateCopyWith<$Res> {
  factory $TableStateCopyWith(
    TableState value,
    $Res Function(TableState) then,
  ) = _$TableStateCopyWithImpl<$Res, TableState>;
  @useResult
  $Res call({int tableNo, List<SeatState> seats, int playerCount});
}

/// @nodoc
class _$TableStateCopyWithImpl<$Res, $Val extends TableState>
    implements $TableStateCopyWith<$Res> {
  _$TableStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TableState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tableNo = null,
    Object? seats = null,
    Object? playerCount = null,
  }) {
    return _then(
      _value.copyWith(
            tableNo: null == tableNo
                ? _value.tableNo
                : tableNo // ignore: cast_nullable_to_non_nullable
                      as int,
            seats: null == seats
                ? _value.seats
                : seats // ignore: cast_nullable_to_non_nullable
                      as List<SeatState>,
            playerCount: null == playerCount
                ? _value.playerCount
                : playerCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TableStateImplCopyWith<$Res>
    implements $TableStateCopyWith<$Res> {
  factory _$$TableStateImplCopyWith(
    _$TableStateImpl value,
    $Res Function(_$TableStateImpl) then,
  ) = __$$TableStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int tableNo, List<SeatState> seats, int playerCount});
}

/// @nodoc
class __$$TableStateImplCopyWithImpl<$Res>
    extends _$TableStateCopyWithImpl<$Res, _$TableStateImpl>
    implements _$$TableStateImplCopyWith<$Res> {
  __$$TableStateImplCopyWithImpl(
    _$TableStateImpl _value,
    $Res Function(_$TableStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TableState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tableNo = null,
    Object? seats = null,
    Object? playerCount = null,
  }) {
    return _then(
      _$TableStateImpl(
        tableNo: null == tableNo
            ? _value.tableNo
            : tableNo // ignore: cast_nullable_to_non_nullable
                  as int,
        seats: null == seats
            ? _value._seats
            : seats // ignore: cast_nullable_to_non_nullable
                  as List<SeatState>,
        playerCount: null == playerCount
            ? _value.playerCount
            : playerCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TableStateImpl implements _TableState {
  const _$TableStateImpl({
    required this.tableNo,
    required final List<SeatState> seats,
    required this.playerCount,
  }) : _seats = seats;

  factory _$TableStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$TableStateImplFromJson(json);

  @override
  final int tableNo;
  final List<SeatState> _seats;
  @override
  List<SeatState> get seats {
    if (_seats is EqualUnmodifiableListView) return _seats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_seats);
  }

  @override
  final int playerCount;

  @override
  String toString() {
    return 'TableState(tableNo: $tableNo, seats: $seats, playerCount: $playerCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TableStateImpl &&
            (identical(other.tableNo, tableNo) || other.tableNo == tableNo) &&
            const DeepCollectionEquality().equals(other._seats, _seats) &&
            (identical(other.playerCount, playerCount) ||
                other.playerCount == playerCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    tableNo,
    const DeepCollectionEquality().hash(_seats),
    playerCount,
  );

  /// Create a copy of TableState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TableStateImplCopyWith<_$TableStateImpl> get copyWith =>
      __$$TableStateImplCopyWithImpl<_$TableStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TableStateImplToJson(this);
  }
}

abstract class _TableState implements TableState {
  const factory _TableState({
    required final int tableNo,
    required final List<SeatState> seats,
    required final int playerCount,
  }) = _$TableStateImpl;

  factory _TableState.fromJson(Map<String, dynamic> json) =
      _$TableStateImpl.fromJson;

  @override
  int get tableNo;
  @override
  List<SeatState> get seats;
  @override
  int get playerCount;

  /// Create a copy of TableState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TableStateImplCopyWith<_$TableStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SeatState _$SeatStateFromJson(Map<String, dynamic> json) {
  return _SeatState.fromJson(json);
}

/// @nodoc
mixin _$SeatState {
  int get seatNo => throw _privateConstructorUsedError;
  String? get playerId => throw _privateConstructorUsedError;
  String? get playerName => throw _privateConstructorUsedError;
  bool get isEmpty => throw _privateConstructorUsedError;

  /// Serializes this SeatState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SeatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SeatStateCopyWith<SeatState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SeatStateCopyWith<$Res> {
  factory $SeatStateCopyWith(SeatState value, $Res Function(SeatState) then) =
      _$SeatStateCopyWithImpl<$Res, SeatState>;
  @useResult
  $Res call({int seatNo, String? playerId, String? playerName, bool isEmpty});
}

/// @nodoc
class _$SeatStateCopyWithImpl<$Res, $Val extends SeatState>
    implements $SeatStateCopyWith<$Res> {
  _$SeatStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SeatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seatNo = null,
    Object? playerId = freezed,
    Object? playerName = freezed,
    Object? isEmpty = null,
  }) {
    return _then(
      _value.copyWith(
            seatNo: null == seatNo
                ? _value.seatNo
                : seatNo // ignore: cast_nullable_to_non_nullable
                      as int,
            playerId: freezed == playerId
                ? _value.playerId
                : playerId // ignore: cast_nullable_to_non_nullable
                      as String?,
            playerName: freezed == playerName
                ? _value.playerName
                : playerName // ignore: cast_nullable_to_non_nullable
                      as String?,
            isEmpty: null == isEmpty
                ? _value.isEmpty
                : isEmpty // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SeatStateImplCopyWith<$Res>
    implements $SeatStateCopyWith<$Res> {
  factory _$$SeatStateImplCopyWith(
    _$SeatStateImpl value,
    $Res Function(_$SeatStateImpl) then,
  ) = __$$SeatStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int seatNo, String? playerId, String? playerName, bool isEmpty});
}

/// @nodoc
class __$$SeatStateImplCopyWithImpl<$Res>
    extends _$SeatStateCopyWithImpl<$Res, _$SeatStateImpl>
    implements _$$SeatStateImplCopyWith<$Res> {
  __$$SeatStateImplCopyWithImpl(
    _$SeatStateImpl _value,
    $Res Function(_$SeatStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SeatState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? seatNo = null,
    Object? playerId = freezed,
    Object? playerName = freezed,
    Object? isEmpty = null,
  }) {
    return _then(
      _$SeatStateImpl(
        seatNo: null == seatNo
            ? _value.seatNo
            : seatNo // ignore: cast_nullable_to_non_nullable
                  as int,
        playerId: freezed == playerId
            ? _value.playerId
            : playerId // ignore: cast_nullable_to_non_nullable
                  as String?,
        playerName: freezed == playerName
            ? _value.playerName
            : playerName // ignore: cast_nullable_to_non_nullable
                  as String?,
        isEmpty: null == isEmpty
            ? _value.isEmpty
            : isEmpty // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SeatStateImpl implements _SeatState {
  const _$SeatStateImpl({
    required this.seatNo,
    this.playerId,
    this.playerName,
    this.isEmpty = false,
  });

  factory _$SeatStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SeatStateImplFromJson(json);

  @override
  final int seatNo;
  @override
  final String? playerId;
  @override
  final String? playerName;
  @override
  @JsonKey()
  final bool isEmpty;

  @override
  String toString() {
    return 'SeatState(seatNo: $seatNo, playerId: $playerId, playerName: $playerName, isEmpty: $isEmpty)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SeatStateImpl &&
            (identical(other.seatNo, seatNo) || other.seatNo == seatNo) &&
            (identical(other.playerId, playerId) ||
                other.playerId == playerId) &&
            (identical(other.playerName, playerName) ||
                other.playerName == playerName) &&
            (identical(other.isEmpty, isEmpty) || other.isEmpty == isEmpty));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, seatNo, playerId, playerName, isEmpty);

  /// Create a copy of SeatState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SeatStateImplCopyWith<_$SeatStateImpl> get copyWith =>
      __$$SeatStateImplCopyWithImpl<_$SeatStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SeatStateImplToJson(this);
  }
}

abstract class _SeatState implements SeatState {
  const factory _SeatState({
    required final int seatNo,
    final String? playerId,
    final String? playerName,
    final bool isEmpty,
  }) = _$SeatStateImpl;

  factory _SeatState.fromJson(Map<String, dynamic> json) =
      _$SeatStateImpl.fromJson;

  @override
  int get seatNo;
  @override
  String? get playerId;
  @override
  String? get playerName;
  @override
  bool get isEmpty;

  /// Create a copy of SeatState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SeatStateImplCopyWith<_$SeatStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
