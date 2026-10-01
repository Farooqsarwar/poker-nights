// E17 — Automations: every automatic behaviour, client-side only.
//
// No Cloud Functions. All visuals, haptics triggers, announcements and
// formatting are pure Dart so offline host phones behave identically.
// UI listens to AppProvider.levelFlashSeq / clockPulseSeq via notifyListeners.

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
  /// only on TV/stat tiles — handled by callers.
  static String formatMoney(num amount) {
    final negative = amount < 0;
    final abs = amount.abs();
    final parts = abs.toStringAsFixed(abs % 1 == 0 ? 0 : 2).split('.');
    final digits = parts[0].split('').reversed.toList();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    final grouped = buf.toString().split('').reversed.join();
    final dec = parts.length > 1 ? '.${parts[1]}' : '';
    return '${negative ? '-' : ''}$grouped$dec';
  }

  /// Bust announcement words (same words voice uses).
  static String announceBust(String playerName, int position) =>
      '$playerName is out, finished $position';

  /// Rebuy / add-on announcement words.
  static String announceRebuyAddOn(String playerName, String action) =>
      '$playerName, $action';

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
