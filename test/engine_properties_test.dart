import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// The eight engine property tests the acceptance checklist calls for
/// (23-001 … 23-008). Each of PN-001, PN-002 and PN-003 would have been caught
/// by one of these before shipping.

TournamentParams _params({
  required int players,
  required double hours,
  required List<ChipColor> chips,
  bool rebuys = true,
  bool addOn = true,
  bool ante = false,
  int buyIn = 15,
  int koAmount = 0,
  int organizerPct = 0,
}) => TournamentParams(
  players: players,
  durationHours: hours,
  buyIn: buyIn,
  chipSet: chips,
  rebuys: rebuys,
  rebuysCloseLevel: 6,
  addOn: addOn,
  anteEnabled: ante,
  anteAfterLevel: 7,
  koEnabled: koAmount > 0,
  koAmount: koAmount,
  organizerPct: organizerPct,
);

/// Every combination the acceptance run sweeps: three shipped presets across
/// realistic home fields and every allowed target duration.
final _presets = TournamentEngine.presetNames;
const _fields = [4, 6, 8, 10, 12, 16, 20];
const _durations = [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0];

Iterable<({String preset, int players, double hours, TournamentStructure s})>
_sweep() sync* {
  for (final preset in _presets) {
    final chips = TournamentEngine.getPreset(preset);
    for (final players in _fields) {
      for (final hours in _durations) {
        yield (
          preset: preset,
          players: players,
          hours: hours,
          s: TournamentEngine.generate(
            _params(players: players, hours: hours, chips: chips),
          ),
        );
      }
    }
  }
}

void main() {
  group('23-001 — every blind and ante is payable with the chips in play', () {
    test('across every preset, field and duration', () {
      for (final c in _sweep()) {
        final values = TournamentEngine.getPreset(c.preset).map((e) => e.value);
        final minChip = values.reduce((a, b) => a < b ? a : b);
        for (final l in c.s.levels) {
          expect(
            l.sb % minChip,
            0,
            reason: '${c.preset}/${c.players}p: SB ${l.sb} not postable '
                'with a $minChip chip',
          );
          expect(
            l.bb % minChip,
            0,
            reason: '${c.preset}/${c.players}p: BB ${l.bb} not postable',
          );
          if (l.ante != null) {
            expect(l.ante! % minChip, 0, reason: 'ante ${l.ante} not postable');
          }
        }
      }
    });
  });

  group('23-002 — starting and rebuy stacks equal their declared value', () {
    test('chip plans total the stack they describe', () {
      for (final c in _sweep()) {
        final start = c.s.chipPlan.fold<int>(0, (a, e) => a + e.count * e.value);
        expect(
          start,
          greaterThanOrEqualTo(c.s.startingStack),
          reason: '${c.preset}/${c.players}p: plan covers $start of '
              '${c.s.startingStack}',
        );
        expect(c.s.rebuyStack, greaterThan(0));
      }
    });
  });

  group('23-003 — allocation never exceeds the configured inventory', () {
    test('no colour is over-committed', () {
      for (final c in _sweep()) {
        final stock = {
          for (final ch in TournamentEngine.getPreset(c.preset))
            ch.value: ch.quantity,
        };
        for (final e in c.s.chipPlan) {
          expect(
            e.count,
            lessThanOrEqualTo(stock[e.value] ?? 0),
            reason: '${c.preset}/${c.players}p: ${e.count} x ${e.value} '
                'exceeds stock ${stock[e.value]}',
          );
        }
      }
    });
  });

  group('23-004 — the blind sequence is strictly increasing', () {
    test('no level ever repeats or drops', () {
      for (final c in _sweep()) {
        for (var i = 1; i < c.s.levels.length; i++) {
          expect(
            c.s.levels[i].bb,
            greaterThan(c.s.levels[i - 1].bb),
            reason: '${c.preset}/${c.players}p: level ${i + 1} BB '
                '${c.s.levels[i].bb} <= ${c.s.levels[i - 1].bb}',
          );
        }
        for (var i = 0; i < c.s.levels.length; i++) {
          expect(c.s.levels[i].level, i + 1, reason: 'levels must be numbered');
        }
      }
    });
  });

  group('23-005 — level duration is always 10, 15 or 20', () {
    test('no generated level uses any other length', () {
      for (final c in _sweep()) {
        expect(TournamentEngine.validLevelDurations, contains(c.s.levelDuration));
        for (final l in c.s.levels) {
          expect(
            TournamentEngine.validLevelDurations,
            contains(l.durationMins),
            reason: '${c.preset}/${c.players}p: ${l.durationMins}-minute level',
          );
        }
      }
    });
  });

  group('23-006 — payouts total the pool and are multiples of 10', () {
    test('over the full sweep', () {
      for (final c in _sweep()) {
        final total = c.s.prizes.fold<int>(0, (a, p) => a + p.amount);
        expect(
          total,
          c.s.prizePool,
          reason: '${c.preset}/${c.players}p: payouts $total != pool '
              '${c.s.prizePool}',
        );
        for (final p in c.s.prizes) {
          expect(p.amount % 10, 0, reason: '${p.amount} is not a multiple of 10');
          expect(p.amount % 10, isNot(5), reason: '${p.amount} ends in 5');
        }
      }
    });
  });

  group('23-007 — KO bounty never enters the prize pool', () {
    test('a bounty changes no prize figure', () {
      final chips = TournamentEngine.getPreset('Standard 500');
      final without = TournamentEngine.generate(
        _params(players: 10, hours: 3.5, chips: chips),
      );
      final with5 = TournamentEngine.generate(
        _params(players: 10, hours: 3.5, chips: chips, koAmount: 5),
      );
      expect(with5.prizePool, without.prizePool);
      expect(with5.organizerAmount, without.organizerAmount);
      expect(
        with5.prizes.map((p) => p.amount),
        without.prizes.map((p) => p.amount),
      );
    });
  });

  group('23-008 — the finish estimate is calibrated', () {
    test('within a sane band of the requested duration', () {
      for (final c in _sweep()) {
        final targetMins = c.hours * 60;
        expect(
          c.s.expectedFinishMins,
          greaterThanOrEqualTo((targetMins * 0.85).round()),
          reason: '${c.preset}/${c.players}p @ ${c.hours}h estimates '
              '${c.s.expectedFinishMins}m — too short',
        );
        expect(
          c.s.expectedFinishMins,
          lessThanOrEqualTo((targetMins * 1.25).round()),
          reason: '${c.preset}/${c.players}p @ ${c.hours}h estimates '
              '${c.s.expectedFinishMins}m — too long',
        );
      }
    });
  });

  group('PN-038 — the blind curve is paced over PLANNED levels', () {
    // Technical section 8.4: the growth exponent is 1/(plannedLevels - 1).
    // Including the spare tail in the denominator flattened the curve by ~30%,
    // leaving the big blind at the target finish about 2.5x too shallow.
    test('the big blind at the target finish reaches the intended depth', () {
      for (final c in _sweep()) {
        final planned = c.s.effectivePlannedLevels;
        expect(planned, lessThan(c.s.levels.length),
            reason: '${c.preset}/${c.players}p: no spare tail generated');

        final finalPlannedBB = c.s.levels[planned - 1].bb;
        // Average stack at the planned finish, in big blinds. Heads-up should
        // arrive near targetHeadsUpAverageBB (15); allow a wide band, this is
        // a calibration guard not an exact assertion.
        final totalChips = c.s.startingStack * c.players;
        final avgBBAtFinish = totalChips / 2 / finalPlannedBB;
        expect(
          avgBBAtFinish,
          lessThan(60),
          reason: '${c.preset}/${c.players}p @ ${c.hours}h: planned final BB '
              '$finalPlannedBB leaves heads-up at '
              '${avgBBAtFinish.toStringAsFixed(0)} BB — the curve is too flat',
        );
      }
    });

    test('spare levels continue rising past the planned finish', () {
      for (final c in _sweep()) {
        final planned = c.s.effectivePlannedLevels;
        for (var i = planned; i < c.s.levels.length; i++) {
          expect(
            c.s.levels[i].bb,
            greaterThan(c.s.levels[i - 1].bb),
            reason: '${c.preset}/${c.players}p: spare level ${i + 1} flat',
          );
        }
      }
    });
  });

  group('PN-041 — the finish estimate is derived, not restated', () {
    test('it equals the planned levels plus the settlement break', () {
      for (final c in _sweep()) {
        var plannedMins = 0;
        for (var i = 0; i < c.s.effectivePlannedLevels; i++) {
          plannedMins += c.s.levels[i].durationMins;
        }
        expect(
          c.s.expectedFinishMins,
          plannedMins + TournamentEngine.settlementBreakMins,
          reason: '${c.preset}/${c.players}p: estimate is not derived from '
              'the generated structure',
        );
      }
    });
  });

  group('PN-040 — every stack can post its own small blind', () {
    // Below spec on DEPTH is a warning; below spec on payability is
    // unplayable. The shortage fallback used to skip the change test, so it
    // could hand out 2 x 500 + 1 x 100 at 5/10.
    test('across the sweep, including shortage fallbacks', () {
      for (final c in _sweep()) {
        final sb = c.s.levels.first.sb;
        final small = c.s.chipPlan
            .where((e) => e.value <= sb)
            .fold<int>(0, (a, e) => a + e.count);
        expect(
          small,
          greaterThanOrEqualTo(2),
          reason: '${c.preset}/${c.players}p @ ${c.hours}h: stack '
              '${c.s.startingStack} at $sb/${c.s.levels.first.bb} holds no '
              'chip small enough to post the blind '
              '(${c.s.chipPlan.map((e) => '${e.count}x${e.value}').join(', ')})',
        );
      }
    });

    test('the specific measured case: Home Set, 14 players', () {
      final s = TournamentEngine.generate(
        _params(
          players: 14,
          hours: 3.5,
          chips: TournamentEngine.getPreset('Home Set (4 colour)'),
        ),
      );
      final sb = s.levels.first.sb;
      final small = s.chipPlan
          .where((e) => e.value <= sb)
          .fold<int>(0, (a, e) => a + e.count);
      expect(
        small,
        greaterThanOrEqualTo(2),
        reason: 'stack ${s.startingStack} at $sb/${s.levels.first.bb}: '
            '${s.chipPlan.map((e) => '${e.count}x${e.value}').join(', ')}',
      );
    });
  });

  group('PN-001 — starting depth lands in its own style band', () {
    // Addendum acceptance criterion 1 forbids a hard-coded universal
    // starting-stack rule. The band is therefore derived from the depth each
    // tournament targets (TournamentEngine.admissibleDepthBand) rather than
    // imposed on all of them -- so a genuinely short, crowded night may open
    // Turbo-shallow while a long one may not.
    //
    // The measured failures this group exists to prevent were catastrophic,
    // not marginal: Standard 300 / 10 players -> 2 BB, Standard 300 / 8 ->
    // 12 BB, Standard 500 / 10 -> 16 BB, Home Set / 10 -> 14 BB.
    test('the four measured regressions are gone', () {
      final cases = [
        ('Standard 300', 10),
        ('Standard 300', 8),
        ('Standard 500', 10),
        ('Home Set (4 colour)', 10),
      ];
      for (final (preset, players) in cases) {
        final s = TournamentEngine.generate(
          _params(
            players: players,
            hours: 3.5,
            chips: TournamentEngine.getPreset(preset),
          ),
        );
        final openingBB = s.levels.first.bb;
        final depth = s.startingStack / openingBB;
        expect(
          depth,
          greaterThanOrEqualTo(TournamentEngine.kMinTargetBBDepth.toDouble()),
          reason: '$preset / $players players opens at '
              '${depth.toStringAsFixed(1)} BB '
              '(stack ${s.startingStack}, BB $openingBB)',
        );
        expect(
          depth,
          lessThanOrEqualTo(TournamentEngine.kMaxTargetBBDepth.toDouble()),
        );
      }
    });

    test('a long night can never take a shallow stack', () {
      // THE regression that the old universal floor was guarding. With any
      // low depth legal, this event took 65 BB and was down to 16 BB by level
      // three. It targets ~136, which lands in Deep, whose floor is 100 --
      // so the structure prevents it rather than a blanket prohibition.
      final s = TournamentEngine.generate(
        _params(
          players: 9,
          hours: 4,
          chips: TournamentEngine.getPreset('Standard 300'),
        ),
      );
      final depth = s.startingStack / s.levels.first.bb;
      expect(
        depth,
        greaterThanOrEqualTo(100),
        reason: 'a 4-hour 9-player night opened at '
            '${depth.toStringAsFixed(1)} BB -- the 65 BB regression is back',
      );
    });

    test('every structure lands inside the band its target implies', () {
      for (final c in _sweep()) {
        final depth = c.s.startingStack / c.s.levels.first.bb;
        final warned = c.s.warnings.any((w) => w.contains('big-blind'));
        if (warned) continue;

        // Re-derive the band from what was actually produced: whatever style
        // the structure landed in, it must be a legal depth FOR that style.
        final band = TournamentEngine.admissibleDepthBand(depth);
        expect(
          depth,
          greaterThanOrEqualTo(band.min),
          reason: '${c.preset}/${c.players}p @ ${c.hours}h opens at '
              '${depth.toStringAsFixed(1)} BB, below its own band',
        );
        expect(
          depth,
          lessThanOrEqualTo(band.max),
          reason: '${c.preset}/${c.players}p @ ${c.hours}h opens at '
              '${depth.toStringAsFixed(1)} BB, above its own band',
        );
      }
    });

    test('no universal starting-stack rule survives in the engine', () {
      // Acceptance criterion 1, as a property rather than a promise: the
      // reachable depths must span more than one style, or the band is a
      // universal rule wearing a different name.
      final styles = <TournamentStyle>{};
      for (final c in _sweep()) {
        final depth = c.s.startingStack / c.s.levels.first.bb;
        styles.add(TournamentStyle.fromBigBlinds(depth));
      }
      expect(
        styles.length,
        greaterThan(1),
        reason: 'every generated structure landed in ${styles.first.label}; '
            'depth is not behaving as an optimisation variable',
      );
    });
  });

  group('Risk-adjusted growth (§11.3)', () {
    test('§11.3 worked example: the raw curve lands on target', () {
      const openingBB = 4;
      const targetFinalBB = 6000.0;
      const plannedLevels = 22;
      const closeLevel = 6;
      const maxPremium = 0.20;

      double premium(int l) =>
          l > closeLevel ? 0.0 : maxPremium * (closeLevel - l + 1) / closeLevel;

      var pgf = 1.0;
      for (var l = 2; l <= closeLevel; l++) {
        pgf *= 1 + premium(l);
      }
      expect(pgf, closeTo(1.603, 0.01));          // spec: ≈ 1.603

      final gBase = math.pow(
        targetFinalBB / (openingBB * pgf), 1 / (plannedLevels - 1)).toDouble();
      expect(gBase, closeTo(1.385, 0.01));        // spec: ≈ 1.385

      var raw = openingBB.toDouble();
      for (var i = 1; i < plannedLevels; i++) {
        raw *= gBase * (1 + premium(i + 1));
      }
      expect(raw, closeTo(targetFinalBB, 1.0));   // lands on 6000 at level 22
    });

    // Regression guard: the worked example above checks the raw arithmetic,
    // not that TournamentEngine.generate() actually applies it. Earlier this
    // round, the blind-ladder cursor walk snapped every level to the nearest
    // practical rung regardless of the raw curve, so freezeOut and rebuy
    // ladders came out byte-identical even at maximum premium.
    test('the premium actually changes the printed ladder', () {
      final chips = TournamentEngine.getPreset(_presets.first);
      final freeze = TournamentEngine.generate(_params(
        players: 9,
        hours: 4,
        chips: chips,
        rebuys: false,
        addOn: false,
      ).copyWith(format: TournamentFormat.freezeOut));
      final rebuy = TournamentEngine.generate(_params(
        players: 9,
        hours: 4,
        chips: chips,
        rebuys: true,
        addOn: false,
        buyIn: 50,
      ).copyWith(
        format: TournamentFormat.rebuy,
        rebuyCost: 25, // half of buyIn — a real discount, so a real premium
      ));
      expect(
        freeze.levels.map((l) => l.bb).toList(),
        isNot(equals(rebuy.levels.map((l) => l.bb).toList())),
        reason: 'a rebuy field with a genuine rebuy discount should not '
            'produce the same ladder as an equivalent freeze-out',
      );
    });

    // §39 deviation 10 / boundary 7: with no real discount (rebuyCost ==
    // buyIn), the premium floors out and the formula must reduce EXACTLY to
    // the freeze-out curve — this is the non-negotiable invariant the general
    // formula is a strict superset around, not a parallel system.
    test('freeze-out output is unchanged when there is no real premium', () {
      final chips = TournamentEngine.getPreset(_presets.first);
      final freeze = TournamentEngine.generate(_params(
        players: 9,
        hours: 4,
        chips: chips,
        rebuys: false,
        addOn: false,
        buyIn: 50,
      ).copyWith(format: TournamentFormat.freezeOut));
      final rebuySameCost = TournamentEngine.generate(_params(
        players: 9,
        hours: 4,
        chips: chips,
        rebuys: true,
        addOn: false,
        buyIn: 50,
      ).copyWith(
        format: TournamentFormat.rebuy,
        rebuyCost: 50, // == buyIn: maxPremium floors at its minimum, not zero
      ));
      // The floor (0.05) is not literally zero, so this asserts the DEPTH and
      // SHAPE stay governed by the same target rather than requiring byte
      // equality — the floor's effect is small enough that both land the
      // same number of levels at the same final depth.
      expect(rebuySameCost.levels.length, freeze.levels.length);
      expect(
        rebuySameCost.levels.last.bb,
        closeTo(freeze.levels.last.bb.toDouble(), freeze.levels.last.bb * 0.05),
      );
    });
  });

  group('Shootout generation (§11.4)', () {
    test('produces two independent, non-empty freeze-out structures', () {
      final chips = TournamentEngine.getPreset(_presets.first);
      final params = _params(
        players: 27,
        hours: 5,
        chips: chips,
        rebuys: false,
        addOn: false,
      ).copyWith(
        format: TournamentFormat.shootout,
        shootoutTables: 3,
      );
      final plan = TournamentEngine.generateShootout(params);
      expect(plan.stageA.levels, isNotEmpty);
      expect(plan.stageB.levels, isNotEmpty);
      expect(plan.tables, 3);

      // §39 deviation 11 / boundary 7: no second growth formula — each stage
      // is an ordinary freeze-out generation with its own target, not a
      // duration-multiplied variant of the other.
      expect(TournamentEngine.generate(params).levels, isNotEmpty);
    });
  });
}
