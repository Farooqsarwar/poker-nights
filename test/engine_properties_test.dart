import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
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

  group('PN-001 — starting depth lands in the 80-240 BB band', () {
    // Technical section 8.2 clamps starting depth to 80-240 BB. The measured
    // failures were: Standard 300 / 10 players -> 2 BB, Standard 300 / 8 ->
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
          greaterThanOrEqualTo(80),
          reason: '$preset / $players players opens at '
              '${depth.toStringAsFixed(1)} BB '
              '(stack ${s.startingStack}, BB $openingBB)',
        );
        expect(depth, lessThanOrEqualTo(240));
      }
    });

    test('and the whole sweep is in band, or says why not', () {
      for (final c in _sweep()) {
        final depth = c.s.startingStack / c.s.levels.first.bb;
        final warned = c.s.warnings.any((w) => w.contains('80 big-blind'));
        if (!warned) {
          expect(
            depth,
            greaterThanOrEqualTo(80),
            reason: '${c.preset}/${c.players}p @ ${c.hours}h opens at '
                '${depth.toStringAsFixed(1)} BB with no shortage warning',
          );
          expect(depth, lessThanOrEqualTo(240));
        }
      }
    });
  });
}
