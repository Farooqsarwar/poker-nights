import 'package:flutter/foundation.dart';
import 'package:localstore/localstore.dart';

/// How this particular screen shows the tournament (addendum §3's "Advanced
/// TV/display customization ... and personalization", §8's readability bar).
///
/// Stored **per device**, not per account, and that is the right scope: the
/// laptop wedged at the end of the table has its own size, its own distance
/// from the players and its own job. The same host's phone should not inherit
/// the text scale that suits a 55-inch screen across the room.
///
/// Every field has a safe default, so a TV that has never been configured —
/// or whose storage is unreadable — behaves exactly as it did before this
/// existed.
@immutable
class TvDisplaySettings {
  const TvDisplaySettings({
    this.textScale = 1.0,
    this.showLeaderboard = true,
    this.showPayouts = true,
    this.showUpcoming = true,
    this.rotateSeconds = 8,
  });

  /// Multiplies the automatic width-derived scale.
  ///
  /// The automatic scale handles screen SIZE; this handles how far away the
  /// players are sitting, which no amount of measuring the viewport can know.
  final double textScale;

  final bool showLeaderboard;
  final bool showPayouts;
  final bool showUpcoming;

  /// How long each rotating panel holds before the next.
  final int rotateSeconds;

  static const double minTextScale = 0.7;
  static const double maxTextScale = 2.0;
  static const List<int> rotatePresets = [5, 8, 12, 20, 30];

  /// A screen with every panel switched off would rotate through nothing, so
  /// the caller is told to fall back rather than render an empty box.
  bool get hasAnyPanel => showLeaderboard || showPayouts || showUpcoming;

  TvDisplaySettings copyWith({
    double? textScale,
    bool? showLeaderboard,
    bool? showPayouts,
    bool? showUpcoming,
    int? rotateSeconds,
  }) =>
      TvDisplaySettings(
        textScale: (textScale ?? this.textScale)
            .clamp(minTextScale, maxTextScale)
            .toDouble(),
        showLeaderboard: showLeaderboard ?? this.showLeaderboard,
        showPayouts: showPayouts ?? this.showPayouts,
        showUpcoming: showUpcoming ?? this.showUpcoming,
        rotateSeconds: rotateSeconds ?? this.rotateSeconds,
      );

  Map<String, dynamic> toMap() => {
        'textScale': textScale,
        'showLeaderboard': showLeaderboard,
        'showPayouts': showPayouts,
        'showUpcoming': showUpcoming,
        'rotateSeconds': rotateSeconds,
      };

  /// Every field falls back to its default rather than throwing. A TV that
  /// cannot read one stored value should still show the tournament.
  factory TvDisplaySettings.fromMap(Map<String, dynamic> m) =>
      const TvDisplaySettings().copyWith(
        textScale: (m['textScale'] as num?)?.toDouble(),
        showLeaderboard: m['showLeaderboard'] as bool?,
        showPayouts: m['showPayouts'] as bool?,
        showUpcoming: m['showUpcoming'] as bool?,
        rotateSeconds: (m['rotateSeconds'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is TvDisplaySettings &&
      other.textScale == textScale &&
      other.showLeaderboard == showLeaderboard &&
      other.showPayouts == showPayouts &&
      other.showUpcoming == showUpcoming &&
      other.rotateSeconds == rotateSeconds;

  @override
  int get hashCode => Object.hash(
        textScale,
        showLeaderboard,
        showPayouts,
        showUpcoming,
        rotateSeconds,
      );
}

/// Reads and writes [TvDisplaySettings] on this device.
abstract final class TvDisplayStore {
  static final _db = Localstore.instance;
  static const _collection = 'tv_display';
  static const _docId = 'settings';

  static Future<TvDisplaySettings> load() async {
    try {
      final doc = await _db.collection(_collection).doc(_docId).get();
      if (doc == null) return const TvDisplaySettings();
      return TvDisplaySettings.fromMap(doc);
    } catch (e) {
      debugPrint('TvDisplayStore: could not read settings: $e');
      return const TvDisplaySettings();
    }
  }

  static Future<void> save(TvDisplaySettings settings) async {
    try {
      await _db.collection(_collection).doc(_docId).set(settings.toMap());
    } catch (e) {
      // A TV that cannot persist its settings should still honour them for
      // the rest of the night rather than refusing the change.
      debugPrint('TvDisplayStore: could not save settings: $e');
    }
  }
}
