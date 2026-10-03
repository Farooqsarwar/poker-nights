// E17 — Automations: every automatic behaviour, client-side only.
//
// No Cloud Functions. All visuals, haptics triggers, announcements and
// formatting are pure Dart so offline host phones behave identically.
// UI listens to AppProvider.levelFlashSeq / clockPulseSeq via notifyListeners.
import 'formatters.dart';

class AutomationsService {
  const AutomationsService._();

  /// Rule 14 announcement: Level {n}, {SB} / {BB}, {mm} minutes left.
  /// Called at level change only, never every second.
  static String announceLevelChange(LevelChangeInfo info) {
    if (info.isBreak) return 'Break, ${info.minutesLeft} minutes left';
    return 'Level ${info.level}, ${info.sb} / ${info.bb}, '
        '${info.minutesLeft} minutes left';
  }

  /// Rule 15: last five seconds show large 5-4-3-2-1 on every Scoreboard.
  static bool isCountdownUrgency(int secondsRemaining) =>
      secondsRemaining >= 1 && secondsRemaining <= 5;

  /// Rule 15: 1-minute warning moment (with next-level blinds spoken elsewhere).
  static bool isOneMinuteWarning(int secondsRemaining) =>
      secondsRemaining == 60;

  /// 5-minute warning moment before level or break ends.
  static bool isFiveMinuteWarning(int secondsRemaining) =>
      secondsRemaining == 300;

  /// Determines if a haptic pulse should trigger based on remaining seconds.
  static bool shouldTriggerHaptic({required int secondsRemaining}) =>
      secondsRemaining == 60 ||
      (secondsRemaining >= 1 && secondsRemaining <= 5) ||
      secondsRemaining == 0;

  /// Shot-clock countdown urgency (last 5 seconds).
  static bool isShotClockUrgency(int secondsRemaining) =>
      secondsRemaining <= 5 && secondsRemaining >= 1;

  /// Rule 16: colour never carries meaning alone.
  /// Returns false if a caller tries to rely on colour without word/icon.
  static bool validatesColourState({
    required bool hasWordOrIcon,
  }) =>
      hasWordOrIcon;

  static String liveStatusWord([bool positive = true]) =>
      positive ? 'LIVE' : 'ELIMINATED';

  static String pnlStatusWord({required bool positive}) =>
      positive ? 'Profit' : 'Loss';

  /// Rule 3: touch targets >= 44x44 px. Constant for UI + tests.
  static const double minTapTarget = 44.0;

  static bool meetsTapTarget(double width, double height) =>
      width >= minTapTarget && height >= minTapTarget;

  /// Rule 7: never abbreviate money (1,250 not 1.3K). Chip counts may use k
  /// only on TV/stat tiles — handled by callers. Deduplicated to [Formatters.prize].
  static String formatMoney(num amount) => Formatters.prize(amount);

  /// Bust announcement words (same words voice uses).
  static String announceBust(String playerName, int position) =>
      '$playerName is out, finished $position';

  /// Rebuy / add-on announcement words.
  static String announceRebuyAddOn(String playerName, String action) =>
      '$playerName, $action';

  /// Colour-up announcement helper.
  static String announceColourUp(int level, String chipInfo) =>
      'Colour-up after Level $level: $chipInfo';

  /// Rebuys closing announcement helper.
  static String announceRebuysClosing(int level) =>
      'Rebuys close after Level $level.';

  /// Number of tables needed for given player count.
  static int tablesNeeded({required int players, int maxPerTable = 9}) =>
      players <= 0 ? 0 : (players / maxPerTable).ceil();

  /// Checks if tables need rebalancing (difference > 1 player).
  static bool isTableBalancingNeeded(List<int> tableCounts) {
    if (tableCounts.length < 2) return false;
    var min = tableCounts.first;
    var max = tableCounts.first;
    for (final c in tableCounts) {
      if (c < min) min = c;
      if (c > max) max = c;
    }
    return (max - min) > 1;
  }

  /// Bust times kept per game per group with consent at sign-up and opt-out
  /// per group (D9). Pure client record shape, no server.
  static Map<String, Object?> bustRecord({
    required String gameId,
    required String groupId,
    required DateTime bustTime,
    required int level,
    required int bigBlind,
    required bool consented,
  }) =>
      {
        'gameId': gameId,
        'groupId': groupId,
        'bustTime': bustTime.toIso8601String(),
        'level': level,
        'bigBlind': bigBlind,
        'consented': consented,
      };
}

/// Information about a level change for automation purposes.
class LevelChangeInfo {
  LevelChangeInfo({
    required this.level,
    required this.sb,
    required this.bb,
    required this.ante,
    required this.minutesLeft,
    required this.isBreak,
  });

  final int level;
  final int sb;
  final int bb;
  final int ante;
  final int minutesLeft;
  final bool isBreak;
}
