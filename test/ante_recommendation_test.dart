import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// §7 lists "system recommendation" as an ante option alongside Off, Big
/// Blind Ante and Individual Ante.
///
/// It existed as a button but always resolved to Big Blind Ante, which made
/// it a third label for the same choice rather than a recommendation. A
/// review caught that.
void main() {
  group('§7 — the recommendation is a real decision', () {
    test('a full table gets the big blind ante', () {
      // One payment per hand from one player: faster than collecting from
      // nine people every hand.
      final r = TournamentEngine.recommendAnte(players: 9, durationHours: 4);
      expect(r.enabled, isTrue);
      expect(r.style, AnteStyle.bigBlind);
    });

    test('a short-handed game gets the individual ante', () {
      final r = TournamentEngine.recommendAnte(players: 5, durationHours: 4);
      expect(r.enabled, isTrue);
      expect(r.style, AnteStyle.individual);
    });

    test('a short game with a small field gets no ante at all', () {
      final r = TournamentEngine.recommendAnte(players: 5, durationHours: 3);
      expect(r.enabled, isFalse);
    });

    test('it does not always return the same answer', () {
      // The whole defect was that it did.
      final styles = <String>{
        for (final c in [(9, 4.0), (5, 4.0), (5, 3.0), (12, 6.0), (4, 3.0)])
          TournamentEngine.recommendAnte(
            players: c.$1,
            durationHours: c.$2,
          ).label,
      };
      expect(
        styles.length,
        greaterThan(1),
        reason: 'a recommendation that never varies is not a recommendation',
      );
    });
  });

  group('every recommendation explains itself', () {
    test('reason and label are always present', () {
      for (final players in [2, 4, 6, 9, 12, 18]) {
        for (final hours in [3.0, 4.0, 5.0, 6.0]) {
          final r = TournamentEngine.recommendAnte(
            players: players,
            durationHours: hours,
          );
          expect(r.reason, isNotEmpty, reason: '$players players, ${hours}h');
          expect(r.label, isNotEmpty);
        }
      }
    });

    test('the label matches the decision', () {
      expect(
        TournamentEngine.recommendAnte(players: 9, durationHours: 4).label,
        'Big blind ante',
      );
      expect(
        TournamentEngine.recommendAnte(players: 5, durationHours: 4).label,
        'Individual ante',
      );
      expect(
        TournamentEngine.recommendAnte(players: 5, durationHours: 3).label,
        'No ante',
      );
    });
  });
}
