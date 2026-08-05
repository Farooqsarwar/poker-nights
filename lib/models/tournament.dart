import 'chip_color.dart';

/// A single blind level within the tournament structure.
class BlindLevel {
  const BlindLevel({
    required this.level,
    required this.sb,
    required this.bb,
    required this.ante,
    required this.durationMins,
  });

  final int level;
  final int sb;
  final int bb;
  final int? ante;
  final int durationMins;

  bool get hasAnte => ante != null;
}

/// A chip used within a starting/rebuystack plan.
class ChipPlanEntry {
  const ChipPlanEntry({
    required this.color,
    required this.hex,
    required this.value,
    required this.count,
  });

  final String color;
  final int hex;
  final int value;
  final int count;

  int get total => value * count;
}

/// Parameters used to generate a tournament structure.
class TournamentParams {
  const TournamentParams({
    required this.players,
    required this.durationHours,
    required this.buyIn,
    required this.chipSet,
    required this.rebuys,
    required this.rebuysCloseLevel,
    this.reEntry = false,
    required this.addOn,
    required this.anteEnabled,
    required this.anteAfterLevel,
    required this.koEnabled,
    required this.koAmount,
    required this.organizerPct,
  });

  final int players;
  final double durationHours;
  final int buyIn;
  final List<ChipColor> chipSet;
  final bool rebuys;
  final int rebuysCloseLevel;

  /// Re-entry enabled as a separate, secondary option (checklist 09-030,
  /// 14-003/14-012). Re-entries are expected at a lower rate than rebuys.
  final bool reEntry;

  final bool addOn;
  final bool anteEnabled;
  final int anteAfterLevel;
  final bool koEnabled;
  final int koAmount;
  final int organizerPct;
}

/// Prize line.
class Prize {
  const Prize({required this.place, required this.amount});

  final int place;
  final int amount;
}

/// The generated tournament structure.
class TournamentStructure {
  const TournamentStructure({
    required this.startingStack,
    required this.chipPlan,
    required this.rebuyStack,
    required this.rebuyChipPlan,
    required this.addOnStack,
    required this.levels,
    required this.levelDuration,
    required this.expectedFinishMins,
    required this.prizes,
    required this.prizePool,
    required this.organizerAmount,
    required this.colorUpInstructions,
    required this.warnings,
  });

  final int startingStack;
  final List<ChipPlanEntry> chipPlan;
  final int rebuyStack;
  final List<ChipPlanEntry> rebuyChipPlan;
  final int addOnStack;
  final List<BlindLevel> levels;
  final int levelDuration;
  final int expectedFinishMins;
  final List<Prize> prizes;
  final int prizePool;
  final int organizerAmount;
  final List<String> colorUpInstructions;
  final List<String> warnings;

  int get expectedFinishHours => expectedFinishMins ~/ 60;
  int get expectedFinishRemainderMins => expectedFinishMins % 60;
}

