import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/chat_report.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/group_settings_screen.dart';
import 'package:poker_night/screens/shell/reports_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/app_badge.dart';
import 'package:poker_night/widgets/report_message.dart';
import 'package:provider/provider.dart';

/// Spec §E10 (2) — reporting a chat message carries a reason.
///
/// "Report (reason: offensive -> spam -> other)" is a closed list, and the
/// point of a closed list is that the host reads the same three words
/// whichever client filed it. So these tests pin three separate links in that
/// chain: the model folds a caller's string onto the list, a stored report
/// keeps decoding when the field is absent (every report filed before the field
/// existed), and both host surfaces actually show the reason — a report the
/// host cannot read the reason on is the gap this was meant to close.
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

  final club = Group(
    id: 'g1',
    name: 'Friday Poker Club',
    joinCode: 'FP2608',
    ownerId: 'u1',
    members: const [host, member],
    games: const [],
    chat: const [],
    polls: const [],
    notifications: const [],
  );

  final when = DateTime(2026, 3, 4, 21, 30);

  ChatReport reportWith({String? reason}) => ChatReport(
        id: 'm1_u2',
        messageId: 'm1',
        authorId: 'u3',
        authorName: 'Rory Vance',
        reporterId: 'u2',
        excerpt: 'that was a ridiculous call, honestly',
        createdAt: when,
        reason: reason,
      );

  AppProvider provider({
    List<ChatReport> reports = const [],
    AppUser user = host,
  }) =>
      AppProvider()
        ..setUserForTesting(user)
        ..setCurrentGroupForTesting(club)
        ..setReportsForTesting(reports);

  /// Pumps [child] at [initialLocation], runs [body], then always unmounts and
  /// disposes.
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
    Widget child,
    String initialLocation,
    Future<void> Function() body,
  ) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', builder: (_, _) => child),
        GoRoute(path: '/reports', builder: (_, _) => child),
        GoRoute(path: '/group-settings', builder: (_, _) => child),
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

  group('ChatReport.reason', () {
    test('the closed list is exactly the three §E10 (2) reasons', () {
      // Order matters: the spec writes them in this order, and 'Other' is the
      // catch-all that has to stay last for normalizeReason's fallback.
      expect(ChatReport.reasons, ['Offensive', 'Spam', 'Other']);
    });

    test('a stored reason survives the round trip', () {
      final original = reportWith(reason: 'Spam');
      final decoded =
          ChatReport.fromMap(original.id, original.toMap(), original.createdAt);
      expect(decoded.reason, 'Spam');
    });

    test('a report filed before the field existed still decodes', () {
      // No 'reason' key at all is what every stored report from before the
      // field was added looks like. It has to keep decoding rather than throw,
      // and the host card has to render without one.
      final legacy = ChatReport.fromMap('m1_u2', {
        'messageId': 'm1',
        'authorId': 'u3',
        'authorName': 'Rory Vance',
        'reporterId': 'u2',
        'excerpt': 'that was a ridiculous call, honestly',
      }, when);
      expect(legacy.reason, isNull);
      expect(legacy.authorName, 'Rory Vance');
    });

    test('a blank or non-textual reason means "no reason", not an error', () {
      expect(ChatReport.fromMap('x', {'reason': '   '}, when).reason, isNull);
      expect(ChatReport.fromMap('x', {'reason': 7}, when).reason, isNull);
    });

    test('toMap omits a null reason so a legacy write stays legacy-shaped', () {
      expect(reportWith().toMap().containsKey('reason'), isFalse);
      expect(reportWith(reason: 'Other').toMap()['reason'], 'Other');
    });

    test('an over-long stored reason is truncated, not rejected', () {
      final long = 'x' * (ChatReport.maxReasonLength + 40);
      final decoded = ChatReport.fromMap('x', {'reason': long}, when);
      expect(decoded.reason!.length, ChatReport.maxReasonLength);
    });

    test('normalizeReason folds case and refuses to widen the list', () {
      expect(ChatReport.normalizeReason('offensive'), 'Offensive');
      expect(ChatReport.normalizeReason('  SPAM  '), 'Spam');
      // An unrecognised string lands on the catch-all rather than putting a
      // host-supplied word in front of the host.
      expect(ChatReport.normalizeReason('because i said so'), 'Other');
      expect(ChatReport.normalizeReason(null), isNull);
      expect(ChatReport.normalizeReason('  '), isNull);
    });
  });

  group('the report dialog', () {
    final message = ChatMessage(
      id: 'm1',
      authorId: 'u3',
      authorName: 'Rory Vance',
      body: 'that was a ridiculous call, honestly',
      timestamp: when,
      deleted: false,
    );

    Future<void> openDialog(
      WidgetTester tester,
      AppProvider app,
      Future<void> Function() body,
    ) =>
        screen(
          tester,
          app,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => confirmReportMessage(context, app, message),
                  child: const Text('Report'),
                ),
              ),
            ),
          ),
          '/',
          () async {
            await tester.tap(find.text('Report'));
            await tester.pumpAndSettle();
            await body();
          },
        );

    testWidgets('all three reasons are offered', (tester) async {
      await openDialog(tester, provider(), () async {
        for (final reason in ChatReport.reasons) {
          expect(find.byKey(ValueKey('reportReason-$reason')), findsOneWidget);
        }
      });
    });

    testWidgets('nothing is filed until a reason is chosen', (tester) async {
      await openDialog(tester, provider(), () async {
        // The host gets a report whether it says anything useful or not, so the
        // reason is not an optional afterthought on the way to a tap.
        final before = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Report'),
        );
        expect(before.onPressed, isNull);

        await tester.tap(find.byKey(const ValueKey('reportReason-Spam')));
        await tester.pumpAndSettle();

        final after = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Report'),
        );
        expect(after.onPressed, isNotNull);
      });
    });

    testWidgets('choosing a reason moves the selection', (tester) async {
      await openDialog(tester, provider(), () async {
        await tester.tap(find.byKey(const ValueKey('reportReason-Spam')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('reportReason-Spam')),
            matching: find.byIcon(Icons.radio_button_checked),
          ),
          findsOneWidget,
        );

        // The previous choice is replaced rather than both staying ticked.
        await tester.tap(find.byKey(const ValueKey('reportReason-Offensive')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('reportReason-Offensive')),
            matching: find.byIcon(Icons.radio_button_checked),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('reportReason-Spam')),
            matching: find.byIcon(Icons.radio_button_checked),
          ),
          findsNothing,
        );
      });
    });

    testWidgets('cancelling files nothing', (tester) async {
      final app = provider();
      await openDialog(tester, app, () async {
        await tester.tap(find.byKey(const ValueKey('reportReason-Spam')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        // No host notification means no report was written.
        expect(app.notifications, isEmpty);
        expect(find.byKey(const ValueKey('reportReason-Spam')), findsNothing);
      });
    });

    testWidgets('confirming files the report and says so', (tester) async {
      // Signed in as the member. The host is the audience, so this device's
      // own inbox stays empty by design - `pushNotification` skips a
      // notification addressed to someone else, and the report's own copy
      // goes to the host. The snackbar is what proves the write path ran.
      final app = provider(user: member);
      await openDialog(tester, app, () async {
        await tester.tap(find.byKey(const ValueKey('reportReason-Spam')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Report'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('reportReason-Spam')), findsNothing,
            reason: 'the dialog is gone, so a report was filed');
        expect(
          find.text('Reported. The host has been told.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('a report the member may not file is refused', (tester) async {
      // `canReport` blocks your own message, a pinned system card and an
      // already-removed one. A report is never filed for those.
      final app = provider(user: member);
      final own = ChatMessage(
        id: 'm1',
        authorId: 'u2',
        authorName: 'Nina Kowalski',
        body: 'my own message',
        timestamp: when,
        deleted: false,
      );
      await screen(
        tester,
        app,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => confirmReportMessage(context, app, own),
                child: const Text('Report'),
              ),
            ),
          ),
        ),
        '/',
        () async {
          await tester.tap(find.text('Report'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('reportReason-Spam')));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, 'Report'));
          await tester.pumpAndSettle();

          expect(
            find.text('This message cannot be reported.'),
            findsOneWidget,
          );
        },
      );
    });
  });

  group('the host sees the reason', () {
    /// Both surfaces a host can read reports from. A reason shown on one and
    /// not the other is still a gap: the spec's "so the host reads the same
    /// three words" does not care which screen they opened.
    testWidgets('the reports screen badges the reason', (tester) async {
      final app = provider(reports: [reportWith(reason: 'Offensive')]);
      await screen(tester, app, const ReportsScreen(), '/reports', () async {
        expect(
          tester.widget<AppBadge>(find.byType(AppBadge)).label,
          'Offensive',
        );
      });
    });

    testWidgets('group settings badges the reason', (tester) async {
      final app = provider(reports: [reportWith(reason: 'Spam')]);
      await screen(
        tester,
        app,
        const GroupSettingsScreen(),
        '/group-settings',
        () async {
          // The reports card is low on a long settings column, so it has to be
          // scrolled into view before it is on screen at all.
          await tester.ensureVisible(find.text(reportWith().excerpt).first);
          await tester.pumpAndSettle();
          expect(
            tester.widget<AppBadge>(find.byType(AppBadge).last).label,
            'Spam',
          );
        },
      );
    });

    testWidgets('a legacy report renders without a reason badge',
        (tester) async {
      final app = provider(reports: [reportWith()]);
      await screen(tester, app, const ReportsScreen(), '/reports', () async {
        // Still shown, just without a reason - an empty badge would read as
        // "Other" to the host.
        expect(find.text(reportWith().excerpt), findsOneWidget);
        expect(find.byType(AppBadge), findsNothing);
      });
    });
  });
}
