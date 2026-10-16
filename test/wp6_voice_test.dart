import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/voice_service.dart';
import 'package:poker_night/widgets/tournament_timer_card.dart';
import 'package:provider/provider.dart';

const _host = AppUser(
  id: 'u1',
  name: 'Alex Morgan',
  email: 'alex@poker.night',
  isAdmin: true,
  stats: UserStats(played: 3, wins: 1, podium: 1, avgFinish: 2, knockouts: 4),
);

const _group = Group(
  id: 'g1',
  name: 'Friday Poker Club',
  joinCode: 'FP2608',
  ownerId: 'u1',
  members: [_host],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

const _settings = GameSettings(
  name: 'Friday',
  date: '2026-10-16',
  time: '20:00',
  location: 'Home',
  players: 8,
  durationHours: 3,
  buyIn: 20,
  koEnabled: false,
  koAmount: 0,
  rebuys: false,
  rebuysCloseLevel: 6,
  addOn: false,
  anteEnabled: true,
  anteAfterLevel: 2,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
);

const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 5000,
  rebuyChipPlan: [],
  addOnStack: 5000,
  addOnChipPlan: [],
  levels: [
    BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15),
    BlindLevel(level: 2, sb: 50, bb: 100, ante: 25, durationMins: 20),
  ],
  levelDuration: 15,
  expectedFinishMins: 35,
  prizes: [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

LiveGame _game({
  int level = 1,
  String editorDeviceId = '',
  bool running = false,
}) => LiveGame(
  id: 'game-1',
  groupId: 'g1',
  settings: _settings,
  structure: _structure,
  status: LiveGameStatus.running,
  publicCode: 'ABC123',
  tvCode: 'TV123',
  currentLevel: level,
  timerRunning: running,
  secondsRemaining: 900,
  editorDeviceId: editorDeviceId,
  players: const [],
  chat: const [],
  announcements: const [],
  pendingGuests: const [],
  finishOrder: const [],
  totalChipsInPlay: 40000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  group('canonical voice copy', () {
    test('level change includes named blinds, optional ante and duration', () {
      expect(
        VoiceService.levelChangeMessage(
          level: 2,
          sb: 25,
          bb: 50,
          durationMins: 15,
        ),
        'Level two. Small blind twenty five, big blind fifty. '
        'Duration fifteen minutes.',
      );
      expect(
        VoiceService.levelChangeMessage(
          level: 3,
          sb: 50,
          bb: 100,
          ante: 25,
          durationMins: 20,
        ),
        'Level three. Small blind fifty, big blind one hundred, ante twenty five. '
        'Duration twenty minutes.',
      );
    });

    test('one-minute warning names the next level and optional ante', () {
      expect(
        VoiceService.oneMinuteMessage(nextSb: 50, nextBb: 100),
        'One minute left. Next level: small blind fifty, big blind one hundred.',
      );
      expect(
        VoiceService.oneMinuteMessage(nextSb: 50, nextBb: 100, nextAnte: 25),
        'One minute left. Next level: small blind fifty, big blind one hundred, '
        'ante twenty five.',
      );
    });

    test('canonical clock voice copy is always currency-free', () {
      final text = [
        VoiceService.levelChangeMessage(
          level: 2,
          sb: 25,
          bb: 50,
          ante: 5,
          durationMins: 15,
        ),
        VoiceService.oneMinuteMessage(nextSb: 50, nextBb: 100, nextAnte: 25),
      ].join(' ');
      expect(text, isNot(contains(RegExp(r'[$£€]'))));
    });
  });

  testWidgets('the level live region uses the canonical voice copy', (
    tester,
  ) async {
    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group)
      ..setCurrentGameForTesting(_game(level: 2));
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: TournamentTimerCard(
              game: app.currentGame!,
              showSubStats: false,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Level two. Small blind fifty, big blind one hundred, ante twenty five. '
        'Duration twenty minutes.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  test('the real level transition stores the canonical spoken line', () {
    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group);
    app.setCurrentGame(_game(editorDeviceId: app.thisDeviceId, running: true));

    app.nextLevel(idempotencyKey: 'wp6-level-change');

    expect(app.currentGame!.currentLevel, 2);
    expect(
      app.currentGame!.announcements.last.text,
      'Level two. Small blind fifty, big blind one hundred, ante twenty five. '
      'Duration twenty minutes.',
    );
    app.dispose();
  });
}
