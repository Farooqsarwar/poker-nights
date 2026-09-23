import 'dart:math' as math;

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

/// How many of the field are expected to take a rebuy, a re-entry or an add-on.
///
/// These were hard-coded inside the engine, which meant the single biggest
/// input to the blind curve — how many chips end up on the table — could not be
/// changed by the one person who actually knows the answer. A host who runs the
/// same twelve people every month knows whether they all rebuy or none of them
/// do; a constant does not. They survive as the DEFAULTS the fields are
/// prefilled with, so a host who touches nothing gets exactly what they got
/// before.
const double kExpectedRebuyRate = 0.35;
const double kExpectedReEntryRate = 0.20;
const double kExpectedAddOnRate = 0.65;

/// How steeply the prize pool falls away from first place.
///
/// The engine already offered a choice of how MANY places to pay. It offered no
/// choice of how the money is spread across them, so a host who wanted three
/// paid places but a flatter split had nowhere to say it — their only lever was
/// to pay a fourth place they did not want to pay.
///
/// [standard] is the client's own section-25 reference style and is left
/// untouched: same weights, same reference table, same figures as before. The
/// other two are geometric curves — each place gets [ratio] times the one above
/// — which is the shape every other tournament tool uses and the one the
/// client's spec names.
enum PayoutShape {
  /// The reference style (73/27, 57/30/13, 56/30/10/4). The default, and the
  /// only shape that consults the section-25 reference table.
  standard,

  /// Steeper than standard: a bigger first prize, a thinner tail.
  topHeavy,

  /// Shallower than standard: the min-cash is worth collecting.
  flat;

  /// Decay per place for the geometric shapes. Unused by [standard], which
  /// carries explicit per-count weights instead.
  double get ratio => switch (this) {
        PayoutShape.standard => 0.65,
        PayoutShape.topHeavy => 0.50,
        PayoutShape.flat => 0.90,
      };

  String get label => switch (this) {
        PayoutShape.standard => 'Standard',
        PayoutShape.topHeavy => 'Top heavy',
        PayoutShape.flat => 'Flat',
      };

  String get blurb => switch (this) {
        PayoutShape.standard => 'The recommended split for this field and pool.',
        PayoutShape.topHeavy => 'More to the winner, less down the list.',
        PayoutShape.flat => 'Closer together — the last paid place still earns.',
      };
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
    this.breaks = const [],
    this.rebuyCloseChosenByOrganizer = false,
    this.expectedRebuys,
    this.expectedReEntries,
    this.expectedAddOns,
    this.rebuyChips,
    this.reEntryChips,
    this.addOnChips,
    this.levelDurationMins,
    this.payoutShape = PayoutShape.standard,
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

  /// True when the organizer set [rebuysCloseLevel] deliberately rather than
  /// leaving the UI default.
  ///
  /// Addendum section 6: "Level 6 remains the UI default, not the
  /// authoritative AI rule" and "Manual organizer changes are authoritative
  /// for that tournament". The engine optimises the default and leaves an
  /// explicit choice alone, so this flag is what separates the two.
  final bool rebuyCloseChosenByOrganizer;

  /// Scheduled breaks to place (specification section 8). Empty means OFF.
  ///
  /// When breaks are ON but no placement was chosen, pass a break with
  /// `afterLevel: 0` and the engine picks the default position: immediately
  /// after the rebuy window when rebuys are enabled, otherwise the structural
  /// midpoint (v11 addendum section 5).
  final List<ScheduledBreak> breaks;

  /// Host overrides for the expected take-up of each entry type. Null means
  /// "use the rate", which is what every tournament created before these
  /// existed does.
  final int? expectedRebuys;
  final int? expectedReEntries;
  final int? expectedAddOns;

  /// Chips handed out for a rebuy, a re-entry and an add-on. Null means "the
  /// starting stack", the engine's long-standing behaviour.
  final int? rebuyChips;
  final int? reEntryChips;
  final int? addOnChips;

  /// Minutes per level, when the host has chosen one. Null leaves the engine
  /// to pick from the duration, which is what it did exclusively before.
  final int? levelDurationMins;

  /// How steeply the prize pool falls away from first place. Defaults to the
  /// reference style, so every tournament that predates the choice splits its
  /// pool exactly as it always did.
  final PayoutShape payoutShape;

  int get effectiveRebuyCost => rebuyCost ?? buyIn;
  int get effectiveAddOnCost => addOnCost ?? buyIn;

  /// Expected take-up, override first and the rate as the fallback. A format
  /// that is switched off contributes nothing however the field is filled in —
  /// a stale number left behind by toggling rebuys off must not keep inflating
  /// the chip count.
  int get effectiveExpectedRebuys => rebuys
      ? math.max(0, expectedRebuys ?? (players * kExpectedRebuyRate).round())
      : 0;

  int get effectiveExpectedReEntries => reEntry
      ? math.max(0, expectedReEntries ?? (players * kExpectedReEntryRate).round())
      : 0;

  int get effectiveExpectedAddOns => addOn
      ? math.max(0, expectedAddOns ?? (players * kExpectedAddOnRate).round())
      : 0;

  TournamentParams copyWith({
    int? players,
    double? durationHours,
    int? buyIn,
    List<ChipColor>? chipSet,
    bool? rebuys,
    int? rebuysCloseLevel,
    int? rebuyLimit,
    bool? reEntry,
    bool? addOn,
    bool? anteEnabled,
    int? anteAfterLevel,
    AnteStyle? anteStyle,
    bool? koEnabled,
    int? koAmount,
    int? organizerPct,
    int? rebuyCost,
    int? addOnCost,
    List<ScheduledBreak>? breaks,
    bool? rebuyCloseChosenByOrganizer,
    int? expectedRebuys,
    int? expectedReEntries,
    int? expectedAddOns,
    int? rebuyChips,
    int? reEntryChips,
    int? addOnChips,
    int? levelDurationMins,
    PayoutShape? payoutShape,
  }) =>
      TournamentParams(
        players: players ?? this.players,
        durationHours: durationHours ?? this.durationHours,
        buyIn: buyIn ?? this.buyIn,
        chipSet: chipSet ?? this.chipSet,
        rebuys: rebuys ?? this.rebuys,
        rebuysCloseLevel: rebuysCloseLevel ?? this.rebuysCloseLevel,
        rebuyLimit: rebuyLimit ?? this.rebuyLimit,
        reEntry: reEntry ?? this.reEntry,
        addOn: addOn ?? this.addOn,
        anteEnabled: anteEnabled ?? this.anteEnabled,
        anteAfterLevel: anteAfterLevel ?? this.anteAfterLevel,
        anteStyle: anteStyle ?? this.anteStyle,
        koEnabled: koEnabled ?? this.koEnabled,
        koAmount: koAmount ?? this.koAmount,
        organizerPct: organizerPct ?? this.organizerPct,
        rebuyCost: rebuyCost ?? this.rebuyCost,
        addOnCost: addOnCost ?? this.addOnCost,
        breaks: breaks ?? this.breaks,
        rebuyCloseChosenByOrganizer:
            rebuyCloseChosenByOrganizer ?? this.rebuyCloseChosenByOrganizer,
        expectedRebuys: expectedRebuys ?? this.expectedRebuys,
        expectedReEntries: expectedReEntries ?? this.expectedReEntries,
        expectedAddOns: expectedAddOns ?? this.expectedAddOns,
        rebuyChips: rebuyChips ?? this.rebuyChips,
        reEntryChips: reEntryChips ?? this.reEntryChips,
        addOnChips: addOnChips ?? this.addOnChips,
        levelDurationMins: levelDurationMins ?? this.levelDurationMins,
        payoutShape: payoutShape ?? this.payoutShape,
      );
}

/// A scheduled break in the tournament structure (specification section 8).
///
/// Deliberately NOT the same thing as a manual pause. Section 8 is explicit:
/// "A break is a real scheduled state, not merely a manual pause." It is part
/// of the generated structure and its minutes count toward the target
/// duration, which is why it lives here and not in the live-game status alone.
class ScheduledBreak {
  const ScheduledBreak({
    required this.afterLevel,
    required this.durationMins,
  });

  /// The break runs once this level has finished. Level 6 means "after
  /// Level 6", i.e. between Level 6 and Level 7.
  final int afterLevel;

  /// 5, 10, 15, 20 or a custom value (section 8).
  final int durationMins;

  ScheduledBreak copyWith({int? afterLevel, int? durationMins}) =>
      ScheduledBreak(
        afterLevel: afterLevel ?? this.afterLevel,
        durationMins: durationMins ?? this.durationMins,
      );

  @override
  bool operator ==(Object other) =>
      other is ScheduledBreak &&
      other.afterLevel == afterLevel &&
      other.durationMins == durationMins;

  @override
  int get hashCode => Object.hash(afterLevel, durationMins);

  @override
  String toString() => 'Break after L$afterLevel for ${durationMins}m';
}

/// Break duration options offered in setup (section 8), plus Custom.
const List<int> kBreakDurationPresets = [5, 10, 15, 20];

/// How many breaks a tournament may schedule.
///
/// Section 8 of the 10 September specification said 1 or 2; the v11 addendum
/// raised it to 3.
const int kMaxScheduledBreaks = 3;

/// How deep the tournament starts, in the v11 addendum's own vocabulary.
///
/// Addendum section 2 replaced the old hard 50-100 BB rule with style bands
/// that are "style guidance, never hard constraints", and requires that when
/// the engine picks an unusual depth it "explain why in plain language". This
/// is that vocabulary.
enum TournamentStyle {
  turbo,
  fast,
  standard,
  deep;

  /// Band boundaries from addendum section 2's table.
  static TournamentStyle fromBigBlinds(double bb) {
    if (bb < 60) return TournamentStyle.turbo;
    if (bb < 75) return TournamentStyle.fast;
    if (bb <= 120) return TournamentStyle.standard;
    return TournamentStyle.deep;
  }

  String get label => switch (this) {
        TournamentStyle.turbo => 'Turbo',
        TournamentStyle.fast => 'Fast',
        TournamentStyle.standard => 'Standard',
        TournamentStyle.deep => 'Deep',
      };

  /// The "purpose" column of the addendum's table, in plain language.
  String get purpose => switch (this) {
        TournamentStyle.turbo =>
          'a short, aggressive event — expect early all-ins',
        TournamentStyle.fast => 'quick but still playable',
        TournamentStyle.standard => 'the balanced home-game default',
        TournamentStyle.deep =>
          'more post-flop play, for a longer evening',
      };
}

/// What the engine suggests for antes, and why (§7 "system recommendation").
class AnteRecommendation {
  const AnteRecommendation({
    required this.enabled,
    required this.style,
    required this.reason,
  });

  final bool enabled;
  final AnteStyle style;

  /// Plain language, shown beside the option so the host can disagree with a
  /// reason rather than a coin flip.
  final String reason;

  String get label => !enabled
      ? 'No ante'
      : style == AnteStyle.bigBlind
          ? 'Big blind ante'
          : 'Individual ante';
}

/// Prize line.
class Prize {
  const Prize({required this.place, required this.amount});

  final int place;
  final int amount;
}

/// One way of splitting the prize pool (specification section 18).
///
/// Section 18 and section 25 both require the engine to offer SEVERAL shapes
/// rather than imposing one: "AI generates multiple payout options, not only
/// one. Example options could cover 3, 4 or 5 paid positions. Each option
/// shows position, percentage and calculated amount." The organizer picks.
class PayoutOption {
  const PayoutOption({
    required this.paidPlaces,
    required this.prizes,
    required this.prizePool,
    required this.roundingRemainder,
    required this.rationale,
  });

  final int paidPlaces;
  final List<Prize> prizes;

  /// Net pool this option splits — gross minus the organizer allocation.
  final int prizePool;

  /// Whatever could not be split into clean amounts. Section 18 requires
  /// deterministic rounding to "practical clean amounts", so a few units may
  /// be left over rather than producing an ugly figure.
  final int roundingRemainder;

  /// Plain-language reason this shape is offered, e.g. "Top-heavy — rewards
  /// the win". Shown beside the option so the choice is informed.
  final String rationale;

  /// Percentage of the pool each place receives, rounded for display.
  List<int> get percentages => [
        for (final p in prizes)
          prizePool == 0 ? 0 : ((p.amount / prizePool) * 100).round(),
      ];

  /// Section 30's financial invariant: what is paid plus what is left over
  /// must equal the pool exactly.
  bool get reconciles =>
      prizes.fold<int>(0, (a, p) => a + p.amount) + roundingRemainder ==
      prizePool;
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
    this.breaks = const [],
    this.styleNote = '',
    this.rebuysCloseLevel = 0,
  });

  /// The rebuy cutoff this structure was actually built around.
  ///
  /// Addendum acceptance criterion 10 — "AI can dynamically change the rebuy
  /// cutoff in generated structures" — only means anything if the chosen level
  /// reaches the settings that gate rebuys live. The engine reports it here
  /// and the provider adopts it. 0 on structures generated before this field
  /// existed; callers fall back to the settings value.
  final int rebuysCloseLevel;

  /// Plain-language explanation of the depth this structure chose.
  ///
  /// Addendum section 2: "If the engine chooses an unusual depth, explain why
  /// in plain language." A warning is not an explanation — the host needs to
  /// know this is a Turbo because their chips could not fund anything deeper,
  /// not just that something is "short".
  final String styleNote;

  /// The style band this structure's opening depth falls into.
  TournamentStyle? get style {
    if (levels.isEmpty || levels.first.bb <= 0) return null;
    return TournamentStyle.fromBigBlinds(startingStack / levels.first.bb);
  }

  /// Opening depth in big blinds.
  double? get openingBBDepth {
    if (levels.isEmpty || levels.first.bb <= 0) return null;
    return startingStack / levels.first.bb;
  }

  /// Breaks actually placed in this structure (section 8). Empty means the
  /// tournament runs straight through, which is what every structure written
  /// before breaks existed did.
  final List<ScheduledBreak> breaks;

  /// Total scheduled break time. Section 8: "target 4h = 3h40 playing + 20 min
  /// scheduled breaks", so this is part of the duration, not outside it.
  int get totalBreakMins =>
      breaks.fold<int>(0, (a, b) => a + b.durationMins);

  /// Whether a break falls immediately after [level].
  ScheduledBreak? breakAfter(int level) {
    for (final b in breaks) {
      if (b.afterLevel == level) return b;
    }
    return null;
  }

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
    List<ScheduledBreak>? breaks,
    String? styleNote,
    int? rebuysCloseLevel,
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
      // These three were absent, so every copyWith silently reset them to
      // their defaults. Breaks vanished from every player, guest and TV
      // projection -- which all go through copyWith -- and a single Speed Up
      // press wiped them off the tournament entirely. Section 8 calls breaks
      // "real scheduled states" whose duration counts toward the target; they
      // cannot survive being dropped by a copy.
      breaks: breaks ?? this.breaks,
      styleNote: styleNote ?? this.styleNote,
      rebuysCloseLevel: rebuysCloseLevel ?? this.rebuysCloseLevel,
    );
  }
}
