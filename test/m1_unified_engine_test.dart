import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/utils/structure_builder_controller.dart';
import 'package:poker_night/utils/tournament_engine.dart';

void main() {
  group('M1: One engine, one stack object for every flow', () {
    test('seedChipSet has 4 colours matching its name "Home Set (4 colour)"', () {
      final seed = AppProvider.seedChipSet;
      expect(seed.name, 'Home Set (4 colour)');
      expect(seed.chips.length, 4,
          reason: 'A chip set named "Home Set (4 colour)" must have exactly 4 colours (fixes C1)');
    });

    test('identical inputs across quick, event and tool modes produce identical stack and BB', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      const players = 9;
      const durationHours = 4.0;
      const format = TournamentFormat.freezeOut;

      final quick = StructureBuilderController(
        mode: BuilderMode.quick,
        chipSet: chipSet,
        players: players,
        durationHours: durationHours,
        format: format,
      );

      final event = StructureBuilderController(
        mode: BuilderMode.event,
        chipSet: chipSet,
        players: players,
        durationHours: durationHours,
        format: format,
      );

      final tool = StructureBuilderController(
        mode: BuilderMode.tool,
        chipSet: chipSet,
        players: players,
        durationHours: durationHours,
        format: format,
      );

      expect(quick.structure.startingStack, event.structure.startingStack,
          reason: 'Quick game and Event must produce identical starting stack for identical inputs');
      expect(quick.structure.startingStack, tool.structure.startingStack,
          reason: 'Quick game and Tool must produce identical starting stack for identical inputs');

      expect(quick.structure.levels.first.bb, event.structure.levels.first.bb,
          reason: 'Quick game and Event must produce identical opening BB for identical inputs');
      expect(quick.structure.levels.first.bb, tool.structure.levels.first.bb,
          reason: 'Quick game and Tool must produce identical opening BB for identical inputs');

      expect(quick.stackDepthBB, event.stackDepthBB,
          reason: 'Quick game and Event must produce identical stack depth for identical inputs');
      expect(quick.stackDepthBB, tool.stackDepthBB,
          reason: 'Quick game and Tool must produce identical stack depth for identical inputs');
    });

    test('actual opening BB depth equals startingStack / openingBB', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final c = StructureBuilderController(
        mode: BuilderMode.quick,
        chipSet: chipSet,
        players: 9,
        durationHours: 4,
        format: TournamentFormat.freezeOut,
      );

      final structure = c.structure;
      final expectedDepth = structure.startingStack / structure.levels.first.bb;
      expect(c.stackDepthBB, closeTo(expectedDepth, 0.01));
    });
  });
}
