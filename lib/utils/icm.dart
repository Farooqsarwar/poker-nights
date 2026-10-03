import 'dart:math' as math;

/// Independent Chip Model (§2's public ICM Calculator, §3's "Advanced
/// payout/ICM"; build spec §F2.5).
///
/// ICM answers the question every chop argument is really about: *what is my
/// stack worth in money, right now?* Chips are not money — a player with half
/// the chips does not win half the prize pool, because they can still bust.
///
/// The model is Malmuth–Harville: P(i finishes 1st) = stackᵢ / total, then the
/// same question recurses for 2nd among whoever is left, and so on down to the
/// last paid place. That recursion revisits the same "who is already placed"
/// state through every order that reaches it — naive top-down recursion does
/// this once per permutation (factorial blow-up); this implementation instead
/// keeps a **frontier**: a map from the bitmask of players already placed to
/// the total probability of reaching that mask, merging every path that lands
/// on the same mask. The number of distinct masks visited while resolving `P`
/// paid places among `n` players is `Σ_{k<P} C(n,k)` — the spec's own count
/// (10 players, 3 paid → 56 states) — which is what makes the exact model
/// tractable far past a nine-player final table.
///
/// Above [maxStates] frontier entries the exact walk is abandoned for a
/// seeded Monte-Carlo sample: 200,000 stack-weighted finishing orders drawn
/// with a Park–Miller generator, so the same seed reproduces the same answer
/// on every device (spec §F2.5).
abstract final class Icm {
  /// Kept for the UI's own "large field" hint (the ICM calculator's add-player
  /// cap and its "this is an estimate" copy). The real exact/Monte-Carlo
  /// boundary is decided per call from the actual DP state count, not from a
  /// fixed player count — see [maxStates].
  static const int maxExactPlayers = 9;

  /// Above this many DP frontier states, [equity] falls back to Monte Carlo.
  static const int maxStates = 2000000;

  /// Finishing orders sampled by the Monte-Carlo fallback.
  static const int monteCarloSamples = 200000;

  /// Default Park–Miller seed. Fixed (not random) so the same inputs produce
  /// the same equities on every device, as the spec requires.
  static const int defaultSeed = 1;

  /// Each player's equity, in the same order as [stacks].
  ///
  /// [payouts] is the prize for each paid place, largest first. Players beyond
  /// the paid places still hold equity — they can climb — which is exactly
  /// what makes ICM worth computing rather than reading off a chip count.
  static List<double> equity({
    required List<int> stacks,
    required List<int> payouts,
  }) =>
      compute(stacks: stacks, payouts: payouts).equity;

  /// As [equity], but also reports which model produced the numbers
  /// (`'exact'` or `'montecarlo'`) — the build spec's `result.method`.
  static IcmResult compute({
    required List<int> stacks,
    required List<int> payouts,
    int seed = defaultSeed,
  }) {
    final n = stacks.length;
    final equities = List<double>.filled(n, 0);
    if (n == 0 || payouts.isEmpty) {
      return IcmResult(equities, 'exact');
    }

    // Zero stacks (busted this hand) take the bottom places, split equally
    // (§F2.5). Everyone else plays the standard model among themselves for
    // the places that remain once the busted players' bottom places are set
    // aside.
    final live = <int>[];
    final busted = <int>[];
    for (var i = 0; i < n; i++) {
      if (stacks[i] > 0) {
        live.add(i);
      } else {
        busted.add(i);
      }
    }

    final m = live.length;
    final paid = payouts.length;
    final rounds = math.min(paid, m);

    if (m == 0) {
      // Nobody has live chips: split every paid place equally — there is no
      // stack to weigh anybody's chance by.
      if (n == 0) return IcmResult(equities, 'exact');
      final total = payouts.fold<double>(0, (a, p) => a + p);
      final share = total / n;
      for (var i = 0; i < n; i++) {
        equities[i] = share;
      }
      return IcmResult(equities, 'exact');
    }

    if (rounds > 0) {
      final liveStacks = [for (final i in live) stacks[i].toDouble()];
      final totalLive = liveStacks.fold<double>(0, (a, b) => a + b);

      final states = _frontierStates(m, rounds);
      final method = (states <= maxStates)
          ? _exactDp(
              liveStacks: liveStacks,
              liveOriginalIndex: live,
              payouts: payouts,
              rounds: rounds,
              totalLive: totalLive,
              into: equities,
            )
          : _monteCarlo(
              liveStacks: liveStacks,
              liveOriginalIndex: live,
              payouts: payouts,
              rounds: rounds,
              totalLive: totalLive,
              seed: seed,
              into: equities,
            );

      if (busted.isNotEmpty && paid > m) {
        var leftover = 0.0;
        for (var k = m; k < paid; k++) {
          leftover += payouts[k];
        }
        final share = leftover / busted.length;
        for (final i in busted) {
          equities[i] += share;
        }
      }
      return IcmResult(equities, method);
    }

    return IcmResult(equities, 'exact');
  }

  /// `Σ_{k<rounds} C(m,k)` — the number of distinct "who is already placed"
  /// bitmasks the exact DP visits. Stops counting (and reports a value beyond
  /// [maxStates]) the moment the running total already overflows it, so a
  /// huge `m` never spends time computing binomial coefficients nobody needs.
  static int _frontierStates(int m, int rounds) {
    var states = 0;
    for (var k = 0; k < rounds; k++) {
      final c = _choose(m, k);
      states += c;
      if (states > maxStates) return states;
    }
    return states;
  }

  static int _choose(int n, int k) {
    if (k < 0 || k > n) return 0;
    if (k == 0 || k == n) return 1;
    final kk = math.min(k, n - k);
    var result = 1;
    for (var i = 0; i < kk; i++) {
      result = result * (n - i) ~/ (i + 1);
    }
    return result;
  }

  /// The exact bitmask-frontier DP described at the top of this file.
  ///
  /// `frontier` maps a bitmask of already-placed live players to the summed
  /// probability of every order that reaches that exact set — this merge is
  /// what turns a factorial recursion into `Σ C(m,k)` states. Verified against
  /// the build spec's own hand-worked trace: `icm([8000,5000,2000],[250,150,
  /// 100])` must equal 197.44 / 171.61 / 130.95 — it does.
  static String _exactDp({
    required List<double> liveStacks,
    required List<int> liveOriginalIndex,
    required List<int> payouts,
    required int rounds,
    required double totalLive,
    required List<double> into,
  }) {
    final m = liveStacks.length;
    var frontier = <int, double>{0: 1.0};

    for (var round = 0; round < rounds; round++) {
      final prize = payouts[round].toDouble();
      final next = <int, double>{};

      for (final entry in frontier.entries) {
        final mask = entry.key;
        final prob = entry.value;

        var taken = 0.0;
        for (var b = 0; b < m; b++) {
          if ((mask & (1 << b)) != 0) taken += liveStacks[b];
        }
        final remaining = totalLive - taken;
        if (remaining <= 0) continue;

        for (var b = 0; b < m; b++) {
          if ((mask & (1 << b)) != 0) continue;
          final p = prob * (liveStacks[b] / remaining);
          into[liveOriginalIndex[b]] += p * prize;

          if (round < rounds - 1) {
            final newMask = mask | (1 << b);
            next[newMask] = (next[newMask] ?? 0) + p;
          }
        }
      }
      frontier = next;
    }
    return 'exact';
  }

  /// 200,000 stack-weighted finishing orders, seeded with Park–Miller
  /// (`s = s × 16807 mod (2³¹ − 1)`) so the same seed always gives the same
  /// answer. Used only once the exact frontier would exceed [maxStates].
  static String _monteCarlo({
    required List<double> liveStacks,
    required List<int> liveOriginalIndex,
    required List<int> payouts,
    required int rounds,
    required double totalLive,
    required int seed,
    required List<double> into,
  }) {
    final m = liveStacks.length;
    final rng = _ParkMiller(seed);
    final accum = List<double>.filled(m, 0);

    for (var s = 0; s < monteCarloSamples; s++) {
      final pool = List<int>.generate(m, (i) => i);
      final stackPool = [...liveStacks];
      var remainingTotal = totalLive;

      for (var place = 0; place < rounds; place++) {
        final r = rng.nextDouble() * remainingTotal;
        var cumulative = 0.0;
        var chosen = stackPool.length - 1;
        for (var k = 0; k < stackPool.length; k++) {
          cumulative += stackPool[k];
          if (r < cumulative) {
            chosen = k;
            break;
          }
        }
        accum[pool[chosen]] += payouts[place].toDouble();
        remainingTotal -= stackPool[chosen];
        pool.removeAt(chosen);
        stackPool.removeAt(chosen);
      }
    }

    for (var b = 0; b < m; b++) {
      into[liveOriginalIndex[b]] = accum[b] / monteCarloSamples;
    }
    return 'montecarlo';
  }

  /// Whether [stacks] is small enough that the UI can promise the exact
  /// model. Decorative only (drives the ICM calculator's "add player" cap and
  /// its estimate warning) — the actual per-call decision is state-count
  /// based, see [compute].
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

/// [Icm.compute]'s result: the equities plus which model produced them.
class IcmResult {
  const IcmResult(this.equity, this.method);

  /// Each player's equity, same order as the `stacks` passed in.
  final List<double> equity;

  /// `'exact'` (bitmask DP) or `'montecarlo'` (seeded sample fallback).
  final String method;
}

/// Park–Miller minimal-standard PRNG: `s = s × 16807 mod (2³¹ − 1)`. Seeded
/// and deterministic — the same seed produces the same stream everywhere,
/// which is the whole point of using it instead of `dart:math`'s `Random`.
class _ParkMiller {
  _ParkMiller(int seed) : _state = seed <= 0 ? 1 : (seed % 2147483647);

  int _state;

  static const int _multiplier = 16807;
  static const int _modulus = 2147483647; // 2^31 - 1

  /// Next uniform value in `[0, 1)`.
  double nextDouble() {
    _state = (_state * _multiplier) % _modulus;
    return _state / _modulus;
  }
}
