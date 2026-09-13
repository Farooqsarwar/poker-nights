import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';

/// Specification §7 and §18: the organizer allocation is "0–20%".
///
/// A review found the cap existed only in the entry forms — the model, engine
/// and providers had none, so a preset, a restored document or a direct
/// provider call could compute a prize split against 50% or 99%.
void main() {
  GameSettings settings(int pct) => GameSettings(
        name: 'Friday',
        date: '2026-09-18',
        time: '20:00',
        location: '',
        players: 9,
        durationHours: 4,
        buyIn: 20,
        koEnabled: false,
        koAmount: 0,
        rebuys: true,
        rebuysCloseLevel: 6,
        addOn: true,
        anteEnabled: false,
        anteAfterLevel: 7,
        organizerPct: pct,
        chipSet: const [
          ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
        ],
        chipSetName: 'Test',
      );

  group('§7 / §18 — calculations never exceed 20%', () {
    for (final pct in [0, 5, 10, 20]) {
      test('$pct% passes through untouched', () {
        expect(settings(pct).effectiveOrganizerPct, pct);
      });
    }

    for (final pct in [21, 35, 50, 99, 100]) {
      test('$pct% is capped at 20 for calculation', () {
        expect(settings(pct).effectiveOrganizerPct, 20);
      });
    }

    test('a negative value cannot produce a negative allocation', () {
      expect(settings(-10).effectiveOrganizerPct, 0);
    });
  });

  group('the stored value is never rewritten', () {
    test('a legacy figure above the cap survives as written', () {
      // Clamping in the constructor would retroactively change a game the
      // host has already run. The cap belongs at the point of USE.
      final s = settings(35);
      expect(
        s.organizerPct,
        35,
        reason: 'the stored figure is history and must not change meaning',
      );
      expect(s.effectiveOrganizerPct, 20);
    });

    test('copyWith does not clamp either', () {
      expect(settings(10).copyWith(organizerPct: 90).organizerPct, 90);
      expect(
        settings(10).copyWith(organizerPct: 90).effectiveOrganizerPct,
        20,
      );
    });
  });

  group('the cap is named, not a magic number', () {
    test('maxOrganizerPct matches the specification', () {
      expect(GameSettings.maxOrganizerPct, 20);
    });
  });
}
