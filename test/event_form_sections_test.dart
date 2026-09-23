import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/widgets/event_settings_form.dart';

/// The D1 split: the creation wizard's "Rebuys & add-ons" step may render only
/// rebuys/add-ons fields and the "Format" step only KO/ante/breaks. These pin
/// the fine-grained [EventFormSection.rebuys] / [EventFormSection.format]
/// sections AND that the legacy monolithic `rules` section still renders every
/// rule field exactly once (the invitation edit modal's four-section mount).
GameSettings settings() {
  return GameSettings(
    name: 'Friday',
    date: '2026-09-25',
    time: '20:00',
    location: '',
    players: 9,
    durationHours: 4,
    buyIn: 20,
    koEnabled: true,
    koAmount: 5,
    rebuys: true,
    rebuysCloseLevel: 6,
    rebuyLimit: 3,
    rebuyCost: 10,
    addOn: true,
    addOnCost: 5,
    antePreference: AntePreference.bigBlind,
    anteEnabled: true,
    anteAfterLevel: 6,
    organizerPct: 10,
    breaks: const [],
    chipSet: const [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
    ],
    chipSetName: 'Test',
  );
}

Future<void> pumpForm(
  WidgetTester tester,
  Set<EventFormSection> sections,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: EventSettingsForm(
            initial: settings(),
            sections: sections,
            onChanged: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('rebuys section renders only rebuys/add-ons fields', (
    tester,
  ) async {
    await pumpForm(tester, {EventFormSection.rebuys});
    expect(find.text('Rebuys & re-entry'), findsOneWidget);
    expect(find.text('Close rebuys'), findsOneWidget);
    expect(find.text('Add-on'), findsOneWidget);
    // Format decisions must not leak onto the rebuys step (D1).
    expect(find.text('KO bounty'), findsNothing);
    expect(find.text('Ante'), findsNothing);
    expect(find.text('Breaks'), findsNothing);
  });

  testWidgets('format section renders only format fields', (tester) async {
    await pumpForm(tester, {EventFormSection.format});
    expect(find.text('KO bounty'), findsOneWidget);
    expect(find.text('Ante'), findsOneWidget);
    expect(find.text('Breaks'), findsOneWidget);
    expect(find.text('Override table settings'), findsOneWidget);
    // Rebuys/add-ons belong to their own step (D1).
    expect(find.text('Rebuys & re-entry'), findsNothing);
    expect(find.text('Add-on'), findsNothing);
  });

  testWidgets('the four-section mount renders every rule field once', (
    tester,
  ) async {
    await pumpForm(tester, {
      EventFormSection.details,
      EventFormSection.chips,
      EventFormSection.rules,
      EventFormSection.money,
    });
    // Every field is reachable through the edit modal mount...
    expect(find.text('Rebuys & re-entry'), findsOneWidget);
    expect(find.text('Add-on'), findsOneWidget);
    expect(find.text('KO bounty'), findsOneWidget);
    expect(find.text('Ante'), findsOneWidget);
    expect(find.text('Breaks'), findsOneWidget);
    expect(find.text('Rebuy price'), findsOneWidget);
    expect(find.text('Add-on price'), findsOneWidget);
    expect(find.text('Bounty amount'), findsOneWidget);
    // ...and none is painted twice by the legacy `rules` union overlapping
    // the fine-grained sections.
    for (final s in ['KO bounty', 'Breaks', 'Add-on']) {
      expect(
        find.text(s),
        findsOneWidget,
        reason: '$s must appear exactly once in the full mount',
      );
    }
  });
}