import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/table_settings.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/group_settings_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:provider/provider.dart';

/// Spec B9 — group settings.
///
/// These tests cover what the *screen* decides: the host gate, which rows the
/// spec puts on it, that table settings only reach the group when the host
/// presses Save, and that a destructive row asks first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The recovery store writes into the real project directory and is shared
  // between AppProviders; leaving it on lets one test's save fail the next
  // with a file-lock error that has nothing to do with settings.
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

  /// A host who is NOT the owner: `isAdmin` without matching `ownerId`. The
  /// provider's own rules for table settings, member removal and leaving are
  /// all owner-only, so the screen has to read ownership rather than trust
  /// `isAdmin` alone.
  const coHost = AppUser(
    id: 'u3',
    name: 'Hugo Bekele',
    email: 'hugo@poker.night',
    isAdmin: true,
    stats: UserStats(
      played: 9,
      wins: 1,
      podium: 2,
      avgFinish: 5.0,
      knockouts: 1,
    ),
  );

  Group groupWith({
    List<AppUser> members = const [host],
    TableSettings tableSettings = TableSettings.fallback,
  }) =>
      Group(
        id: 'g1',
        name: 'Friday Poker Club',
        joinCode: 'FP2608',
        ownerId: 'u1',
        members: members,
        games: const [],
        chat: const [],
        polls: const [],
        notifications: const [],
        tableSettings: tableSettings,
      );

  AppProvider provider({
    AppUser user = host,
    List<AppUser> members = const [host],
    TableSettings tableSettings = TableSettings.fallback,
  }) =>
      AppProvider()
        ..setUserForTesting(user)
        ..setCurrentGroupForTesting(
          groupWith(members: members, tableSettings: tableSettings),
        );

  /// Pumps the screen, runs [body], then always unmounts and disposes.
  ///
  /// The cleanup is not optional bookkeeping: AppProvider starts a periodic
  /// ticker in its constructor, and the framework checks for pending timers
  /// after the test body but *before* any tearDown, so a provider left
  /// running fails with "A Timer is still pending" — an error that says
  /// nothing about the screen. `try/finally` keeps that from masking a real
  /// assertion failure.
  Future<void> screen(
    WidgetTester tester,
    AppProvider app,
    Future<void> Function() body,
  ) async {
    final router = GoRouter(
      initialLocation: '/group-settings',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/group-settings',
          builder: (_, _) => const GroupSettingsScreen(),
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

  /// Scrolls [label] into view and taps it.
  ///
  /// The default test surface is 800x600 and this screen is a long column, so
  /// a bare tap lands on whatever happens to be under the pointer.
  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  /// Taps the count stepper's arrow. Found by glyph rather than by the
  /// tooltip text, which only exists inside an overlay on hover.
  Future<void> tapStepper(WidgetTester tester, IconData arrow) async {
    final arrowFinder = find.byIcon(arrow);
    await tester.ensureVisible(arrowFinder);
    await tester.pumpAndSettle();
    await tester.tap(arrowFinder);
    await tester.pumpAndSettle();
  }

  group('gating', () {
    testWidgets('a non-host gets the lock screen, not the rows', (tester) async {
      // The router already bounces non-hosts, but the screen is reachable by
      // deep link and by a stale back stack, so it guards itself the way
      // ImportResultsScreen does.
      final app = provider(user: member, members: [host, member]);

      await screen(tester, app, () async {
        expect(find.textContaining('Only the host'), findsOneWidget);
        expect(find.text('Leave group'), findsNothing);
        expect(find.text('Save table settings'), findsNothing);
        expect(find.text('FP2608'), findsNothing);
      });
    });
  });

  group('rows', () {
    testWidgets('the host sees the rows the spec lists', (tester) async {
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        for (final label in const [
          'Default chip set',
          'Standings and seasons',
          'History',
          'Members and roles',
          'Import past results',
          'Table settings',
          'Group code',
        ]) {
          await tester.ensureVisible(find.text(label).first);
          expect(
            find.text(label),
            findsOneWidget,
            reason: '§B9 lists "$label" as a row',
          );
        }
        // The members row quotes the roster, so the count is readable without
        // opening Members.
        expect(find.textContaining('2 members'), findsOneWidget);
      });
    });

    testWidgets('the Reports row only appears when there is one', (tester) async {
      // §B9: "the row appears when there is one". A Reports card parked on
      // every host's settings screen would be a standing alarm for a group
      // with nothing reported.
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        expect(app.reportCount, 0);
        expect(find.text('Reports'), findsNothing);
      });
    });

    testWidgets('the principle sits behind Why?', (tester) async {
      final app = provider();

      await screen(tester, app, () async {
        expect(find.textContaining('belong to the group'), findsNothing);

        await tap(tester, 'Why?');

        // The quote is the spec's Principle for this screen, in full.
        expect(
          find.textContaining('belong to the group, not to one game'),
          findsOneWidget,
        );
        expect(find.text('Why?'), findsNothing);
        expect(find.text('Hide'), findsOneWidget);
      });
    });
  });

  group('table settings', () {
    testWidgets('nothing reaches the group before Save', (tester) async {
      final app = provider();

      await screen(tester, app, () async {
        // The stepper starts at the stored 9 and the range is 4..10, so one
        // tap down is 8.
        await tapStepper(tester, Icons.remove);
        expect(find.text('8 seats'), findsOneWidget);
        // Still the stored value: the stepper edits a draft.
        expect(app.currentGroup.tableSettings.maxPerTable, 9);

        await tap(tester, 'Save table settings');
        expect(app.currentGroup.tableSettings.maxPerTable, 8);
        // Dirty state is gone, so the button reports itself as saved.
        expect(find.text('Saved'), findsOneWidget);
      });
    });

    testWidgets('a co-host sees the values read-only', (tester) async {
      // `updateGroupTableSettings` returns immediately for anyone who is not
      // the owner, so a co-host is told rather than left pressing a control
      // that does nothing.
      final app = provider(
        user: coHost,
        members: [host, coHost],
        tableSettings: const TableSettings(
          maxPerTable: 6,
          randomizeByDefault: true,
        ),
      );

      await screen(tester, app, () async {
        expect(
          find.textContaining('Only the group owner can change'),
          findsOneWidget,
        );
        expect(find.text('Save table settings'), findsNothing);
        expect(find.text('6 seats'), findsOneWidget);
      });
    });
  });

  group('leaving', () {
    testWidgets('Leave group asks before it calls the provider',
        (tester) async {
      // A co-host is the one person who can both open this screen and use
      // `leaveGroup` — the owner is refused by the provider.
      final app = provider(user: coHost, members: [host, coHost]);

      await screen(tester, app, () async {
        await tap(tester, 'Leave group');

        // The dialog states the consequence rather than asking a bare
        // "are you sure?" — the only way back in is the code.
        expect(
          find.textContaining('sending you the join code again'),
          findsOneWidget,
        );
        // Cancelling must not have touched the provider.
        expect(app.currentGroup.id, 'g1');

        await tap(tester, 'Cancel');
        expect(
          find.textContaining('sending you the join code again'),
          findsNothing,
        );
        expect(app.currentGroup.id, 'g1');

        // Confirming is what actually leaves.
        await tap(tester, 'Leave group');
        await tester.tap(find.widgetWithText(TextButton, 'Leave group'));
        await tester.pumpAndSettle();
        expect(app.currentGroup.id, isNot('g1'));
      });
    });

    testWidgets('an owner cannot leave, and Delete group says why',
        (tester) async {
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        expect(find.text('Delete group'), findsOneWidget);
        expect(find.text('Leave group'), findsNothing);
        // There is no provider method behind a group delete, so the row ships
        // inert with the reason on screen instead of a dialog over a write
        // nobody has written.
        expect(find.textContaining('not wired up'), findsOneWidget);
      });
    });
  });

  group('group code', () {
    testWidgets('the code is shown and the re-roll is inert', (tester) async {
      final app = provider();

      await screen(tester, app, () async {
        expect(find.text('FP2608'), findsOneWidget);
        expect(find.text('Re-roll the code'), findsOneWidget);
        // Both unwired actions say so on screen, not only in a code review.
        expect(find.textContaining('Not available yet'), findsNWidgets(2));
      });
    });
  });
}
