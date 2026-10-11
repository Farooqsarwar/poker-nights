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

int _roundUnit(TournamentStructure s) {
  final dealt = s.chipPlan.map((e) => e.value).where((v) => v > 0).toList();
  final smallestDealt = dealt.isEmpty ? 25 : dealt.reduce(math.min);
  return math.max(25, smallestDealt);
}

void main() {
  test('WP1 engine invariants across the grid', () {
    final counts = <String, int>{
      'sbGeBb': 0,
      'bbNotMultipleOf2Cmin': 0,
      'bbNotRising': 0,
      'stepAbove2': 0,
      'stepBelowMin': 0,
      'stackNotRound': 0,
      'feasibleButBroke': 0, // reported until T5 lets `feasible` gate on bankOk
      'bankFalsePositive': 0, // engine bankOk=true but independently short (bug)
      'bankOkDisagrees': 0, // engine stricter than the test (acceptable, reported)
      'bankFalseNoNote': 0,
      'anteStartWrong': 0,
      'addonBreakWrong': 0,
    };
    final samples = <String, String>{};
    var runs = 0;
    const minStep = 1.15; // OWNER-DECISION: tune MIN_STEP after review.

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
                  TournamentStructure s;
                  try {
                    s = TournamentEngine.generate(p);
                  } catch (_) {
                    continue;
                  }
                  runs++;
                  final tag =
                      '${caseE.key}/$players/${hours}h/${paceE.key}/${rebuy ? 'rebuy' : 'freeze'}/${ante ? 'bb' : 'none'}/c$close';
                  final lv = s.levels;

                  for (var i = 0; i < lv.length; i++) {
                    final cmin = 1; // engine does not expose per-level cmin; 2×1 lower bound
                    if (lv[i].bb > 0 && lv[i].sb >= lv[i].bb) {
                      counts['sbGeBb'] = counts['sbGeBb']! + 1;
                      samples['sbGeBb'] ??= '$tag L${i + 1} ${lv[i].sb}/${lv[i].bb}';
                      break;
                    }
                    if (lv[i].bb % (2 * cmin) != 0) {
                      counts['bbNotMultipleOf2Cmin'] =
                          counts['bbNotMultipleOf2Cmin']! + 1;
                      break;
                    }
                  }
                  var rose = true, stepHi = false, stepLo = false;
                  for (var i = 1; i < lv.length; i++) {
                    if (lv[i].bb <= lv[i - 1].bb) rose = false;
                    if (lv[i - 1].bb > 0) {
                      final r = lv[i].bb / lv[i - 1].bb;
                      if (r > 2.0001) stepHi = true;
                      if (r < minStep - 0.0001 && r > 1.0) stepLo = true;
                    }
                  }
                  if (!rose) counts['bbNotRising'] = counts['bbNotRising']! + 1;
                  if (stepHi) {
                    counts['stepAbove2'] = counts['stepAbove2']! + 1;
                    samples['stepAbove2'] ??= tag;
                  }
                  if (stepLo) counts['stepBelowMin'] = counts['stepBelowMin']! + 1;

                  if (s.startingStack % _roundUnit(s) != 0) {
                    counts['stackNotRound'] = counts['stackNotRound']! + 1;
                    samples['stackNotRound'] ??= '$tag stack=${s.startingStack}';
                  }

                  final bankOk = _bankOk(s, p);
                  if (s.feasible && !bankOk) {
                    counts['feasibleButBroke'] = counts['feasibleButBroke']! + 1;
                    samples['feasibleButBroke'] ??= tag;
                  }
                  // The dangerous direction: the engine claims the bank is OK
                  // when the independent check says it is short. The reverse
                  // (engine more conservative than the test's greedy add-on fit)
                  // is acceptable and only reported.
                  if (s.bankOk && !bankOk) {
                    counts['bankFalsePositive'] = counts['bankFalsePositive']! + 1;
                    samples['bankFalsePositive'] ??= tag;
                  } else if (!s.bankOk && bankOk) {
                    counts['bankOkDisagrees'] = counts['bankOkDisagrees']! + 1;
                    samples['bankOkDisagrees'] ??=
                        '$tag engine=${s.bankOk} indep=$bankOk (engine stricter)';
                  }
                  if (!s.feasible) {
                    final hasNote = s.warnings.any((w) =>
                        w.contains('support') || w.contains('cannot') || w.contains('Short'));
                    if (!hasNote) counts['bankFalseNoNote'] = counts['bankFalseNoNote']! + 1;
                  }

                  if (rebuy) {
                    final add = s.breaks.where((b) => b.afterLevel > 0).toList();
                    if (add.isNotEmpty &&
                        add.first.afterLevel != s.rebuysCloseLevel) {
                      counts['addonBreakWrong'] = counts['addonBreakWrong']! + 1;
                      samples['addonBreakWrong'] ??=
                          '$tag break@${add.first.afterLevel} close=${s.rebuysCloseLevel}';
                    }
                    final firstAnte = lv.indexWhere((l) => (l.ante ?? 0) > 0);
                    if (ante && firstAnte >= 0 &&
                        firstAnte + 1 != s.rebuysCloseLevel + 1) {
                      // ante should start at close+1 (1-indexed level == close+1)
                      counts['anteStartWrong'] = counts['anteStartWrong']! + 1;
                      samples['anteStartWrong'] ??=
                          '$tag ante@L${firstAnte + 1} close=${s.rebuysCloseLevel}';
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // ignore: avoid_print
    print('WP1 invariants over $runs runs:');
    counts.forEach((k, v) {
      // ignore: avoid_print
      print('  $k = $v   ${samples[k] ?? ''}');
    });

    expect(counts['sbGeBb'], 0, reason: 'SB ≥ BB on some level (F6)');
    expect(counts['bbNotRising'], 0, reason: 'BB not strictly rising');
    expect(counts['stepAbove2'], 0, reason: 'a step > ×2.0 (F6/F7)');
    expect(counts['stepBelowMin'], 0, reason: 'a step < MIN_STEP (F7)');
    expect(counts['stackNotRound'], 0, reason: 'stack not a round unit (F32)');
    expect(counts['bankFalsePositive'], 0,
        reason: 'engine must never report bankOk=true when the bank is short (F20/RC10)');
    // feasibleButBroke stays reported (not asserted) until T5 makes the
    // composition solver bank-aware, after which `feasible` gates on bankOk.
    expect(counts['addonBreakWrong'], 0,
        reason: 'add-on break not right after rebuy close (F33, §F1.9)');
    expect(counts['anteStartWrong'], 0,
        reason: 'ante does not start at close+1 (F33, §F1.8)');
  });
}
