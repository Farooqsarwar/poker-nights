import 'dart:math' as math;

import 'chip_color.dart';
import 'tournament_format.dart';

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

/// Deprecated alias for [kAddOnTakeUpRate].
///
/// This was 0.65 while §F1.1 states 70 %, so the engine and the figure shown
/// to the host disagreed by five points on the same quantity. Pointed at the
/// one constant rather than left as a second copy — that is how the two drift.
@Deprecated('Use kAddOnTakeUpRate — §F1.1 states 70 %.')
const double kExpectedAddOnRate = kAddOnTakeUpRate;

/// Build Spec v3.1 §F1.1 defaults for the add-on, expressed the way the spec
/// expresses them: a multiple of the starting stack, and the share of the
/// field expected to take it.
///
/// [kAddOnMultiplier] is the add-on's size as `A × X` (§F1.10, and the
/// Structuring Framework's `A`). [kAddOnTakeUpRate] is the Framework's `q`,
/// and §F1.1's stated default of 70 %.
///
/// `q` feeds the chips-in-play estimate `C` only. The chip BANK check assumes
/// **every** player takes the add-on (§F1.5 point 1), because a bank sized on
/// a 70 % forecast fails on the night everybody takes one. Keeping those two
/// uses apart is what makes it safe to forecast take-up at all.
const double kAddOnMultiplier = 1.25;
const double kAddOnTakeUpRate = 0.7;

/// §F1.1 `pace` · §F1.2 `PACE` — the host's chosen pace.
///
/// The owner's model (2026-09-26) is **one level length all night**: Turbo 15,
/// Regular 20, Deep 30 minutes. The climb per level is then whatever reaches
/// the finishing blind by the finish time, capped at the pace's `gMax`.
///
/// This is **not** [PaceStyle]. §F1.2 carries two separate tables and they do
/// different jobs:
///
/// * `PACE` (this enum) — level length and the growth ceiling. Chosen by the
///   host, or recommended by `paceOptions`.
/// * `STYLE` (`PaceStyle`) — target opening depth `D`, growth `g`, level floor
///   and the rebuy-close `M` floor. Classified from the structure itself.
///
/// A null pace means the legacy phased mode (§F1.13), which is what every
/// tournament created before pace existed uses.
enum PaceMode { turbo, regular, deep }

extension PaceModeSpec on PaceMode {
  /// §F1.2 `PACE` — minutes per level, the same for every level of the night.
  int get levelMinutes => switch (this) {
        PaceMode.turbo => 15,
        PaceMode.regular => 20,
        PaceMode.deep => 30,
      };

  /// §F1.2 `PACE` — the per-level growth ceiling for this pace.
  double get gMax => switch (this) {
        PaceMode.turbo => 1.6,
        PaceMode.regular => 1.5,
        PaceMode.deep => 1.45,
      };

  /// The label the host sees (§F1.3 `paceOptions`, C1 step 4).
  String get label => switch (this) {
        PaceMode.turbo => 'Turbo',
        PaceMode.regular => 'Regular',
        PaceMode.deep => 'Deep',
      };
}

/// §F1.2 `PACE_G_MIN` — below +20 % a level the night simply ends early, so
/// there is no reason to solve for a flatter climb than this.
const double kPaceGMin = 1.2;

/// One line of §F1.1's `explain [{step, text, numbers}]` — the engine's own
/// account of a decision it made.
///
/// §B4 rule 10 and T138 require the long reasons to sit behind a "Why?" link
/// with the first sentence visible. That is only possible if the engine says
/// why at the time; reconstructing it afterwards from the output is guesswork.
class StructureExplanation {
  const StructureExplanation({
    required this.step,
    required this.text,
    this.numbers = const {},
  });

  /// A short stable key — `stack`, `pace`, `depth`, `chipBank`, `endTarget`.
  /// Screens key their "Why?" links off this, so it must not be prose.
  final String step;

  /// The explanation. First sentence is the visible summary; the rest is the
  /// disclosure.
  final String text;

  /// The figures behind it, for a screen that wants to show them separately.
  final Map<String, num> numbers;

  Map<String, dynamic> toMap() => {
        'step': step,
        'text': text,
        'numbers': numbers,
      };

  static StructureExplanation fromMap(Map<String, dynamic> m) =>
      StructureExplanation(
        step: (m['step'] as String?) ?? '',
        text: (m['text'] as String?) ?? '',
        numbers: ((m['numbers'] as Map?) ?? const {}).map(
          (k, v) => MapEntry('$k', v is num ? v : 0),
        ),
      );
}

/// §F1.3 `clockDiff(startTime, endBy)` — minutes between two "HH:mm" times,
/// **crossing midnight**.
///
/// A poker night that starts at 20:00 and ends at 00:30 is four and a half
/// hours long, not minus nineteen and a half. Any end at or before the start
/// is read as the next day, which is the only reading that makes sense for an
/// evening game; the one real ambiguity — an end exactly equal to the start —
/// is treated as a full 24 hours rather than zero, because zero would silently
/// generate an empty structure.
///
/// Returns null when either string is not "HH:mm" in range, so a malformed
/// value falls back to the stated duration rather than producing a wrong
/// window.
int? clockDiffMinutes(String start, String end) {
  final s = _minutesOfDay(start);
  final e = _minutesOfDay(end);
  if (s == null || e == null) return null;
  final diff = e - s;
  return diff > 0 ? diff : diff + 24 * 60;
}

int? _minutesOfDay(String hhmm) {
  final parts = hhmm.trim().split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// §F1.3 fit tolerance, and the same 5 minutes used by `meta.fits`: a pace
/// fits when the night needs at most five minutes more than its window.
const int kPaceFitToleranceMins = 5;

/// §26.1's default seats per table, reused by §11.4 to split a shootout field.
const int kDefaultTableSize = 9;

/// §11.4 / §38. Stage A's per-table target when the host states nothing —
/// typical single-table sit-and-go pace.
const int kShootoutTableTargetMins = 45;

/// §3 / §25.1a. The early-arrival grant, as a fraction of the starting stack.
const double kEarlyArrivalBonusPct = 0.125;

/// §25.1a. How long before the scheduled start a check-in still counts as
/// early. Long enough to mean "arrived on time", short enough not to be
/// everybody.
const int kEarlyArrivalCutoffMins = 30;


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
    this.format,
    this.maxReEntries,
    this.shootoutTables,
    this.shootoutTableTargetMins,
    this.earlyArrivalBonusEnabled = false,
    this.earlyArrivalCutoffMins,
    this.earlyArrivalBonusPctOverride,
    this.pace,
    this.startTime,
    this.endBy,
    this.targetDurationMinutes,
    this.expectedRebuyRate,
    this.addOnMultiplier,
    this.addOnTakeUpRate,
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

  final TournamentFormat? format;
  final int? maxReEntries;
  final int? shootoutTables;
  final int? shootoutTableTargetMins;
  final bool earlyArrivalBonusEnabled;
  final int? earlyArrivalCutoffMins;
  final double? earlyArrivalBonusPctOverride;

  // ── §F1.1 inputs ────────────────────────────────────────────────────────
  //
  // Added in Phase 2 to bring the engine up to the specification's input
  // contract. Every one is nullable and every one has a fallback to the
  // pre-existing behaviour, so a structure generated without them is byte-for
  // byte the structure the engine generated before.

  /// §F1.1 `pace`. Null selects the legacy phased mode (§F1.13).
  final PaceMode? pace;

  /// §F1.1 `startTime` / `endBy` — the night's window, as "HH:mm". `T` is the
  /// clock difference and may cross midnight ("20:00" → "00:30" is 4 h 30).
  ///
  /// These exist because [durationHours] alone cannot express a **late start**:
  /// §E17 row 21 requires that `endBy` is kept and `T` shrinks, which is only
  /// possible if the finish is stored as a time rather than a length.
  final String? startTime;
  final String? endBy;

  /// §F1.1 `targetDurationMinutes` — used only when there is no [endBy].
  final int? targetDurationMinutes;

  /// §F1.1 `expectedRebuyRate` — rebuys per player, the Framework's `r`.
  /// Null falls back to [kExpectedRebuyRate].
  final double? expectedRebuyRate;

  /// §F1.1 `addOn.multiplier` — the add-on as a multiple of the starting
  /// stack, the Framework's `A`. Clamped to the spec's 1.10–1.50.
  final double? addOnMultiplier;

  /// §F1.1 `addOn.takeUpRate` — the Framework's `q`. Feeds the chips-in-play
  /// estimate `C` only, never the bank check.
  final double? addOnTakeUpRate;

  double get effectiveExpectedRebuyRate =>
      math.max(0, expectedRebuyRate ?? kExpectedRebuyRate);

  double get effectiveAddOnMultiplier =>
      (addOnMultiplier ?? kAddOnMultiplier).clamp(1.10, 1.50);

  double get effectiveAddOnTakeUpRate =>
      (addOnTakeUpRate ?? kAddOnTakeUpRate).clamp(0.0, 1.0);

  /// §F1.3 `T` — the night's window in minutes.
  ///
  /// Precedence follows §F1.1: an explicit `startTime`/`endBy` pair wins,
  /// because it is the only form that survives a late start; then
  /// `targetDurationMinutes`; then the legacy [durationHours].
  int get effectiveTargetMinutes {
    final start = startTime, end = endBy;
    if (start != null && end != null) {
      final diff = clockDiffMinutes(start, end);
      if (diff != null && diff > 0) return diff;
    }
    final stated = targetDurationMinutes;
    if (stated != null && stated > 0) return stated;
    return (durationHours * 60).round();
  }

  /// True when this tournament is on the §F1.3 pace path rather than the
  /// legacy phased mode (§F1.13).
  bool get usesPaceMode => pace != null;

  int get effectiveRebuyCost => rebuyCost ?? buyIn;
  int get effectiveAddOnCost => addOnCost ?? buyIn;

  TournamentFormat get effectiveFormat =>
      format ??
      (reEntry
          ? TournamentFormat.reEntry
          : rebuys
              ? TournamentFormat.rebuy
              : TournamentFormat.freezeOut);

  /// §11.4 Stage A. How many independent tables the field splits into. The
  /// host's choice wins; otherwise it is the same seating arithmetic §26.1
  /// uses, so a shootout draws the tables the room would have had anyway.
  int get effectiveShootoutTables {
    final stated = shootoutTables;
    if (stated != null && stated >= 2) return stated;
    if (players <= kDefaultTableSize) return 1;
    return (players / kDefaultTableSize).ceil();
  }

  /// §11.4 Stage A. 45 minutes is the single-table sit-and-go pace in §38.
  int get effectiveShootoutTableTargetMins =>
      shootoutTableTargetMins ?? kShootoutTableTargetMins;

  /// §3. The early-arrival grant as a fraction of the starting stack, 0 when
  /// the bonus is switched off so a stale override cannot keep granting chips.
  double get effectiveEarlyArrivalPct => earlyArrivalBonusEnabled
      ? (earlyArrivalBonusPctOverride ?? kEarlyArrivalBonusPct).clamp(0.0, 1.0)
      : 0;

  /// §25.1a. Minutes before the scheduled start a check-in must land.
  int get effectiveEarlyArrivalCutoffMins =>
      earlyArrivalCutoffMins ?? kEarlyArrivalCutoffMins;

  /// Expected take-up, override first and the rate as the fallback. A format
  /// that is switched off contributes nothing however the field is filled in —
  /// a stale number left behind by toggling rebuys off must not keep inflating
  /// the chip count.
  int get effectiveExpectedRebuys => rebuys
      ? math.max(
          0,
          // The host's own figure wins; otherwise the forecast rate, which is
          // [kExpectedRebuyRate] unless a caller passed a measured one
          // (Framework §14).
          expectedRebuys ?? (players * effectiveExpectedRebuyRate).round(),
        )
      : 0;

  int get effectiveExpectedReEntries => reEntry
      ? math.max(0, expectedReEntries ?? (players * effectiveExpectedRebuyRate).round())
      : 0;

  int get effectiveExpectedAddOns => addOn
      // §F1.3's `C` applies the take-up to **N**, the field:
      //
      //   C = S × (N + Rforecast) + addOnMult × S × N × takeUp + bonusPct × S × N
      //
      // even though §F1 measures take-up as `addOnsTaken /
      // playersAliveAtTheAddOnBreak`. Those denominators genuinely differ, and
      // applying the second to the first slightly OVER-counts add-ons. That is
      // the specification's own choice and it errs the safe way: a larger `C`
      // means a larger `BB_end`, a steeper climb and a night that ends sooner
      // rather than one that drifts.
      //
      // The reason this is safe to do here is that §F1 keeps the two uses
      // apart: take-up "changes only the chips-in-play estimate C … never the
      // chip bank check, which assumes every player takes the add-on"
      // (§F1.5 point 1). `bankReserveTier` in the engine does exactly that, so
      // a 70 % forecast can never under-size the box.
      ? math.max(
          0,
          expectedAddOns ?? (players * effectiveAddOnTakeUpRate).round(),
        )
      : 0;

  /// §12.1: how many times over the box must fund one seat's worth of chips.
  /// One for the starting stack, plus the expected extra entries per seat. An
  /// add-on counts half — it is one stack arriving once, late, after colour-up
  /// has already retired the small denominations it would otherwise need.
  double get reserveMultiplier {
    if (players <= 0) return 1;
    return 1 +
        effectiveExpectedRebuys / players +
        effectiveExpectedReEntries / players +
        effectiveExpectedAddOns / players * 0.5;
  }

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
    TournamentFormat? format,
    int? maxReEntries,
    int? shootoutTables,
    int? shootoutTableTargetMins,
    bool? earlyArrivalBonusEnabled,
    int? earlyArrivalCutoffMins,
    double? earlyArrivalBonusPctOverride,
    PaceMode? pace,
    String? startTime,
    String? endBy,
    int? targetDurationMinutes,
    double? expectedRebuyRate,
    double? addOnMultiplier,
    double? addOnTakeUpRate,
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
        format: format ?? this.format,
        maxReEntries: maxReEntries ?? this.maxReEntries,
        shootoutTables: shootoutTables ?? this.shootoutTables,
        shootoutTableTargetMins:
            shootoutTableTargetMins ?? this.shootoutTableTargetMins,
        earlyArrivalBonusEnabled:
            earlyArrivalBonusEnabled ?? this.earlyArrivalBonusEnabled,
        earlyArrivalCutoffMins:
            earlyArrivalCutoffMins ?? this.earlyArrivalCutoffMins,
        earlyArrivalBonusPctOverride:
            earlyArrivalBonusPctOverride ?? this.earlyArrivalBonusPctOverride,
        pace: pace ?? this.pace,
        startTime: startTime ?? this.startTime,
        endBy: endBy ?? this.endBy,
        targetDurationMinutes:
            targetDurationMinutes ?? this.targetDurationMinutes,
        expectedRebuyRate: expectedRebuyRate ?? this.expectedRebuyRate,
        addOnMultiplier: addOnMultiplier ?? this.addOnMultiplier,
        addOnTakeUpRate: addOnTakeUpRate ?? this.addOnTakeUpRate,
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
    this.engineVersion = '2.1.0',
    this.feasible = true,
    this.depthShortfallNote,
    this.maxPlayersSupported,
    this.pace,
    this.fits = true,
    this.paceOverByMins = 0,
    this.explain = const [],
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

  /// Whether the opening stack actually clears the playable floor (Build
  /// Spec v3.1 §F1.5 / F1.18: 20 big blinds) for the field size it was built
  /// for.
  ///
  /// `true` for every structure generated before this field existed, and for
  /// every structure the normal solve or its shortage fallback produced —
  /// both already refuse to go below the floor. Only the engine's absolute
  /// last-resort branch (an inventory that cannot fund even a 20BB stack for
  /// any blind pair) can set this false.
  final bool feasible;

  /// Plain-language explanation of why the opening stack fell below the
  /// playable floor, and what would fix it. Null unless [feasible] is false.
  final String? depthShortfallNote;

  /// The largest field size these chips/settings can seat at or above the
  /// playable floor, when [feasible] is false. Null when feasible, or when
  /// the engine could not compute one.
  final int? maxPlayersSupported;

  /// §F1.1 `meta.pace` — the pace this structure was solved at. Null for a
  /// structure built in the legacy phased mode (§F1.13).
  final PaceMode? pace;

  /// §F1.3 `meta.fits` — `fits && projectedEnd.minutes ≤ T + 5`.
  ///
  /// False means the night, as generated, runs past its window. It is NOT a
  /// refusal: the structure is still complete and playable, and §E17 row 20
  /// requires the host to be shown the overrun and choose, rather than have a
  /// pace applied silently.
  final bool fits;

  /// Minutes this structure runs past its window. Zero when [fits].
  final int paceOverByMins;

  /// §F1.1 `explain [{step, text, numbers}]` — why the engine chose what it
  /// chose. Feeds the "Why?" disclosures (§B4 rule 10, T138).
  final List<StructureExplanation> explain;

  /// The explanation for one step, or null when the engine did not record one
  /// (every structure generated before this field existed).
  StructureExplanation? explanationFor(String step) {
    for (final e in explain) {
      if (e.step == step) return e;
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

  // ── Time-control architecture (Structuring Framework §13) ───────────────
  //
  // The Framework asks for three layers, not one schedule:
  //
  //   Target schedule       the structure intended to finish on time
  //   Compression schedule  PRE-ANNOUNCED later levels that raise the
  //                         pressure if the field is still large
  //   Hard ceiling          a final level or settlement rule that makes an
  //                         uncontrolled extension impossible
  //
  // The engine already built the middle layer — `SPARE_LEVELS` publishes four
  // levels past the target — but treated it as private overtime insurance.
  // The Framework's word is "pre-announced": the host and the table are
  // entitled to see the compression before it arrives. These getters name the
  // layers so the UI can show them; they store nothing new.

  /// Framework §13, layer 1. The last level of the target schedule, 1-based.
  int get targetScheduleLastLevel => effectivePlannedLevels;

  /// Framework §13, layer 2. The first compression level, 1-based, or null
  /// when there is no tail (a legacy structure, or one edited down).
  int? get compressionFromLevel =>
      levels.length > effectivePlannedLevels
          ? effectivePlannedLevels + 1
          : null;

  /// True when [levelNumber] (1-based) is part of the compression tail rather
  /// than the target schedule.
  bool isCompressionLevel(int levelNumber) =>
      levelNumber > effectivePlannedLevels && levelNumber <= levels.length;

  /// Framework §13, layer 3. The hard ceiling: the last published level,
  /// 1-based. There is no level after it, so play cannot continue past it
  /// without a settlement.
  ///
  /// Reaching it is what raises `targetTimeReached` for
  /// `PayoutsEngine.dealTrigger`, whose `targetTime` trigger is the highest
  /// priority of the four. That is the "settlement rule" half of the
  /// Framework's ceiling — the night ends in a chop rather than drifting.
  int get hardCeilingLevel => levels.length;

  /// True once play has reached the ceiling and the only way on is to settle.
  bool isAtHardCeiling(int levelNumber) => levelNumber >= hardCeilingLevel;

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

  /// The engine version that generated this structure.
  ///
  /// Older versions of the engine generated structures that the current engine
  /// might consider invalid. This version guard prevents the engine from
  /// attempting to verify structures it did not create, avoiding false positive
  /// mismatch warnings.
  final String engineVersion;

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
    String? engineVersion,
    bool? feasible,
    String? depthShortfallNote,
    int? maxPlayersSupported,
    PaceMode? pace,
    bool? fits,
    int? paceOverByMins,
    List<StructureExplanation>? explain,
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
      engineVersion: engineVersion ?? this.engineVersion,
      feasible: feasible ?? this.feasible,
      depthShortfallNote: depthShortfallNote ?? this.depthShortfallNote,
      maxPlayersSupported: maxPlayersSupported ?? this.maxPlayersSupported,
      // Same reason as breaks above: a field left out here is silently reset
      // to its default by every projection, and `fits: true` is the dangerous
      // default — it would tell a host a night fits when the engine said it
      // does not.
      pace: pace ?? this.pace,
      fits: fits ?? this.fits,
      paceOverByMins: paceOverByMins ?? this.paceOverByMins,
      explain: explain ?? this.explain,
    );
  }
}
