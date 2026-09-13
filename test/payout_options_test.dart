import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// Specification section 18 and section 25:
///
///   "AI generates multiple payout options, not only one. Example options
///    could cover 3, 4 or 5 paid positions. Each option shows position,
///    percentage and calculated amount."
///
/// And §29's acceptance gate: "AI payout generation produces multiple options
/// with percentages and amounts."
void main() {
  final cases = <({int gross, int players})>[
    (gross: 100, players: 8),
    (gross: 165, players: 11),
    (gross: 300, players: 12),
    (gross: 450, players: 15),
    (gross: 600, players: 20),
    (gross: 1000, players: 24),
  ];

  group('§18 — more than one option is offered', () {
    for (final c in cases) {
      test('${c.gross} across ${c.players} players', () {
        final options = TournamentEngine.payoutOptions(
          c.gross,
          c.players,
          10,
        );
        expect(
          options.length,
          greaterThanOrEqualTo(2),
          reason: 'one option is not a choice — section 18 requires several',
        );
        expect(
          options.map((o) => o.paidPlaces).toSet().length,
          options.length,
          reason: 'two options paying the same number of places are the same '
              'option twice',
        );
      });
    }

    test('options never exceed five paid places', () {
      // Section 18's own example range is 3, 4 or 5.
      for (final c in cases) {
        final options = TournamentEngine.payoutOptions(c.gross, c.players, 10);
        for (final o in options) {
          expect(o.paidPlaces, lessThanOrEqualTo(5));
        }
      }
    });

    test('exactly one option is marked as the recommendation', () {
      for (final c in cases) {
        final options = TournamentEngine.payoutOptions(c.gross, c.players, 10);
        final recommended =
            options.where((o) => o.rationale.contains('Recommended')).length;
        expect(
          recommended,
          1,
          reason: 'the organizer needs a default, and only one default',
        );
      }
    });
  });

  group('§18 — every option shows position, percentage and amount', () {
    test('places are sequential and descending in value', () {
      for (final c in cases) {
        for (final o in TournamentEngine.payoutOptions(c.gross, c.players, 10)) {
          for (var i = 0; i < o.prizes.length; i++) {
            expect(o.prizes[i].place, i + 1);
            if (i > 0) {
              expect(
                o.prizes[i].amount,
                lessThanOrEqualTo(o.prizes[i - 1].amount),
                reason: 'a later place cannot win more than an earlier one',
              );
            }
          }
        }
      }
    });

    test('percentages are produced and roughly total 100', () {
      for (final c in cases) {
        for (final o in TournamentEngine.payoutOptions(c.gross, c.players, 10)) {
          expect(o.percentages, hasLength(o.prizes.length));
          final total = o.percentages.fold<int>(0, (a, p) => a + p);
          // Each is rounded independently for display, so a couple of points
          // of drift is expected; the AMOUNTS are what must be exact.
          expect(
            (total - 100).abs(),
            lessThanOrEqualTo(4),
            reason: 'percentages totalled $total for ${o.paidPlaces} places',
          );
        }
      }
    });

    test('no place is ever paid zero', () {
      for (final c in cases) {
        for (final o in TournamentEngine.payoutOptions(c.gross, c.players, 10)) {
          for (final p in o.prizes) {
            expect(p.amount, greaterThan(0));
          }
        }
      }
    });
  });

  group('§30 financial invariant — every option reconciles exactly', () {
    test('paid + remainder equals the pool, for every option', () {
      for (final c in cases) {
        for (final o in TournamentEngine.payoutOptions(c.gross, c.players, 10)) {
          expect(
            o.reconciles,
            isTrue,
            reason: '${c.gross}/${c.players}p, ${o.paidPlaces} places: '
                '${o.prizes.map((p) => p.amount).join('+')} '
                '+${o.roundingRemainder} != ${o.prizePool}',
          );
        }
      }
    });

    test('all options split the same net pool', () {
      // Changing how many places are paid must not change how much the
      // organizer keeps.
      for (final c in cases) {
        final options = TournamentEngine.payoutOptions(c.gross, c.players, 10);
        final pools = options.map((o) => o.prizePool).toSet();
        expect(
          pools.length,
          1,
          reason: 'the organizer allocation is independent of the payout '
              'shape, so every option must divide the same pool',
        );
      }
    });

    test('amounts stay multiples of ten', () {
      for (final c in cases) {
        for (final o in TournamentEngine.payoutOptions(c.gross, c.players, 10)) {
          for (final p in o.prizes) {
            expect(p.amount % 10, 0, reason: '${p.amount} is not a clean sum');
          }
        }
      }
    });
  });

  group('shapes that are not worth offering are dropped', () {
    test('no option pays three or more places the same minimum', () {
      // Rounding to clean amounts can produce 90/30/10/10/10 from a 150 pool.
      // Three places collecting 10 is not a real alternative — section 18
      // requires a meaningful lowest prize.
      for (final c in cases) {
        for (final o in TournamentEngine.payoutOptions(c.gross, c.players, 10)) {
          if (o.paidPlaces < 3) continue;
          final lowest = o.prizes.last.amount;
          final atLowest = o.prizes.where((p) => p.amount == lowest).length;
          expect(
            atLowest,
            lessThan(3),
            reason: '${o.paidPlaces} places: '
                '${o.prizes.map((p) => p.amount).join('/')}',
          );
        }
      }
    });

    test('a pool too small to split still returns something', () {
      final options = TournamentEngine.payoutOptions(20, 2, 0);
      expect(options, isNotEmpty);
      expect(options.first.prizes, isNotEmpty);
    });
  });

  group('§18 — the organizer allocation is untouched by the choice', () {
    test('the worked example holds across every option', () {
      // Gross 165 -> organizer 15 -> net 150, whichever shape is picked.
      for (final o in TournamentEngine.payoutOptions(165, 11, 10)) {
        expect(o.prizePool, 150);
      }
    });
  });
}
