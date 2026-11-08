import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/group_screen.dart';
import 'package:poker_night/services/recovery_service.dart';

Player _player(String id, String name, {bool isGuest = false}) => Player(
  id: id,
  name: name,
  isGuest: isGuest,
  checkedIn: true,
  confirmed: true,
  eliminated: false,
  rebuys: 0,
  hasAddOn: false,
  knockouts: 0,
  table: 1,
  seat: 1,
  active: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  const stats = UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0);

  const viewer = AppUser(
    id: 'viewer_uid',
    name: 'Viewer',
    email: 'viewer@test.com',
    isAdmin: false,
    stats: stats,
  );

  const member2 = AppUser(
    id: 'm2_uid',
    name: 'Member Two',
    email: 'm2@test.com',
    isAdmin: false,
    stats: stats,
  );

  const opponentOnly = AppUser(
    id: 'opp_uid',
    name: 'Opponent Only',
    email: 'opp@test.com',
    isAdmin: false,
    stats: stats,
  );

  final pastGameViewerPlayed = LiveGame(
    id: 'game_with_viewer',
    groupId: 'g1',
    settings: const GameSettings(
      name: 'Game With Viewer',
      date: '2026-11-01',
      time: '19:00',
      location: 'Home',
      players: 3,
      durationHours: 2,
      buyIn: 20,
      chipSet: [],
      chipSetName: 'Standard',
      koEnabled: false,
      koAmount: 0,
      rebuys: false,
      rebuysCloseLevel: 6,
      addOn: false,
      anteEnabled: false,
      anteAfterLevel: 1,
      organizerPct: 0,
    ),
    structure: const TournamentStructure(
      startingStack: 1000,
      chipPlan: [],
      rebuyStack: 1000,
      rebuyChipPlan: [],
      addOnStack: 1000,
      addOnChipPlan: [],
      levels: [],
      breaks: [],
      levelDuration: 15,
      expectedFinishMins: 60,
      prizes: [],
      prizePool: 0,
      organizerAmount: 0,
      colorUpInstructions: [],
      warnings: [],
    ),
    status: LiveGameStatus.completed,
    publicCode: 'C1',
    tvCode: 'TV1',
    currentLevel: 3,
    timerRunning: false,
    secondsRemaining: 0,
    players: [
      _player('viewer_uid', 'Viewer'),
      _player('m2_uid', 'Member Two'),
      _player('opp_uid', 'Opponent Only'),
    ],
    chat: const [],
    announcements: const [],
    totalChipsInPlay: 3000,
    pendingGuests: const [],
    finishOrder: const ['opp_uid', 'viewer_uid', 'm2_uid'],
  );

  final pastGameViewerDidNotPlay = LiveGame(
    id: 'game_without_viewer',
    groupId: 'g1',
    settings: const GameSettings(
      name: 'Game Without Viewer',
      date: '2026-11-02',
      time: '19:00',
      location: 'Home',
      players: 2,
      durationHours: 2,
      buyIn: 20,
      chipSet: [],
      chipSetName: 'Standard',
      koEnabled: false,
      koAmount: 0,
      rebuys: false,
      rebuysCloseLevel: 6,
      addOn: false,
      anteEnabled: false,
      anteAfterLevel: 1,
      organizerPct: 0,
    ),
    structure: const TournamentStructure(
      startingStack: 1000,
      chipPlan: [],
      rebuyStack: 1000,
      rebuyChipPlan: [],
      addOnStack: 1000,
      addOnChipPlan: [],
      levels: [],
      breaks: [],
      levelDuration: 15,
      expectedFinishMins: 60,
      prizes: [],
      prizePool: 0,
      organizerAmount: 0,
      colorUpInstructions: [],
      warnings: [],
    ),
    status: LiveGameStatus.completed,
    publicCode: 'C2',
    tvCode: 'TV2',
    currentLevel: 3,
    timerRunning: false,
    secondsRemaining: 0,
    players: [
      _player('stranger_1', 'Stranger One'),
      _player('stranger_2', 'Stranger Two'),
    ],
    chat: const [],
    announcements: const [],
    totalChipsInPlay: 2000,
    pendingGuests: const [],
    finishOrder: const ['stranger_1', 'stranger_2'],
  );

  final group1 = Group(
    id: 'g1',
    name: 'Friday Poker',
    joinCode: 'FP1234',
    ownerId: 'viewer_uid',
    members: const [viewer, member2],
    games: [pastGameViewerPlayed, pastGameViewerDidNotPlay],
    chat: const [],
    polls: const [],
    notifications: const [],
  );

  final group2 = Group(
    id: 'g2',
    name: 'Weekend Club',
    joinCode: 'WC5678',
    ownerId: 'viewer_uid',
    members: const [viewer, member2, opponentOnly],
    games: const [],
    chat: const [],
    polls: const [],
    notifications: const [],
  );

  testWidgets('Invite modal renders group picker with member count and filters opponents', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);

    final app = AppProvider()
      ..setUserForTesting(viewer)
      ..setGroupsForTesting([group1, group2])
      ..setCurrentGroupForTesting(group1);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: InviteModalContent(
              group: group1,
              link: 'https://poker-night-tools.web.app/join-group?code=${group1.joinCode}',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Group picker shows member count
    expect(find.text('Friday Poker (2 members)'), findsOneWidget);

    // 2. Opponents from games viewer played in appear
    expect(find.text('Opponent Only'), findsOneWidget);

    // 3. Strangers from games viewer did NOT play in are NOT displayed
    expect(find.text('Stranger One'), findsNothing);
    expect(find.text('Stranger Two'), findsNothing);

    // 4. In Group 1, Member Two is already a member -> Member badge
    expect(find.text('Member'), findsOneWidget);

    // 5. Opponent Only is NOT a member of Group 1 -> has Invite button
    expect(find.widgetWithText(ElevatedButton, 'Invite'), findsNothing);
    expect(find.text('Invite'), findsOneWidget);

    app.dispose();
    await tester.pumpAndSettle();
  });
}
