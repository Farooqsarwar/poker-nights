import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/members_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:provider/provider.dart';

/// Removing a group member from the Members screen.
///
/// Regression test: the "Remove from Group" entry used to be a value-less
/// [PopupMenuItem] handled in `onTap` with the menu's own (itemBuilder)
/// context. Tapping it dismissed the menu route first, so `showDialog` ran
/// with a deactivated context and the confirm dialog never appeared — the
/// remove button did nothing. The entry now rides through `onSelected` with
/// a sentinel value and the screen's context.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  const host = AppUser(
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

  const member = AppUser(
    id: 'u2',
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

  AppProvider provider() => AppProvider()
    ..setUserForTesting(host)
    ..setCurrentGroupForTesting(
      const Group(
        id: 'g1',
        name: 'Friday Poker Club',
        joinCode: 'FP2608',
        ownerId: 'u1',
        members: [host, member],
        games: [],
        chat: [],
        polls: [],
        notifications: [],
      ),
    );

  Future<void> screen(
    WidgetTester tester,
    AppProvider app,
    Future<void> Function() body,
  ) async {
    final router = GoRouter(
      initialLocation: '/members',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/members',
          builder: (_, _) => const MembersScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    try {
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await tester.pump();
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  group('remove member', () {
    testWidgets('owner opens the menu, confirms, and the member is gone',
        (tester) async {
      final app = provider();

      await screen(tester, app, () async {
        expect(find.text('Nina Kowalski'), findsOneWidget);

        // Open the member card's options menu (only the owner sees it).
        await tap(tester, find.byTooltip('Member options'));
        expect(find.text('Remove from Group'), findsOneWidget);

        // The confirm dialog appears (this is what used to never happen).
        await tap(tester, find.text('Remove from Group'));
        expect(find.text('Remove Member'), findsOneWidget);

        // Cancel keeps the member.
        await tap(tester, find.text('Cancel'));
        expect(
          app.currentGroup.members.map((m) => m.id),
          contains('u2'),
        );

        // Confirm removes the member locally and from the list.
        await tap(tester, find.byTooltip('Member options'));
        await tap(tester, find.text('Remove from Group'));
        await tap(
          tester,
          find.widgetWithText(TextButton, 'Remove'),
        );
        expect(
          app.currentGroup.members.map((m) => m.id),
          isNot(contains('u2')),
        );
        expect(find.text('Nina Kowalski'), findsNothing);
      });
    });

    testWidgets('a non-owner sees no remove option', (tester) async {
      final app = AppProvider()
        ..setUserForTesting(member)
        ..setCurrentGroupForTesting(
          const Group(
            id: 'g1',
            name: 'Friday Poker Club',
            joinCode: 'FP2608',
            ownerId: 'u1',
            members: [host, member],
            games: [],
            chat: [],
            polls: [],
            notifications: [],
          ),
        );

      await screen(tester, app, () async {
        expect(find.byTooltip('Member options'), findsNothing);
      });
    });
  });
}
