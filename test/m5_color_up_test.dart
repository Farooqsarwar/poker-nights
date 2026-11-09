import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';

void main() {
  group('M5: Exact colour-up (B2)', () {
    test('every colour-up instruction multiplies out exactly', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final structure = TournamentEngine.generate(TournamentParams(
        players: 8,
        durationHours: 3,
        buyIn: 20,
        chipSet: chipSet,
        rebuys: true,
        rebuysCloseLevel: 4,
        reEntry: false,
        addOn: false,
        anteEnabled: true,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      ));

      final regex = RegExp(r'exchange (\d+) × (\d+)[^f]+for (\d+) × (\d+)');
      var verifiedExchanges = 0;

      for (final line in structure.colorUpInstructions) {
        final match = regex.firstMatch(line);
        if (match != null) {
          final fromCount = int.parse(match.group(1)!);
          final fromVal = int.parse(match.group(2)!);
          final toCount = int.parse(match.group(3)!);
          final toVal = int.parse(match.group(4)!);

          expect(fromCount * fromVal, equals(toCount * toVal),
              reason: 'Colour-up math must multiply out exactly ($line) (fixes B2 / M5)');
          verifiedExchanges++;
        }
      }
      expect(verifiedExchanges, greaterThan(0), reason: 'Should have at least one colour-up exchange');
    });

    test('a chip is retired only when no later blind or ante needs it', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final structure = TournamentEngine.generate(TournamentParams(
        players: 8,
        durationHours: 3,
        buyIn: 20,
        chipSet: chipSet,
        rebuys: true,
        rebuysCloseLevel: 4,
        reEntry: false,
        addOn: false,
        anteEnabled: true,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      ));

      final regex = RegExp(r'Level (\d+): exchange \d+ × (\d+) [^f]+for \d+ × (\d+)');
      for (final line in structure.colorUpInstructions) {
        final match = regex.firstMatch(line);
        if (match != null) {
          final levelNum = int.parse(match.group(1)!);
          final nextVal = int.parse(match.group(3)!);

          // All levels from levelNum onward must be multiples of nextVal
          for (var i = levelNum - 1; i < structure.levels.length; i++) {
            final l = structure.levels[i];
            expect(l.sb % nextVal, 0,
                reason: 'Level ${l.level} SB ${l.sb} must be multiple of $nextVal after chip retirement');
            expect(l.bb % nextVal, 0,
                reason: 'Level ${l.level} BB ${l.bb} must be multiple of $nextVal after chip retirement');
            if (l.ante != null && l.ante! > 0) {
              expect(l.ante! % nextVal, 0,
                  reason: 'Level ${l.level} Ante ${l.ante} must be multiple of $nextVal after chip retirement');
            }
          }
        }
      }
    });
  });
}
