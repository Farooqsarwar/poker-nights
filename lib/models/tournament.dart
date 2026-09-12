import 'chip_color.dart';

/// A single blind level within the tournament structure.
class BlindLevel {
  const BlindLevel({
    required this.level,
    required this.sb,
    required this.bb,
    required this.ante,
    required this.durationMins,
    this.manuallyEdited = false,
  });

  final int level;
  final int sb;
  final int bb;
  final int? ante;
  final int durationMins;

  /// True when a human set this level's values rather than the engine.
  ///
  /// Specification sections 11 and 29: "manual future edits need visible
  /// markers and cannot be silently overwritten by Recalculate". Recalculate
  /// used to rebuild the whole ladder, so a host who hand-tuned level 9 lost
  /// it the next time anything regenerated — with no warning and no way to
  /// tell it had happened.
  ///
  /// Defaults to false, so every structure written before this field existed
  /// loads as "all engine-generated", which is what it was.
  final bool manuallyEdited;

  bool get hasAnte => ante != null;

  BlindLevel copyWith({
    int? level,
    int? sb,
    int? bb,
    int? ante,
    bool clearAnte = false,
    int? durationMins,
    bool? manuallyEdited,
  }) {
    return BlindLevel(
      level: level ?? this.level,
      sb: sb ?? this.sb,
      bb: bb ?? this.bb,
      ante: clearAnte ? null : (ante ?? this.ante),
      durationMins: durationMins ?? this.durationMins,
      manuallyEdited: manuallyEdited ?? this.manuallyEdited,
    );
  }
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

/// The admin's ante choice at creation (checklist 09-010). "recommend" keeps
/// the system recommendation (big blind ante from a fixed level onward),
/// while the other values override it explicitly.
enum AntePreference { recommend, none, bigBlind, individual }

/// Parameters used to generate a tournament structure.
class TournamentParams {
  const TournamentParams({
    required this.players,
    required this.durationHours,
    required this.buyIn,
    required this.chipSet,
    required this.rebuys,
    required this.rebuysCloseLevel,
    this.rebuyLimit,
    this.reEntry = false,
    required this.addOn,
    required this.anteEnabled,
    required this.anteAfterLevel,
    this.anteStyle = AnteStyle.bigBlind,
    required this.koEnabled,
    required this.koAmount,
    required this.organizerPct,
    this.rebuyCost,
    this.addOnCost,
  });

  final int players;
  final double durationHours;
  final int buyIn;
  final List<ChipColor> chipSet;
  final bool rebuys;
  final int rebuysCloseLevel;
  final int? rebuyLimit;

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

  final int? rebuyCost;
  final int? addOnCost;

  int get effectiveRebuyCost => rebuyCost ?? buyIn;
  int get effectiveAddOnCost => addOnCost ?? buyIn;
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
    this.plannedLevels = 0,
    required this.expectedFinishMins,
    required this.prizes,
    required this.prizePool,
    required this.organizerAmount,
    this.roundingRemainder = 0,
    this.paidPlaces = 0,
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

  /// How many of [levels] fall inside the TARGET duration.
  ///
  /// The generator appends a short tail of spare levels so a slow field never
  /// plays off the end of the structure (11-014). Those spares are meant to go
  /// unused, so anything modelling PACE — the blind growth exponent, the
  /// finish estimate, the speed-up/slow-down drift — must count only the
  /// planned levels. Counting the tail flattened the curve by roughly 30% and
  /// made every tournament report ~45 minutes of drift from level 1.
  ///
  /// 0 on structures written before this field existed; callers fall back to
  /// `levels.length`.
  final int plannedLevels;

  /// Planned levels, or the whole ladder for a legacy structure.
  int get effectivePlannedLevels =>
      plannedLevels > 0 && plannedLevels <= levels.length
          ? plannedLevels
          : levels.length;

  final int expectedFinishMins;
  final List<Prize> prizes;
  final int prizePool;
  final int organizerAmount;

  /// Money left over when the eligible gross is not a multiple of 10.
  ///
  /// Every displayed payout must be a multiple of 10 and must never end in 5
  /// (14-022 / 14-023, Technical section 9.4). A pool that is not itself a
  /// multiple of 10 cannot be split into such payouts at all — any partition
  /// of multiples of 10 sums to a multiple of 10 — so the residue has to leave
  /// the pool. It is tracked SEPARATELY from [organizerAmount] because it is
  /// not an organizer cut and must never be labelled as one (14-010, 14-011);
  /// show it as "rounding remainder".
  final int roundingRemainder;

  /// How many places are paid, WITHOUT the amounts.
  ///
  /// Non-admin views need only the count — "3 places paid" — never the
  /// figures. Projections therefore ship an EMPTY `prizes` list and this
  /// scalar instead, which lets the Firestore rules verify the omission
  /// (`prizes.size() == 0`). Zeroed `Prize` entries could not be verified:
  /// the rules language cannot iterate a list to confirm every amount is 0,
  /// so the boundary would have rested on the client alone (19-019).
  final int paidPlaces;

  /// Paid-place count for display, whichever shape this copy is in.
  int get paidPlacesForDisplay =>
      prizes.isNotEmpty ? prizes.length : paidPlaces;

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
    int? plannedLevels,
    int? expectedFinishMins,
    List<Prize>? prizes,
    int? prizePool,
    int? organizerAmount,
    int? roundingRemainder,
    int? paidPlaces,
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
      plannedLevels: plannedLevels ?? this.plannedLevels,
      expectedFinishMins: expectedFinishMins ?? this.expectedFinishMins,
      prizes: prizes ?? this.prizes,
      prizePool: prizePool ?? this.prizePool,
      organizerAmount: organizerAmount ?? this.organizerAmount,
      roundingRemainder: roundingRemainder ?? this.roundingRemainder,
      paidPlaces: paidPlaces ?? this.paidPlaces,
      colorUpInstructions: colorUpInstructions ?? this.colorUpInstructions,
      warnings: warnings ?? this.warnings,
    );
  }
}
