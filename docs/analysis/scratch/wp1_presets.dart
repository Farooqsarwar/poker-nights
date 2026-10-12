import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// Scratch (not a product test): every built-in chip preset x 6-10 players x
/// 4 h x regular pace x freeze-out / rebuy (35 % rebuys + add-on). Writes the
/// markdown table to docs/analysis/wp1-presets.md.
void main() {
  test('presets table', () {
    final sb = StringBuffer()
      ..writeln('| Preset | Players | Format | Stack | Opening | Depth (BB) | Feasible | In band 85-130 | Notes |')
      ..writeln('|---|---|---|---|---|---|---|---|---|');
    var infeasible = 0, belowBand = 0, rows = 0;
    final flags = <String>[];
    for (final name in TournamentEngine.presetNames) {
      final chips = TournamentEngine.getPreset(name);
      final pieces = chips.fold<int>(0, (a, c) => a + c.quantity);
      final value = chips.fold<int>(0, (a, c) => a + c.quantity * c.value);
      for (final rebuy in [false, true]) {
        for (var n = 6; n <= 10; n++) {
          final s = TournamentEngine.generate(TournamentParams(
            players: n, durationHours: 4, buyIn: 20, chipSet: chips,
            rebuys: rebuy, rebuysCloseLevel: 0, reEntry: false, addOn: rebuy,
            anteEnabled: true, anteAfterLevel: 6, koEnabled: false, koAmount: 0,
            organizerPct: 0,
            format: rebuy ? TournamentFormat.rebuy : TournamentFormat.freezeOut,
            expectedRebuyRate: rebuy ? 0.35 : 0, addOnMultiplier: 1.25,
            pace: PaceMode.regular,
          ));
          final o = s.levels.first;
          final depth = s.startingStack / o.bb;
          final inBand = depth >= 85 && depth <= 130;
          rows++;
          if (!s.feasible) infeasible++;
          if (s.feasible && !inBand) belowBand++;
          final notes = <String>[
            if (!s.feasible)
              'INFEASIBLE'
                  '${s.maxPlayersSupported != null ? " (covers up to ${s.maxPlayersSupported})" : ""}',
            if (s.feasible && s.depthShortfallNote != null) 'depth note',
            if (s.bankShortfall.isNotEmpty)
              'short ${s.bankShortfall.map((x) => "${x.short}x${x.colour}").join("/")}',
            'close L${s.rebuysCloseLevel}',
          ];
          final label = rebuy ? 'rebuy' : 'freeze';
          if (!s.feasible || !inBand) {
            flags.add('$name ${n}p $label: stack ${s.startingStack} @ ${o.sb}/${o.bb} '
                '= ${depth.toStringAsFixed(0)} BB, ${s.feasible ? "feasible" : "INFEASIBLE"}');
          }
          sb.writeln('| $name ($pieces pcs, value $value) | $n | $label | '
              '${s.startingStack} | ${o.sb}/${o.bb} | ${depth.toStringAsFixed(0)} | '
              '${s.feasible ? "yes" : "**NO**"} | ${inBand ? "yes" : "**no**"} | '
              '${notes.join("; ")} |');
        }
      }
    }
    sb
      ..writeln()
      ..writeln('rows=$rows infeasible=$infeasible feasible-but-outside-band=$belowBand')
      ..writeln()
      ..writeln('FLAGGED:')
      ..writeAll(flags.map((f) => '- $f'), '\n');
    File('docs/analysis/wp1-presets.md').writeAsStringSync(sb.toString());
    // ignore: avoid_print
    print('PRESETS rows=$rows infeasible=$infeasible outsideBand=$belowBand');
  });
}
