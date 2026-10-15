import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/admin_dashboard_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/tournament_timer_card.dart';
import 'package:provider/provider.dart';

const _host = AppUser(
  id: 'host',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

GameSettings _settings({bool rebuys = true}) => GameSettings(
  name: 'Quick game',
  date: '2026-10-15',
  time: '20:00',
  location: 'Kitchen table',
  players: 3,
  durationHours: 3,
  buyIn: 20,
  koEnabled: false,
  koAmount: 0,
  rebuys: rebuys,
  rebuysCloseLevel: 2,
  addOn: false,
  anteEnabled: false,
  anteAfterLevel: 3,
  organizerPct: 0,
  chipSet: const [],
  chipSetName: 'Quick set',
);

const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 5000,
  rebuyChipPlan: [],
  addOnStack: 0,
  addOnChipPlan: [],
  levels: [
    BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15),
    BlindLevel(level: 2, sb: 50, bb: 100, ante: null, durationMins: 15),
    BlindLevel(level: 3, sb: 75, bb: 150, ante: null, durationMins: 15),
  ],
  levelDuration: 15,
  expectedFinishMins: 45,
  prizes: [Prize(place: 1, amount: 40), Prize(place: 2, amount: 20)],
  prizePool: 60,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

Player _player(int index) => Player(
  id: 'p$index',
  name: 'Player $index',
  isGuest: false,
  rsvp: null,
  checkedIn: true,
  confirmed: true,
  eliminated: false,
  rebuys: 0,
  hasAddOn: false,
  knockouts: 0,
  table: 1,
  seat: index,
  active: true,
);

LiveGame _game({
  bool rebuys = true,
  int level = 1,
  bool settled = false,
  LiveGameStatus status = LiveGameStatus.running,
}) => LiveGame(
  id: 'quick-game',
  groupId: 'group',
  settings: _settings(rebuys: rebuys),
  structure: _structure,
  status: status,
  publicCode: 'ABC123',
  tvCode: 'TV1234',
  currentLevel: level,
  timerRunning: status == LiveGameStatus.running,
  secondsRemaining: 600,
  players: [_player(1), _player(2), _player(3)],
  chat: const [],
  announcements: const [],
  totalChipsInPlay: 15000,
  pendingGuests: const [],
  finishOrder: const [],
  settlementConfirmed: settled,
);

Group _group(LiveGame game) => Group(
  id: 'group',
  name: 'Quick games',
  joinCode: 'QUICK',
  ownerId: _host.id,
  members: const [_host],
  games: [game],
  chat: const [],
  polls: const [],
  notifications: const [],
);

AppProvider _provider(LiveGame game) => AppProvider()
  ..setUserForTesting(_host)
  ..setCurrentGroupForTesting(_group(game))
  ..setCurrentGameForTesting(game);

Future<GoRouter> _mount(
  WidgetTester tester,
  AppProvider app, {
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/rebuy-settlement',
        builder: (_, _) => const Scaffold(body: Text('SETTLEMENT')),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return router;
}

Future<void> _unmount(
  WidgetTester tester,
  AppProvider app,
  GoRouter router,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  router.dispose();
  app.dispose();
  await tester.binding.setSurfaceSize(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  test('rebuy payouts stay hidden until settlement is confirmed', () {
    expect(_game().payoutTableRevealed, isFalse);
    expect(
      _game(status: LiveGameStatus.rebuypause).payoutTableRevealed,
      isFalse,
    );
    expect(_game(level: 3, settled: true).payoutTableRevealed, isTrue);
  });

  test('freeze-out payouts appear when late registration closes', () {
    expect(_game(rebuys: false, level: 2).payoutTableRevealed, isFalse);
    expect(_game(rebuys: false, level: 3).payoutTableRevealed, isTrue);
  });

  test('quick game hold to settlement reveals the final payout table', () {
    final app = _provider(_game(level: 2));
    addTearDown(app.dispose);

    expect(app.currentGame!.payoutTableRevealed, isFalse);
    app.nextLevel(idempotencyKey: 'close-rebuys');
    expect(app.currentGame!.status, LiveGameStatus.rebuypause);
    expect(app.currentGame!.payoutTableRevealed, isFalse);

    app.confirmSettlement();
    expect(app.currentGame!.settlementConfirmed, isTrue);
    expect(app.currentGame!.payoutTableRevealed, isTrue);
    expect(app.currentGame!.structure.prizes, isNotEmpty);
  });

  test('a quick game can add a walk-in after the clock starts', () {
    final app = _provider(_game());
    addTearDown(app.dispose);

    app.addLatePlayer('Walk-in');

    expect(app.currentGame!.activePlayers, hasLength(4));
    expect(app.currentGame!.activePlayers.last.name, 'Walk-in');
    expect(app.currentGame!.totalChipsInPlay, 20000);
  });

  testWidgets('Pause and Next stay directly below the compact scoreboard', (
    tester,
  ) async {
    final app = _provider(_game());
    final router = await _mount(tester, app);

    final scoreboard = find.byType(TournamentTimerCard);
    final pause = find.text('Pause');
    final next = find.text('Next');
    expect(scoreboard, findsOneWidget);
    expect(pause, findsOneWidget);
    expect(next, findsOneWidget);

    final scoreboardBottom = tester.getBottomLeft(scoreboard).dy;
    final pauseTop = tester.getTopLeft(pause).dy;
    expect(pauseTop, greaterThan(scoreboardBottom));
    expect(tester.getBottomLeft(pause).dy, lessThanOrEqualTo(844));
    expect(tester.getBottomLeft(next).dy, lessThanOrEqualTo(844));

    await _unmount(tester, app, router);
  });

  testWidgets('the prize tab shows only the pool until payouts are revealed', (
    tester,
  ) async {
    final game = _game();
    final app = _provider(game);
    final router = await _mount(tester, app, size: const Size(390, 1800));

    await tester.tap(find.text('Prize pool'));
    await tester.pump();
    expect(find.text('Prize pool so far'), findsOneWidget);
    expect(find.text('Paid places'), findsNothing);

    app.setCurrentGameForTesting(game.copyWith(settlementConfirmed: true));
    await tester.pump();
    expect(find.text('Paid places'), findsOneWidget);

    await _unmount(tester, app, router);
  });

  testWidgets('the live player list offers a clearly named walk-in action', (
    tester,
  ) async {
    final app = _provider(_game());
    final router = await _mount(tester, app, size: const Size(390, 1800));

    expect(find.text('Add a walk-in player'), findsOneWidget);

    await _unmount(tester, app, router);
  });
}
