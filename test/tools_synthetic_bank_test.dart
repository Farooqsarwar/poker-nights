import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// Decision (WP1 review): the free tools follow §F1.14 — with no chip case, the
/// engine is run with a synthetic 1 · 5 · 25 · 100 · 500 · 1,000 case "sized so
/// the bank never binds", so a tool never answers with a bank card. The
/// placeholder-ladder guard stays as a safety net (see
/// infeasible_start_guard_test.dart).
void main() {
  test('the default tool box is the six denominations §F1.14 names', () {
    expect(kToolChipSet.map((c) => c.value).toList(),
        [1, 5, 25, 100, 500, 1000]);
  });

  group('neverBindingBank', () {
    test('keeps every colour and value, only the quantities grow', () {
      final bank = TournamentEngine.neverBindingBank(kToolChipSet, players: 40);
      expect(bank.map((c) => c.value).toList(),
          kToolChipSet.map((c) => c.value).toList());
      expect(bank.map((c) => c.color).toList(),
          kToolChipSet.map((c) => c.color).toList());
    });

    test('is sized for the field: at least 100 of each colour per player', () {
      for (final players in [2, 9, 14, 100]) {
        final bank =
            TournamentEngine.neverBindingBank(kToolChipSet, players: players);
        for (final c in bank) {
          expect(c.quantity, greaterThanOrEqualTo(players * 100),
              reason: '$players players, ${c.color}');
        }
      }
    });

    test('never SHRINKS a real quantity', () {
      const real = [
        ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 99999),
        ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 7),
      ];
      final bank = TournamentEngine.neverBindingBank(real, players: 4);
      expect(bank[0].quantity, 99999);
      expect(bank[1].quantity, 400);
    });

    test('does not mutate its input', () {
      final before = kToolChipSet.map((c) => c.quantity).toList();
      TournamentEngine.neverBindingBank(kToolChipSet, players: 100);
      expect(kToolChipSet.map((c) => c.quantity).toList(), before);
    });
  });

  group('every tool box is dealable for every field the tools allow', () {
    // The tools' stepper allows 2-100 players and 3-6 hours, with rebuys,
    // a 6-level window and an add-on on (tools_screen.dart).
    for (final entry in kToolChipSets.entries) {
      test(entry.key, () {
        for (final players in [2, 3, 6, 9, 14, 17, 25, 40, 60, 100]) {
          for (final hours in [3.0, 4.0, 5.0, 6.0]) {
            for (final ante in [false, true]) {
              final s = TournamentEngine.generate(
                TournamentParams(
                  players: players,
                  durationHours: hours,
                  buyIn: 20,
                  chipSet: TournamentEngine.neverBindingBank(
                    entry.value,
                    players: players,
                  ),
                  rebuys: true,
                  rebuysCloseLevel: 6,
                  reEntry: false,
                  addOn: true,
                  anteEnabled: ante,
                  anteAfterLevel: 7,
                  koEnabled: false,
                  koAmount: 0,
                  organizerPct: 0,
                ),
                findMaxPlayers: false,
              );
              expect(s.isBlocked, isFalse,
                  reason: '${entry.key}: $players players, ${hours}h, '
                      'ante=$ante must not be blocked');
              expect(s.bankOk, isTrue,
                  reason: '${entry.key}: $players players, ${hours}h');
              expect(s.levels.first.sb, lessThan(s.levels.first.bb));
            }
          }
        }
      });
    }
  });
}
