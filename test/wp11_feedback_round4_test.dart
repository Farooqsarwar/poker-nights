import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/utils/structure_builder_controller.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/game_preferences_card.dart';

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
  });

  group('Turbo depth', () {
    test('Turbo is 50 big blinds, Normal 100, Deep 150', () {
      expect(TournamentType.turbo.depthBB, 50);
      expect(TournamentType.normal.depthBB, 100);
      expect(TournamentType.deep.depthBB, 150);
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
    });
  });
}
