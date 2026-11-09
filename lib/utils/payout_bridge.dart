import 'dart:math' as math;

import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/payouts_engine.dart';

class PayoutBridge {
  static String? lastHostAlert;
  static final List<String> hostAlerts = [];

  /// Framework §13 / Spec F2.8: Hard-time finish check.
  /// True when hard finish is enabled and the elapsed minutes from start reaches
  /// or exceeds expectedFinishMins + hardFinishMinsAfterFinish.
  static bool isAtHardTimeLimit(LiveGame game) {
    if (!game.settings.hardFinishEnabled || game.startedAt == null) return false;
    final elapsed = DateTime.now().difference(game.startedAt!).inMinutes;
    final cutoff = game.structure.expectedFinishMins +
        game.settings.hardFinishMinsAfterFinish;
    return elapsed >= cutoff;
  }

  /// Which deal prompt (if any) the room should see right now (§F2.8, §F4).
  ///
  /// Priority is the engine's: targetTime > bubble > inTheMoney > headsUp.
  /// `targetTime` fires once the target finish time has elapsed (or target
  /// planned levels exceeded, or hard finish ceiling reached) with ≥ 2 players left.
  static DealTriggerType? dealTriggerFor(
    LiveGame game, {
    int suggestFrom = 5,
    Set<DealTriggerType> alreadyFired = const {},
  }) {
    switch (game.status) {
      case LiveGameStatus.draft:
      case LiveGameStatus.published:
      case LiveGameStatus.checkin:
      case LiveGameStatus.ready:
      case LiveGameStatus.completed:
      case LiveGameStatus.cancelled:
        return null;
      default:
        break;
    }
    final bool targetTimeReached = isAtHardTimeLimit(game) ||
        (game.startedAt != null &&
            DateTime.now().difference(game.startedAt!).inMinutes >=
                game.structure.expectedFinishMins) ||
        (game.currentLevel > game.structure.targetScheduleLastLevel);
    return PayoutsEngine.dealTrigger(
      DealTriggerState(
        remainingPlayers: game.activePlayers.length,
        paidPlaces: game.structure.paidPlacesForDisplay,
        targetTimeReached: targetTimeReached,
        suggestFrom: suggestFrom,
        alreadyFired: alreadyFired,
      ),
    );
  }

  /// Several ways to split the pool, for the organizer to choose between
  /// (specification sections 18 and 25).
  ///
  /// The recommended split (whatever [recalculate] returns with no forced
  /// place count) comes first; around it sit the neighbouring shapes, so a
  /// host who wants to pay one more or one fewer place can see exactly what
  /// that costs the winner before deciding. Options that cannot produce a
  /// meaningful lowest prize are dropped rather than offered.
  static List<PayoutOption> options({
    required int grossEligible,
    required int players,
    required num organizerPct,
    required num buyIn,
    int extraEntries = 0,
  }) {
    final recommended = recalculate(
      grossEligible: grossEligible,
      players: players,
      organizerPct: organizerPct,
      buyIn: buyIn,
      extraEntries: extraEntries,
    );
    final defaultPlaces = recommended.prizes.length;
    if (defaultPlaces == 0) return const [];

    final candidates = <int>{
      defaultPlaces,
      defaultPlaces - 1,
      defaultPlaces + 1,
      defaultPlaces + 2,
    }.where((n) => n >= 1 && n <= 6 && n <= players).toList()
      ..sort();

    final result = <PayoutOption>[];
    for (final places in candidates) {
      final r = recalculate(
        grossEligible: grossEligible,
        players: players,
        organizerPct: organizerPct,
        buyIn: buyIn,
        forcePaidPlaces: places,
        extraEntries: extraEntries,
      );
      if (r.prizes.length != places) continue;
      if (r.prizes.any((p) => p.amount <= 0)) continue;
      // Drop shapes where the tail is meaningless. Rounding to clean amounts
      // can leave three or more places sharing the same minimum award, which
      // pays nobody anything worth collecting and is not a real alternative.
      if (places >= 3) {
        final lowest = r.prizes.last.amount;
        final atLowest = r.prizes.where((p) => p.amount == lowest).length;
        if (atLowest >= 3) continue;
      }
      result.add(
        PayoutOption(
          paidPlaces: places,
          prizes: r.prizes,
          prizePool: r.prizePool,
          roundingRemainder: r.roundingRemainder,
          rationale: _rationale(places, defaultPlaces),
        ),
      );
    }
    return result;
  }

  static String _rationale(int places, int recommended) {
    if (places == recommended) return 'Recommended for this field and pool';
    if (places == 1) return 'Winner takes all';
    if (places < recommended) return 'Top-heavy — bigger first prize';
    return 'Flatter — more players get paid';
  }

  static ({int organizerAmount, int prizePool, List<Prize> prizes, int roundingRemainder})
      recalculate({
    required int grossEligible,
    required int players,
    required num organizerPct,
    required num buyIn,
    int? forcePaidPlaces,
    int extraEntries = 0,
  }) {
    if (grossEligible <= 0 || players <= 0) {
      return (organizerAmount: 0, prizePool: 0, prizes: const [], roundingRemainder: 0);
    }
    
    final pct = organizerPct.clamp(0, 30).toDouble();
    PayoutPlanResult result;
    
    try {
      result = PayoutsEngine.payoutPlan(
        players,
        grossEligible,
        PayoutPlanOptions(
          buyIn: buyIn,
          organiser: OrganiserFeeConfig(
            mode: pct > 0 ? OrganiserFeeMode.percent : OrganiserFeeMode.none,
            value: pct,
            // §F2.3: the fee rounds DOWN to a whole unit, never to tens.
            // 10 % of 165 is 16, not 10 (and not the 17 `Math.round` gives).
            roundTo: 1,
          ),
          rebuys: extraEntries,
          forcePlaces: forcePaidPlaces,
          shape: 'owner',
          maxPlaces: 6,
        ),
      );
    } on ArgumentError {
      // Spec §F2.3: If fee >= pool, lower the fee to pool - 1 unit and record host alert
      final unit = PayoutsEngine.cashUnit(buyIn);
      final adjustedFee = math.max(0, grossEligible - unit);
      final alert = 'Organiser fee reached the prize pool and was lowered to $adjustedFee ($grossEligible - 1 cash unit).';
      lastHostAlert = alert;
      hostAlerts.add(alert);
      result = PayoutsEngine.payoutPlan(
        players,
        grossEligible,
        PayoutPlanOptions(
          buyIn: buyIn,
          organiser: OrganiserFeeConfig(
            mode: adjustedFee > 0 ? OrganiserFeeMode.fixed : OrganiserFeeMode.none,
            value: adjustedFee.toDouble(),
            roundTo: 1,
          ),
          rebuys: extraEntries,
          forcePlaces: forcePaidPlaces,
          shape: 'owner',
          maxPlaces: 6,
        ),
      );
    }
    
    final amounts = [for (final a in result.amounts) a.round()];
    final net = result.netPool.round();
    
    return (
      organizerAmount: result.fee.round(),
      prizePool: net,
      prizes: [for (var i = 0; i < amounts.length; i++) Prize(place: i + 1, amount: amounts[i])],
      roundingRemainder: net - amounts.fold<int>(0, (a, b) => a + b)
    );
  }
}
