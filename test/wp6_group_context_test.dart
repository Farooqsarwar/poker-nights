import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/group_switcher.dart';
import 'package:poker_night/widgets/screen_shell.dart';
import 'package:provider/provider.dart';

const _host = AppUser(
  id: 'u1',
  name: 'Alex Morgan',
  email: 'alex@poker.night',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

Group _group(String id, String name) => Group(
  id: id,
  name: name,
  joinCode: id == 'g1' ? 'FIRST1' : 'SECOND',
  ownerId: _host.id,
  members: const [_host],
  games: const [],
  chat: const [],
  polls: const [],
  notifications: const [],
);

Future<(AppProvider, GoRouter)> _mount(
  WidgetTester tester, {
  required String path,
  required double width,
  String groupName = 'Friday Poker Club',
}) async {
  final groups = [_group('g1', groupName), _group('g2', 'Sunday Cards')];
  final app = AppProvider()
    ..setUserForTesting(_host)
    ..setGroupsForTesting(groups, currentGroupId: 'g1');
  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: path,
        builder: (_, _) => ScreenShell(
          requiredPath: path,
          child: const ColoredBox(color: Colors.transparent),
        ),
      ),
      if (path != RoutePaths.group)
        GoRoute(
          path: RoutePaths.group,
          builder: (_, _) => const ScreenShell(
            requiredPath: RoutePaths.group,
            child: ColoredBox(color: Colors.transparent),
          ),
        ),
    ],
  );

  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  return (app, router);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  testWidgets('custom and standard group routes share the current-group chip', (
    tester,
  ) async {
    var mounted = await _mount(tester, path: RoutePaths.group, width: 390);
    expect(find.byType(CurrentGroupChip), findsOneWidget);
    expect(find.text('Friday Poker Club'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    mounted.$1.dispose();
    mounted.$2.dispose();

    mounted = await _mount(tester, path: RoutePaths.hostDashboard, width: 390);
    expect(find.byType(CurrentGroupChip), findsOneWidget);
    expect(find.text('Friday Poker Club'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    mounted.$1.dispose();
    mounted.$2.dispose();
  });

  testWidgets('desktop chrome shows the same switcher', (tester) async {
    final mounted = await _mount(tester, path: RoutePaths.members, width: 1280);
    expect(find.byType(CurrentGroupChip), findsOneWidget);
    expect(find.text('Friday Poker Club'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    mounted.$1.dispose();
    mounted.$2.dispose();
  });

  testWidgets('long names fit at 320 px and keep a 44 px switch target', (
    tester,
  ) async {
    final mounted = await _mount(
      tester,
      path: RoutePaths.group,
      width: 320,
      groupName:
          'The Extremely Long Thursday Night Neighbourhood Poker Association',
    );

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(CurrentGroupChip));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, lessThanOrEqualTo(320));
    expect(
      tester.getSemantics(find.byType(CurrentGroupChip)).label,
      contains('Switch group'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    mounted.$1.dispose();
    mounted.$2.dispose();
  });

  testWidgets('chip reuses the switch sheet and changes the selected group', (
    tester,
  ) async {
    final mounted = await _mount(tester, path: RoutePaths.group, width: 390);

    await tester.tap(find.byType(CurrentGroupChip));
    await tester.pumpAndSettle();
    expect(find.text('Switch group'), findsOneWidget);

    await tester.tap(find.text('Sunday Cards'));
    await tester.pumpAndSettle();
    expect(mounted.$1.currentGroupId, 'g2');
    expect(find.text('Switch group'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    mounted.$1.dispose();
    mounted.$2.dispose();
  });

  testWidgets('account routes do not show group context', (tester) async {
    final mounted = await _mount(tester, path: RoutePaths.settings, width: 390);
    expect(find.byType(CurrentGroupChip), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    mounted.$1.dispose();
    mounted.$2.dispose();
  });
}
