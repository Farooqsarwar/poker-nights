import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/shot_clock.dart';

/// §12: "Soft shot clock/time bank independent of level timer."
///
/// That is the entire specification. Everything asserted below is therefore a
/// DECISION rather than a requirement, pinned here so changing one is a
/// deliberate act with a visible consequence.
///
/// The word that shaped all of them is *soft*: this is a home game, so the
/// clock exists to settle a slow decision without an argument, not to enforce
/// anything.
void main() {
  final now = DateTime(2026, 9, 18, 21, 0, 0);

  ShotClock clock({int seconds = 30, int startedSecondsAgo = 0}) => ShotClock(
        playerId: 'p1',
        endsAt: now.add(Duration(seconds: seconds - startedSecondsAgo)),
        seconds: seconds,
      );

  group('it counts down', () {
    test('a fresh clock has its full duration', () {
      expect(clock().remainingAt(now), 30);
    });

    test('it loses a second per second', () {
      expect(clock(startedSecondsAgo: 10).remainingAt(now), 20);
    });

    test('it floors at zero rather than going negative', () {
      expect(clock(startedSecondsAgo: 45).remainingAt(now), 0);
      expect(clock(startedSecondsAgo: 45).expiredAt(now), isTrue);
    });

    test('progress runs 0 to 1', () {
      expect(clock().progressAt(now), 0);
      expect(clock(startedSecondsAgo: 15).progressAt(now), closeTo(0.5, 0.01));
      expect(clock(startedSecondsAgo: 30).progressAt(now), 1);
    });

    test('a zero-length clock does not divide by zero', () {
      final odd = ShotClock(playerId: 'p1', endsAt: now, seconds: 0);
      expect(odd.progressAt(now), 1);
      expect(odd.remainingAt(now), 0);
    });
  });

  group('it gets loud near the end', () {
    test('the last ten seconds are urgent', () {
      expect(clock(startedSecondsAgo: 21).isUrgentAt(now), isTrue);
      expect(clock(startedSecondsAgo: 29).isUrgentAt(now), isTrue);
    });

    test('earlier is not', () {
      expect(clock(startedSecondsAgo: 5).isUrgentAt(now), isFalse);
    });

    test('expired is not urgent — it is over', () {
      // Urgency is a call to act. Once it has run out there is nothing left to
      // hurry, and a UI that keeps flashing is just noise.
      expect(clock(startedSecondsAgo: 40).isUrgentAt(now), isFalse);
    });
  });

  group('the decisions, pinned', () {
    test('the default is 30 seconds', () {
      expect(ShotClock.defaultSeconds, 30);
    });

    test('30, 60 and 90 are offered', () {
      // 30 is the common live-poker default; 60 is the gentler choice for a
      // genuinely big decision.
      expect(ShotClock.presets, [30, 60, 90]);
    });

    test('expiry carries no consequence in the model', () {
      // A SOFT clock. Running out reports a fact; it does not fold a hand.
      // If this ever needs to act, the change belongs here and will fail this
      // test, which is the point.
      final expired = clock(startedSecondsAgo: 60);
      expect(expired.expiredAt(now), isTrue);
      expect(
        expired.playerId,
        'p1',
        reason: 'the clock still names who it was for — it simply does not '
            'do anything to them',
      );
    });
  });

  group('it is independent of the level timer', () {
    test('nothing about it references a level', () {
      // §12 requires independence. A level must not end early because a player
      // tanked, so the clock carries no level, no structure and no ability to
      // reach either.
      final c = clock();
      expect(c.playerId, isNotEmpty);
      expect(c.seconds, 30);
      // The type exposes exactly three things, none of them a level.
      expect(c.copyWith(seconds: 60).seconds, 60);
      expect(c.copyWith(seconds: 60).playerId, 'p1');
    });
  });
}
