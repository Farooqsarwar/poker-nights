import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/tournament_engine.dart';

const _cases = <String, List<ChipColor>>{
  'box500': [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 150),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 100),
  ],
  'demo': [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 120),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
    ChipColor(color: 'Green', hex: 0xFF27AE60, value: 25, quantity: 80),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 40),
  ],
  'base25': [
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 100),
    ChipColor(color: 'Green', hex: 0xFF27AE60, value: 100, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 80),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 1000, quantity: 50),
    ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 5000, quantity: 30),
  ],
  'base100': [
    ChipColor(color: 'Green', hex: 0xFF27AE60, value: 100, quantity: 120),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 100),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 1000, quantity: 80),
    ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 5000, quantity: 40),
  ],
};

void main() {
  test('home25 vs niceSpec representative nights', () {
    final nights = <(String, int, bool)>[
      ('6p freeze', 6, false),
      ('9p freeze', 9, false),
      ('9p rebuy', 9, true),
      ('20p freeze', 20, false),
    ];
    final sb = StringBuffer()
      ..writeln('| Case | Night (4 h, regular, BB ante) | Family | Stack | Opening | Depth (BB) | Feasible | Ladder all 25-based |')
      ..writeln('|---|---|---|---|---|---|---|---|');
    for (final c in _cases.entries) {
      for (final night in nights) {
        for (final fam in BlindFamily.values) {
          final s = TournamentEngine.generate(TournamentParams(
            players: night.$2, durationHours: 4, buyIn: 20, chipSet: c.value,
            blindFamily: fam, rebuys: night.$3, rebuysCloseLevel: 0,
            reEntry: false, addOn: night.$3, anteEnabled: true, anteAfterLevel: 6,
            koEnabled: false, koAmount: 0, organizerPct: 0,
            format: night.$3 ? TournamentFormat.rebuy : TournamentFormat.freezeOut,
            expectedRebuyRate: night.$3 ? 0.35 : 0, addOnMultiplier: 1.25,
            pace: PaceMode.regular,
          ));
          final o = s.levels.first;
          final all25 = s.levels.every((l) => l.bb % 50 == 0 && l.sb % 25 == 0);
          sb.writeln('| ${c.key} | ${night.$1} | ${fam.name} | ${s.startingStack} | '
              '${o.sb}/${o.bb} | ${(s.startingStack / o.bb).toStringAsFixed(0)} | '
              '${s.feasible ? "yes" : "**NO**"} | ${all25 ? "yes" : "no"} |');
        }
      }
    }
    File('docs/analysis/wp1-home25.md').writeAsStringSync(sb.toString());
    // ignore: avoid_print
    print('HOME25 done');
  });
}
