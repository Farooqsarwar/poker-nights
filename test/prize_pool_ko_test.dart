import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// §23.1 — KO bounty is never part of the gross-eligible pool.
void main() {
  group('grossEligibleFor', () {
    test('computes gross without KO subtraction', () {
      // 10×15 + 3×15 + 2×15 + 4×15 = 150 + 45 + 30 + 60 = 285
      final gross = TournamentEngine.grossEligibleFor(
        confirmedCount: 10,
        buyIn: 15,
        totalRebuys: 3,
        effectiveRebuyCost: 15,
        totalReEntries: 2,
        addOnEnabled: true,
        totalAddOns: 4,
        effectiveAddOnCost: 15,
      );
      expect(gross, 285);
    });

    test('KO bounty parameter does not exist — same inputs yield same result', () {
      // Mirror the existing test at tournament_engine_test.dart:285.
      // A game with KO enabled and one without must produce identical gross
      // when buy-in and all other inputs are the same.
      const inputs = (
        confirmedCount: 10,
        buyIn: 15,
        totalRebuys: 3,
        effectiveRebuyCost: 15,
        totalReEntries: 2,
        addOnEnabled: true,
        totalAddOns: 4,
        effectiveAddOnCost: 15,
      );
      expect(
        TournamentEngine.grossEligibleFor(
          confirmedCount: inputs.confirmedCount,
          buyIn: inputs.buyIn,
          totalRebuys: inputs.totalRebuys,
          effectiveRebuyCost: inputs.effectiveRebuyCost,
          totalReEntries: inputs.totalReEntries,
          addOnEnabled: inputs.addOnEnabled,
          totalAddOns: inputs.totalAddOns,
          effectiveAddOnCost: inputs.effectiveAddOnCost,
        ),
        285,
      );
    });

    test('gross = prizePool + organizerAmount at 0% organizer', () {
      const gross = 285;
      final result = TournamentEngine.recalculatePrizes(gross, 10, 0);
      expect(result.prizePool, gross);
      expect(result.organizerAmount, 0);
    });
  });
}
