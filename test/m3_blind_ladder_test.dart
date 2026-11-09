import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/structure_builder_controller.dart';
import 'package:poker_night/utils/tournament_engine.dart';

void main() {
  group('M3: Blind ladder from the chip-set grid (B11, B12)', () {
    test('individualAnteValue uses nearest payable chip to 12% of big blind', () {
      final chipVals = [5, 25, 100, 500];
      // 12% of 100 = 12 -> nearest payable chip is 5 (or 25? |12-5|=7, |12-25|=13 -> 5)
      expect(TournamentEngine.individualAnteValue(100, chipVals), 5);
      // 12% of 200 = 24 -> nearest payable chip is 25 (|24-25|=1 vs |24-5|=19 -> 25)
      expect(TournamentEngine.individualAnteValue(200, chipVals), 25);
    });

    test('recalculate recomputes antes so they never stay stale', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final params = TournamentParams(
        players: 8,
        durationHours: 3.0,
        buyIn: 20,
        chipSet: chipSet,
        rebuys: false,
        rebuysCloseLevel: 0,
        reEntry: false,
        addOn: false,
        anteEnabled: true,
        anteAfterLevel: 3,
        anteStyle: AnteStyle.bigBlind,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      );

      final base = TournamentEngine.generate(params);
      final anteLevelIdx = base.levels.indexWhere((l) => l.ante != null);
      expect(anteLevelIdx, greaterThanOrEqualTo(0));
      final origLevel = base.levels[anteLevelIdx];
      expect(origLevel.ante, equals(origLevel.bb));

      // Pin an earlier or later level with doubled BB to force recalculation of anteLevel
      final pinLevelNum = anteLevelIdx + 1;
      final newBB = origLevel.bb * 2;
      final recalculated = TournamentEngine.recalculate(
        params,
        [PinnedLevel(levelNum: pinLevelNum, sb: origLevel.sb * 2, bb: newBB)],
      );

      final recalcLevel = recalculated.levels[anteLevelIdx];
      expect(recalcLevel.bb, equals(newBB));
      expect(recalcLevel.ante, equals(newBB),
          reason: 'Big blind ante must match the new recalculated BB, not the old stale one');
    });

    test('3h, 8 players at 100 BB: stack is 100 BB and does not shrink to hit finish time', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final c = StructureBuilderController(
        mode: BuilderMode.quick,
        chipSet: chipSet,
        players: 8,
        durationHours: 3.0,
        format: TournamentFormat.freezeOut,
      );

      expect(c.structure.openingBBDepth, closeTo(100.0, 1.0),
          reason: 'Starting stack must be 100 BB default; engine never shrinks stack');
    });
  });
}
