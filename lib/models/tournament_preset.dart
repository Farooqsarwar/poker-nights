import 'chip_color.dart';
import 'live_game.dart';
import 'table_settings.dart';
import 'tournament.dart';
import 'tournament_format.dart';

/// A saved tournament template (checklist §9.1). Stores the inputs the admin
/// chooses before generation — never a fixed blind structure; the engine
/// regenerates the structure for the actual attendance and chips (09-003).
class TournamentPreset {
  const TournamentPreset({
    required this.id,
    required this.name,
    required this.buyIn,
    required this.koEnabled,
    required this.koAmount,
    this.koKind = BountyKind.fixed,
    required this.rebuys,
    required this.rebuysCloseLevel,
    this.rebuyCloseChosenByOrganizer = false,
    this.rebuyLimit,
    required this.reEntry,
    required this.addOn,
    this.addOnOvertime = false,
    this.addOnCloseLevel = 6,
    this.breaks = const [],
    required this.durationHours,
    required this.anteEnabled,
    required this.anteAfterLevel,
    this.anteStyle = AnteStyle.bigBlind,
    this.antePreference = AntePreference.recommend,
    required this.organizerPct,
    required this.chipSetName,
    required this.chipSet,
    this.rebuyCost,
    this.addOnCost,
    this.format,
    this.maxReEntries,
    this.earlyArrivalBonusEnabled = false,
    this.earlyArrivalCutoffMins,
    this.earlyArrivalBonusPctOverride,
    this.rsvpDeadlineHours,
    this.hardFinishEnabled = false,
    this.hardFinishMinsAfterFinish = 60,
    this.hardFinishSplit = 'icm',
    this.levelDurationMins,
    this.pace,
    this.shootoutTables,
    this.shootoutTableTargetMins,
    this.expectedPlayersOverride,
    this.announceEliminations = false,
    this.locationPrivate = false,
    this.forcePaidPlaces,
    this.rebuyChips,
    this.reEntryChips,
    this.addOnChips,
    this.tableSettingsOverride,
    this.lockedExpectedPlayers,
    this.expectedRebuys,
    this.expectedRebuyRate,
    this.expectedReEntries,
    this.expectedAddOns,
    this.forecastRebuyRate,
    this.forecastAddOnTakeUp,
    this.forceStack,
    this.targetDepthBB,
  });

  factory TournamentPreset.fromSettings({
    required String id,
    required String name,
    required GameSettings settings,
  }) => TournamentPreset(
    id: id,
    name: name,
    buyIn: settings.buyIn,
    koEnabled: settings.koEnabled,
    koAmount: settings.koAmount,
    koKind: settings.koKind,
    rebuys: settings.rebuys,
    rebuysCloseLevel: settings.rebuysCloseLevel,
    rebuyCloseChosenByOrganizer: settings.rebuyCloseChosenByOrganizer,
    rebuyLimit: settings.rebuyLimit,
    reEntry: settings.reEntry,
    addOn: settings.addOn,
    addOnOvertime: settings.addOnOvertime,
    addOnCloseLevel: settings.addOnCloseLevel,
    breaks: settings.breaks,
    durationHours: settings.durationHours,
    anteEnabled: settings.anteEnabled,
    anteAfterLevel: settings.anteAfterLevel,
    anteStyle: settings.anteStyle,
    antePreference: settings.antePreference,
    organizerPct: settings.organizerPct,
    chipSetName: settings.chipSetName,
    chipSet: List.of(settings.chipSet),
    rebuyCost: settings.rebuyCost,
    addOnCost: settings.addOnCost,
    format: settings.effectiveFormat,
    maxReEntries: settings.maxReEntries,
    earlyArrivalBonusEnabled: settings.earlyArrivalBonusEnabled,
    earlyArrivalCutoffMins: settings.earlyArrivalCutoffMins,
    earlyArrivalBonusPctOverride: settings.earlyArrivalBonusPctOverride,
    rsvpDeadlineHours: settings.rsvpDeadlineHours,
    hardFinishEnabled: settings.hardFinishEnabled,
    hardFinishMinsAfterFinish: settings.hardFinishMinsAfterFinish,
    hardFinishSplit: settings.hardFinishSplit,
    levelDurationMins: settings.levelDurationMins,
    pace: settings.pace,
    shootoutTables: settings.shootoutTables,
    shootoutTableTargetMins: settings.shootoutTableTargetMins,
    expectedPlayersOverride: settings.expectedPlayersOverride,
    announceEliminations: settings.announceEliminations,
    locationPrivate: settings.locationPrivate,
    forcePaidPlaces: settings.forcePaidPlaces,
    rebuyChips: settings.rebuyChips,
    reEntryChips: settings.reEntryChips,
    addOnChips: settings.addOnChips,
    tableSettingsOverride: settings.tableSettingsOverride,
    lockedExpectedPlayers: settings.lockedExpectedPlayers,
    expectedRebuys: settings.expectedRebuys,
        expectedRebuyRate: settings.expectedRebuyRate,
    expectedReEntries: settings.expectedReEntries,
    expectedAddOns: settings.expectedAddOns,
    forecastRebuyRate: settings.forecastRebuyRate,
    forecastAddOnTakeUp: settings.forecastAddOnTakeUp,
    forceStack: settings.forceStack,
    targetDepthBB: settings.targetDepthBB,
  );

  final String id;
  final String name;
  final int buyIn;
  final bool koEnabled;
  final int koAmount;
  final BountyKind koKind;
  final bool rebuys;
  final int rebuysCloseLevel;
  final bool rebuyCloseChosenByOrganizer;
  final int? rebuyLimit;
  final bool reEntry;
  final bool addOn;
  final bool addOnOvertime;

  /// Level after which add-ons close (defaults to end of Level 6).
  final int addOnCloseLevel;

  /// Scheduled breaks remembered with the preset (section 8).
  final List<ScheduledBreak> breaks;

  final double durationHours;
  final bool anteEnabled;
  final int anteAfterLevel;
  final AnteStyle anteStyle;
  final AntePreference antePreference;
  final int organizerPct;
  final String chipSetName;
  final List<ChipColor> chipSet;

  /// Optional custom rebuy price (defaults to buy-in when null, checklist
  /// 09-050/12-051).
  final int? rebuyCost;

  /// Optional custom add-on price (defaults to buy-in when null, 12-060).
  final int? addOnCost;

  final TournamentFormat? format;
  final int? maxReEntries;
  final bool earlyArrivalBonusEnabled;
  final int? earlyArrivalCutoffMins;
  final double? earlyArrivalBonusPctOverride;
  final int? rsvpDeadlineHours;
  final bool hardFinishEnabled;
  final int hardFinishMinsAfterFinish;
  final String hardFinishSplit;
  final int? levelDurationMins;
  final PaceMode? pace;
  final int? shootoutTables;
  final int? shootoutTableTargetMins;
  final int? expectedPlayersOverride;
  final bool announceEliminations;
  final bool locationPrivate;
  final int? forcePaidPlaces;
  final int? rebuyChips;
  final int? reEntryChips;
  final int? addOnChips;
  final TableSettings? tableSettingsOverride;
  final int? lockedExpectedPlayers;
  final int? expectedRebuys;
  final double? expectedRebuyRate;
  final int? expectedReEntries;
  final int? expectedAddOns;
  final double? forecastRebuyRate;
  final double? forecastAddOnTakeUp;
  final int? forceStack;
  final int? targetDepthBB;

  /// Applies this reusable preference without touching event-only identity,
  /// date, time, location or attendance on [base].
  GameSettings applyTo(GameSettings base) => base.copyWith(
    buyIn: buyIn,
    koEnabled: koEnabled,
    koAmount: koAmount,
    koKind: koKind,
    rebuys: rebuys,
    rebuysCloseLevel: rebuysCloseLevel,
    rebuyCloseChosenByOrganizer: rebuyCloseChosenByOrganizer,
    rebuyLimit: rebuyLimit,
    clearRebuyLimit: rebuyLimit == null,
    reEntry: reEntry,
    addOn: addOn,
    addOnOvertime: addOnOvertime,
    addOnCloseLevel: addOnCloseLevel,
    breaks: List.of(breaks),
    durationHours: durationHours,
    anteEnabled: anteEnabled,
    anteAfterLevel: anteAfterLevel,
    anteStyle: anteStyle,
    antePreference: antePreference,
    organizerPct: organizerPct,
    chipSetName: chipSetName,
    chipSet: List.of(chipSet),
    rebuyCost: rebuyCost,
    addOnCost: addOnCost,
    format:
        format ??
        (reEntry
            ? TournamentFormat.reEntry
            : rebuys
            ? TournamentFormat.rebuy
            : TournamentFormat.freezeOut),
    maxReEntries: maxReEntries,
    clearMaxReEntries: maxReEntries == null,
    earlyArrivalBonusEnabled: earlyArrivalBonusEnabled,
    earlyArrivalCutoffMins: earlyArrivalCutoffMins,
    clearEarlyArrivalCutoffMins: earlyArrivalCutoffMins == null,
    earlyArrivalBonusPctOverride: earlyArrivalBonusPctOverride,
    clearEarlyArrivalBonusPctOverride: earlyArrivalBonusPctOverride == null,
    rsvpDeadlineHours: rsvpDeadlineHours,
    hardFinishEnabled: hardFinishEnabled,
    hardFinishMinsAfterFinish: hardFinishMinsAfterFinish,
    hardFinishSplit: hardFinishSplit,
    levelDurationMins: levelDurationMins,
    pace: pace,
    shootoutTables: shootoutTables,
    clearShootoutTables: shootoutTables == null,
    shootoutTableTargetMins: shootoutTableTargetMins,
    clearShootoutTableTargetMins: shootoutTableTargetMins == null,
    expectedPlayersOverride: expectedPlayersOverride,
    clearExpectedPlayersOverride: expectedPlayersOverride == null,
    announceEliminations: announceEliminations,
    locationPrivate: locationPrivate,
    forcePaidPlaces: forcePaidPlaces,
    clearForcePaidPlaces: forcePaidPlaces == null,
    rebuyChips: rebuyChips,
    reEntryChips: reEntryChips,
    addOnChips: addOnChips,
    tableSettingsOverride: tableSettingsOverride,
    clearTableSettingsOverride: tableSettingsOverride == null,
    lockedExpectedPlayers: lockedExpectedPlayers,
    clearLockedExpectedPlayers: lockedExpectedPlayers == null,
    expectedRebuys: expectedRebuys,
        expectedRebuyRate: expectedRebuyRate,
    expectedReEntries: expectedReEntries,
    expectedAddOns: expectedAddOns,
    forecastRebuyRate: forecastRebuyRate,
    forecastAddOnTakeUp: forecastAddOnTakeUp,
    forceStack: forceStack,
    clearForceStack: forceStack == null,
    targetDepthBB: targetDepthBB,
    clearTargetDepthBB: targetDepthBB == null,
  );

  TournamentPreset copyWith({
    String? id,
    String? name,
    int? buyIn,
    bool? koEnabled,
    int? koAmount,
    BountyKind? koKind,
    bool? rebuys,
    int? rebuysCloseLevel,
    bool? rebuyCloseChosenByOrganizer,
    int? rebuyLimit,
    bool? reEntry,
    bool? addOn,
    bool? addOnOvertime,
    int? addOnCloseLevel,
    List<ScheduledBreak>? breaks,
    double? durationHours,
    bool? anteEnabled,
    int? anteAfterLevel,
    AnteStyle? anteStyle,
    AntePreference? antePreference,
    int? organizerPct,
    String? chipSetName,
    List<ChipColor>? chipSet,
    int? rebuyCost,
    int? addOnCost,
    TournamentFormat? format,
    int? maxReEntries,
    bool? earlyArrivalBonusEnabled,
    int? earlyArrivalCutoffMins,
    double? earlyArrivalBonusPctOverride,
    int? rsvpDeadlineHours,
    bool? hardFinishEnabled,
    int? hardFinishMinsAfterFinish,
    String? hardFinishSplit,
    int? levelDurationMins,
    PaceMode? pace,
    int? shootoutTables,
    int? shootoutTableTargetMins,
    int? expectedPlayersOverride,
    bool? announceEliminations,
    bool? locationPrivate,
    int? forcePaidPlaces,
    int? rebuyChips,
    int? reEntryChips,
    int? addOnChips,
    TableSettings? tableSettingsOverride,
    int? lockedExpectedPlayers,
    int? expectedRebuys,
    double? expectedRebuyRate,
    int? expectedReEntries,
    int? expectedAddOns,
    double? forecastRebuyRate,
    double? forecastAddOnTakeUp,
    int? forceStack,
    int? targetDepthBB,
  }) {
    return TournamentPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      buyIn: buyIn ?? this.buyIn,
      koEnabled: koEnabled ?? this.koEnabled,
      koAmount: koAmount ?? this.koAmount,
      koKind: koKind ?? this.koKind,
      rebuys: rebuys ?? this.rebuys,
      rebuysCloseLevel: rebuysCloseLevel ?? this.rebuysCloseLevel,
      rebuyCloseChosenByOrganizer:
          rebuyCloseChosenByOrganizer ?? this.rebuyCloseChosenByOrganizer,
      rebuyLimit: rebuyLimit ?? this.rebuyLimit,
      reEntry: reEntry ?? this.reEntry,
      addOn: addOn ?? this.addOn,
      addOnOvertime: addOnOvertime ?? this.addOnOvertime,
      addOnCloseLevel: addOnCloseLevel ?? this.addOnCloseLevel,
      breaks: breaks ?? this.breaks,
      durationHours: durationHours ?? this.durationHours,
      anteEnabled: anteEnabled ?? this.anteEnabled,
      anteAfterLevel: anteAfterLevel ?? this.anteAfterLevel,
      anteStyle: anteStyle ?? this.anteStyle,
      antePreference: antePreference ?? this.antePreference,
      organizerPct: organizerPct ?? this.organizerPct,
      chipSetName: chipSetName ?? this.chipSetName,
      chipSet: chipSet ?? this.chipSet,
      rebuyCost: rebuyCost ?? this.rebuyCost,
      addOnCost: addOnCost ?? this.addOnCost,
      format: format ?? this.format,
      maxReEntries: maxReEntries ?? this.maxReEntries,
      earlyArrivalBonusEnabled:
          earlyArrivalBonusEnabled ?? this.earlyArrivalBonusEnabled,
      earlyArrivalCutoffMins:
          earlyArrivalCutoffMins ?? this.earlyArrivalCutoffMins,
      earlyArrivalBonusPctOverride:
          earlyArrivalBonusPctOverride ?? this.earlyArrivalBonusPctOverride,
      rsvpDeadlineHours: rsvpDeadlineHours ?? this.rsvpDeadlineHours,
      hardFinishEnabled: hardFinishEnabled ?? this.hardFinishEnabled,
      hardFinishMinsAfterFinish:
          hardFinishMinsAfterFinish ?? this.hardFinishMinsAfterFinish,
      hardFinishSplit: hardFinishSplit ?? this.hardFinishSplit,
      levelDurationMins: levelDurationMins ?? this.levelDurationMins,
      pace: pace ?? this.pace,
      shootoutTables: shootoutTables ?? this.shootoutTables,
      shootoutTableTargetMins:
          shootoutTableTargetMins ?? this.shootoutTableTargetMins,
      expectedPlayersOverride:
          expectedPlayersOverride ?? this.expectedPlayersOverride,
      announceEliminations: announceEliminations ?? this.announceEliminations,
      locationPrivate: locationPrivate ?? this.locationPrivate,
      forcePaidPlaces: forcePaidPlaces ?? this.forcePaidPlaces,
      rebuyChips: rebuyChips ?? this.rebuyChips,
      reEntryChips: reEntryChips ?? this.reEntryChips,
      addOnChips: addOnChips ?? this.addOnChips,
      tableSettingsOverride:
          tableSettingsOverride ?? this.tableSettingsOverride,
      lockedExpectedPlayers:
          lockedExpectedPlayers ?? this.lockedExpectedPlayers,
      expectedRebuys: expectedRebuys ?? this.expectedRebuys,
      expectedRebuyRate: expectedRebuyRate ?? this.expectedRebuyRate,
      expectedReEntries: expectedReEntries ?? this.expectedReEntries,
      expectedAddOns: expectedAddOns ?? this.expectedAddOns,
      forecastRebuyRate: forecastRebuyRate ?? this.forecastRebuyRate,
      forecastAddOnTakeUp: forecastAddOnTakeUp ?? this.forecastAddOnTakeUp,
      forceStack: forceStack ?? this.forceStack,
      targetDepthBB: targetDepthBB ?? this.targetDepthBB,
    );
  }
}
