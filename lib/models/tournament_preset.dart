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
    required this.reEntry,
    required this.addOn,
    required this.durationHours,
    required this.anteEnabled,
    required this.anteAfterLevel,
    required this.organizerPct,
    required this.chipSetName,
    required this.chipSet,
  });

  final String id;
  final String name;
  final int buyIn;
  final bool koEnabled;
  final int koAmount;
  final bool rebuys;
  final int rebuysCloseLevel;
  final bool reEntry;
  final bool addOn;
  final double durationHours;
  final bool anteEnabled;
  final int anteAfterLevel;
  final int organizerPct;
  final String chipSetName;
  final List<ChipColor> chipSet;

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
    double? durationHours,
    bool? anteEnabled,
    int? anteAfterLevel,
    int? organizerPct,
    String? chipSetName,
    List<ChipColor>? chipSet,
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
      durationHours: durationHours ?? this.durationHours,
      anteEnabled: anteEnabled ?? this.anteEnabled,
      anteAfterLevel: anteAfterLevel ?? this.anteAfterLevel,
      organizerPct: organizerPct ?? this.organizerPct,
      chipSetName: chipSetName ?? this.chipSetName,
      chipSet: chipSet ?? this.chipSet,
    );
  }
}
