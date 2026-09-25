/// Pure, provider-independent helpers for live-game bookkeeping.
///
/// Kept separate from `AppProvider` — which needs Firebase to construct —
/// specifically so they are unit-testable directly, the same reason
/// `mergeMemberOwnedFields` lives outside the provider too (§2: "pure logic
/// takes values and returns values").
///
/// §25.5 / §3. The new `Player.lowestStackBB` for a survivor whose current
/// chip count is [stack], measured in whole big blinds at [currentBB].
///
/// Returns [existing] unchanged when [stack] or [currentBB] tells us nothing
/// (the host never recorded a stack, or the level's BB is not yet known), or
/// when the new sample is not actually a new low.
int? sampledLowestStackBB({
  required int? existing,
  required int? stack,
  required int currentBB,
}) {
  if (stack == null || currentBB <= 0) return existing;
  final stackBB = stack ~/ currentBB;
  if (existing == null || stackBB < existing) return stackBB;
  return existing;
}

/// §25.1a. Whether a check-in landing at [now] earns the early-arrival bonus:
/// the bonus must be switched on, a scheduled start must exist, and [now]
/// must be at least [cutoffMins] before it.
bool isEarlyArrivalEligible({
  required bool bonusEnabled,
  required DateTime? scheduledStart,
  required DateTime now,
  required int cutoffMins,
}) {
  if (!bonusEnabled || scheduledStart == null) return false;
  return now.isBefore(scheduledStart.subtract(Duration(minutes: cutoffMins)));
}

/// §25.1a / §3. The chip bonus granted once the starting stack is final —
/// [effectivePct] is [GameSettings.effectiveEarlyArrivalPct] (0 when the
/// bonus is off, so this naturally returns 0 rather than needing its own
/// enable check).
int earlyArrivalBonusChips({
  required int startingStack,
  required double effectivePct,
}) =>
    (startingStack * effectivePct).round();

/// §34 / `app_provider_user_data.dart`. `LiveGame.finishOrder` is
/// first-out-first — index 0 is LAST place, not 1st. Converts a zero-based
/// index into that list to a finish position (1 = winner).
///
/// `index + 1` was the bug this replaces: it gave the first player eliminated
/// 1st place and the winner last place, inverting every lifetime win/podium
/// stat computed from it.
int finishPositionFromIndex({required int index, required int listLength}) =>
    listLength - index;
