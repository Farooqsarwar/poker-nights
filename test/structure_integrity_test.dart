import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/model_codec.dart';

/// Phase 5 — structure integrity.
///
/// Specification 2026-09 sections 6, 11 and 29.
void main() {
  group('section 11 — manual future edits carry a marker', () {
    test('a level defaults to engine-generated', () {
      const l = BlindLevel(
        level: 1,
        sb: 25,
        bb: 50,
        ante: null,
        durationMins: 15,
      );
      expect(
        l.manuallyEdited,
        isFalse,
        reason: 'nothing is a manual edit until a human touches it',
      );
    });

    test('the marker survives a Firestore round trip', () {
      const l = BlindLevel(
        level: 9,
        sb: 400,
        bb: 800,
        ante: 100,
        durationMins: 20,
        manuallyEdited: true,
      );
      final back = blindLevelFromMap(blindLevelToMap(l));
      expect(back.manuallyEdited, isTrue);
      expect(back.sb, 400);
      expect(back.bb, 800);
      expect(back.ante, 100);
      expect(back.durationMins, 20);
    });

    test('a document written before the marker existed loads as unedited', () {
      // Section 2.1 of the plan: every new field must have a sane default in
      // fromMap, because old documents are read by new clients.
      final back = blindLevelFromMap({
        'level': 3,
        'sb': 50,
        'bb': 100,
        'ante': null,
        'durationMins': 15,
      });
      expect(
        back.manuallyEdited,
        isFalse,
        reason: 'levels generated before the marker existed WERE all engine '
            'output, so false is not merely a safe default, it is correct',
      );
    });

    test('copyWith preserves the marker unless asked otherwise', () {
      const l = BlindLevel(
        level: 5,
        sb: 100,
        bb: 200,
        ante: null,
        durationMins: 15,
        manuallyEdited: true,
      );
      expect(l.copyWith(level: 6).manuallyEdited, isTrue);
      expect(l.copyWith(manuallyEdited: false).manuallyEdited, isFalse);
    });
  });

  group('section 6 — the four head-count concepts are distinct', () {
    const chips = [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
      ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 50),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 30),
    ];

    GameSettings settings({int? override, int? locked}) => GameSettings(
      name: 'Friday',
      date: '2026-09-18',
      time: '20:00',
      location: 'Basement',
      players: 12,
      durationHours: 3.5,
      buyIn: 15,
      koEnabled: false,
      koAmount: 0,
      rebuys: true,
      rebuysCloseLevel: 6,
      addOn: true,
      anteEnabled: false,
      anteAfterLevel: 7,
      organizerPct: 10,
      chipSet: chips,
      chipSetName: 'Standard',
      expectedPlayersOverride: override,
      lockedExpectedPlayers: locked,
    );

    test('Expected and Locked are separate fields', () {
      // The specification's own worked example: "Confirmed 12, Expected 15,
      // lock 15." Expected is the estimate; Locked is that estimate frozen.
      // They are not the same thing and must not collapse into one field.
      final s = settings(override: 15, locked: 15);
      expect(s.players, 12, reason: 'Confirmed is untouched by either');
      expect(s.expectedPlayersOverride, 15);
      expect(s.lockedExpectedPlayers, 15);
    });

    test('locking does not require an override to have been set', () {
      final s = settings(locked: 15);
      expect(s.expectedPlayersOverride, isNull);
      expect(s.lockedExpectedPlayers, 15);
    });

    test('both survive a Firestore round trip', () {
      final back = gameSettingsFromMap(
        gameSettingsToMap(settings(override: 15, locked: 16)),
      );
      expect(back.expectedPlayersOverride, 15);
      expect(back.lockedExpectedPlayers, 16);
    });

    test('an old document loads as neither overridden nor locked', () {
      final back = gameSettingsFromMap(
        gameSettingsToMap(settings())
          ..remove('expectedPlayersOverride')
          ..remove('lockedExpectedPlayers'),
      );
      expect(back.expectedPlayersOverride, isNull);
      expect(back.lockedExpectedPlayers, isNull);
    });

    test('clearing the lock is distinguishable from not setting it', () {
      // `copyWith(lockedExpectedPlayers: null)` cannot mean "clear" — null is
      // how copyWith spells "leave alone". Unlocking needs its own flag, or
      // the host could never release a lock.
      final locked = settings(locked: 15);
      expect(
        locked.copyWith(lockedExpectedPlayers: null).lockedExpectedPlayers,
        15,
        reason: 'a bare null must not silently unlock',
      );
      expect(
        locked
            .copyWith(clearLockedExpectedPlayers: true)
            .lockedExpectedPlayers,
        isNull,
      );
    });
  });
}
