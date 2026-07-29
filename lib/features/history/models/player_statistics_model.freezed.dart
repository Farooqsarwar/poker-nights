// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'player_statistics_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PlayerStatistics _$PlayerStatisticsFromJson(Map<String, dynamic> json) {
  return _PlayerStatistics.fromJson(json);
}

/// @nodoc
mixin _$PlayerStatistics {
  String get playerId => throw _privateConstructorUsedError;
  String get playerName => throw _privateConstructorUsedError;
  int get gamesPlayed => throw _privateConstructorUsedError;
  int get wins => throw _privateConstructorUsedError;
  int get podiumFinishes => throw _privateConstructorUsedError;
  double get averageFinish => throw _privateConstructorUsedError;
  int get knockouts => throw _privateConstructorUsedError;

  /// Serializes this PlayerStatistics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlayerStatistics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlayerStatisticsCopyWith<PlayerStatistics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlayerStatisticsCopyWith<$Res> {
  factory $PlayerStatisticsCopyWith(
    PlayerStatistics value,
    $Res Function(PlayerStatistics) then,
  ) = _$PlayerStatisticsCopyWithImpl<$Res, PlayerStatistics>;
  @useResult
  $Res call({
    String playerId,
    String playerName,
    int gamesPlayed,
    int wins,
    int podiumFinishes,
    double averageFinish,
    int knockouts,
  });
}

/// @nodoc
class _$PlayerStatisticsCopyWithImpl<$Res, $Val extends PlayerStatistics>
    implements $PlayerStatisticsCopyWith<$Res> {
  _$PlayerStatisticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlayerStatistics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? playerId = null,
    Object? playerName = null,
    Object? gamesPlayed = null,
    Object? wins = null,
    Object? podiumFinishes = null,
    Object? averageFinish = null,
    Object? knockouts = null,
  }) {
    return _then(
      _value.copyWith(
            playerId: null == playerId
                ? _value.playerId
                : playerId // ignore: cast_nullable_to_non_nullable
                      as String,
            playerName: null == playerName
                ? _value.playerName
                : playerName // ignore: cast_nullable_to_non_nullable
                      as String,
            gamesPlayed: null == gamesPlayed
                ? _value.gamesPlayed
                : gamesPlayed // ignore: cast_nullable_to_non_nullable
                      as int,
            wins: null == wins
                ? _value.wins
                : wins // ignore: cast_nullable_to_non_nullable
                      as int,
            podiumFinishes: null == podiumFinishes
                ? _value.podiumFinishes
                : podiumFinishes // ignore: cast_nullable_to_non_nullable
                      as int,
            averageFinish: null == averageFinish
                ? _value.averageFinish
                : averageFinish // ignore: cast_nullable_to_non_nullable
                      as double,
            knockouts: null == knockouts
                ? _value.knockouts
                : knockouts // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PlayerStatisticsImplCopyWith<$Res>
    implements $PlayerStatisticsCopyWith<$Res> {
  factory _$$PlayerStatisticsImplCopyWith(
    _$PlayerStatisticsImpl value,
    $Res Function(_$PlayerStatisticsImpl) then,
  ) = __$$PlayerStatisticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String playerId,
    String playerName,
    int gamesPlayed,
    int wins,
    int podiumFinishes,
    double averageFinish,
    int knockouts,
  });
}

/// @nodoc
class __$$PlayerStatisticsImplCopyWithImpl<$Res>
    extends _$PlayerStatisticsCopyWithImpl<$Res, _$PlayerStatisticsImpl>
    implements _$$PlayerStatisticsImplCopyWith<$Res> {
  __$$PlayerStatisticsImplCopyWithImpl(
    _$PlayerStatisticsImpl _value,
    $Res Function(_$PlayerStatisticsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PlayerStatistics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? playerId = null,
    Object? playerName = null,
    Object? gamesPlayed = null,
    Object? wins = null,
    Object? podiumFinishes = null,
    Object? averageFinish = null,
    Object? knockouts = null,
  }) {
    return _then(
      _$PlayerStatisticsImpl(
        playerId: null == playerId
            ? _value.playerId
            : playerId // ignore: cast_nullable_to_non_nullable
                  as String,
        playerName: null == playerName
            ? _value.playerName
            : playerName // ignore: cast_nullable_to_non_nullable
                  as String,
        gamesPlayed: null == gamesPlayed
            ? _value.gamesPlayed
            : gamesPlayed // ignore: cast_nullable_to_non_nullable
                  as int,
        wins: null == wins
            ? _value.wins
            : wins // ignore: cast_nullable_to_non_nullable
                  as int,
        podiumFinishes: null == podiumFinishes
            ? _value.podiumFinishes
            : podiumFinishes // ignore: cast_nullable_to_non_nullable
                  as int,
        averageFinish: null == averageFinish
            ? _value.averageFinish
            : averageFinish // ignore: cast_nullable_to_non_nullable
                  as double,
        knockouts: null == knockouts
            ? _value.knockouts
            : knockouts // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PlayerStatisticsImpl implements _PlayerStatistics {
  const _$PlayerStatisticsImpl({
    required this.playerId,
    required this.playerName,
    required this.gamesPlayed,
    required this.wins,
    required this.podiumFinishes,
    required this.averageFinish,
    required this.knockouts,
  });

  factory _$PlayerStatisticsImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlayerStatisticsImplFromJson(json);

  @override
  final String playerId;
  @override
  final String playerName;
  @override
  final int gamesPlayed;
  @override
  final int wins;
  @override
  final int podiumFinishes;
  @override
  final double averageFinish;
  @override
  final int knockouts;

  @override
  String toString() {
    return 'PlayerStatistics(playerId: $playerId, playerName: $playerName, gamesPlayed: $gamesPlayed, wins: $wins, podiumFinishes: $podiumFinishes, averageFinish: $averageFinish, knockouts: $knockouts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayerStatisticsImpl &&
            (identical(other.playerId, playerId) ||
                other.playerId == playerId) &&
            (identical(other.playerName, playerName) ||
                other.playerName == playerName) &&
            (identical(other.gamesPlayed, gamesPlayed) ||
                other.gamesPlayed == gamesPlayed) &&
            (identical(other.wins, wins) || other.wins == wins) &&
            (identical(other.podiumFinishes, podiumFinishes) ||
                other.podiumFinishes == podiumFinishes) &&
            (identical(other.averageFinish, averageFinish) ||
                other.averageFinish == averageFinish) &&
            (identical(other.knockouts, knockouts) ||
                other.knockouts == knockouts));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    playerId,
    playerName,
    gamesPlayed,
    wins,
    podiumFinishes,
    averageFinish,
    knockouts,
  );

  /// Create a copy of PlayerStatistics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayerStatisticsImplCopyWith<_$PlayerStatisticsImpl> get copyWith =>
      __$$PlayerStatisticsImplCopyWithImpl<_$PlayerStatisticsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PlayerStatisticsImplToJson(this);
  }
}

abstract class _PlayerStatistics implements PlayerStatistics {
  const factory _PlayerStatistics({
    required final String playerId,
    required final String playerName,
    required final int gamesPlayed,
    required final int wins,
    required final int podiumFinishes,
    required final double averageFinish,
    required final int knockouts,
  }) = _$PlayerStatisticsImpl;

  factory _PlayerStatistics.fromJson(Map<String, dynamic> json) =
      _$PlayerStatisticsImpl.fromJson;

  @override
  String get playerId;
  @override
  String get playerName;
  @override
  int get gamesPlayed;
  @override
  int get wins;
  @override
  int get podiumFinishes;
  @override
  double get averageFinish;
  @override
  int get knockouts;

  /// Create a copy of PlayerStatistics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayerStatisticsImplCopyWith<_$PlayerStatisticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
