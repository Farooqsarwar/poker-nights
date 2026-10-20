import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/group_screen.dart';
import 'package:poker_night/screens/shell/home_screen.dart';
import 'package:poker_night/screens/shell/settings_screen.dart';
import 'package:poker_night/screens/tournament/payouts_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/formatters.dart';
import 'package:provider/provider.dart';

const _host = AppUser(
  id: 'host',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 1, wins: 1, podium: 1, avgFinish: 1, knockouts: 2),
);

const _settings = GameSettings(
  name: 'Friday game',
  date: '2026-10-17',
  time: '20:00',
  location: 'Kitchen table',
  players: 3,
  durationHours: 3,
  buyIn: 20,
  koEnabled: false,
  koAmount: 0,
  rebuys: false,
  rebuysCloseLevel: 0,
  addOn: false,
  anteEnabled: false,
  anteAfterLevel: 3,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
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
  ],
  levelDuration: 15,
  expectedFinishMins: 45,
  prizes: [Prize(place: 1, amount: 800), Prize(place: 2, amount: 434)],
  prizePool: 1234,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

final _game = LiveGame(
  id: 'game-1',
  groupId: 'group-1',
  settings: _settings,
  structure: _structure,
  status: LiveGameStatus.completed,
  publicCode: 'ABC123',
  tvCode: 'TV1234',
  currentLevel: 1,
  timerRunning: false,
  secondsRemaining: 0,
  players: const [],
  chat: const [],
  announcements: const [],
  totalChipsInPlay: 0,
  pendingGuests: const [],
  finishOrder: const [],
  settlementConfirmed: true,
);

final _upcoming = _game.copyWith(
  id: 'game-2',
  status: LiveGameStatus.published,
);

final _group = Group(
  id: 'group-1',
  name: 'Friday regulars',
  joinCode: 'FRIDAY',
  ownerId: _host.id,
  members: const [_host],
  games: [_game, _upcoming],
  chat: const [],
  polls: const [],
  notifications: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    RecoveryService.enabled = false;
    Formatters.currencySymbol = r'$';
  });
  tearDown(() {
    RecoveryService.enabled = true;
    Formatters.currencySymbol = '';
  });

  testWidgets(
    'Settings currency updates Home, group and payouts live for None and euro',
    (tester) async {
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group)
        ..setCurrentGameForTesting(_game);
      tester.view.physicalSize = const Size(800, 5000);
      tester.view.devicePixelRatio = 1;

      Future<void> show(Widget child) async {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: app,
            child: MaterialApp(home: Scaffold(body: child)),
          ),
        );
        await tester.pump();
      }

      await show(const SettingsScreen());
      await tester.tap(find.text('None'));
      await tester.pump();

      await show(const HomeScreen());
      expect(find.text('1,234'), findsWidgets);
      expect(find.textContaining(r'$'), findsNothing);
      await show(const GroupScreen());
      expect(find.text('Buy-in: 20'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      await show(const PayoutsScreen());
      expect(find.text('800'), findsWidgets);
      expect(find.textContaining(r'$'), findsNothing);

      await show(const SettingsScreen());
      await tester.tap(find.text('€'));
      await tester.pump();

      await show(const HomeScreen());
      expect(find.text('€1,234'), findsWidgets);
      await show(const GroupScreen());
      expect(find.text('Buy-in: €20'), findsOneWidget);
      await show(const PayoutsScreen());
      expect(find.text('€800'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      tester.view.reset();
    },
  );
}
