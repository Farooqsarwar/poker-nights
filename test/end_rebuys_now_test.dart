import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/screens/tournament/admin_dashboard_screen.dart';
import 'package:poker_night/screens/tournament/rebuy_settlement_screen.dart';

/// Spec C6 — the second rebuy-close entry point, "End rebuys now".
///
/// The first entry point is the hold that has always existed: play reaches the
/// configured closing level, the host presses Next, and the rebuy window shuts
/// with the settlement break. C6 adds a second way in — a host who decides
/// mid-level that nobody else is coming, and wants the window shut at the end
/// of *this* level rather than three levels from now.
///
/// The implementation arms `rebuysCloseLevel` at the current level and lets the
/// existing level-end transition do the rest, so the two entry points share one
/// state change rather than two that can drift. What is testable, and what these
/// tests pin, is that the armed game is in exactly the same modelled state as
/// a game that had been configured to close at that level all along.

const _settings = GameSettings(
  name: 'Friday',
  date: '2026-09-08',
  time: '20:00',
  location: 'Basement',
  players: 8,
  durationHours: 3.5,
  buyIn: 15,
  koEnabled: false,
  koAmount: 0,
  rebuys: true,
  rebuysCloseLevel: 8,
  addOn: true,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
);

TournamentStructure _structure({int levels = 20}) => TournamentStructure(
  startingStack: 5000,
  chipPlan: const [],
  rebuyStack: 5000,
  rebuyChipPlan: const [],
  addOnStack: 5000,
  addOnChipPlan: const [],
  levels: [
    for (var i = 1; i <= levels; i++)
      BlindLevel(level: i, sb: 25 * i, bb: 50 * i, ante: null, durationMins: 15),
  ],
  levelDuration: 15,
  expectedFinishMins: 300,
  prizes: const [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: const [],
  warnings: const [],
);

LiveGame _game({
  LiveGameStatus status = LiveGameStatus.running,
  int currentLevel = 3,
  GameSettings? settings,
  int rebuysCloseLevel = 8,
  bool settlementConfirmed = false,
  int levels = 20,
}) =>
    LiveGame(
      id: 'game-1',
      groupId: 'grp-1',
      settings:
          (settings ?? _settings).copyWith(rebuysCloseLevel: rebuysCloseLevel),
      structure: _structure(levels: levels),
      status: status,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: currentLevel,
      timerRunning: true,
      secondsRemaining: 900,
      players: const [],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 0,
      pendingGuests: const [],
      finishOrder: const [],
      settlementConfirmed: settlementConfirmed,
    );

/// What `endRebuysNow` writes: the close pulled forward to the current level.
/// Mirrors the provider so the test can assert the *state* without standing up
/// a Firebase-backed AppProvider.
LiveGame _armed(LiveGame game) => game.copyWith(
  settings: game.settings.copyWith(
    rebuysCloseLevel: game.currentLevel,
    rebuyCloseChosenByOrganizer: true,
  ),
);

void main() {
  group('the button is offered only while rebuys are open', () {
    test('mid-level, on a live game, the current level is offered', () {
      expect(_game().endRebuysNowLevel, 3);
    });

    test('a paused clock is still mid-level and is offered', () {
      expect(_game(status: LiveGameStatus.paused).endRebuysNowLevel, 3);
    });

    test('hidden once the level in play IS the closing level', () {
      // Offering "End rebuys now - after Level 8" while Level 8 is running
      // would be a button that changes nothing: the same close happens on the
      // next press of Next either way.
      expect(_game(currentLevel: 8, rebuysCloseLevel: 8).endRebuysNowLevel, isNull);
    });

    test('hidden after the level has passed the closing level', () {
      expect(
        _game(currentLevel: 9, rebuysCloseLevel: 8).endRebuysNowLevel,
        isNull,
      );
    });

    test('hidden in the settlement break, where the window is already shut',
        () {
      expect(
        _game(status: LiveGameStatus.rebuypause).endRebuysNowLevel,
        isNull,
      );
    });

    test('hidden once the settlement is confirmed', () {
      expect(
        _game(settlementConfirmed: true).endRebuysNowLevel,
        isNull,
        reason: 'rebuysClosed is true, and nothing is open to close',
      );
    });

    test('hidden in the pre-game lobby, where there is no level running', () {
      for (final s in [
        LiveGameStatus.draft,
        LiveGameStatus.published,
        LiveGameStatus.checkin,
        LiveGameStatus.ready,
      ]) {
        expect(
          _game(status: s).endRebuysNowLevel,
          isNull,
          reason: '$s has no level in progress',
        );
      }
    });

    test('hidden once the tournament is over', () {
      for (final s in [LiveGameStatus.completed, LiveGameStatus.cancelled]) {
        expect(_game(status: s).endRebuysNowLevel, isNull, reason: '$s');
      }
    });

    test('hidden on the last level, which has no next level to hand play to',
        () {
      expect(
        _game(currentLevel: 20, levels: 20, rebuysCloseLevel: 25)
            .endRebuysNowLevel,
        isNull,
      );
    });

    test('never offered when the tournament has no rebuys at all', () {
      final noRebuys = _settings.copyWith(rebuys: false);
      expect(
        _game(settings: noRebuys, rebuysCloseLevel: 8).endRebuysNowLevel,
        isNull,
      );
    });
  });

  group('the button is offered only to the host or co-host', () {
    test('a host is offered it', () {
      expect(
        endRebuysNowLevelFor(game: _game(), canRunGame: true),
        3,
      );
    });

    test('a non-host is not', () {
      // A plain member has every reason to see the blind schedule and no
      // reason at all to be able to shut the rebuy window for the table.
      expect(
        endRebuysNowLevelFor(game: _game(), canRunGame: false),
        isNull,
      );
    });

    test('a non-host is not offered it even mid-level with rebuys open', () {
      // The exact shape in which the host IS offered it, so the only thing
      // that changed is who is asking.
      final game = _game();
      expect(game.endRebuysNowLevel, isNotNull);
      expect(endRebuysNowLevelFor(game: game, canRunGame: false), isNull);
    });
  });

  group('the label is the wording the clause specifies', () {
    test('is "End rebuys now - after Level {n}"', () {
      expect(endRebuysNowLabel(3), 'End rebuys now - after Level 3');
      expect(endRebuysNowLabel(1), 'End rebuys now - after Level 1');
      expect(endRebuysNowLabel(12), 'End rebuys now - after Level 12');
    });
  });

  group('arming the close produces the same state as the hold would have', () {
    // The whole design claim: there is one rebuy-close transition, reached
    // from two entry points. So the armed game must be indistinguishable, from
    // everything the transition reads, from a game that had been configured to
    // close at this level from the start.
    late LiveGame natural;
    late LiveGame armed;

    setUp(() {
      // Entry point 1: configured to close at Level 3, now playing Level 3.
      natural = _game(currentLevel: 3, rebuysCloseLevel: 3);
      // Entry point 2: configured to close at Level 8, now playing Level 3,
      // then armed by the host.
      armed = _armed(_game(currentLevel: 3, rebuysCloseLevel: 8));
    });

    test('both sit at the same closing level', () {
      expect(armed.settings.rebuysCloseLevel, natural.settings.rebuysCloseLevel);
      expect(armed.settings.rebuysCloseLevel, 3);
    });

    test('both consider the rebuy window still open', () {
      expect(natural.rebuysClosed, isFalse);
      expect(armed.rebuysClosed, isFalse);
    });

    test('both are "rebuys closing" on the header', () {
      expect(natural.rebuysClosingArmed, isTrue);
      expect(armed.rebuysClosingArmed, isTrue);
    });

    test('both hide the button, because there is nothing left to change', () {
      expect(natural.endRebuysNowLevel, isNull);
      expect(armed.endRebuysNowLevel, isNull);
    });

    test('neither lets anybody new in, and both close the door at the same '
        'moment', () {
      // `registrationClosed` keys off the same level, so an armed close shuts
      // the door to walk-ins at exactly the same point a configured one does —
      // which is what "no more players after this point" is supposed to mean.
      // It flips when the closing level has ENDED, not while it is running:
      // a player arriving at 3:50 into the last rebuyable level still gets in.
      expect(natural.registrationClosed, isFalse);
      expect(armed.registrationClosed, isFalse);

      final naturalAfter = natural.copyWith(currentLevel: 4);
      final armedAfter = armed.copyWith(currentLevel: 4);
      expect(naturalAfter.registrationClosed, isTrue);
      expect(armedAfter.registrationClosed, isTrue);
    });

    test('arming is not mistaken for the configured-close case for add-ons', () {
      // `rebuyCloseChosenByOrganizer` is what the generation parameters use to
      // tell "the host picked this level" from "the engine suggested it", so it
      // is set by the arm and must not change anything else about the game.
      expect(armed.settings.rebuyCloseChosenByOrganizer, isTrue);
      expect(armed.settings.rebuys, natural.settings.rebuys);
      expect(armed.currentLevel, natural.currentLevel);
      expect(armed.structure.levels.length, natural.structure.levels.length);
    });

    test('the level end is what fires: the close is at the end of level 3', () {
      // Spelled out because it is the promise the button makes — "after Level
      // 3", not "now". The next level is 4, so the crossing
      // `currentLevel <= close < next` holds for the armed game exactly as it
      // does for the configured one.
      for (final g in [natural, armed]) {
        expect(g.currentLevel <= g.settings.rebuysCloseLevel, isTrue);
        expect(g.currentLevel + 1 > g.settings.rebuysCloseLevel, isTrue);
      }
    });
  });

  group('the header pill reads REBUYS CLOSING until the break, then BREAK', () {
    test('RUNNING while the window is open and the close is not imminent', () {
      expect(liveStatusPillLabel(_game()), 'RUNNING');
    });

    test('REBUYS CLOSING on the closing level, before the break', () {
      expect(liveStatusPillLabel(_game(currentLevel: 8)), 'REBUYS CLOSING');
    });

    test('REBUYS CLOSING the moment the host arms the close', () {
      expect(liveStatusPillLabel(_armed(_game())), 'REBUYS CLOSING');
    });

    test('BREAK once the close has actually happened', () {
      final g = _game(status: LiveGameStatus.rebuypause, currentLevel: 4);
      expect(liveStatusPillLabel(g), 'BREAK');
    });

    test('the two labels are never both live', () {
      // REBUYS CLOSING is armed on the closing level; `rebuysClosed` is what
      // `rebuypause` satisfies, so a game in the break is not "closing".
      final inBreak = _game(status: LiveGameStatus.rebuypause, currentLevel: 4);
      expect(inBreak.rebuysClosingArmed, isFalse);
      expect(liveStatusPillLabel(inBreak), isNot('REBUYS CLOSING'));
    });

    test('PAUSED stays PAUSED even on the closing level', () {
      // A host who paused the clock has not closed anything, and the pill
      // should not imply the room is about to be cut off.
      expect(
        liveStatusPillLabel(
          _game(status: LiveGameStatus.paused, currentLevel: 8),
        ),
        'PAUSED',
      );
    });

    test('the add-on overtime window still takes precedence', () {
      final g = _game(
        currentLevel: 8,
        settings: _settings.copyWith(addOnOvertime: true),
      );
      expect(liveStatusPillLabel(g), 'ADD-ON WINDOW (OVERTIME)');
    });

    test('anything else falls back to the status label', () {
      expect(
        liveStatusPillLabel(_game(status: LiveGameStatus.finaltable)),
        'FINAL TABLE',
      );
    });
  });

  group('the confirmation dialog', () {
    Future<void> pump(WidgetTester t, {required int level, int previous = 8}) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EndRebuysNowConfirm(
              level: level,
              previousLevel: previous,
              onKeepOpen: () {},
              onEnd: () {},
            ),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('names the level, and what is changing', (t) async {
      await pump(t, level: 3, previous: 8);
      expect(
        find.textContaining('close at the end of Level 3 instead of Level 8'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
    });

    testWidgets('says the level is still played out in full', (t) async {
      // The clause says "after Level {n}", and the most likely misreading is
      // that it stops the clock now. It does not.
      await pump(t, level: 3, previous: 8);
      expect(
        find.textContaining('still played out in full'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
    });

    testWidgets('has a way out that does not end anything', (t) async {
      var kept = false;
      var ended = false;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EndRebuysNowConfirm(
              level: 3,
              previousLevel: 8,
              onKeepOpen: () => kept = true,
              onEnd: () => ended = true,
            ),
          ),
        ),
      );
      await t.pump();
      await t.tap(find.text('Keep rebuys open'));
      await t.pump();
      expect(kept, isTrue);
      expect(ended, isFalse);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
    });

    testWidgets('the confirming button actually ends the rebuys', (t) async {
      var kept = false;
      var ended = false;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EndRebuysNowConfirm(
              level: 3,
              previousLevel: 8,
              onKeepOpen: () => kept = true,
              onEnd: () => ended = true,
            ),
          ),
        ),
      );
      await t.pump();
      await t.tap(find.text('End rebuys'));
      await t.pump();
      expect(ended, isTrue);
      expect(kept, isFalse);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
    });

    testWidgets('does not claim to be changing anything when it is not',
        (t) async {
      // Offered on the last level it is not, so the copy must not invent a
      // previous level to contrast against.
      await pump(t, level: 3, previous: 3);
      expect(find.textContaining('instead of'), findsNothing);
      expect(
        find.textContaining('close at the end of Level 3'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
    });
  });

  group('ending the break early', () {
    test('the control is labelled exactly as the clause writes it', () {
      expect(kConfirmAndResumeClock, 'Confirm & resume clock');
    });
  });
}
