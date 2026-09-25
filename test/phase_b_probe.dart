import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/app/theme.dart';
import 'package:poker_night/models/app_notification.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/chat_screen.dart';
import 'package:poker_night/screens/shell/group_screen.dart';
import 'package:poker_night/screens/shell/history_screen.dart';
import 'package:poker_night/screens/shell/home_screen.dart';
import 'package:poker_night/screens/shell/members_screen.dart';
import 'package:poker_night/screens/shell/notifications_screen.dart';
import 'package:poker_night/screens/shell/polls_screen.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/utils/mock_data.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/screen_shell.dart';
import 'package:provider/provider.dart';

import 'design_probe.dart' as design show loadRealFonts;

/// Phase B (group hub) camera: renders each hub screen inside the real
/// [ScreenShell] — so the bottom nav is in frame — against a seeded,
/// signed-in group, so the screens show content rather than empty states.
///
///   flutter test test/phase_b_probe.dart --update-goldens
///
/// Not a `*_test.dart`: a camera, not an assertion (see design_probe.dart).
void main() {
  setUpAll(design.loadRealFonts);
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterError.onError = (_) {};
  });
  tearDown(() => FlutterError.onError = FlutterError.presentError);

  final now = DateTime(2026, 9, 25, 18);
  const stats = UserStats(
    played: 34,
    wins: 6,
    podium: 11,
    avgFinish: 3.2,
    knockouts: 18,
  );
  const me = AppUser(
    id: 'u1',
    name: 'Alex Morgan',
    email: 'alex@poker.night',
    isAdmin: true,
    stats: stats,
  );
  const members = [
    me,
    AppUser(
      id: 'u2',
      name: 'Marcus L.',
      email: 'marcus@poker.night',
      isAdmin: false,
      isCoAdmin: true,
      stats: stats,
    ),
    AppUser(id: 'u3', name: 'Ava R.', email: 'ava@poker.night', isAdmin: false, stats: stats),
    AppUser(id: 'u4', name: 'Devi K.', email: 'devi@poker.night', isAdmin: false, stats: stats),
    AppUser(id: 'u5', name: 'Jordan P.', email: 'jordan@poker.night', isAdmin: false, stats: stats),
  ];

  GameSettings settings(String name) => GameSettings(
    name: name,
    date: 'Fri, Mar 14',
    time: '8:00 PM',
    location: "Marcus's place",
    durationHours: 4,
    players: 18,
    buyIn: 100,
    chipSet: MockData.defaultChipSet,
    chipSetName: 'Home set',
    koEnabled: false,
    koAmount: 0,
    rebuys: false,
    rebuysCloseLevel: 6,
    addOn: false,
    addOnCloseLevel: 8,
    anteEnabled: true,
    anteAfterLevel: 4,
    organizerPct: 0,
    breaks: const [],
  );

  LiveGame game(String id, String name, LiveGameStatus status) {
    final s = settings(name);
    return LiveGame(
      id: id,
      groupId: 'g1',
      settings: s,
      structure: TournamentEngine.generate(
        TournamentParams(
          players: s.players,
          durationHours: s.durationHours,
          buyIn: s.buyIn,
          chipSet: s.chipSet,
          rebuys: false,
          rebuysCloseLevel: 6,
          addOn: false,
          anteEnabled: true,
          anteAfterLevel: 4,
          koEnabled: false,
          koAmount: 0,
          organizerPct: 0,
        ),
      ),
      status: status,
      publicCode: 'FP2608',
      tvCode: 'TV4821',
      currentLevel: 4,
      timerRunning: false,
      secondsRemaining: 872,
      players: const [],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 0,
      pendingGuests: const [],
      finishOrder: const [],
    );
  }

  final group = Group(
    id: 'g1',
    name: 'Friday Poker Club',
    joinCode: 'FP2608',
    ownerId: 'u1',
    members: members,
    games: [
      game('live1', 'Friday Night Freezeout', LiveGameStatus.running),
      game('up1', 'Sunday Deepstack', LiveGameStatus.published),
      game('done1', 'Freezeout #33', LiveGameStatus.completed),
    ],
    chat: [
      ChatMessage(
        id: 'c1',
        authorId: 'u2',
        authorName: 'Marcus L.',
        body: "Who's in for Friday? Thinking a \$50 freezeout.",
        timestamp: now.subtract(const Duration(minutes: 40)),
        deleted: false,
      ),
      ChatMessage(
        id: 'c2',
        authorId: 'u3',
        authorName: 'Ava R.',
        body: "I'll bring the good chips",
        timestamp: now.subtract(const Duration(minutes: 30)),
        deleted: false,
      ),
      ChatMessage(
        id: 'c3',
        authorId: 'u1',
        authorName: 'Alex Morgan',
        body: 'In. Setting it up now.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        deleted: false,
      ),
    ],
    polls: [
      Poll(
        id: 'p1',
        question: 'What night works best?',
        options: const ['Friday', 'Saturday', 'Sunday'],
        votes: const {
          'u1': ['Friday'],
          'u2': ['Friday'],
          'u3': ['Saturday'],
          'u4': ['Sunday'],
        },
        closed: false,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Poll(
        id: 'p2',
        question: 'Rebuys: yes or no?',
        options: const ['Yes, 1 rebuy', 'No rebuys'],
        votes: const {
          'u1': ['Yes, 1 rebuy'],
          'u2': ['Yes, 1 rebuy'],
          'u3': ['No rebuys'],
        },
        closed: true,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ],
    notifications: [
      AppNotification(
        id: 'n1',
        title: 'Freezeout starts in 30 min',
        body: 'Check in now to keep your seat',
        type: NotificationType.game,
        link: null,
        read: false,
        timestamp: now.subtract(const Duration(minutes: 12)),
      ),
      AppNotification(
        id: 'n2',
        title: 'Devi K. joined the group',
        body: 'Say hi',
        type: NotificationType.invite,
        link: null,
        read: false,
        timestamp: now.subtract(const Duration(hours: 1)),
      ),
      AppNotification(
        id: 'n3',
        title: 'You finished 2nd',
        body: 'Freezeout #33',
        type: NotificationType.result,
        link: null,
        read: true,
        timestamp: now.subtract(const Duration(days: 2)),
      ),
    ],
  );

  final screens = <String, (String, Widget)>{
    'b1_home': (RoutePaths.home, const HomeScreen()),
    'b2_group': (RoutePaths.group, const GroupScreen()),
    'b3_members': (RoutePaths.members, const MembersScreen()),
    'b4_chat': (RoutePaths.chat, const ChatScreen()),
    'b5_polls': (RoutePaths.polls, const PollsScreen()),
    'b6_notifications': (RoutePaths.notifications, const NotificationsScreen()),
    'b7_history': (RoutePaths.history, const HistoryScreen()),
  };

  Future<void> shoot(
    WidgetTester t,
    String name,
    String path,
    Widget screen,
    Size size,
  ) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final app = AppProvider()
      ..setUserForTesting(me)
      ..setCurrentGroupForTesting(group);
    // The inbox is its own list, not the group's; oldest first so the newest
    // ends up on top, as pushNotification prepends.
    for (final n in group.notifications.reversed) {
      app.pushNotification(n);
    }
    final router = GoRouter(
      initialLocation: path,
      routes: [
        for (final e in screens.values)
          GoRoute(
            path: e.$1,
            builder: (_, _) => ScreenShell(requiredPath: e.$1, child: e.$2),
          ),
      ],
      errorBuilder: (_, _) => const Scaffold(body: SizedBox.shrink()),
    );
    await t.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.forPalette(ThemePalettes.forId('red')),
          routerConfig: router,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 700));
    while (t.takeException() != null) {}
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/phase_b/$name.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await t.pump();
    while (t.takeException() != null) {}
  }

  for (final e in screens.entries) {
    testWidgets('${e.key} phone', (t) async {
      await shoot(t, '${e.key}_phone', e.value.$1, e.value.$2, const Size(390, 844));
    });
    testWidgets('${e.key} desktop', (t) async {
      await shoot(t, '${e.key}_desktop', e.value.$1, e.value.$2, const Size(1280, 860));
    });
  }
}
