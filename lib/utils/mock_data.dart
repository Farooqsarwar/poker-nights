import '../models/chip_color.dart';

/// Design-time defaults only. Every runtime demo dataset that used to live
/// here (demo group/game/notifications/cash history) was removed when the app
/// moved to Firestore-backed state — nothing seeds fake data anymore.
class MockData {
  MockData._();

  /// Home Set (4 colour) starter chip set matching TournamentEngine preset.
  // DECISION: Home Set (4 colour) must strictly contain 4 colours (fixes C1 contradictory count).
  static const homeSet4Colour = <ChipColor>[
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 5, quantity: 100),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 80),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 100, quantity: 60),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 30),
  ];

  /// Neutral starter chip set used as a template for new games and chip sets.
  static const defaultChipSet = <ChipColor>[
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 150),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 60),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 40),
  ];
}
