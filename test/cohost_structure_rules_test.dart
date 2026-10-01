import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/widgets/structure_editor.dart';

/// D15 / §C2 line 1892 — what a co-host may not change.
///
/// D15: "One co-host role: bust, rebuy, pause, approve check-ins, run the
/// clock. Cannot change the structure, payouts or the organiser contribution."
/// §C2 line 1892 makes the surface explicit: `/t/:id/review` and
/// `/t/:id/levels` are "host, co-host (co-host read-only for structure - D15)".
///
/// The first half of this file mirrors `organizerStructurePinned()` and
/// `organizerTermsPinned()` in `firestore.rules`, the same way
/// `projection_boundary_test.dart` mirrors `projectionSafe()`. The emulator is
/// not available to this suite, so the mirror is the executable form of the
/// rule; the text assertions at the bottom then check the rules file still
/// agrees with the mirror, so the two cannot drift apart silently.
///
/// The second half covers the UI, because the rules pin alone is not enough:
/// a co-host could still have been handed a live editor whose write the rules
/// would then refuse.
const _levels = [BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15)];

Map<String, Object?> _structureDoc({
  List<Object?> prizes = const [1, 180],
  int paidPlaces = 2,
  int prizePool = 240,
  int organizerAmount = 26,
  int roundingRemainder = 4,
  int startingStack = 5000,
  int rebuyStack = 5000,
  int addOnStack = 5000,
  int levelDuration = 15,
  List<Object?> levels = _levels,
}) {
  return <String, Object?>{
    'prizes': prizes,
    'paidPlaces': paidPlaces,
    'prizePool': prizePool,
    'organizerAmount': organizerAmount,
    'roundingRemainder': roundingRemainder,
    'startingStack': startingStack,
    'rebuyStack': rebuyStack,
    'addOnStack': addOnStack,
    'levelDuration': levelDuration,
    'chipPlan': <Object?>[],
    'rebuyChipPlan': <Object?>[],
    'addOnChipPlan': <Object?>[],
    'levels': levels,
  };
}

Map<String, Object?> _gameDoc({
  Map<String, Object?>? structure,
  Map<String, Object?> settings = const {},
  String groupId = 'g1',
  String publicCode = 'ABC123',
  String tvCode = 'TV99999',
  String hostUid = 'host-1',
}) {
  return <String, Object?>{
    'groupId': groupId,
    'publicCode': publicCode,
    'tvCode': tvCode,
    'hostUid': hostUid,
    'structure': structure ?? _structureDoc(),
    'settings': <String, Object?>{'buyIn': 20, 'koAmount': 5, ...settings},
  };
}

/// Firestore rules compare lists and maps by value, deeply and in order.
/// Dart's `==` on a `List` is identity, so a mirror written with `==` would
/// reject every write -- including the ones the rules allow. This is that
/// comparison, and it is the whole reason the first draft of this file failed
/// its own "the clock may run" cases.
bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

/// Dart mirror of `ladderAppendOnly()`.
///
/// The rules cannot walk a list, so the grown case is permissive by
/// construction: a longer ladder is allowed, a shorter one is refused, and a
/// same-length one has to be identical.
bool _ladderAppendOnly(List<Object?> was, List<Object?> now) {
  if (now.length < was.length) return false;
  if (now.length == was.length) return _deepEquals(now, was);
  return true;
}

/// Dart mirror of `organizerStructurePinned()`.
///
/// The rules compare the whole structure except the ladder, with no allow-list
/// of money terms. An allow-list has to be extended every time `structure`
/// grows a field, and the failure mode of forgetting is a field that is
/// silently writable — so the rules pin everything, and this mirror has to do
/// the same or it would keep passing tests for an allow-list the rules no
/// longer use.
bool _structurePinned(Map<String, Object?> before, Map<String, Object?> after) {
  if (!before.containsKey('prizes')) return true;
  final wasRest = Map<String, Object?>.of(before)..remove('levels');
  final nowRest = Map<String, Object?>.of(after)..remove('levels');
  if (!_deepEquals(nowRest, wasRest)) return false;
  return _ladderAppendOnly(
    (before['levels'] as List<Object?>?) ?? const [],
    (after['levels'] as List<Object?>?) ?? const [],
  );
}

/// Dart mirror of `organizerTermsPinned()`, the whole co-host game-doc gate.
bool _termsPinned(Map<String, Object?> before, Map<String, Object?> after) {
  // The rule reads `get('structure', {})`, so a document that never had one
  // compares against an empty map rather than throwing.
  final wasStructure =
      before['structure'] as Map<String, Object?>? ?? const <String, Object?>{};
  final nowStructure =
      after['structure'] as Map<String, Object?>? ?? const <String, Object?>{};
  final was = before['settings'] as Map<String, Object?>? ?? const {};
  final now = after['settings'] as Map<String, Object?>? ?? const {};
  bool sameTop(String key) => _deepEquals(after[key], before[key]);
  bool sameMoney(String key) => _deepEquals(now[key], was[key]);
  return sameTop('groupId') &&
      sameTop('publicCode') &&
      sameTop('tvCode') &&
      sameTop('hostUid') &&
      sameMoney('buyIn') &&
      sameMoney('rebuyCost') &&
      sameMoney('addOnCost') &&
      sameMoney('koAmount') &&
      _structurePinned(wasStructure, nowStructure);
}

void main() {
  group('D15 — a co-host cannot change the structure', () {
    test('the payout ladder is pinned', () {
      final before = _gameDoc();
      final after = _gameDoc(
        structure: _structureDoc(prizes: const [1, 1000000]),
      );
      expect(_termsPinned(before, after), isFalse);
    });

    test('the paid-place count is pinned', () {
      final before = _gameDoc();
      expect(
        _termsPinned(before, _gameDoc(structure: _structureDoc(paidPlaces: 1))),
        isFalse,
      );
    });

    test('the prize pool and organiser take are pinned', () {
      final before = _gameDoc();
      expect(
        _termsPinned(
          before,
          _gameDoc(structure: _structureDoc(prizePool: 100000, organizerAmount: 0)),
        ),
        isFalse,
      );
    });

    test('the rounding remainder is pinned', () {
      final before = _gameDoc();
      expect(
        _termsPinned(
          before,
          _gameDoc(structure: _structureDoc(roundingRemainder: 999)),
        ),
        isFalse,
      );
    });

    test('every stack size is pinned, including the add-on stack', () {
      final before = _gameDoc();
      for (final mutated in <Map<String, Object?>>[
        _structureDoc(startingStack: 1),
        _structureDoc(rebuyStack: 1),
        _structureDoc(addOnStack: 1),
      ]) {
        expect(
          _termsPinned(before, _gameDoc(structure: mutated)),
          isFalse,
          reason: 'stack sizes set what a seat costs, so they are money terms',
        );
      }
    });

    test('the level length is pinned', () {
      final before = _gameDoc();
      expect(
        _termsPinned(before, _gameDoc(structure: _structureDoc(levelDuration: 5))),
        isFalse,
      );
    });

    test('the chip-count plans are pinned', () {
      final before = _gameDoc();
      final after = _gameDoc();
      (after['structure']! as Map<String, Object?>)['chipPlan'] = <Object?>[
        1,
        2,
      ];
      expect(_termsPinned(before, after), isFalse);
    });
  });

  group('D15 — a co-host still runs the game', () {
    test('the clock may move the level ladder', () {
      // `acceptLevelExtension` and `applyFutureLevels` both append to or
      // rewrite `structure.levels`. D15 withholds the structure, but running
      // the clock means the ladder in front of the host has to be able to move,
      // and §C2 1892's "read-only" is about the co-host editing it, not about
      // the clock being frozen. This is the carve-out the rules encode.
      final before = _gameDoc();
      final after = _gameDoc(
        structure: _structureDoc(
          levels: const [
            BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15),
            BlindLevel(level: 2, sb: 50, bb: 100, ante: null, durationMins: 15),
          ],
        ),
      );
      expect(_structurePinned(
        before['structure']! as Map<String, Object?>,
        after['structure']! as Map<String, Object?>,
      ), isTrue);
    });

    test('unrelated game-doc writes are untouched', () {
      // The pin is a pin, not a lock on the document: the clock, the control
      // state and the ledger all live outside `structure`.
      final before = _gameDoc();
      final after = _gameDoc()
        ..['status'] = 'running'
        ..['secondsRemaining'] = 42
        ..['currentLevel'] = 3
        ..['players'] = <Object?>['p1'];
      expect(_termsPinned(before, after), isTrue);
    });

    test('re-saving the document unchanged is allowed', () {
      // Every co-host action rewrites the whole game doc. A write that changes
      // nothing the rules protect must not start failing, so this is the case
      // that would break first if the pin were too tight.
      expect(_termsPinned(_gameDoc(), _gameDoc()), isTrue);
    });

    test('a legacy document with no structure passes', () {
      final before = _gameDoc()..remove('structure');
      final after = _gameDoc()..remove('structure');
      expect(_termsPinned(before, after), isTrue);
    });

    test('a legacy structure with no payout ladder is let through', () {
      // The rule's guard clause exists so the pin cannot lock a game that was
      // already running when the ladder was introduced.
      final before = _gameDoc(structure: _structureDoc())..['structure'] =
          <String, Object?>{'startingStack': 5000};
      final after = _gameDoc(structure: _structureDoc(prizePool: 1));
      expect(_termsPinned(before, after), isTrue);
    });

    test('dropping the payout ladder is refused', () {
      // The mirror is strict on purpose: the guard clause is one-directional.
      // Removing `structure` is a change to it, so it must not slip through the
      // `[]`/`0` defaults.
      final before = _gameDoc();
      final after = _gameDoc()..remove('structure');
      expect(_termsPinned(before, after), isFalse);
    });
  });

  group('Addendum 1 — host identity and money settings stay host-only', () {
    test('hostUid cannot be reassigned by a co-host', () {
      final before = _gameDoc();
      expect(
        _termsPinned(before, _gameDoc(hostUid: 'cohost-1')),
        isFalse,
      );
    });

    test('the join codes cannot be reissued', () {
      final before = _gameDoc();
      expect(_termsPinned(before, _gameDoc(publicCode: 'ZZZ999')), isFalse);
      expect(_termsPinned(before, _gameDoc(tvCode: 'TV11111')), isFalse);
    });

    test('the game cannot be moved to another group', () {
      final before = _gameDoc();
      expect(_termsPinned(before, _gameDoc(groupId: 'g2')), isFalse);
    });

    test('the buy-in, rebuy cost and add-on cost are pinned', () {
      final before = _gameDoc();
      expect(
        _termsPinned(before, _gameDoc(settings: const {'buyIn': 0})),
        isFalse,
      );
      expect(
        _termsPinned(before, _gameDoc(settings: const {'rebuyCost': 0})),
        isFalse,
      );
      expect(
        _termsPinned(before, _gameDoc(settings: const {'addOnCost': 0})),
        isFalse,
      );
    });

    test('the KO amount is pinned', () {
      final before = _gameDoc();
      expect(
        _termsPinned(before, _gameDoc(settings: const {'koAmount': 0})),
        isFalse,
      );
    });

    test('the frozen head-count stays open so a co-host can still start', () {
      // `organizerTermsPinned` deliberately leaves the rest of `settings`
      // writable, because starting the game rewrites the head-count. A co-host
      // may start the game, so this must not be pinned.
      final before = _gameDoc();
      final after = _gameDoc(settings: const {'frozenHeadcount': 9});
      expect(_termsPinned(before, after), isTrue);
    });
  });

  group('the rules file still says what this file assumes', () {
    late final String rules = File('firestore.rules').readAsStringSync();

    test('the structure pin exists and is wired into the co-host gate', () {
      expect(rules, contains('function organizerStructurePinned()'));
      expect(
        rules,
        contains('organizerStructurePinned();'),
        reason: 'an unwired pin function is dead code that looks like a fix',
      );
    });

    test('every money term the mirror covers is pinned by the whole map', () {
      const mirrored = [
        'prizes',
        'paidPlaces',
        'prizePool',
        'organizerAmount',
        'roundingRemainder',
        'startingStack',
        'rebuyStack',
        'addOnStack',
        'levelDuration',
        'chipPlan',
        'rebuyChipPlan',
        'addOnChipPlan',
      ];
      final body = rules.substring(
        rules.indexOf('function organizerStructurePinned()'),
        rules.indexOf('function organizerTermsPinned()'),
      );
      // The mechanism is the assertion now: a total comparison pins every term
      // above AND every term added to `structure` later, with nothing to keep in
      // step. If this ever comes back as a list of `get('...')` comparisons then
      // something has to own the list, and these tests stop covering the terms
      // nobody thought of.
      // (The legacy `prizes` bypass folds into a ternary around the same
      // comparison — the rules compiler rejects `if` inside functions — so
      // this asserts the comparison itself rather than the whole line.)
      expect(body, contains("before.removeAll(['levels'])"));
      expect(body, contains('wasRest == nowRest && ladderAppendOnly()'));
      for (final key in mirrored) {
        // Still worth knowing the term is part of the structure being compared:
        // if a term moved out of `structure` and into `settings`, this stops
        // being pinned by this function at all and the mirror above is lying.
        expect(
          _structureDoc().containsKey(key),
          isTrue,
          reason: '$key is no longer part of the pinned structure',
        );
      }
    });

    test('a field nobody listed is still pinned', () {
      // The failure this design exists to prevent: a term added to `structure`
      // later, absent from every list in this file, silently writable because
      // the pin was an enumeration.
      final tampered = _structureDoc()..['someFutureTerm'] = 999;
      expect(
        _structurePinned(_structureDoc(), tampered),
        isFalse,
        reason: 'an unlisted structure field must not be co-host writable',
      );
    });

    test('the ladder may grow but never shrink or change in place', () {
      final twoLevels = [
        BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15),
        BlindLevel(level: 2, sb: 50, bb: 100, ante: null, durationMins: 15),
      ];
      // Grown: allowed, because the clock needs it.
      expect(
        _structurePinned(_structureDoc(), _structureDoc(levels: twoLevels)),
        isTrue,
      );
      // Shrunk: a completed level was removed, which sections 11 and 29 forbid.
      expect(
        _structurePinned(_structureDoc(levels: twoLevels), _structureDoc()),
        isFalse,
      );
      // Same length but a different blind: an in-place rewrite, which the clock
      // is not doing and the co-host is not allowed to do.
      final rewritten = [
        twoLevels[0],
        BlindLevel(level: 2, sb: 50, bb: 200, ante: null, durationMins: 15),
      ];
      expect(
        _structurePinned(
          _structureDoc(levels: twoLevels),
          _structureDoc(levels: rewritten),
        ),
        isFalse,
      );
    });
  });

  group('§C2 1892 — the levels editor is read-only for a co-host', () {
    Future<void> pumpEditor(WidgetTester tester, {required bool readOnly}) async {
      var applied = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.noScaling),
              child: SingleChildScrollView(
                child: StructureEditor(
                  structure: const TournamentStructure(
                    startingStack: 5000,
                    chipPlan: [],
                    rebuyStack: 5000,
                    rebuyChipPlan: [],
                    addOnStack: 5000,
                    addOnChipPlan: [],
                    levels: [
                      BlindLevel(
                          level: 1, sb: 25, bb: 50, ante: null, durationMins: 15),
                      BlindLevel(
                          level: 2, sb: 50, bb: 100, ante: null, durationMins: 15),
                    ],
                    levelDuration: 15,
                    expectedFinishMins: 210,
                    prizes: [Prize(place: 1, amount: 180)],
                    prizePool: 180,
                    organizerAmount: 0,
                    colorUpInstructions: [],
                    warnings: [],
                  ),
                  currentLevel: 1,
                  anteStyle: AnteStyle.bigBlind,
                  readOnly: readOnly,
                  onSpeedUp: () {},
                  onSlowDown: () {},
                  onApply: (_) => applied = true,
                ),
              ),
            ),
          ),
        ),
      );
      if (readOnly) {
        expect(
          find.textContaining('cannot change the structure'),
          findsOneWidget,
        );
        expect(find.text('Speed up (-5m)'), findsNothing);
        expect(find.text('Slow down (+5m)'), findsNothing);
        // And with no Apply control there is no path to `onApply` at all.
        expect(applied, isFalse);
      } else {
        expect(find.text('Apply & close'), findsOneWidget);
        expect(find.text('Speed up (-5m)'), findsOneWidget);
        expect(find.text('Slow down (+5m)'), findsOneWidget);
        // The host's editor is not just present, it still writes: the fix must
        // not have cost the host the ability to edit their own levels.
        await tester.ensureVisible(find.text('Apply & close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply & close'));
        await tester.pumpAndSettle();
        expect(applied, isTrue);
      }
    }

    testWidgets('a host gets the editor', (t) => pumpEditor(t, readOnly: false));

    testWidgets('a co-host gets the numbers and an explanation, no pencil',
        (t) => pumpEditor(t, readOnly: true));

    // The half above proves the co-host is TOLD the structure is read-only and
    // is not handed Apply. This proves the controls that remain on screen are
    // inert, which is a different failure: a live-looking dropdown whose write
    // is discarded is worse than no control, and "not offered" is not the same
    // claim as "cannot be changed".
    testWidgets('every control left on screen is inert for a co-host',
        (tester) async {
      await pumpEditor(tester, readOnly: true);

      // The blinds/duration selects stay on screen so the ladder is readable.
      // `AppSelect` passes `onChanged: null` through, which is what stops the
      // dropdown opening at all.
      final selects = tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .toList();
      expect(selects, isNotEmpty, reason: 'the ladder is still shown');
      for (final select in selects) {
        expect(
          select.onChanged,
          isNull,
          reason: 'a read-only row must not offer a change',
        );
      }

      // The ante row is a tap target rather than a form field, so it is guarded
      // separately: tapping it must not toggle it.
      final ante = find.text('Ante (big blind ante)');
      await tester.ensureVisible(ante);
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.check_box_outline_blank),
        findsOneWidget,
        reason: 'the structure starts with the ante off',
      );
      await tester.tap(ante);
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.check_box),
        findsNothing,
        reason: 'a co-host tap must not turn the ante on',
      );

      // The insert control is still on screen — a disabled `IconButton` keeps
      // its icon — so the claim is that it is disabled, not that it is absent.
      final insert = tester.widgetList<IconButton>(find.byType(IconButton));
      expect(insert, isNotEmpty, reason: 'the row still offers the control');
      for (final button in insert) {
        expect(
          button.onPressed,
          isNull,
          reason: 'a co-host must not be able to press insert',
        );
      }
    });

    testWidgets('the same controls are live for the host', (tester) async {
      // The counterpart, so the read-only test above cannot be satisfied by
      // controls that are simply broken for everybody.
      await pumpEditor(tester, readOnly: false);

      final selects = tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .toList();
      expect(selects, isNotEmpty);
      for (final select in selects) {
        expect(select.onChanged, isNotNull);
      }

      final ante = find.text('Ante (big blind ante)');
      await tester.ensureVisible(ante);
      await tester.pumpAndSettle();
      await tester.tap(ante);
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.check_box),
        findsOneWidget,
        reason: 'the host still turns the ante on',
      );
      expect(
        find.byIcon(Icons.add_circle_outline),
        findsWidgets,
        reason: 'the host still gets the insert-level control',
      );
      for (final button
          in tester.widgetList<IconButton>(find.byType(IconButton))) {
        expect(button.onPressed, isNotNull);
      }
    });
  });
}
