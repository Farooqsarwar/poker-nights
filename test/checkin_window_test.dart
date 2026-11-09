import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/screens/public/guest_flow_screen.dart';
import 'package:poker_night/utils/formatters.dart';
import 'package:poker_night/widgets/app_timer.dart';

/// Spec C4/C4p — the automatic check-in window — and spec D6/T32, the
/// early-arrival bonus rule that was supposed to ride on top of it.
///
/// The window is a wall-clock fact: it opens 10 minutes before the scheduled
/// start without anybody pressing anything. Before C4 the only gate was
/// `status.index >= LiveGameStatus.checkin.index`, and a tournament document
/// is created in that status days before a 7pm start, so the door was open
/// from the moment the host hit publish.
///
/// Everything here takes `now` as a parameter rather than reading the clock
/// inside the model, which is what makes the exact boundary — the single
/// second the window opens — assertable instead of approximate.

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
  rebuysCloseLevel: 6,
  addOn: true,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
  earlyArrivalBonusEnabled: true,
);

const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 5000,
  rebuyChipPlan: [],
  addOnStack: 5000,
  addOnChipPlan: [],
  levels: [BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15)],
  levelDuration: 15,
  expectedFinishMins: 225,
  prizes: [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

/// The scheduled start, as the model parses it.
final _start = DateTime(2026, 9, 8, 20, 0);

/// The instant C4 opens the window: 10 minutes before the start.
final _opensAt = DateTime(2026, 9, 8, 19, 50);

LiveGame _game({
  LiveGameStatus status = LiveGameStatus.checkin,
  GameSettings settings = _settings,
}) =>
    LiveGame(
      id: 'game-1',
      groupId: 'grp-1',
      settings: settings,
      structure: _structure,
      status: status,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: const [],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 0,
      pendingGuests: const [],
      finishOrder: const [],
    );

void main() {
  group('the window opens 10 minutes before the start, by itself', () {
    test('the opening instant is the start minus ten minutes', () {
      expect(_settings.checkInOpensAt, _opensAt);
      expect(
        _settings.checkInOpensAt!.difference(_start).inMinutes,
        -GameSettings.checkInLeadMins,
      );
    });

    test('a start whose time is not 24-hour cannot be parsed, and says so', () {
      // `scheduledStart` is `DateTime.tryParse('${date}T$time')`, which only
      // accepts HH:mm. A host who typed "8:00 PM" gets no instant at all —
      // the window then falls back to the status rather than locking a lobby
      // shut against a clock that does not exist.
      final twelve = _settings.copyWith(time: '8:00 PM');
      expect(twelve.scheduledStart, isNull);
      expect(twelve.checkInOpensAt, isNull);
      // The 24-hour form the model does accept, for the same date.
      expect(_settings.copyWith(time: '20:00').scheduledStart, _start);
    });
  });

  group('the door is locked before the window', () {
    test('an hour before the opening, the window is shut', () {
      final game = _game();
      final now = DateTime(2026, 9, 8, 19, 0);
      expect(game.isCheckInOpenAt(now), isFalse);
      final window = game.checkInWindowAt(now);
      expect(window.isOpen, isFalse);
      expect(window.secondsUntilOpen, 50 * 60);
    });

    test('one second before the opening, the window is still shut', () {
      // The boundary itself is the next test. This one exists so an
      // off-by-one in the comparison cannot hide by only ever being probed
      // from far away.
      final game = _game();
      expect(
        game.isCheckInOpenAt(_opensAt.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('the countdown reaches the window rather than the start', () {
      final game = _game();
      final window = game.checkInWindowAt(DateTime(2026, 9, 8, 19, 45));
      // 5 minutes to the window, not 15 to the start: the guest is being told
      // when they can check in, not when the first hand is dealt.
      expect(window.secondsUntilOpen, 5 * 60);
    });
  });

  group('the door is open from the opening instant on', () {
    test('exactly at the opening, the window is open', () {
      expect(_game().isCheckInOpenAt(_opensAt), isTrue);
      expect(_game().checkInWindowAt(_opensAt).isOpen, isTrue);
    });

    test('one second past it, still open', () {
      expect(
        _game().isCheckInOpenAt(_opensAt.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('the countdown reads zero once open, never negative', () {
      final window = _game().checkInWindowAt(
        _opensAt.add(const Duration(minutes: 3)),
      );
      expect(window.isOpen, isTrue);
      expect(window.secondsUntilOpen, 0);
    });

    test('a guest who arrives inside the last ten minutes is on time', () {
      // The point of the whole clause: a member walking in at 19:56 for a
      // 20:00 start is not late, and must not be shown a locked door.
      final game = _game();
      expect(game.isCheckInOpenAt(DateTime(2026, 9, 8, 19, 56)), isTrue);
    });
  });

  group('the status still has to be check-in', () {
    test('a published game never opens, however late the clock is', () {
      // The other half of "both gates": a host who has not opened check-in
      // has not opened check-in, whatever the date says.
      final game = _game(status: LiveGameStatus.published);
      expect(game.isCheckInOpenAt(DateTime(2026, 9, 8, 20, 30)), isFalse);
    });

    test('a draft never opens either', () {
      final game = _game(status: LiveGameStatus.draft);
      expect(game.isCheckInOpenAt(DateTime(2026, 9, 8, 20, 30)), isFalse);
    });

    test('every later live status does open', () {
      for (final s in [
        LiveGameStatus.checkin,
        LiveGameStatus.ready,
        LiveGameStatus.running,
        LiveGameStatus.paused,
        LiveGameStatus.rebuypause,
        LiveGameStatus.finaltable,
      ]) {
        expect(
          _game(status: s).isCheckInOpenAt(_opensAt),
          isTrue,
          reason: '$s is inside the check-in window',
        );
      }
    });

    test('a finished or cancelled game does not', () {
      for (final s in [
        LiveGameStatus.completed,
        LiveGameStatus.cancelled,
      ]) {
        expect(
          _game(status: s).isCheckInOpenAt(_opensAt),
          isFalse,
          reason: '$s is not a check-in window',
        );
      }
    });
  });

  group('D6: the bonus line is the start, not a lead time before it', () {
    test('approved well before the start, the bonus is earned', () {
      expect(
        isEarlyArrivalApproved(
          bonusEnabled: true,
          scheduledStart: _start,
          now: DateTime(2026, 9, 8, 18, 0),
        ),
        isTrue,
      );
    });

    test('approved 30 seconds before the start, the bonus is earned', () {
      // The bug this replaces. The legacy 30-minute cutoff required arrival a
      // full half hour early, so the person who walked in twenty minutes
      // before the first shuffle and was approved half a minute before it —
      // the case D6 is written about — was refused their bonus.
      expect(
        isEarlyArrivalApproved(
          bonusEnabled: true,
          scheduledStart: _start,
          now: _start.subtract(const Duration(seconds: 30)),
        ),
        isTrue,
      );
    });

    test('approved inside the check-in window, the bonus is earned', () {
      // The two clauses have to agree: C4 lets a guest check in from 19:50,
      // and D6 must not then refuse them the bonus for using it.
      expect(
        isEarlyArrivalApproved(
          bonusEnabled: true,
          scheduledStart: _start,
          now: _opensAt.add(const Duration(minutes: 2)),
        ),
        isTrue,
      );
    });

    test('approved at the start itself is not before the start', () {
      expect(
        isEarlyArrivalApproved(
          bonusEnabled: true,
          scheduledStart: _start,
          now: _start,
        ),
        isFalse,
      );
    });

    test('approved after the start is not before the start', () {
      expect(
        isEarlyArrivalApproved(
          bonusEnabled: true,
          scheduledStart: _start,
          now: _start.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('the bonus being off means no eligibility, however early', () {
      expect(
        isEarlyArrivalApproved(
          bonusEnabled: false,
          scheduledStart: _start,
          now: DateTime(2026, 9, 7),
        ),
        isFalse,
      );
    });

    test('no scheduled start means no eligibility, not a crash', () {
      expect(
        isEarlyArrivalApproved(
          bonusEnabled: true,
          scheduledStart: null,
          now: DateTime(2026, 9, 7),
        ),
        isFalse,
      );
    });
  });

  group('the locked card says what the clause says', () {
    Future<void> pump(WidgetTester t, LiveGame game, CheckInWindow w) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GuestCheckInLockedCard(game: game, window: w),
            ),
          ),
        ),
      );
      await t.pump();
    }

    /// [AppTimer] draws each character as its own `Text`, so the displayed
    /// string cannot be found with `find.text`. Asserting on the widget's own
    /// `secondsRemaining` is both simpler and more honest about what is being
    /// checked: the number the card counts down from.
    int countdown(WidgetTester t) =>
        t.widget<AppTimer>(find.byType(AppTimer)).secondsRemaining;

    /// Unmount before the test body ends. `AppTimer` animates through
    /// `flutter_animate`, which leaves a timer behind, and `testWidgets` fails
    /// a test for a pending timer even when every assertion passed — which
    /// says nothing about the card.
    Future<void> unmount(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(milliseconds: 50));
    }

    testWidgets('a lock, the opening time, and the reason', (t) async {
      final game = _game();
      await pump(t, game, game.checkInWindowAt(DateTime(2026, 9, 8, 19, 20)));

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text("Check-in isn't open yet"), findsOneWidget);
      // 19:50 — derived from the parsed start, not the configured "20:00".
      expect(find.text('Opens at 19:50'), findsOneWidget);
      expect(
        find.text('10 minutes before the start, automatically.'),
        findsOneWidget,
      );
      await unmount(t);
    });

    testWidgets('the countdown is present and counting', (t) async {
      final game = _game();
      await pump(t, game, game.checkInWindowAt(DateTime(2026, 9, 8, 19, 20)));
      expect(find.text('Opens in'), findsOneWidget);
      // 30 minutes out.
      expect(countdown(t), 30 * 60);
      await unmount(t);
    });

    testWidgets('a fresh window re-renders the seconds, it does not latch',
        (t) async {
      // The clause asks the state to resolve as time passes. The parent hands
      // this card a new window on every tick, so the card must not cache the
      // first value it was given.
      final game = _game();
      await pump(t, game, game.checkInWindowAt(DateTime(2026, 9, 8, 19, 20)));
      expect(countdown(t), 30 * 60);

      await pump(t, game, game.checkInWindowAt(DateTime(2026, 9, 8, 19, 21)));
      expect(countdown(t), 29 * 60);

      await pump(t, game, game.checkInWindowAt(DateTime(2026, 9, 8, 19, 22)));
      expect(countdown(t), 28 * 60);
      await unmount(t);
    });

    testWidgets('once the window arrives the countdown is gone', (t) async {
      // Nothing left to count down to, so the card stops claiming there is.
      // The parent stops rendering it altogether at this point; the card
      // proving the boundary by what it stops saying is the belt to that
      // braces.
      final game = _game();
      await pump(t, game, game.checkInWindowAt(_opensAt));
      expect(find.text('Opens in'), findsNothing);
      expect(find.byType(AppTimer), findsNothing);
      await unmount(t);
    });

    testWidgets('a game with no parseable start shows the configured time',
        (t) async {
      // "8:00 PM" cannot be parsed, so there is no instant to subtract ten
      // minutes from. Showing a guessed "08:00" would be worse than showing
      // what the host typed.
      final game = _game(settings: _settings.copyWith(time: '8:00 PM'));
      final window = game.checkInWindowAt(DateTime(2026, 9, 8, 19, 20));
      expect(window.opensAt, isNull);
      expect(window.isOpen, isTrue, reason: 'falls back to the status');
      await pump(t, game, window);
      expect(find.text('Opens in'), findsNothing);
      expect(find.text('Opens at 8:00 PM'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('the formatter the countdown relies on agrees', (t) async {
      expect(Formatters.time(1800), '30:00');
      expect(Formatters.time(59), '00:59');
    });
  });

  group('the call to action the clause specifies', () {
    test('is the wording the spec asks for', () {
      expect(kGuestCheckInCta, "I'm here — check me in");
    });
  });
}
