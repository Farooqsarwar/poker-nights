import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/models/tournament_preset.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/utils/model_codec.dart';
import 'package:poker_night/utils/formatters.dart';
import 'package:poker_night/utils/structure_builder_controller.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/utils/tv_cast.dart';
import 'package:poker_night/widgets/game_preferences_card.dart';
import 'package:provider/provider.dart';

/// Round 4 (Dani, 4 Nov): T10 colour-up breaks, Turbo depth, Settings
/// preferences.
TournamentParams _params({int colorUpBreakMins = kColorUpBreakMins}) =>
    TournamentParams(
      players: 9,
      durationHours: 4,
      buyIn: 20,
      chipSet: TournamentEngine.getPreset('Home Set (4 colour)'),
      rebuys: false,
      rebuysCloseLevel: 0,
      reEntry: false,
      addOn: false,
      anteEnabled: true,
      anteAfterLevel: 6,
      koEnabled: false,
      koAmount: 0,
      organizerPct: 0,
      pace: PaceMode.regular,
      colorUpBreakMins: colorUpBreakMins,
    );

void main() {
  group('Cast address', () {
    test('uses a separate public code URL on web and native', () {
      expect(
        tvDisplayUri(
          'TV 123',
          base: Uri.parse('http://localhost:7357/host-dashboard'),
        ).toString(),
        'http://localhost:7357/tv/TV%20123',
      );
      expect(
        tvDisplayUri('TV123', base: Uri.parse('file:///app/')).toString(),
        'https://poker-night-tools.web.app/tv/TV123',
      );
    });
  });

  group('T10 colour-up break', () {
    test('every colour-up exchange has a break before its level', () {
      final s = TournamentEngine.generate(_params());
      final levelRe = RegExp(r'^Level (\d+): exchange');
      final exchanges = s.colorUpInstructions
          .map(levelRe.firstMatch)
          .whereType<RegExpMatch>()
          .toList();
      expect(exchanges, isNotEmpty,
          reason: 'the Home Set needs at least one colour-up');
      for (final m in exchanges) {
        final level = int.parse(m.group(1)!);
        final brk = s.breakAfter(level - 1);
        expect(brk, isNotNull, reason: 'no break before level $level');
        expect(brk!.durationMins, greaterThan(0));
      }
    });

    test('the break is the configured length; 0 switches them off', () {
      final on = TournamentEngine.generate(_params());
      final off = TournamentEngine.generate(_params(colorUpBreakMins: 0));
      expect(on.breaks.where((b) => b.durationMins == kColorUpBreakMins),
          isNotEmpty);
      expect(off.breaks, isEmpty);
      expect(on.expectedFinishMins,
          greaterThan(off.expectedFinishMins - 1),
          reason: 'breaks are part of the finish time');
    });

    test('a break is never placed on top of another break', () {
      final s = TournamentEngine.generate(_params());
      final afters = s.breaks.map((b) => b.afterLevel).toList();
      expect(afters.toSet().length, afters.length);
    });

    test('zero preserves the legacy ladder, breaks and finish', () {
      final legacyParams = _params(colorUpBreakMins: 0);
      final copiedParams = _params().copyWith(colorUpBreakMins: 0);
      final legacy = TournamentEngine.generate(legacyParams);
      final copied = TournamentEngine.generate(copiedParams);
      final enabled = TournamentEngine.generate(_params());

      List<(int, int, int?, int)> ladder(TournamentStructure structure) => [
            for (final level in structure.levels)
              (level.sb, level.bb, level.ante, level.durationMins),
          ];

      expect(copiedParams.colorUpBreakMins, 0);
      expect(ladder(copied), ladder(legacy));
      expect(copied.breaks, legacy.breaks);
      expect(copied.expectedFinishMins, legacy.expectedFinishMins);
      expect(ladder(enabled), ladder(legacy),
          reason: 'WP11 adds room time, not a different blind ladder');
      expect(
        enabled.expectedFinishMins,
        legacy.expectedFinishMins + enabled.totalBreakMins,
      );
    });

    test('an existing host break is reused and bounds are valid', () {
      final preview = TournamentEngine.generate(_params());
      final exchange = RegExp(r'^Level (\d+): exchange')
          .firstMatch(preview.colorUpInstructions.first)!;
      final after = int.parse(exchange.group(1)!) - 1;
      final withHostBreak = TournamentEngine.generate(
        _params().copyWith(
          breaks: [ScheduledBreak(afterLevel: after, durationMins: 11)],
        ),
      );

      final atExchange = withHostBreak.breaks
          .where((b) => b.afterLevel == after)
          .toList();
      expect(atExchange, hasLength(1));
      expect(atExchange.single.durationMins, 11);
      for (final brk in withHostBreak.breaks) {
        expect(brk.afterLevel, greaterThanOrEqualTo(1));
        expect(brk.afterLevel, lessThan(withHostBreak.effectivePlannedLevels));
      }
    });

    test('final ante ladder drives a fresh, duplicate-free schedule', () {
      final s = TournamentEngine.generate(_params());
      final exchangeRows = s.colorUpInstructions
          .where((line) => line.startsWith('Level '))
          .toList();
      expect(exchangeRows.toSet(), hasLength(exchangeRows.length));
      expect(s.levels.any((level) => (level.ante ?? 0) > 0), isTrue);
      for (final row in exchangeRows) {
        final level = int.parse(
          RegExp(r'^Level (\d+):').firstMatch(row)!.group(1)!,
        );
        expect(s.breakAfter(level - 1), isNotNull);
        expect(row, contains('$kColorUpBreakMins-minute break before it'));
      }
    });

    test('configured colour-up time survives settings persistence', () {
      const settings = GameSettings(
        name: 'Friday',
        date: '2026-11-13',
        time: '20:00',
        location: 'Home',
        players: 9,
        durationHours: 4,
        buyIn: 20,
        koEnabled: false,
        koAmount: 0,
        rebuys: false,
        rebuysCloseLevel: 0,
        addOn: false,
        anteEnabled: true,
        anteAfterLevel: 6,
        organizerPct: 0,
        chipSet: [],
        chipSetName: 'Home set',
        colorUpBreakMins: 0,
      );
      final map = gameSettingsToMap(settings);
      final restored = gameSettingsFromMap(map);
      expect(map['colorUpBreakMins'], 0);
      expect(restored.colorUpBreakMins, 0);
      expect(restored.copyWith().colorUpBreakMins, 0);
      final preset = TournamentPreset.fromSettings(
        id: 'saved',
        name: 'Saved',
        settings: settings,
      );
      final presetBack = tournamentPresetFromMap(tournamentPresetToMap(preset));
      expect(presetBack.colorUpBreakMins, 0);
      expect(presetBack.applyTo(settings.copyWith(colorUpBreakMins: 5))
          .colorUpBreakMins, 0);
      expect(
        gameSettingsFromMap({...map}..remove('colorUpBreakMins'))
            .colorUpBreakMins,
        kColorUpBreakMins,
      );
    });
  });

  group('Turbo depth', () {
    test('Turbo is 50 big blinds, Normal 100, Deep 150', () {
      expect(TournamentType.turbo.depthBB, 50);
      expect(TournamentType.normal.depthBB, 100);
      expect(TournamentType.deep.depthBB, 150);
    });

    test('builder Turbo opens near 50 BB for 6, 9 and 12 players', () {
      for (final players in [6, 9, 12]) {
        final controller = StructureBuilderController(
          mode: BuilderMode.tool,
          chipSet: TournamentEngine.getPreset('Home Set (4 colour)'),
          players: players,
          durationHours: 4,
          format: TournamentFormat.freezeOut,
        )..setType(TournamentType.turbo);
        final structure = controller.structure;
        final depth = structure.startingStack / structure.levels.first.bb;
        expect(
          depth,
          inInclusiveRange(45, 70),
          reason: '$players players opened at ${depth.toStringAsFixed(1)} BB',
        );
        controller.dispose();
      }
    });
  });

  group('Settings game preferences (#23)', () {
    test('every default a game starts from is listed', () {
      final rows = GamePreferencesCard.rowsFor(AppProvider.seedPresets.first);
      final titles = rows.map((r) => r.$1).toList();
      expect(titles, [
        'Tournament type',
        'Format',
        'Level length',
        'Ante',
        'Buy-in',
        'On-time bonus',
        'Rebuys close',
      ]);
      for (final r in rows) {
        expect(r.$2, isNotEmpty, reason: '${r.$1} has no value');
      }
      final bonusRows = GamePreferencesCard.rowsFor(
        AppProvider.seedPresets.first.copyWith(
          earlyArrivalBonusEnabled: true,
          earlyArrivalBonusPctOverride: 0.125,
        ),
      );
      expect(
        bonusRows.singleWhere((row) => row.$1 == 'On-time bonus').$2,
        '12.5% extra chips',
      );
    });

    testWidgets('card fits 360 px at 1.5x and currency is editable to None',
        (tester) async {
      final app = AppProvider();
      Formatters.currencySymbol = '';
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 1200),
                textScaler: TextScaler.linear(1.5),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(child: GamePreferencesCard()),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('pref-currency'))).height,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(find.byKey(const Key('pref-currency')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pref-currency-US dollar')));
      await tester.pumpAndSettle();
      expect(app.currencySymbol, r'$');

      await tester.tap(find.byKey(const Key('pref-currency')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pref-currency-None')));
      await tester.pumpAndSettle();
      expect(app.currencySymbol, isEmpty);
      expect(find.text('None'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      tester.view.reset();
      Formatters.currencySymbol = '';
    });
  });
}
