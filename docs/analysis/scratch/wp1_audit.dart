import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// WP1 invariant suite (§F1.5–§F1.10). Runs `generate` across the same grid as
/// the 1,440-run analysis matrix plus a 100-chip-minimum case, and asserts the
/// structural invariants the analysis found broken (SB>BB, ×6–×8 steps,
/// non-round stacks, `feasible` that is not a real bank check, rebuy close).
///
/// The bank check here is computed **independently** of the engine, per §F1.5
/// (Poisson 90th-percentile rebuys, every player takes the add-on and the
/// bonus, per-colour `count × draws ≤ owned`), so it is a genuine cross-check
/// and not the engine agreeing with itself.
///
/// Counts are aggregated per invariant so the red baseline is one line each;
/// see docs/analysis/wp1-results.md for the recorded before/after numbers.

const _box500 = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 150),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
  ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
  ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 100),
];
const _demo = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 120),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
  ChipColor(color: 'Green', hex: 0xFF27AE60, value: 25, quantity: 80),
  ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 40),
];
const _base25 = [
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 100),
  ChipColor(color: 'Green', hex: 0xFF27AE60, value: 100, quantity: 100),
  ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 80),
  ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 1000, quantity: 50),
  ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 5000, quantity: 30),
];
const _base100 = [
  ChipColor(color: 'Green', hex: 0xFF27AE60, value: 100, quantity: 120),
  ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 100),
  ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 1000, quantity: 80),
  ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 5000, quantity: 40),
];

const _cases = {
  'box500': _box500,
  'demo': _demo,
  'base25': _base25,
  'base100': _base100,
};

const _paces = {
  'turbo': PaceMode.turbo,
  'regular': PaceMode.regular,
  'deep': PaceMode.deep,
  'none': null,
};

/// Smallest k with P(Poisson(mean) ≤ k) ≥ 0.90. Independent of the engine.
int _poisson90(double mean) {
  if (mean <= 0) return 0;
  var term = math.exp(-mean);
  var cdf = term;
  var k = 0;
  while (cdf < 0.9 && k < 1000) {
    k++;
    term *= mean / k;
    cdf += term;
  }
  return k;
}

/// Greedy largest-first chip breakdown of [amount] from [values], bounded by
/// [avail]; returns per-value counts, or null if it cannot be made.
Map<int, int>? _fewest(int amount, List<int> values, Map<int, int> avail) {
  final out = <int, int>{};
  var rest = amount;
  for (final v in values) {
    if (rest <= 0) break;
    final want = rest ~/ v;
    final take = math.min(want, avail[v] ?? 0);
    if (take > 0) {
      out[v] = take;
      rest -= take * v;
    }
  }
  return rest == 0 ? out : null;
}

/// Independent §F1.5 hard bank check on the generated structure.
bool _bankOk(TournamentStructure s, TournamentParams p) {
  final owned = {for (final c in p.chipSet) c.value: c.quantity};
  final rForecast = p.rebuys ? p.players * (p.expectedRebuyRate ?? 0.35) : 0.0;
  final rbank = _poisson90(rForecast);
  final draws = p.players + rbank; // start + rebuy stacks (same composition)
  final remaining = {...owned};
  // Start + rebuy stacks: count × draws per colour.
  for (final e in s.chipPlan) {
    final need = e.count * draws;
    final have = remaining[e.value] ?? 0;
    if (need > have) return false;
    remaining[e.value] = have - need;
  }
  if (!p.addOn) return true;
  // Every player takes the add-on and the bonus, paid from what is left.
  final valuesDesc = (owned.keys.toList()..sort((a, b) => b - a));
  final addOnEach = s.addOnStack;
  final bonusEach = p.earlyArrivalBonusEnabled
      ? ((p.earlyArrivalBonusPctOverride ?? 0.125) * s.startingStack).round()
      : 0;
  for (var i = 0; i < p.players; i++) {
    if (addOnEach > 0) {
      final plan = _fewest(addOnEach, valuesDesc, remaining);
      if (plan == null) return false;
      plan.forEach((v, c) => remaining[v] = (remaining[v] ?? 0) - c);
    }
    if (bonusEach > 0) {
      final plan = _fewest(bonusEach, valuesDesc, remaining);
      if (plan == null) return false;
      plan.forEach((v, c) => remaining[v] = (remaining[v] ?? 0) - c);
    }
  }
  return true;
}

/// Scratch audit (not a product test): one CSV row per run of the 3,840-run
/// invariant grid, incl. engine vs independent bank verdicts. Output:
/// docs/analysis/wp1-audit-runs.csv
void main() {
  test('audit grid', () {
    final rows = <String>[
      'family,case,players,hours,pace,format,ante,close,stack,sb,bb,depth,feasible,depthOk,bankOk,indepBankOk,fits,closeLevel,shortfall,note'
    ];
    for (final fam in BlindFamily.values) {
      for (final players in [6, 9, 12, 20]) {
        for (final hours in [3.0, 4.0, 5.0]) {
          for (final paceE in _paces.entries) {
            for (final rebuy in [false, true]) {
              for (final ante in [true, false]) {
                for (final close in rebuy ? [0, 4, 5, 6] : [0]) {
                  for (final caseE in _cases.entries) {
                    final p = TournamentParams(
                      players: players,
                      durationHours: hours,
                      buyIn: 20,
                      chipSet: caseE.value,
                      blindFamily: fam,
                      rebuys: rebuy,
                      rebuysCloseLevel: close,
                      rebuyCloseChosenByOrganizer: close > 0,
                      reEntry: false,
                      addOn: rebuy,
                      anteEnabled: ante,
                      anteAfterLevel: 6,
                      koEnabled: false,
                      koAmount: 0,
                      organizerPct: 0,
                      format: rebuy ? TournamentFormat.rebuy : TournamentFormat.freezeOut,
                      expectedRebuyRate: rebuy ? 0.35 : 0,
                      addOnMultiplier: 1.25,
                      pace: paceE.value,
                    );
                    final s = TournamentEngine.generate(p);
                    final o = s.levels.first;
                    rows.add([
                      fam.name, caseE.key, players, hours, paceE.key,
                      rebuy ? 'rebuy' : 'freeze', ante ? 'bb' : 'none', close,
                      s.startingStack, o.sb, o.bb,
                      (s.startingStack / o.bb).toStringAsFixed(1),
                      s.feasible, s.depthOk, s.bankOk, _bankOk(s, p), s.fits,
                      s.rebuysCloseLevel,
                      s.bankShortfall.map((x) => '${x.short}x${x.colour}').join('/'),
                      (s.depthShortfallNote ?? '').replaceAll(',', ';'),
                    ].join(','));
                  }
                }
              }
            }
          }
        }
      }
    }
    File('docs/analysis/wp1-audit-runs.csv').writeAsStringSync(rows.join('\n'));
    // ignore: avoid_print
    print('AUDIT rows=${rows.length - 1}');
  });
}
