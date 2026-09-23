import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/utils/event_settings_validation.dart';
import 'package:poker_night/utils/sanitization.dart';
import 'package:poker_night/widgets/event_settings_form.dart';

/// Shared validation for the event-settings form — the union of the creation
/// wizard's step-1 / step-3 checks and the edit form's save-time checks.
GameSettings settings({
  String name = 'Friday',
  String date = '2026-09-25',
  String time = '20:00',
  String location = '',
  double durationHours = 4,
  int buyIn = 20,
  bool koEnabled = false,
  int koAmount = 0,
  bool rebuys = false,
  int? rebuyLimit,
  int organizerPct = 0,
}) {
  return GameSettings(
    name: name,
    date: date,
    time: time,
    location: location,
    players: 9,
    durationHours: durationHours,
    buyIn: buyIn,
    koEnabled: koEnabled,
    koAmount: koAmount,
    rebuys: rebuys,
    rebuysCloseLevel: 6,
    rebuyLimit: rebuyLimit,
    addOn: true,
    anteEnabled: false,
    anteAfterLevel: 7,
    organizerPct: organizerPct,
    chipSet: const [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
    ],
    chipSetName: 'Test',
  );
}

/// A fixed clock so "today"/"in the future" are deterministic.
final _noon = DateTime(2026, 9, 23, 12, 0);

void main() {
  group('validateEventSettings — valid input', () {
    test('an empty result means valid', () {
      // date 2026-09-25 is after the pinned "today" of 2026-09-23.
      expect(validateEventSettings(settings(), now: _noon), isEmpty);
    });
  });

  group('name', () {
    test('empty name is rejected', () {
      expect(
        validateEventSettings(settings(name: '   '), now: _noon),
        {'name': 'Required'},
      );
    });

    test('name over the limit is rejected', () {
      final name = List.filled(82, 'a').join();
      expect(
        validateEventSettings(settings(name: name), now: _noon),
        {'name': 'Max ${Sanitization.maxTournamentNameLength} characters'},
      );
    });
  });

  group('location', () {
    test('location over the limit is rejected', () {
      final location = List.filled(170, 'x').join();
      expect(
        validateEventSettings(settings(location: location), now: _noon),
        {'location': 'Max ${Sanitization.maxLocationLength} characters'},
      );
    });

    test('empty location is fine', () {
      expect(validateEventSettings(settings(location: ''), now: _noon), isEmpty);
    });
  });

  group('date', () {
    test('empty date is rejected', () {
      expect(
        validateEventSettings(settings(date: ''), now: _noon),
        {'date': 'Required'},
      );
    });

    test('a malformed date is rejected', () {
      expect(
        validateEventSettings(settings(date: 'not-a-date'), now: _noon),
        contains('date'),
      );
    });

    test('an impossible date is rejected', () {
      expect(
        validateEventSettings(settings(date: '2026-13-45'), now: _noon),
        contains('date'),
      );
    });

    test('a past date is rejected', () {
      expect(
        validateEventSettings(settings(date: '2020-01-01'), now: _noon),
        {'date': 'Date must be today or in the future'},
      );
    });
  });

  group('time', () {
    test('empty time is rejected', () {
      expect(
        validateEventSettings(settings(time: ''), now: _noon),
        {'time': 'Required'},
      );
    });

    test('a malformed time is rejected', () {
      expect(
        validateEventSettings(settings(time: 'ten'), now: _noon),
        contains('time'),
      );
    });

    test('an out-of-range clock is rejected', () {
      expect(
        validateEventSettings(settings(time: '99:99'), now: _noon),
        {'time': 'Invalid time (HH:MM)'},
      );
    });

    test('a past time on today\'s date is rejected', () {
      // Pinned clock is 2026-09-23 noon; a 09:00 start that day is the past.
      expect(
        validateEventSettings(
          settings(date: '2026-09-23', time: '09:00'),
          now: _noon,
        ),
        {'time': 'Start time must be in the future'},
      );
    });
  });

  group('money', () {
    test('zero buy-in is rejected', () {
      expect(
        validateEventSettings(settings(buyIn: 0), now: _noon),
        {'buyIn': 'Must be positive'},
      );
    });

    test('a negative buy-in is rejected', () {
      expect(
        validateEventSettings(settings(buyIn: -5), now: _noon),
        {'buyIn': 'Must be positive'},
      );
    });

    test('a negative KO amount is rejected when KO is on', () {
      expect(
        validateEventSettings(
          settings(koEnabled: true, koAmount: -1),
          now: _noon,
        ),
        {'koAmount': 'Must be >= 0'},
      );
    });

    test('KO amount is ignored when KO is off', () {
      expect(
        validateEventSettings(settings(koEnabled: false, koAmount: -1), now: _noon),
        isEmpty,
      );
    });

    test('a negative rebuy limit is rejected when rebuys are on', () {
      expect(
        validateEventSettings(
          settings(rebuys: true, rebuyLimit: -1),
          now: _noon,
        ),
        {'rebuyLimit': 'Must be >= 0'},
      );
    });

    test('an unlimited rebuy (null limit) is accepted', () {
      expect(
        validateEventSettings(settings(rebuys: true, rebuyLimit: null), now: _noon),
        isEmpty,
      );
    });

    test('an organizer percentage above the cap is rejected', () {
      expect(
        validateEventSettings(settings(organizerPct: 25), now: _noon),
        {'orgPct': 'Must be 0-${GameSettings.maxOrganizerPct}'},
      );
    });

    test('the documented organizer cap itself is accepted', () {
      expect(
        validateEventSettings(settings(organizerPct: 20), now: _noon),
        isEmpty,
      );
    });
  });

  group('errors accumulate across fields', () {
    test('every broken field is reported at once', () {
      final errors = validateEventSettings(
        settings(
          name: '',
          date: '2020-01-01',
          // Malformed, not merely past: a past DATE already suppresses the
          // past-TIME check (one root cause, one error), so proving that
          // errors accumulate needs a time broken on its own terms.
          time: '99:99',
          buyIn: 0,
          koEnabled: true,
          koAmount: -1,
          rebuys: true,
          rebuyLimit: -1,
          organizerPct: 30,
        ),
        now: _noon,
      );
      expect(errors.keys.toSet(), {
        'name',
        'date',
        'time',
        'buyIn',
        'koAmount',
        'rebuyLimit',
        'orgPct',
      });
    });
  });

  group('EventSettingsForm — legacy organizer percentage', () {
    testWidgets('a legacy figure above the cap is only reducible', (tester) async {
      final drafts = <GameSettings>[];
      final initial = settings(organizerPct: 40);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventSettingsForm(
                initial: initial,
                sections: const {EventFormSection.money},
                showOrganizerPct: true,
                orgPctCeiling: 20,
                onChanged: drafts.add,
              ),
            ),
          ),
        ),
      );

      // The stored 40 survives — CountStepper renders the live value.
      expect(find.text('40 %'), findsOneWidget);
      // + is blocked at the raised ceiling of 40; - lets it down to 39.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('40 %'), findsOneWidget, reason: 'plus is blocked at 40');
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.text('39 %'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('40 %'), findsOneWidget);

      // Drafts carry the stepped value and can never exceed the legacy ceiling.
      expect(drafts.last.organizerPct, 40);
      expect(drafts.map((d) => d.organizerPct).any((p) => p > 40), isFalse);
    });
  });
}