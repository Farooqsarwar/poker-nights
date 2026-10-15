import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/create_tournament_screen.dart';
import 'package:poker_night/screens/tournament/invitation_screen.dart';
import 'package:poker_night/screens/tournament/structure_review_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/structure_builder_controller.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/count_stepper.dart';
import 'package:poker_night/widgets/structure_builder.dart';
import 'package:provider/provider.dart';

const _host = AppUser(
  id: 'host',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

Group _group({int members = 7}) => Group(
  id: 'group',
  name: 'Friday',
  joinCode: 'FRIDAY',
  ownerId: _host.id,
  members: [
    _host,
    for (var i = 1; i < members; i++)
      AppUser(
        id: 'p$i',
        name: 'Player $i',
        email: 'p$i@example.com',
        isAdmin: false,
        stats: const UserStats(
          played: 0,
          wins: 0,
          podium: 0,
          avgFinish: 0,
          knockouts: 0,
        ),
      ),
  ],
  games: const [],
  chat: const [],
  polls: const [],
  notifications: const [],
);

GameSettings _settings({List<ChipColor> chips = const []}) => GameSettings(
  name: 'Poker Night',
  date: '2026-10-20',
  time: '20:00',
  location: 'The den',
  players: 3,
  durationHours: 4,
  buyIn: 25,
  koEnabled: true,
  koAmount: 5,
  rebuys: false,
  reEntry: true,
  rebuysCloseLevel: 6,
  addOn: true,
  anteEnabled: true,
  anteAfterLevel: 6,
  organizerPct: 0,
      chipSet: chips,
  chipSetName: '',
  format: TournamentFormat.reEntry,
  pace: PaceMode.deep,
  targetDepthBB: TournamentType.deep.depthBB,
  earlyArrivalBonusEnabled: true,
  earlyArrivalBonusPctOverride: 0.10,
);

LiveGame _event(GameSettings settings) => LiveGame(
  id: 'game',
  groupId: 'group',
  settings: settings,
  structure: const TournamentStructure(
    startingStack: 0,
    chipPlan: [],
    rebuyStack: 0,
    rebuyChipPlan: [],
    addOnStack: 0,
    addOnChipPlan: [],
    levels: [],
    levelDuration: 20,
    expectedFinishMins: 0,
    prizes: [],
    prizePool: 0,
    organizerAmount: 0,
    colorUpInstructions: [],
    warnings: [],
  ),
  status: LiveGameStatus.published,
  publicCode: 'ABC123',
  tvCode: 'TV1234',
  currentLevel: 1,
  timerRunning: false,
  secondsRemaining: 1200,
  players: [
    for (var i = 0; i < 7; i++)
      Player(
        id: i == 0 ? 'host' : 'p$i',
        name: i == 0 ? 'Host' : 'Player $i',
        isGuest: false,
        rsvp: i < 2
            ? Rsvp.going
            : i == 2
            ? Rsvp.maybe
            : null,
        checkedIn: false,
        confirmed: false,
        eliminated: false,
        rebuys: 0,
        hasAddOn: false,
        knockouts: 0,
        table: 0,
        seat: 0,
        active: true,
      ),
  ],
  chat: const [],
  announcements: const [],
  totalChipsInPlay: 0,
  pendingGuests: const [],
  finishOrder: const [],
);

Future<void> _mount(WidgetTester tester, Widget screen, AppProvider app) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: screen),
      ),
      GoRoute(
        path: '/invitation',
        builder: (_, _) => const Scaffold(body: Text('INVITATION')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(800, 2400));
  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester, AppProvider app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  app.dispose();
  await tester.pump();
  await tester.binding.setSurfaceSize(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => RecoveryService.enabled = false);
  tearDown(() async {
    RecoveryService.enabled = true;
  });

  testWidgets('event post is one screen with exactly the light-event fields', (
    tester,
  ) async {
    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group());
    await _mount(
      tester,
      CreateTournamentScreen(initialSettings: _settings()),
      app,
    );

    for (final label in [
      'Buy-in',
      'Location',
      'Date',
      'Start time',
      'KO bounty',
      'Tournament type',
      'Rebuy type',
      'On-time bonus',
      'Post',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is required');
    }
    expect(find.byType(CountStepper), findsNWidgets(3));
    for (final removed in [
      'Event name',
      'Chip set',
      'Rebuy price',
      'Add-on',
      'Ante',
      'Pace',
      'Bounty type',
      'Review & create',
    ]) {
      expect(find.text(removed), findsNothing, reason: '$removed moved out');
    }
    expect(
      find.textContaining('final amount set in Create structure'),
      findsOneWidget,
    );
    await _unmount(tester, app);
  });

  testWidgets('posting does not require a chip set', (tester) async {
    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group());
    await _mount(
      tester,
      CreateTournamentScreen(initialSettings: _settings(chips: const [])),
      app,
    );

    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(find.text('INVITATION'), findsOneWidget);
    expect(app.currentGame, isNotNull);
    expect(app.currentGame!.settings.chipSet, isEmpty);
    expect(app.currentGame!.status, LiveGameStatus.published);
    await _unmount(tester, app);
  });

  testWidgets('each edit autosaves the event draft for this group', (
    tester,
  ) async {
    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group());
    await _mount(
      tester,
      CreateTournamentScreen(initialSettings: _settings()),
      app,
    );

    final buyIn = find.byKey(const Key('event-buy-in'));
    await tester.tap(
      find.descendant(of: buyIn, matching: find.byIcon(Icons.add)),
    );
    await tester.pump();

    expect(app.eventDraftForCurrentGroup?.buyIn, 30);
    await _unmount(tester, app);
  });

  testWidgets('the event page offers Create structure to the host only', (
    tester,
  ) async {
    final group = _group();
    final settings = _settings(
      chips: TournamentEngine.getPreset('Home Set (4 colour)'),
    );
    final game = _event(settings);
    final hostApp = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(group)
      ..setCurrentGame(game);
    await _mount(tester, const InvitationScreen(), hostApp);
    expect(find.text('Create structure'), findsOneWidget);
    await _unmount(tester, hostApp);

    final memberApp = AppProvider()
      ..setUserForTesting(group.members[1])
      ..setCurrentGroupForTesting(group)
      ..setCurrentGame(game);
    await _mount(tester, const InvitationScreen(), memberApp);
    expect(find.text('Create structure'), findsNothing);
    await _unmount(tester, memberApp);
  });

  testWidgets(
    'Create structure starts from all invitees and shows RSVP counts',
    (tester) async {
      final settings = _settings(
        chips: TournamentEngine.getPreset('Home Set (4 colour)'),
      );
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group())
        ..setCurrentGame(_event(settings));
      await _mount(tester, const StructureReviewScreen(), app);

      final builder = tester.widget<StructureBuilder>(
        find.byType(StructureBuilder),
      );
      expect(builder.controller.players, 7);
      expect(builder.controller.buyIn, 25);
      expect(builder.controller.type, TournamentType.deep);
      expect(builder.controller.format, TournamentFormat.reEntry);
      expect(builder.controller.bonusPct, 10);
      expect(find.text('7 invited · 2 Going · 1 Maybe'), findsOneWidget);
      await _unmount(tester, app);
    },
  );

  testWidgets('rebuy price defaults to buy-in and remains editable', (
    tester,
  ) async {
    final settings = _settings(
      chips: TournamentEngine.getPreset('Home Set (4 colour)'),
    ).copyWith(rebuys: true, reEntry: false, format: TournamentFormat.rebuy);
    final controller = StructureBuilderController.fromSettings(
      settings,
      players: 7,
      suggestRebuyLimit: true,
    );
    addTearDown(controller.dispose);
    expect(controller.options.rebuyCost, 25);

    await tester.binding.setSurfaceSize(const Size(800, 2400));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StructureBuilder(
              controller: controller,
              confirmLabel: 'Save',
              onConfirm: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('more-options')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('opt-rebuy-price')), '30');
    await tester.pump();

    expect(controller.options.rebuyCost, 30);
    expect(controller.applyTo(settings).rebuyCost, 30);
  });
}
