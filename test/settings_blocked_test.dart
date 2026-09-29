// §E10 (3) / §B4 — "until unblocked in Settings → Blocked".
//
// The block itself is a pure provider concern and is covered by
// `chat_block_test.dart`. What this file pins is the thing that was missing:
// the account-wide undo path, and the fact that using it actually restores
// the conversation. A "Settings → Blocked" screen that listed people but did
// not put their messages back would satisfy a screenshot review and still be
// the bug, so the assertion is on `visibleChat`, not on the label.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/settings_screen.dart';
import 'package:poker_night/services/recovery_service.dart';

AppUser _member(String id, String name, {bool admin = false}) => AppUser(
      id: id,
      name: name,
      email: '$id@example.com',
      isAdmin: admin,
      stats: const UserStats(
        played: 0,
        wins: 0,
        podium: 0,
        avgFinish: 0,
        knockouts: 0,
      ),
    );

void main() {
  // AppProvider's constructor subscribes to a connectivity EventChannel.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings → Blocked — §E10 (3) / §B4', () {
    late AppProvider app;
    late AppUser alice;
    late AppUser bob;
    late List<ChatMessage> messages;

    Future<void> mount(WidgetTester t) async {
      app = AppProvider();
      alice = _member('alice', 'Alice', admin: true);
      bob = _member('bob', 'Bob');
      messages = [
        ChatMessage(
          id: 'm1',
          authorId: 'alice',
          authorName: 'Alice',
          body: 'dealer ready',
          timestamp: DateTime(2025, 1, 1, 12, 0),
          deleted: false,
        ),
        ChatMessage(
          id: 'm2',
          authorId: 'bob',
          authorName: 'Bob',
          body: 'buy my chips',
          timestamp: DateTime(2025, 1, 1, 12, 1),
          deleted: false,
        ),
      ];
      app.setUserForTesting(alice);
      app.setCurrentGroupForTesting(
        Group(
          id: 'g1',
          name: 'Test Group',
          joinCode: 'JOIN1',
          ownerId: 'alice',
          members: [alice, bob],
          games: const [],
          chat: messages,
          polls: const [],
          notifications: const [],
        ),
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              backgroundColor: Colors.transparent,
              body: SettingsScreen(),
            ),
          ),
        ],
      );
      await t.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
    }

    /// AppProvider runs a periodic live-clock ticker. Unmount and dispose
    /// inside the test body — a `tearDown` runs after the binding's pending
    /// timer check, so it would fail every test with "A Timer is still
    /// pending" no matter what it did.
    Future<void> unmount(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await t.pump();
    }

    setUp(() {
      // Same reason as `chat_block_test.dart`: the recovery store writes one
      // `recovery/active_game` document per process and collides between
      // tests. Nothing here is about recovery.
      RecoveryService.enabled = false;
    });

    tearDown(() => RecoveryService.enabled = true);

    testWidgets('a blocked member is listed, and unblocking restores their message', (t) async {
      await mount(t);

      // The row is always present, empty or not: it is the only undo path for
      // a message the user can no longer see.
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('Manage who you have blocked'), findsOneWidget);

      expect(app.blockUser('bob'), isTrue);
      await t.pumpAndSettle();
      expect(
        app.visibleChat(messages).map((m) => m.id),
        ['m1'],
        reason: "Bob's message is hidden while the block stands",
      );

      // The count and the subtitle both change with the list.
      expect(find.text('1'), findsOneWidget);
      expect(
        find.text('Their messages and polls are hidden for you'),
        findsOneWidget,
      );

      await t.ensureVisible(find.text('Blocked'));
      await t.pumpAndSettle();
      await t.tap(find.text('Blocked'));
      await t.pumpAndSettle();

      expect(find.text('Blocked members'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      await t.tap(find.widgetWithText(TextButton, 'Unblock'));
      await t.pumpAndSettle();

      // The real assertion: the messages come back.
      expect(app.isBlocked('bob'), isFalse);
      expect(app.blockedUserIds, isEmpty);
      expect(
        app.visibleChat(messages).map((m) => m.id),
        ['m1', 'm2'],
        reason: 'unblocking from Settings restores the whole conversation',
      );

      // And the sheet falls back to its empty state in place, rather than
      // showing a row for somebody who is no longer blocked.
      expect(find.text('Nobody is blocked.'), findsOneWidget);
      expect(find.text('Unblock'), findsNothing);

      await unmount(t);
    });

    testWidgets('unblocking a member who left the group still falls back to their id', (t) async {
      await mount(t);

      // Blocked by id, so the row has to render even with nobody to name it.
      expect(app.blockUser('carol'), isTrue);
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Blocked'));
      await t.pumpAndSettle();
      await t.tap(find.text('Blocked'));
      await t.pumpAndSettle();

      expect(find.text('carol'), findsOneWidget);
      expect(app.isBlocked('carol'), isTrue);

      await unmount(t);
    });
  });
}
