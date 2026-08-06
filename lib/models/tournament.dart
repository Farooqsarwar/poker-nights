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

/// How the ante is posted once enabled (technical §11: Off, big blind ante,
/// individual ante). The big blind ante is the recommended default.
enum AnteStyle { bigBlind, individual }

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
    this.anteStyle = AnteStyle.bigBlind,
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
  final AnteStyle anteStyle;
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
    required this.addOnChipPlan,
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

  /// Recommended physical composition of one add-on (checklist 12-060).
  final List<ChipPlanEntry> addOnChipPlan;

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

  /// Returns a copy with only the prize-related fields updated.
  /// All blind levels and manual overrides remain intact.
  TournamentStructure copyWith({
    int? startingStack,
    List<ChipPlanEntry>? chipPlan,
    int? rebuyStack,
    List<ChipPlanEntry>? rebuyChipPlan,
    int? addOnStack,
    List<ChipPlanEntry>? addOnChipPlan,
    List<BlindLevel>? levels,
    int? levelDuration,
    int? expectedFinishMins,
    List<Prize>? prizes,
    int? prizePool,
    int? organizerAmount,
    List<String>? colorUpInstructions,
    List<String>? warnings,
  }) {
    return TournamentStructure(
      startingStack: startingStack ?? this.startingStack,
      chipPlan: chipPlan ?? this.chipPlan,
      rebuyStack: rebuyStack ?? this.rebuyStack,
      rebuyChipPlan: rebuyChipPlan ?? this.rebuyChipPlan,
      addOnStack: addOnStack ?? this.addOnStack,
      addOnChipPlan: addOnChipPlan ?? this.addOnChipPlan,
      levels: levels ?? this.levels,
      levelDuration: levelDuration ?? this.levelDuration,
      expectedFinishMins: expectedFinishMins ?? this.expectedFinishMins,
      prizes: prizes ?? this.prizes,
      prizePool: prizePool ?? this.prizePool,
      organizerAmount: organizerAmount ?? this.organizerAmount,
      colorUpInstructions: colorUpInstructions ?? this.colorUpInstructions,
      warnings: warnings ?? this.warnings,
    );
  }
}

