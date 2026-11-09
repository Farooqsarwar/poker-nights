import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// Throw-away scenario matrix for the 2026-10 feedback analysis (round 2).
/// Widened: ante none/bb, manual close 0/4/5/6, true bank feasibility, ladder
/// dumps, and a resolveAroundPins pin test. NOT a product test.

List<ChipColor> box500() => const [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 150),
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
      ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 100),
    ];

List<ChipColor> demoCase() => const [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 120),
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
      ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 80),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 40),
    ];

List<ChipColor> base25Case() => const [
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 100),
      ChipColor(color: 'Green', hex: 0xFF27AE60, value: 100, quantity: 100),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 80),
      ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 1000, quantity: 50),
      ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 5000, quantity: 30),
    ];

int ownedValue(List<ChipColor> cs) =>
    cs.fold(0, (a, c) => a + c.value * c.quantity);

void main() {
  final cases = <String, List<ChipColor>>{
    'box500': box500(),
    'demo': demoCase(),
    'base25': base25Case(),
  };
  final paces = <String, PaceMode?>{
    'turbo': PaceMode.turbo,
    'regular': PaceMode.regular,
    'deep': PaceMode.deep,
    'none': null,
  };

  test('scenario matrix (widened)', () {
    final rows = <String>[];
    rows.add([
      'case', 'players', 'hours', 'pace', 'format', 'ante', 'manualClose',
      'startStack', 'openSB', 'openBB', 'depthBB', 'levels', 'levelMin',
      'minStep', 'maxStep', 'anySbGeBb', 'engineFeasible', 'trueBankOk',
      'needValue', 'ownedValue', 'fits', 'rebuysCloseLevel', 'warnings',
    ].join(','));

    final v = <String>[];
    var runs = 0;

    for (final players in [6, 9, 12, 20]) {
      for (final hours in [3.0, 4.0, 5.0]) {
        for (final paceEntry in paces.entries) {
          for (final rebuy in [false, true]) {
            for (final ante in [true, false]) {
              for (final manualClose in rebuy ? [0, 4, 5, 6] : [0]) {
                final params = TournamentParams(
                  players: players,
                  durationHours: hours,
                  buyIn: 20,
                  chipSet: box500(), // placeholder, replaced per case below
                  rebuys: rebuy,
                  rebuysCloseLevel: manualClose,
                  rebuyCloseChosenByOrganizer: manualClose > 0,
                  reEntry: false,
                  addOn: rebuy,
                  anteEnabled: ante,
                  anteAfterLevel: 6,
                  koEnabled: false,
                  koAmount: 0,
                  organizerPct: 0,
                  expectedRebuyRate: rebuy ? 0.35 : 0,
                  addOnMultiplier: 1.25,
                  pace: paceEntry.value,
                );
                for (final caseEntry in cases.entries) {
                  final p = params.copyWith(chipSet: caseEntry.value);
                  runs++;
                  TournamentStructure s;
                  try {
                    s = TournamentEngine.generate(p);
                  } catch (e) {
                    rows.add('${caseEntry.key},$players,$hours,${paceEntry.key},'
                        '${rebuy ? 'rebuy' : 'freeze'},${ante ? 'bb' : 'none'},'
                        '$manualClose,ERR,,,,,,,,,,,,,,,"$e"');
                    continue;
                  }
                  final lv = s.levels;
                  final open = lv.isNotEmpty ? lv.first : null;
                  final openSB = open?.sb ?? 0;
                  final openBB = open?.bb ?? 0;
                  final depth = openBB > 0 ? s.startingStack / openBB : 0;
                  double minStep = double.infinity, maxStep = 0;
                  var anySbGeBb = false;
                  for (var i = 0; i < lv.length; i++) {
                    if (lv[i].bb > 0 && lv[i].sb >= lv[i].bb) anySbGeBb = true;
                    if (i > 0 && lv[i - 1].bb > 0) {
                      final r = lv[i].bb / lv[i - 1].bb;
                      if (r > 0 && r < minStep) minStep = r;
                      if (r > maxStep) maxStep = r;
                    }
                  }
                  if (minStep == double.infinity) minStep = 0;

                  final owned = ownedValue(caseEntry.value);
                  final need = s.startingStack * players +
                      s.rebuyStack * p.effectiveExpectedRebuys +
                      s.addOnStack * p.effectiveExpectedAddOns;
                  final trueBankOk = need <= owned;

                  rows.add([
                    caseEntry.key, players, hours, paceEntry.key,
                    rebuy ? 'rebuy' : 'freeze', ante ? 'bb' : 'none',
                    manualClose, s.startingStack, openSB, openBB,
                    depth.toStringAsFixed(1), lv.length, s.levelDuration,
                    minStep.toStringAsFixed(2), maxStep.toStringAsFixed(2),
                    anySbGeBb, s.feasible, trueBankOk, need, owned, s.fits,
                    s.rebuysCloseLevel, s.warnings.length,
                  ].join(','));

                  final tag =
                      '${caseEntry.key}/$players/${hours}h/${paceEntry.key}/'
                      '${rebuy ? 'rebuy' : 'freeze'}/${ante ? 'bb' : 'none'}/c$manualClose';
                  if (anySbGeBb) v.add('SB>=BB            $tag');
                  if (s.startingStack % 25 != 0) {
                    v.add('stack%25!=0 (${s.startingStack})  $tag');
                  }
                  if (s.feasible && !trueBankOk) {
                    v.add('FEASIBLE_BUT_BROKE need=$need owned=$owned  $tag');
                  }
                  if (maxStep > 2.01) {
                    v.add('step x${maxStep.toStringAsFixed(2)}        $tag');
                  }
                  if (paceEntry.value == PaceMode.deep && s.levelDuration != 30) {
                    v.add('DEEP dur=${s.levelDuration} (spec 30)  $tag');
                  }
                }
              }
            }
          }
        }
      }
    }

    Directory('docs/analysis/scratch').createSync(recursive: true);
    File('docs/analysis/engine-scenarios.csv').writeAsStringSync(rows.join('\n'));
    final byType = <String, int>{};
    for (final x in v) {
      final k = x.split(RegExp(r'\s')).first;
      byType[k] = (byType[k] ?? 0) + 1;
    }
    final sb = StringBuffer()
      ..writeln('runs=$runs  violations=${v.length}')
      ..writeln('by type: $byType')
      ..writeln('---')
      ..writeAll(v, '\n');
    File('docs/analysis/scratch/violations.txt').writeAsStringSync(sb.toString());
    // ignore: avoid_print
    print('RUNS=$runs VIOLATIONS=${v.length} BYTYPE=$byType');
  });

  test('ladder dump — locate the big BB step (base25)', () {
    final out = StringBuffer();
    for (final spec in [
      [9, 'regular'],
      [9, 'turbo'],
      [20, 'regular'],
    ]) {
      final players = spec[0] as int;
      final pace = {
        'turbo': PaceMode.turbo,
        'regular': PaceMode.regular,
        'deep': PaceMode.deep,
      }[spec[1]];
      final s = TournamentEngine.generate(TournamentParams(
        players: players,
        durationHours: 4,
        buyIn: 20,
        chipSet: base25Case(),
        rebuys: false,
        rebuysCloseLevel: 0,
        rebuyCloseChosenByOrganizer: false,
        reEntry: false,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 6,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        pace: pace,
      ));
      out.writeln('== base25 $players players, ${spec[1]}, stack ${s.startingStack} ==');
      for (var i = 0; i < s.levels.length && i < 12; i++) {
        final l = s.levels[i];
        final step = i > 0 && s.levels[i - 1].bb > 0
            ? (l.bb / s.levels[i - 1].bb).toStringAsFixed(2)
            : '-';
        out.writeln('  L${l.level}: ${l.sb}/${l.bb}   step x$step');
      }
    }
    File('docs/analysis/scratch/ladder_dump.txt').writeAsStringSync(out.toString());
    // ignore: avoid_print
    print(out.toString());
  });

  test('resolveAroundPins keeps the pin and the tail rises', () {
    // Clean reference ladder from box500.
    final s = TournamentEngine.generate(TournamentParams(
      players: 9,
      durationHours: 4,
      buyIn: 20,
      chipSet: box500(),
      rebuys: false,
      rebuysCloseLevel: 0,
      rebuyCloseChosenByOrganizer: false,
      reEntry: false,
      addOn: false,
      anteEnabled: false,
      anteAfterLevel: 6,
      koEnabled: false,
      koAmount: 0,
      organizerPct: 0,
      pace: PaceMode.regular,
    ));
    final existingBB = s.levels.map((l) => l.bb).toList();
    // Correction 4: use the ladder's real smallest dealt chip, not a forced 25
    // (box500's smallest chip is 1). A forced coarse cmin was the only reason
    // the earlier pin test reported sb≥bb.
    final realCmin =
        s.chipPlan.isNotEmpty ? s.chipPlan.map((e) => e.value).reduce((a, b) => a < b ? a : b) : 1;
    final cmin = List<int>.filled(existingBB.length, realCmin);
    final mid = existingBB.length ~/ 2;
    final pinnedBB = existingBB[mid] + 25; // nudge the pin off the curve
    final pinnedSB = pinnedBB ~/ 2;
    final r = TournamentEngine.resolveAroundPins(
      existingBB: existingBB,
      cminOfLevel: cmin,
      pins: [PinnedLevel(levelNum: mid + 1, sb: pinnedSB, bb: pinnedBB)],
      bbEnd: existingBB.last.toDouble(),
    );
    final out = StringBuffer()
      ..writeln('resolveAroundPins feasible=${r.feasible} error=${r.error}')
      ..writeln('pinned L${mid + 1} -> asked bb=$pinnedBB got bb=${r.bbLadder[mid]} sb=${r.sbLadder[mid]}');
    var rises = true;
    for (var i = 1; i < r.bbLadder.length; i++) {
      if (r.bbLadder[i] < r.bbLadder[i - 1]) rises = false;
    }
    var sbLtBb = true;
    for (var i = 0; i < r.bbLadder.length; i++) {
      if (r.sbLadder[i] >= r.bbLadder[i]) sbLtBb = false;
    }
    out.writeln('pinKept=${r.bbLadder[mid] == pinnedBB}  bbRises=$rises  sb<bb=$sbLtBb');
    File('docs/analysis/scratch/pins_test.txt').writeAsStringSync(out.toString());
    // ignore: avoid_print
    print(out.toString());
  });
}
