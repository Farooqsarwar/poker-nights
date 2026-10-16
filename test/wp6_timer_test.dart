import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/app_timer.dart';
import 'package:poker_night/widgets/tournament_display_block.dart';
import 'package:poker_night/widgets/tournament_timer_card.dart';
import 'package:provider/provider.dart';

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

LiveGame _game({int level = 1, int remaining = 900}) => LiveGame(
  id: 'game-1',
  groupId: 'g1',
  settings: _settings,
  structure: _structure,
  status: LiveGameStatus.running,
  publicCode: 'ABC123',
  tvCode: 'TV123',
  currentLevel: level,
  timerRunning: false,
  secondsRemaining: remaining,
  players: const [],
  chat: const [],
  announcements: const [],
  pendingGuests: const [],
  finishOrder: const [],
  totalChipsInPlay: 40000,
);

Widget _timer(int seconds, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: AnimatedTimerDigits(
        secondsRemaining: seconds,
        size: 80,
        minutesColor: Colors.white,
        secondsColor: Colors.red,
      ),
    ),
  ),
);

double _scale(WidgetTester tester, String pulseKey) => tester
    .widget<Transform>(find.byKey(ValueKey('$pulseKey-scale')))
    .transform
    .getMaxScaleOnAxis();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  testWidgets(
    'timer keeps digit positions stable and animates changed digits',
    (tester) async {
      await tester.pumpWidget(_timer(610)); // 10:10
      final firstPosition = tester.element(
        find.byKey(const ValueKey('timer-position-0')),
      );

      await tester.pumpWidget(_timer(609)); // 10:09
      await tester.pump();

      expect(
        tester.element(find.byKey(const ValueKey('timer-position-0'))),
        same(firstPosition),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('timer-position-0')),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('timer-position-3')),
          matching: find.byType(Text),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('timer-position-4')),
          matching: find.byType(Text),
        ),
        findsNWidgets(2),
      );
    },
  );

  testWidgets('only warning thresholds pulse the clock seconds', (
    tester,
  ) async {
    await tester.pumpWidget(_timer(302));
    await tester.pumpWidget(_timer(301));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_scale(tester, 'clock-seconds-pulse'), 1);

    await tester.pumpWidget(_timer(300));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_scale(tester, 'clock-seconds-pulse'), greaterThan(1));

    await tester.pumpAndSettle();
    expect(_scale(tester, 'clock-seconds-pulse'), 1);

    await tester.pumpWidget(_timer(61));
    await tester.pumpWidget(_timer(60));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_scale(tester, 'clock-seconds-pulse'), greaterThan(1));
  });

  testWidgets('level change pulses level and blinds for 600 ms only', (
    tester,
  ) async {
    Widget frame(int level) => MaterialApp(
      home: Row(
        children: [
          LevelEventPulse(
            level: level,
            pulseKey: 'level-label-pulse',
            child: const Text('Level'),
          ),
          LevelEventPulse(
            level: level,
            pulseKey: 'blinds-pulse',
            child: const Text('Blinds'),
          ),
        ],
      ),
    );

    await tester.pumpWidget(frame(1));
    await tester.pumpWidget(frame(2));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_scale(tester, 'level-label-pulse'), greaterThan(1));
    expect(_scale(tester, 'blinds-pulse'), greaterThan(1));

    await tester.pump(const Duration(milliseconds: 525));
    expect(_scale(tester, 'level-label-pulse'), closeTo(1, 0.001));
    expect(_scale(tester, 'blinds-pulse'), closeTo(1, 0.001));
  });

  testWidgets('reduced motion uses a three-second red outline', (tester) async {
    Widget frame(int level) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: LevelEventPulse(
          level: level,
          pulseKey: 'level-label-pulse',
          child: const Text('Level'),
        ),
      ),
    );

    await tester.pumpWidget(frame(1));
    await tester.pumpWidget(frame(2));
    await tester.pump();

    final active = tester.widget<Container>(
      find.byKey(const ValueKey('level-label-pulse-outline')),
    );
    expect((active.decoration! as BoxDecoration).border, isNotNull);
    expect(_scale(tester, 'level-label-pulse'), 1);

    await tester.pump(const Duration(seconds: 3));
    final ended = tester.widget<Container>(
      find.byKey(const ValueKey('level-label-pulse-outline')),
    );
    expect((ended.decoration! as BoxDecoration).border, isNull);
  });

  testWidgets('dashboard and TV use the shared per-digit timer', (
    tester,
  ) async {
    final app = AppProvider();
    addTearDown(app.dispose);

    Future<void> pump(Widget child, Size size) => tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: SizedBox.fromSize(size: size, child: child),
          ),
        ),
      ),
    );

    await pump(TournamentTimerCard(game: _game()), const Size(390, 844));
    expect(find.byType(AnimatedTimerDigits), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);

    await pump(TournamentDisplayBlock(game: _game()), const Size(1280, 800));
    expect(find.byType(AnimatedTimerDigits), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);
  });
}
