import 'dart:math' as math;

/// Independent Chip Model (§2's public ICM Calculator, §3's "Advanced
/// payout/ICM").
///
/// ICM answers the question every chop argument is really about: *what is my
/// stack worth in money, right now?* Chips are not money — a player with half
/// the chips does not win half the prize pool, because they can still bust.
///
/// The model is the standard one: a player's equity is the sum, over every
/// finishing position, of the probability they finish there multiplied by that
/// position's prize. The probability of finishing first is your share of the
/// chips in play; the probability of finishing second is the chance somebody
/// else wins and then you win what remains, and so on.
///
/// That recursion is exact and factorial in the number of players, which is
/// fine for a final table — nine players is the realistic ceiling, and that is
/// the only place anybody actually needs ICM. Beyond [maxExactPlayers] the
/// recursion is capped and the remaining places are shared proportionally,
/// because a 45-second wait to settle a chop is worse than a rounding error
/// nobody can perceive.
abstract final class Icm {
  /// Above this, the exact recursion is abandoned for a proportional split.
  static const int maxExactPlayers = 9;

  /// Each player's equity, in the same order as [stacks].
  ///
  /// [payouts] is the prize for each paid place, largest first. Players beyond
  /// the paid places still hold equity — they can climb — which is exactly
  /// what makes ICM worth computing rather than reading off a chip count.
  static List<double> equity({
    required List<int> stacks,
    required List<int> payouts,
  }) {
    final live = stacks.where((s) => s > 0).length;
    if (stacks.isEmpty || payouts.isEmpty || live == 0) {
      return List<double>.filled(stacks.length, 0);
    }

    // One prize and one player left: no model needed.
    if (payouts.length == 1 && live == 1) {
      return [
        for (final s in stacks) s > 0 ? payouts.first.toDouble() : 0.0,
      ];
    }

    if (stacks.length > maxExactPlayers) {
      return _proportional(stacks: stacks, payouts: payouts);
    }

    final total = stacks.fold<int>(0, (a, s) => a + s);
    if (total <= 0) return List<double>.filled(stacks.length, 0);

    final equities = List<double>.filled(stacks.length, 0);
    _accumulate(
      stacks: stacks.map((s) => s.toDouble()).toList(),
      payouts: payouts,
      place: 0,
      probability: 1,
      taken: List<bool>.filled(stacks.length, false),
      into: equities,
    );
    return equities;
  }

  /// Walks the finishing orders, adding each one's contribution.
  ///
  /// [probability] is the chance of reaching this branch; [place] is the
  /// position about to be filled. The recursion stops once every prize is
  /// allocated — positions below the money contribute nothing, so enumerating
  /// them would be work for no answer.
  static void _accumulate({
    required List<double> stacks,
    required List<int> payouts,
    required int place,
    required double probability,
    required List<bool> taken,
    required List<double> into,
  }) {
    if (place >= payouts.length || probability <= 0) return;

    var remaining = 0.0;
    for (var i = 0; i < stacks.length; i++) {
      if (!taken[i]) remaining += stacks[i];
    }
    if (remaining <= 0) return;

    for (var i = 0; i < stacks.length; i++) {
      if (taken[i] || stacks[i] <= 0) continue;
      // Chance this player takes THIS place, given who is already placed.
      final p = probability * (stacks[i] / remaining);
      into[i] += p * payouts[place];

      taken[i] = true;
      _accumulate(
        stacks: stacks,
        payouts: payouts,
        place: place + 1,
        probability: p,
        taken: taken,
        into: into,
      );
      taken[i] = false;
    }
  }

  /// Fallback for fields too large to enumerate.
  ///
  /// Deliberately crude and deliberately labelled: it splits the pool by chip
  /// share, which is what ICM exists to correct. It only applies above nine
  /// players, where nobody is settling a chop anyway.
  static List<double> _proportional({
    required List<int> stacks,
    required List<int> payouts,
  }) {
    final total = stacks.fold<int>(0, (a, s) => a + s);
    final pool = payouts.fold<int>(0, (a, p) => a + p);
    if (total <= 0) return List<double>.filled(stacks.length, 0);
    return [for (final s in stacks) pool * (s / total)];
  }

  /// Whether [stacks] is small enough for the exact model.
  static bool isExact(List<int> stacks) => stacks.length <= maxExactPlayers;

  /// Rounds equities to whole units while preserving the total exactly.
  ///
  /// Rounding each independently loses or invents money — three players at
  /// 33.4 each round to 33 and lose a unit. The largest remainders take the
  /// difference, which is the same deterministic rule the payout engine uses.
  static List<int> roundPreservingTotal(List<double> equities, int total) {
    if (equities.isEmpty) return const [];
    final floors = equities.map((e) => e.floor()).toList();
    var shortfall = total - floors.fold<int>(0, (a, f) => a + f);

    final order = List<int>.generate(equities.length, (i) => i)
      ..sort((a, b) {
        final ra = equities[a] - floors[a];
        final rb = equities[b] - floors[b];
        return rb.compareTo(ra);
      });

    var i = 0;
    while (shortfall > 0 && order.isNotEmpty) {
      floors[order[i % order.length]] += 1;
      shortfall--;
      i++;
    }
    // Negative shortfall means the floors already overshoot, which can only
    // happen if `total` is smaller than the equities describe.
    while (shortfall < 0 && order.isNotEmpty) {
      final idx = order[order.length - 1 - (i % order.length)];
      if (floors[idx] > 0) {
        floors[idx] -= 1;
        shortfall++;
      }
      i++;
      if (i > equities.length * math.max(1, total)) break;
    }
    return floors;
  }
}
