import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// §E17 row 22 and §G2.3 row 30 — the Auto ante rule and its four vectors.
///
/// §E17 row 22 (spec `:3476`) names §F1.8 as the requirement and its test
/// column reads "none yet (§G2.3)"; §G2.3 row 30 (spec `:5147`) is the list:
/// "Auto ante rule - the four vectors".
///
/// §F1.8 (spec `:3947`):
///
///   "players <= 6 and nightMinutes < 210 -> no ante
///    otherwise                            -> BB ante
///    (Individual is never suggested; the host can still pick it)"
///
///   "Vectors: (6, 180) -> none · (6, 240) -> bb · (10, 180) -> bb ·
///   (12, 270) -> bb. The host's hosting default **Ante: Always suggest ON /
///   Auto / Always suggest OFF** biases the pre-selection: Auto = the rule;
///   Always ON = BB ante; Always OFF = none. (Changed in v3.1: the old rule
///   suggested Individual for small tables, which the home-game research
///   advises against, §G4.)"
///
/// The vectors alone would pass against a function that got the rule
/// structurally wrong, so the boundary cases are asserted separately: 210
/// minutes is the first minute that WANTS an ante, and 7 players is the first
/// field that does. "Individual is never suggested" is asserted as an
/// invariant over a sweep rather than as four literals, because it is the
/// clause v3.1 was written to add.
///
/// REWRITTEN, not extended. This file previously tested
/// `TournamentEngine.recommendAnte`, which implements the retired pre-v3.1
/// rule and returns `AnteStyle.individual` for any field of six or fewer
/// (`lib/utils/tournament_engine.dart:1050`). Its old assertion
/// `recommendAnte(players: 5, durationHours: 4).style == AnteStyle.individual`
/// was therefore factually wrong against the current specification, which
/// retires that suggestion in as many words. `recommendAnteStyle`
/// (`lib/utils/tournament_engine.dart:514`) is the implementation that matches
/// §F1.8 and is what these tests now pin.
void main() {
  AnteRecommendation rule(int players, double hours) =>
      TournamentEngine.recommendAnteStyle(
        players: players,
        durationHours: hours,
      );

  group('§G2.3 row 30 — the four spec vectors', () {
    test('(6, 180) -> no ante', () {
      final r = rule(6, 3);
      expect(r.enabled, isFalse);
      expect(r.label, 'No ante');
    });

    test('(6, 240) -> BB ante', () {
      // The same six players, four hours instead of three: the field alone does
      // not decide it.
      final r = rule(6, 4);
      expect(r.enabled, isTrue);
      expect(r.style, AnteStyle.bigBlind);
    });

    test('(10, 180) -> BB ante', () {
      // The same three hours, more than six players: the night alone does not
      // decide it either. Both conditions are required for "no ante".
      final r = rule(10, 3);
      expect(r.enabled, isTrue);
      expect(r.style, AnteStyle.bigBlind);
    });

    test('(12, 270) -> BB ante', () {
      final r = rule(12, 4.5);
      expect(r.enabled, isTrue);
      expect(r.style, AnteStyle.bigBlind);
    });
  });

  group('§F1.8 — the rule is a conjunction, and 210 minutes is the line', () {
    test('no ante needs BOTH a short night and six players or fewer', () {
      // Sweeping the four combinations around the rule's own corner. If the
      // implementation used `||` instead of `&&` the first two would flip.
      expect(rule(6, 3).enabled, isFalse, reason: 'both conditions met');
      expect(rule(5, 3).enabled, isFalse, reason: 'both conditions met');
      expect(rule(6, 4).enabled, isTrue, reason: 'night too long');
      expect(rule(7, 3).enabled, isTrue, reason: 'field too large');
      expect(rule(9, 3).enabled, isTrue, reason: 'both conditions failed');
    });

    test('the night boundary is strict: 210 minutes already wants an ante', () {
      // "nightMinutes < 210" is exclusive, so 3.5h exactly is an ante night.
      // An off-by-one here moves every 3.5-hour home game to the wrong
      // pre-selection, which is the most common shape of night this app runs.
      expect(rule(6, 3.49).enabled, isFalse, reason: 'one minute under the line');
      expect(rule(6, 3.5).enabled, isTrue, reason: 'exactly on the line');
      expect(rule(6, 3.51).enabled, isTrue, reason: 'one minute over');
    });

    test('the field boundary is inclusive: six players still qualifies', () {
      // "players <= 6" is inclusive, so the sixth seat is the last one that
      // can talk the ante out of a short night.
      expect(rule(6, 3).enabled, isFalse);
      expect(rule(7, 3).enabled, isTrue);
    });

    test('a two-handed, one-hour game is the clearest no-ante case', () {
      expect(rule(2, 1).enabled, isFalse);
      expect(rule(2, 1).label, 'No ante');
    });
  });

  group('§F1.8 — Individual is never suggested', () {
    test('no field size and no length ever yields the individual style', () {
      // Swept rather than sampled, because the clause is universal and the
      // retired rule violated it across an entire region of the input space
      // (anything <= 6 players that ran long enough). Sampling four points
      // would not have caught it.
      for (var players = 1; players <= 20; players++) {
        for (final hours in [1.0, 2.0, 3.0, 3.5, 4.0, 5.0, 6.0, 8.0]) {
          final r = rule(players, hours);
          expect(
            r.style,
            isNot(AnteStyle.individual),
            reason: '$players players, ${hours}h must not suggest individual',
          );
        }
      }
    });

    test('when an ante is on, the style carried on the record is the big blind',
        () {
      // `AnteRecommendation.style` is read downstream, not just `enabled`, so a
      // record that said "on, individual" would post an individual ante. The
      // disabled case still reports `bigBlind` — the engine cannot express
      // "on, but individual" and the label getter hides it — so this asserts
      // the enabled half only.
      for (var players = 7; players <= 20; players++) {
        for (final hours in [3.5, 4.0, 5.0]) {
          expect(rule(players, hours).style, AnteStyle.bigBlind);
        }
      }
    });
  });

  group('every recommendation explains itself', () {
    test('reason and label are always present', () {
      for (var players = 1; players <= 18; players++) {
        for (final hours in [1.0, 2.0, 3.0, 3.5, 4.0, 5.0, 6.0]) {
          final r = rule(players, hours);
          expect(r.reason, isNotEmpty, reason: '$players players, ${hours}h');
          expect(r.label, isNotEmpty, reason: '$players players, ${hours}h');
        }
      }
    });

    test('the label matches the decision', () {
      expect(rule(9, 4).label, 'Big blind ante');
      expect(rule(5, 3).label, 'No ante');
      expect(
        rule(5, 4).label,
        'Big blind ante',
        reason: 'a small field that ran long gets the BB ante, not Individual',
      );
    });

    test('the rule still varies, which is the point of a recommendation', () {
      // The original defect this file's first version was written against: an
      // option that always resolved to the same thing was a third label for the
      // same choice, not a recommendation.
      final labels = <String>{
        for (final c in [(6, 3.0), (6, 4.0), (9, 4.0), (12, 6.0), (2, 1.0)])
          rule(c.$1, c.$2).label,
      };
      expect(labels, hasLength(2), reason: 'exactly "No ante" and "Big blind ante"');
    });
  });

  group('Spec §F1.8 — recommendAnte matches recommendAnteStyle', () {
    test('recommendAnte delegates to Spec §F1.8 rule', () {
      final r = TournamentEngine.recommendAnte(players: 5, durationHours: 4);
      expect(r.style, AnteStyle.bigBlind);
    });

    test('and it agrees with the implemented rule for every vector', () {
      for (final v in [(6, 3.0), (6, 4.0), (10, 3.0), (12, 4.5)]) {
        expect(
          TournamentEngine.recommendAnte(players: v.$1, durationHours: v.$2)
              .enabled,
          rule(v.$1, v.$2).enabled,
          reason: '${v.$1} players, ${v.$2}h: both agree on on/off',
        );
      }
      expect(
        TournamentEngine.recommendAnte(players: 6, durationHours: 4).style,
        AnteStyle.bigBlind,
      );
      expect(rule(6, 4).style, AnteStyle.bigBlind);
    });
  });
}
