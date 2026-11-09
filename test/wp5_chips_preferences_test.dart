import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/table_settings.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/models/tournament_preset.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/create_tournament_screen.dart';
import 'package:poker_night/screens/tournament/quick_start_screen.dart';
import 'package:poker_night/services/payment_service.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/model_codec.dart';
import 'package:poker_night/utils/formatters.dart';
import 'package:poker_night/utils/structure_builder_controller.dart';
import 'package:poker_night/widgets/chip_set_editor.dart';
import 'package:poker_night/widgets/count_stepper.dart';
import 'package:poker_night/widgets/structure_builder.dart';
import 'package:poker_night/widgets/save_game_preset_offer.dart';
import 'package:provider/provider.dart';

const _host = AppUser(
  id: 'host',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

const _chips = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
];

Group _group() => const Group(
  id: 'group',
  name: 'Friday game',
  joinCode: 'FRIDAY',
  ownerId: 'host',
  members: [_host],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

GameSettings _baseSettings() => GameSettings(
  name: 'Poker Night',
  date: '2026-10-16',
  time: '20:00',
  location: '',
  players: 8,
  durationHours: 4,
  buyIn: 20,
  koEnabled: false,
  koAmount: 5,
  rebuys: false,
  rebuysCloseLevel: 0,
  addOn: false,
  anteEnabled: true,
  anteAfterLevel: 5,
  organizerPct: 0,
  chipSet: _chips,
  chipSetName: 'Test set',
  format: TournamentFormat.freezeOut,
  pace: PaceMode.regular,
);

TournamentPreset _preset(
  String id, {
  int buyIn = 20,
  int? forceStack,
  int? targetDepthBB,
}) => TournamentPreset(
  id: id,
  name: 'Preset $id',
  buyIn: buyIn,
  koEnabled: true,
  koAmount: 10,
  rebuys: true,
  rebuysCloseLevel: 5,
  reEntry: false,
  addOn: true,
  durationHours: 3.5,
  anteEnabled: true,
  anteAfterLevel: 6,
  organizerPct: 5,
  chipSetName: 'Test set',
  chipSet: _chips,
  format: TournamentFormat.rebuy,
  pace: PaceMode.deep,
  earlyArrivalBonusEnabled: true,
  earlyArrivalBonusPctOverride: 0.15,
  forcePaidPlaces: 3,
  tableSettingsOverride: const TableSettings(maxPerTable: 7),
  forceStack: forceStack,
  targetDepthBB: targetDepthBB,
);

AppProvider _provider() => AppProvider()
  ..setUserForTesting(_host)
  ..setCurrentGroupForTesting(_group());

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  AppProvider? app,
}) async {
  await tester.pumpWidget(
    app == null
        ? MaterialApp(home: Scaffold(body: child))
        : ChangeNotifierProvider<AppProvider>.value(
            value: app,
            child: MaterialApp(home: Scaffold(body: child)),
          ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  group('CountStepper fast entry', () {
    testWidgets('step-size choices change both plus and minus', (tester) async {
      var value = 10;
      await _mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) => CountStepper(
            value: value,
            min: 0,
            max: 100,
            stepSizes: const [1, 5, 10, 25],
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );

      await tester.tap(find.text('×10'));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(value, 20);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(value, 10);
    });

    testWidgets('tapping the value accepts a typed number', (tester) async {
      var value = 0;
      await _mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) => CountStepper(
            value: value,
            min: 0,
            max: 100,
            stepSizes: const [1, 5, 10, 25],
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );

      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      expect(find.text('Enter number'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '24');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(value, 24);
    });

    testWidgets('holding plus repeats and stops on release', (tester) async {
      var value = 0;
      await _mount(
        tester,
        StatefulBuilder(
          builder: (context, setState) => CountStepper(
            value: value,
            min: 0,
            max: 100,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 360));
      expect(value, greaterThan(1));
      await gesture.up();
      final releasedAt = value;
      await tester.pump(const Duration(milliseconds: 400));
      expect(value, releasedAt);
    });
  });

  testWidgets('the chip editor can add a custom named colour', (tester) async {
    List<ChipColor>? changed;
    await _mount(
      tester,
      SingleChildScrollView(
        child: ChipSetEditor(
          initial: _chips,
          initialName: 'Test set',
          onChanged: (chips, _) => changed = chips,
        ),
      ),
    );

    await tester.tap(find.text('Add a colour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom colour'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPicker), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('custom-chip-colour-name')),
      'Lavender',
    );
    await tester.tap(find.text('Add colour'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.last.color, 'Lavender');
    expect(changed!.last.hex, isNot(isIn(_chips.map((c) => c.hex))));
  });

  group('unified game preferences', () {
    test('new stack/depth fields round-trip and old maps stay compatible', () {
      final preset = _preset(
        'round-trip',
        forceStack: 12000,
        targetDepthBB: 150,
      );
      final decoded = tournamentPresetFromMap(tournamentPresetToMap(preset));
      expect(decoded.forceStack, 12000);
      expect(decoded.targetDepthBB, 150);

      final old = tournamentPresetToMap(preset)
        ..remove('forceStack')
        ..remove('targetDepthBB');
      final migrated = tournamentPresetFromMap(old);
      expect(migrated.forceStack, isNull);
      expect(migrated.targetDepthBB, isNull);
    });

    test('one selected preset is the default and deletion falls back', () {
      final app = _provider();
      addTearDown(app.dispose);
      final custom = _preset('custom-default', buyIn: 47);
      expect(app.savePreset(custom), isTrue);

      app.setDefaultGamePreset(custom.id);
      expect(app.defaultGamePresetId, custom.id);
      expect(app.defaultGamePreset.buyIn, 47);

      app.deletePreset(custom.id);
      expect(app.defaultGamePresetId, isNull);
      expect(app.defaultGamePreset.id, 'starter-freezeout');
    });

    test('Free allows three saved preferences and Premium is unlimited', () {
      final app = _provider();
      addTearDown(app.dispose);
      expect(app.savePreset(_preset('one')), isTrue);
      expect(app.savePreset(_preset('two')), isTrue);
      expect(app.savePreset(_preset('three')), isTrue);
      expect(app.savePreset(_preset('four')), isFalse);

      app.premiumTier = PremiumTier.premium;
      expect(app.savePreset(_preset('four')), isTrue);
    });

    test('editing a referenced chip set refreshes the preset label and chips', () {
      final app = _provider();
      addTearDown(app.dispose);
      app.saveChipSet('linked', 'Friday chips', _chips);
      expect(
        app.savePreset(
          _preset('linked-preset').copyWith(
            chipSetName: 'Friday chips',
            chipSet: _chips,
          ),
        ),
        isTrue,
      );
      const edited = [
        ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 120),
        ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 80),
      ];

      app.saveChipSet('linked', 'Friday chips updated', edited);

      final preset = app.presetById('linked-preset')!;
      expect(preset.chipSetName, 'Friday chips updated');
      expect(preset.chipSet, edited);
    });

    test('a complete preset seeds StructureBuilder without a second model', () {
      final preset = _preset(
        'builder',
        buyIn: 35,
        forceStack: 12000,
        targetDepthBB: 150,
      );
      final settings = preset.applyTo(_baseSettings());
      final controller = StructureBuilderController.fromSettings(settings);
      addTearDown(controller.dispose);

      expect(controller.buyIn, 35);
      expect(controller.format, TournamentFormat.rebuy);
      expect(controller.bonusPct, 15);
      expect(controller.options.paidPlaces, 3);
      expect(controller.options.maxPerTable, 7);
      expect(controller.forceStack, 12000);
      expect(controller.depthBB, 150);
      expect(controller.chipSet, _chips);
    });

    testWidgets(
      'selected default seeds event, explicit preset wins over draft',
      (tester) async {
        final app = _provider();
        final selected = _preset('selected', buyIn: 41);
        final explicit = _preset('explicit', buyIn: 63);
        app.savePreset(selected);
        app.savePreset(explicit);
        app.setDefaultGamePreset(selected.id);

        await _mount(tester, const CreateTournamentScreen(), app: app);
        expect(
          tester.widget<CountStepper>(find.byType(CountStepper).first).value,
          41,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        app.saveEventDraft(_baseSettings().copyWith(buyIn: 52));
        await _mount(
          tester,
          const CreateTournamentScreen(presetId: 'explicit'),
          app: app,
        );
        expect(
          tester.widget<CountStepper>(find.byType(CountStepper).first).value,
          63,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        app.dispose();
      },
    );

    testWidgets('selected default seeds quick game', (tester) async {
      final app = _provider();
      final selected = _preset('selected-quick', buyIn: 44);
      app.savePreset(selected);
      app.setDefaultGamePreset(selected.id);

      await _mount(tester, const QuickStartScreen(), app: app);
      await tester.ensureVisible(find.text('More options'));
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      final buyIn = tester.widget<TextFormField>(
        find.byKey(const Key('opt-buyin')),
      );
      expect(buyIn.initialValue, '44');
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });
  });

  testWidgets('the builder exposes complete Save as preset', (tester) async {
    final controller = StructureBuilderController.fromSettings(_baseSettings());
    addTearDown(controller.dispose);
    GameSettings? saved;
    await _mount(
      tester,
      SingleChildScrollView(
        child: StructureBuilder(
          controller: controller,
          confirmLabel: 'Confirm',
          onSavePreset: () => saved = controller.applyTo(_baseSettings()),
          onConfirm: (_) {},
        ),
      ),
    );

    expect(find.text('Save as preset'), findsOneWidget);
    await tester.ensureVisible(find.text('Save as preset'));
    await tester.tap(find.text('Save as preset'));
    expect(saved, isNotNull);
    expect(saved!.chipSet, _chips);
    expect(saved!.buyIn, controller.buyIn);
  });

  testWidgets('a fourth preset refusal offers See Premium', (tester) async {
    final app = _provider();
    for (final id in ['one', 'two', 'three']) {
      expect(app.savePreset(_preset(id)), isTrue);
    }
    await _mount(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => offerSaveGamePreset(context, app, _baseSettings()),
          child: const Text('Open save'),
        ),
      ),
      app: app,
    );

    await tester.tap(find.text('Open save'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fourth');
    await tester.tap(find.text('Save preset'));
    await tester.pump();

    expect(find.text('Free accounts can save up to 3 presets.'), findsOneWidget);
    expect(find.text('See Premium'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  testWidgets('event bonus estimate uses the engine proposed stack', (
    tester,
  ) async {
    final app = _provider();
    final settings = _baseSettings().copyWith(
      earlyArrivalBonusEnabled: true,
      earlyArrivalBonusPctOverride: 0.10,
      clearForceStack: true,
    );
    final controller = StructureBuilderController.fromSettings(settings);
    final expectedStack = controller.structure.startingStack;
    controller.dispose();

    await _mount(
      tester,
      CreateTournamentScreen(initialSettings: settings),
      app: app,
    );

    expect(
      find.textContaining(
        '≈ ${expectedStack ~/ 10} chips at a ${Formatters.chips(expectedStack)} stack',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
