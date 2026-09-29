import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/clock_authority_notice.dart';
import 'package:provider/provider.dart';

/// C-ops "Take-over" (T84) and §E9's one-writer rule.
///
/// The specification's words, from the C-ops board and §E9:
///
///   "a second phone opening a running game as host/co-host sees
///   'Costa is running this clock on another phone' · 'One phone runs the
///   clock. Take over and Costa's phone becomes a live view, or keep watching
///   from here.' → Take over / Watch only"
///
///   and, for the silent phone: "The host's phone isn't responding — Take over
///   the clock?"
///
/// What these tests pin is the property behind both: ONE device operates the
/// clock, and the choice of which one is made explicitly rather than by
/// whichever tab happened to open the game first. The regression they guard is
/// named in `app_provider_timer.dart` — a device that is not the authority used
/// to run the same level-rollover branch as the host, advancing the level and
/// firing host-only side effects on every member, guest and TV phone in the
/// room.
const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 5000,
  rebuyChipPlan: [],
  addOnStack: 5000,
  addOnChipPlan: [],
  levels: [
    BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 20),
    BlindLevel(level: 2, sb: 50, bb: 100, ante: null, durationMins: 20),
  ],
  levelDuration: 20,
  expectedFinishMins: 40,
  prizes: [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

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
  rebuys: false,
  rebuysCloseLevel: 6,
  addOn: false,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
);

const _host = AppUser(
  id: 'u1',
  name: 'Alex Morgan',
  email: 'alex@poker.night',
  isAdmin: true,
  stats: UserStats(
    played: 34,
    wins: 6,
    podium: 11,
    avgFinish: 3.2,
    knockouts: 18,
  ),
);

/// A co-host. In this codebase the co-host of a tournament is the member the
/// host assigned it to (`LiveGame.organizerIds`), which is exactly what
/// `Permissions.actorFor` resolves to `Actor.organizer` and what §E9's table
/// gives "Run the clock" to.
const _cohost = AppUser(
  id: 'u2',
  name: 'Costa Marchetti',
  email: 'costa@poker.night',
  isAdmin: false,
  isCoAdmin: true,
  stats: UserStats(
    played: 21,
    wins: 3,
    podium: 6,
    avgFinish: 3.9,
    knockouts: 9,
  ),
);

const _member = AppUser(
  id: 'u3',
  name: 'Nina Kowalski',
  email: 'nina@poker.night',
  isAdmin: false,
  stats: UserStats(
    played: 12,
    wins: 2,
    podium: 4,
    avgFinish: 4.1,
    knockouts: 3,
  ),
);

const _group = Group(
  id: 'g1',
  name: 'Friday Poker Club',
  joinCode: 'FP2608',
  ownerId: 'u1',
  members: [_host, _cohost, _member],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

Player _player(String id, {String? name, bool checkedIn = true}) => Player(
      id: id,
      name: name ?? id.toUpperCase(),
      isGuest: false,
      rsvp: Rsvp.going,
      checkedIn: checkedIn,
      confirmed: checkedIn,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: 1,
      seat: 1,
      active: true,
    );

/// A running game whose clock is held by [editorDeviceId].
///
/// [silentFor] sets the claim heartbeat into the past, which is the ONLY
/// evidence §E9's rescue rule has: the document records a device and the
/// moment it last wrote.
LiveGame _runningGame({
  required String id,
  required String editorDeviceId,
  Duration? silentFor = const Duration(seconds: 30),
  String operatorName = '',
  List<String> coHosts = const ['u2'],
  int currentLevel = 1,
  DateTime? levelEndsAt,
}) =>
    LiveGame(
      id: id,
      groupId: 'g1',
      settings: _settings,
      structure: _structure,
      status: LiveGameStatus.running,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: currentLevel,
      timerRunning: true,
      secondsRemaining: 1200,
      levelEndTime: levelEndsAt,
      players: [
        _player('u1', name: 'Alex Morgan'),
        _player('u2', name: 'Costa Marchetti'),
        _player('u3', name: 'Nina Kowalski'),
      ],
      chat: const [],
      announcements: const [],
      auditHistory: operatorName == ''
          ? const []
          : [
              AuditRecord(
                id: 'audit-claim-1',
                timestamp: DateTime(2026, 9, 8, 20, 30),
                type: AppProviderCloudSync.clockTakeoverAuditType,
                actor: operatorName,
                details: '$operatorName is running the clock on this phone.',
              ),
            ],
      totalChipsInPlay: 15000,
      pendingGuests: const [],
      finishOrder: const [],
      organizerIds: coHosts,
      editorDeviceId: editorDeviceId,
      editorClaimedAt:
          silentFor == null ? null : DateTime.now().subtract(silentFor),
    );

AppProvider _provider({
  required AppUser user,
  required LiveGame game,
}) =>
    AppProvider()
      ..setUserForTesting(user)
      ..setCurrentGroupForTesting(_group)
      ..setCurrentGame(game);

/// Pumps the notice, runs [body], then always unmounts and disposes.
///
/// The cleanup is not optional bookkeeping: `AppProvider` starts a periodic
/// ticker in its constructor, and the framework checks for pending timers
/// after the test body but *before* any tearDown, so a provider left running
/// fails with "A Timer is still pending" — an error that says nothing about
/// the notice. `try/finally` keeps that from masking a real failure.
Future<void> notice(
  WidgetTester tester,
  AppProvider app,
  Future<void> Function() body,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: const ClockAuthorityNotice(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  try {
    await body();
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await tester.pump();
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The recovery store writes into the real project directory and is shared
  // between AppProviders; leaving it on makes one test's save fail the next
  // with a file-lock error that has nothing to do with the clock.
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  group('a second host/co-host device', () {
    testWidgets('is told who runs the clock and gets both choices',
        (tester) async {
      final app = _provider(
        user: _cohost,
        game: _runningGame(
          id: 'g-second-host',
          editorDeviceId: 'dev-costa-phone',
          operatorName: 'Costa Marchetti',
        ),
      );

      await notice(tester, app, () async {
        // §C-ops, verbatim: "Costa is running this clock on another phone".
        expect(
          find.textContaining(
            'Costa Marchetti is running this clock on another phone',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            "One phone runs the clock. Take over and Costa Marchetti's phone "
            'becomes a live view, or keep watching from here.',
          ),
          findsOneWidget,
        );
        expect(find.text('Take over'), findsOneWidget);
        expect(find.text('Watch only'), findsOneWidget);

        // It is a statement of fact, not a question: this device does not hold
        // the clock.
        expect(app.thisDeviceRunsTheClock, isFalse);
        expect(app.canOperateTheClock, isTrue);
      });
    });

    testWidgets('is told who runs the clock even when the name is unknown',
        (tester) async {
      // A game written before claims were audited carries a device id and no
      // person. The notice still has to say something true.
      final app = _provider(
        user: _cohost,
        game: _runningGame(
          id: 'g-unnamed-operator',
          editorDeviceId: 'dev-unknown-phone',
          operatorName: '',
        ),
      );

      await notice(tester, app, () async {
        expect(
          find.textContaining('Another phone is running this clock'),
          findsOneWidget,
        );
        expect(app.clockOperatorName, isNull);
      });
    });
  });

  group('Watch only', () {
    testWidgets('leaves this device unable to operate the clock',
        (tester) async {
      final app = _provider(
        user: _cohost,
        game: _runningGame(
          id: 'g-watch-only',
          editorDeviceId: 'dev-costa-phone',
          operatorName: 'Costa Marchetti',
        ),
      );

      await notice(tester, app, () async {
        await _tap(tester, 'Watch only');

        expect(find.text('Take over'), findsNothing);
        expect(app.clockWatchingOnly, isTrue);
        expect(
          app.shouldOfferClockTakeover,
          isFalse,
          reason: 'a device that was asked and said no must not be asked again',
        );
        expect(app.thisDeviceRunsTheClock, isFalse);
      });
    });

    testWidgets('stops the device reclaiming the clock when it goes stale',
        (tester) async {
      // §E9's automatic 90-second claim is an answer to "nobody has this
      // yet", not to "somebody asked me and I declined". A phone told to watch
      // that starts writing the game anyway has not been asked.
      final app = _provider(
        user: _cohost,
        game: _runningGame(
          id: 'g-watch-only-stale',
          editorDeviceId: 'dev-costa-phone',
          silentFor: const Duration(minutes: 5),
          operatorName: 'Costa Marchetti',
        ),
      );

      await notice(tester, app, () async {
        await _tap(tester, 'Watch only');
        // The hold is long past the 90-second staleness window.
        app.setCurrentGame(
          _runningGame(
            id: 'g-watch-only-stale',
            editorDeviceId: 'dev-costa-phone',
            silentFor: const Duration(minutes: 5),
            operatorName: 'Costa Marchetti',
          ),
        );
        await tester.pumpAndSettle();

        expect(app.thisDeviceRunsTheClock, isFalse);
      });
    });
  });

  group('Take over', () {
    testWidgets('moves clock operation to this device', (tester) async {
      final app = _provider(
        user: _cohost,
        game: _runningGame(
          id: 'g-takeover',
          editorDeviceId: 'dev-costa-phone',
          operatorName: 'Costa Marchetti',
        ),
      );

      await notice(tester, app, () async {
        final before = app.currentGame!.editorDeviceId;
        expect(before, 'dev-costa-phone');

        await _tap(tester, 'Take over');

        expect(app.currentGame!.editorDeviceId, app.thisDeviceId);
        expect(
          app.currentGame!.editorDeviceId,
          isNot(before),
          reason: 'the winning device identity has to actually change',
        );
        expect(app.thisDeviceRunsTheClock, isTrue);
        expect(app.shouldOfferClockTakeover, isFalse);
        expect(find.text('Take over'), findsNothing);

        // §C-ops: "every device shows 'Sam took over the clock'".
        expect(
          app.currentGame!.announcements.any(
            (a) => a.text == 'Costa Marchetti took over the clock',
          ),
          isTrue,
        );
        expect(
          app.currentGame!.auditHistory.any(
            (a) =>
                a.type == AppProviderCloudSync.clockTakeoverAuditType &&
                a.actor == 'Costa Marchetti',
          ),
          isTrue,
        );
      });
    });

    testWidgets('a co-host takes the clock over without group-admin rights',
        (tester) async {
      // A tournament co-host is an ORGANIZER, not a group admin — `isAdmin` is
      // the group role. Every gate on the take-over path therefore has to ask
      // `canOperateTheClock` / `canRunCurrentGame` rather than `isAdmin`, or a
      // co-host gets a button that only flips the role on its own phone and
      // never writes the document.
      //
      // Scope note: the Firestore claim itself cannot be asserted here. With no
      // backend the claim path returns at its `!_backendUp` guard before the
      // role gate is ever reached, so that line is verified by reading, not by
      // this suite. What IS asserted here is the role distinction the widening
      // exists for: not a group admin, yet a full clock operator.
      final app = _provider(
        user: _cohost,
        game: _runningGame(
          id: 'g-cohost-not-group-admin',
          editorDeviceId: 'dev-costa-phone',
          operatorName: 'Costa Marchetti',
        ),
      );

      await notice(tester, app, () async {
        expect(
          app.isAdmin,
          isFalse,
          reason: 'premise: the co-host is not a group admin',
        );
        expect(app.canOperateTheClock, isTrue);
        expect(app.shouldOfferClockTakeover, isTrue);

        await _tap(tester, 'Take over');

        expect(app.thisDeviceRunsTheClock, isTrue);
        expect(app.currentGame!.editorDeviceId, app.thisDeviceId);
        expect(app.canOperateTheClock, isTrue);
      });
    });
  });

  group('who is offered it', () {
    testWidgets('a plain member never sees the notice', (tester) async {
      final app = _provider(
        user: _member,
        game: _runningGame(
          id: 'g-member-view',
          editorDeviceId: 'dev-costa-phone',
          operatorName: 'Costa Marchetti',
        ),
      );

      await notice(tester, app, () async {
        expect(app.canOperateTheClock, isFalse);
        expect(app.shouldOfferClockTakeover, isFalse);
        expect(app.shouldOfferOrphanedClockTakeover, isFalse);
        expect(find.text('Take over'), findsNothing);
        expect(find.text('Watch only'), findsNothing);
        expect(
          find.textContaining('is running this clock on another phone'),
          findsNothing,
        );
      });
    });

    testWidgets('a signed-out device never sees the notice', (tester) async {
      // The TV browser, a guest link and a signed-out phone all land here.
      final app = _provider(
        user: _member,
        game: _runningGame(
          id: 'g-tv-view',
          editorDeviceId: 'dev-costa-phone',
          operatorName: 'Costa Marchetti',
        ),
      )..setUserForTesting(null);

      await notice(tester, app, () async {
        expect(app.canOperateTheClock, isFalse);
        expect(app.shouldOfferClockTakeover, isFalse);
        expect(find.text('Take over'), findsNothing);
      });
    });

    testWidgets('the device that already holds the clock is never asked',
        (tester) async {
      // Alex's own phone, mid-game. The provider's own id is the claim, so the
      // notice must not tell Alex to take over from Alex.
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group);
      final thisDevice = app.thisDeviceId;
      app.setCurrentGame(
        _runningGame(
          id: 'g-owner',
          editorDeviceId: thisDevice,
          operatorName: 'Alex Morgan',
        ),
      );

      await notice(tester, app, () async {
        expect(app.thisDeviceRunsTheClock, isTrue);
        expect(app.shouldOfferClockTakeover, isFalse);
        expect(find.text('Take over'), findsNothing);
      });
    });

    testWidgets('a game nobody has claimed is not a take-over',
        (tester) async {
      // Before the first host action there is no holder to take anything from.
      final app = _provider(
        user: _host,
        game: _runningGame(
          id: 'g-unclaimed',
          editorDeviceId: '',
          operatorName: 'Alex Morgan',
        ),
      );

      await notice(tester, app, () async {
        expect(app.shouldOfferClockTakeover, isFalse);
        expect(find.text('Take over'), findsNothing);
      });
    });
  });

  group('§E9 — the clock phone has gone silent', () {
    testWidgets('a host/co-host is offered the rescue after 30 minutes',
        (tester) async {
      final app = _provider(
        user: _cohost,
        game: _runningGame(
          id: 'g-orphan',
          editorDeviceId: 'dev-costa-phone',
          silentFor: const Duration(minutes: 31),
          operatorName: 'Costa Marchetti',
        ),
      );

      await notice(tester, app, () async {
        expect(app.clockHasGoneSilent, isTrue);
        expect(app.shouldOfferOrphanedClockTakeover, isTrue);
        // §C-ops, verbatim.
        expect(
          find.textContaining(
            "The host's phone isn't responding — take over the clock?",
          ),
          findsOneWidget,
        );
        expect(find.text('Take over the clock'), findsOneWidget);
      });
    });

    testWidgets('at 29 minutes the clock is not yet declared gone',
        (tester) async {
      final app = _provider(
        user: _cohost,
        game: _runningGame(
          id: 'g-not-quite-orphan',
          editorDeviceId: 'dev-costa-phone',
          silentFor: const Duration(minutes: 29),
          operatorName: 'Costa Marchetti',
        ),
      );

      await notice(tester, app, () async {
        expect(app.clockHasGoneSilent, isFalse);
        expect(app.shouldOfferOrphanedClockTakeover, isFalse);
        expect(
          find.textContaining("The host's phone isn't responding"),
          findsNothing,
        );
        // Still the everyday prompt: another phone has the clock, and it is
        // presumably alive.
        expect(find.text('Take over'), findsOneWidget);
      });
    });

    testWidgets('taking the rescue clock makes this device the operator',
        (tester) async {
      final app = _provider(
        user: _host,
        game: _runningGame(
          id: 'g-orphan-takeover',
          editorDeviceId: 'dev-costa-phone',
          silentFor: const Duration(minutes: 45),
          operatorName: 'Costa Marchetti',
        ),
      );

      await notice(tester, app, () async {
        await _tap(tester, 'Take over the clock');

        expect(app.thisDeviceRunsTheClock, isTrue);
        expect(app.currentGame!.editorDeviceId, app.thisDeviceId);
        expect(
          app.currentGame!.announcements.any(
            (a) => a.text == 'Alex Morgan took over the clock',
          ),
          isTrue,
        );
      });
    });
  });

  group('only one device runs the clock', () {
    testWidgets(
        'the level that just ran out is advanced by the clock device alone',
        (tester) async {
      // The regression: the previous bug let every member / guest / TV device
      // take the same branch in the 1-second ticker, so the level moved on
      // screens that were supposed to be read-only, each firing its own
      // announcement, notification and undo entry.
      //
      // Both providers below read the SAME document. `FirebaseRepository` is a
      // process singleton, so two `AppProvider`s in one test share a device
      // id; the device identity that decides the role is therefore modelled
      // through the document itself — the game the provider holds names a
      // device, and only the provider whose own id that device is operates the
      // clock. The second provider below stands for the phone the document
      // does NOT name, which after a take-over is precisely the phone that
      // used to run the clock.
      final scratch = _provider(
        user: _host,
        game: _runningGame(
          id: 'g-invariants-scratch',
          editorDeviceId: 'dev-the-clock',
          operatorName: 'Costa Marchetti',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final deviceId = scratch.thisDeviceId;
      scratch.dispose();
      await tester.pump();

      // The level is already spent, so the next tick of the 1-second ticker is
      // the transition.
      final expired = DateTime.now().subtract(const Duration(seconds: 1));

      final clockDevice = _provider(
        user: _host,
        game: _runningGame(
          id: 'g-invariants',
          editorDeviceId: deviceId,
          operatorName: 'Alex Morgan',
          levelEndsAt: expired,
        ),
      );
      final otherDevice = _provider(
        user: _member,
        game: _runningGame(
          id: 'g-invariants',
          editorDeviceId: deviceId,
          operatorName: 'Alex Morgan',
          levelEndsAt: expired,
        ),
      );

      try {
        expect(clockDevice.thisDeviceRunsTheClock, isTrue);
        expect(otherDevice.thisDeviceRunsTheClock, isFalse);

        await tester.pump(const Duration(seconds: 1));

        // The clock device OPERATED the transition: it burned a revision,
        // announced the new level and pushed an undo entry.
        expect(clockDevice.currentGame!.currentLevel, 2);
        expect(clockDevice.currentGame!.revision, greaterThan(0));
        expect(
          clockDevice.currentGame!.announcements.any(
            (a) => a.text.startsWith('Start of level 2'),
          ),
          isTrue,
        );
        expect(clockDevice.canUndo, isTrue);

        // The other device moved the DISPLAY on, so the countdown keeps
        // running, and did nothing else: no revision, no announcement, no undo
        // entry, nothing written.
        expect(otherDevice.currentGame!.currentLevel, 2);
        expect(
          otherDevice.currentGame!.revision,
          0,
          reason: 'a read-only device must not burn a revision',
        );
        expect(
          otherDevice.currentGame!.announcements,
          isEmpty,
          reason: 'a read-only device must not speak for the host',
        );
        expect(otherDevice.canUndo, isFalse);
      } finally {
        clockDevice.dispose();
        otherDevice.dispose();
        await tester.pump();
      }
    });

    testWidgets('a stale claim is not taken by a co-host nobody asked',
        (tester) async {
      // §E9 lets any admin device take over a claim older than 90 seconds. The
      // C-ops take-over is the USER-FACING half of that and it is a choice:
      // until the co-host presses the button, this phone is a live view of
      // Costa's game, however long the claim has been quiet.
      final coHostDevice = _provider(
        user: _cohost,
        game: _runningGame(
          id: 'g-stale-unasked',
          editorDeviceId: 'dev-costa-phone',
          silentFor: const Duration(minutes: 12),
          operatorName: 'Costa Marchetti',
          levelEndsAt: DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      );

      await notice(tester, coHostDevice, () async {
        expect(coHostDevice.shouldOfferClockTakeover, isTrue);
        expect(coHostDevice.shouldOfferOrphanedClockTakeover, isFalse);

        await tester.pump(const Duration(seconds: 1));

        expect(coHostDevice.thisDeviceRunsTheClock, isFalse);
        expect(coHostDevice.currentGame!.revision, 0);
        expect(coHostDevice.currentGame!.announcements, isEmpty);
        expect(coHostDevice.canUndo, isFalse);
        // Still being offered the choice — nothing was decided for them.
        expect(find.text('Take over'), findsOneWidget);
      });
    });
  });
}
