/// A soft shot clock for a slow decision (specification §12).
///
/// §12 gives this one line — "soft shot clock/time bank independent of level
/// timer" — and nothing else. No duration, no trigger, no consequence. So the
/// rules below are decisions, and they are gathered here rather than scattered
/// through a screen so the product owner can change any of them in one place.
///
/// The word that shaped every choice is **soft**. This is a home game: the
/// clock exists so somebody can say "shall we put you on the clock?" without
/// it becoming an argument, and so the answer is a visible countdown rather
/// than six people guessing how long a minute is. It therefore:
///
///  * never folds anybody's hand — it runs out, it says so, and the table
///    decides what that means;
///  * is started deliberately by the host, never automatically. Automatic
///    clocks belong in casinos with floor staff, not at a kitchen table;
///  * runs beside the level timer and never touches it. §12 is explicit that
///    it is "independent of level timer", and a level must not end early
///    because somebody tanked.
class ShotClock {
  const ShotClock({
    required this.playerId,
    required this.endsAt,
    required this.seconds,
  });

  /// Who is on the clock.
  final String playerId;

  /// When it runs out. A timestamp rather than a countdown, for the same
  /// reason the level timer uses one: every device derives the same remaining
  /// time from it without needing to tick in step.
  final DateTime endsAt;

  /// How long it was set for, kept so the UI can show progress.
  final int seconds;

  /// Durations offered. Thirty seconds is the common live-poker default and
  /// sits first; a minute is the gentler choice for a big decision.
  static const List<int> presets = [30, 60, 90];

  /// Default when the host just taps the button.
  static const int defaultSeconds = 30;

  /// Seconds left, floored at zero.
  int remainingAt(DateTime now) {
    final left = endsAt.difference(now).inSeconds;
    return left < 0 ? 0 : left;
  }

  bool expiredAt(DateTime now) => remainingAt(now) <= 0;

  /// Whether the clock is into its closing seconds — the point at which the
  /// UI should get loud about it.
  bool isUrgentAt(DateTime now) {
    final left = remainingAt(now);
    return left > 0 && left <= 10;
  }

  /// How far through it is, 0 to 1, for a progress indicator.
  double progressAt(DateTime now) {
    if (seconds <= 0) return 1;
    return 1 - (remainingAt(now) / seconds).clamp(0.0, 1.0);
  }

  ShotClock copyWith({String? playerId, DateTime? endsAt, int? seconds}) =>
      ShotClock(
        playerId: playerId ?? this.playerId,
        endsAt: endsAt ?? this.endsAt,
        seconds: seconds ?? this.seconds,
      );

  @override
  bool operator ==(Object other) =>
      other is ShotClock &&
      other.playerId == playerId &&
      other.endsAt == endsAt &&
      other.seconds == seconds;

  @override
  int get hashCode => Object.hash(playerId, endsAt, seconds);
}
