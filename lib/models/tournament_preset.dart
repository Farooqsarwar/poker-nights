import 'chip_color.dart';

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
    required this.rebuys,
    required this.rebuysCloseLevel,
    this.rebuyLimit,
    required this.reEntry,
    required this.addOn,
    this.addOnCloseLevel = 6,
    required this.durationHours,
    required this.anteEnabled,
    required this.anteAfterLevel,
    required this.organizerPct,
    required this.chipSetName,
    required this.chipSet,
    this.rebuyCost,
    this.addOnCost,
  });

  final String id;
  final String name;
  final int buyIn;
  final bool koEnabled;
  final int koAmount;
  final bool rebuys;
  final int rebuysCloseLevel;
  final int? rebuyLimit;
  final bool reEntry;
  final bool addOn;

  /// Level after which add-ons close (defaults to end of Level 6).
  final int addOnCloseLevel;

  final double durationHours;
  final bool anteEnabled;
  final int anteAfterLevel;
  final int organizerPct;
  final String chipSetName;
  final List<ChipColor> chipSet;

  /// Optional custom rebuy price (defaults to buy-in when null, checklist
  /// 09-050/12-051).
  final int? rebuyCost;

  /// Optional custom add-on price (defaults to buy-in when null, 12-060).
  final int? addOnCost;

  TournamentPreset copyWith({
    String? id,
    String? name,
    int? buyIn,
    bool? koEnabled,
    int? koAmount,
    bool? rebuys,
    int? rebuysCloseLevel,
    bool? reEntry,
    bool? addOn,
    int? addOnCloseLevel,
    double? durationHours,
    bool? anteEnabled,
    int? anteAfterLevel,
    int? organizerPct,
    String? chipSetName,
    List<ChipColor>? chipSet,
    int? rebuyCost,
    int? addOnCost,
  }) {
    return TournamentPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      buyIn: buyIn ?? this.buyIn,
      koEnabled: koEnabled ?? this.koEnabled,
      koAmount: koAmount ?? this.koAmount,
      rebuys: rebuys ?? this.rebuys,
      rebuysCloseLevel: rebuysCloseLevel ?? this.rebuysCloseLevel,
      reEntry: reEntry ?? this.reEntry,
      addOn: addOn ?? this.addOn,
      addOnCloseLevel: addOnCloseLevel ?? this.addOnCloseLevel,
      durationHours: durationHours ?? this.durationHours,
      anteEnabled: anteEnabled ?? this.anteEnabled,
      anteAfterLevel: anteAfterLevel ?? this.anteAfterLevel,
      organizerPct: organizerPct ?? this.organizerPct,
      chipSetName: chipSetName ?? this.chipSetName,
      chipSet: chipSet ?? this.chipSet,
      rebuyCost: rebuyCost ?? this.rebuyCost,
      addOnCost: addOnCost ?? this.addOnCost,
    );
  }
}
