import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/imported_night.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/screens/shell/import_results_screen.dart';
import 'package:poker_night/widgets/app_button.dart';
import 'package:provider/provider.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';

/// Spec B12 — import past results.
///
/// The parser itself is covered in `import_results_parser_test.dart`. These
/// tests cover what the *screen* decides on top of it: that Check previews
/// before anything is stored, that a good line imports while a bad one is
/// skipped, and that the counts it reports are the counts it stored.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The recovery store writes into the real project directory and is shared
  // between AppProviders; leaving it on lets one test's save fail the next
  // with a file-lock error that has nothing to do with importing.
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

  Group groupWith({List<AppUser> members = const [host]}) => Group(
        id: 'g1',
        name: 'Friday Poker Club',
        joinCode: 'FP2608',
        ownerId: 'u1',
        members: members,
        games: [],
        chat: [],
        polls: [],
        notifications: [],
      );

  AppProvider provider({
    List<AppUser> members = const [host],
    List<ImportedNight> imported = const [],
  }) =>
      AppProvider()
        ..setUserForTesting(host)
        ..setCurrentGroupForTesting(groupWith(members: members))
        ..setImportedNightsForTesting(imported);

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
      initialLocation: '/import-results',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/import-results',
          builder: (_, _) => const ImportResultsScreen(),
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

  /// Types [text] into the paste area and presses **Check**.
  ///
  /// Both are scrolled into view first: the default test surface is 800x600
  /// and the paste box sits below the example card, so a bare tap lands on
  /// whatever is actually under the pointer.
  Future<void> pasteAndCheck(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.ensureVisible(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
  }

  Future<void> tapImport(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('gating', () {
    testWidgets('a non-host gets the lock screen, not the text area',
        (tester) async {
      // The screen is host-only, so the guard runs before the paste box is
      // ever on screen: a member deep-linking in must not even be able to
      // stage text, let alone commit it.
      final app = AppProvider()
        ..setUserForTesting(member)
        ..setCurrentGroupForTesting(groupWith(members: [host, member]));

      await screen(tester, app, () async {
        expect(find.byType(TextField), findsNothing);
        expect(find.textContaining('Only the host'), findsOneWidget);
      });
    });
  });

  group('preview', () {
    testWidgets('nothing is stored before Import is pressed', (tester) async {
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        await pasteAndCheck(
          tester,
          '2026-06-27; Alex Morgan, Nina Kowalski',
        );

        // The spec splits the two steps on purpose: Check "parses and
        // previews", only "Import n nights" commits.
        expect(find.text('1 ready'), findsOneWidget);
        expect(find.text('Import 1 night'), findsOneWidget);
        expect(app.importedNights, isEmpty);
      });
    });

    testWidgets('a good line imports while a bad one is skipped',
        (tester) async {
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        await pasteAndCheck(
          tester,
          '2026-06-27; Alex Morgan, Nina Kowalski\nnot a line at all',
        );

        // §B12: "Valid lines import even when others fail." The button count
        // is the good lines, not all of them.
        expect(find.textContaining('1 good line'), findsOneWidget);
        expect(find.text('Import 1 night'), findsOneWidget);
        expect(find.textContaining('1 below will be skipped'), findsOneWidget);
      });
    });

    testWidgets('editing after Check clears the preview', (tester) async {
      // The preview describes one specific text. Leaving it standing after a
      // keystroke invites committing nights that are no longer what is on
      // screen.
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        await pasteAndCheck(
          tester,
          '2026-06-27; Alex Morgan, Nina Kowalski',
        );
        expect(find.text('1 ready'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '2026-06-28; ');
        await tester.pumpAndSettle();

        expect(find.text('1 ready'), findsNothing);
        expect(find.text('Import 1 night'), findsNothing);
      });
    });

    testWidgets('a fully-invalid paste offers no Import button',
        (tester) async {
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        await pasteAndCheck(tester, 'rubbish');

        expect(find.textContaining('Nothing to import'), findsOneWidget);
        expect(
          find.widgetWithText(AppButton, 'Import'),
          findsNothing,
        );
      });
    });
  });

  group('import', () {
    testWidgets('commit reports the count it actually stored',
        (tester) async {
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        await pasteAndCheck(
          tester,
          '2026-06-27; Alex Morgan, Nina Kowalski\n'
          '2026-06-28; Nina Kowalski, Alex Morgan',
        );
        await tapImport(tester, 'Import 2 nights');

        expect(
          find.textContaining('Imported 2 nights'),
          findsOneWidget,
        );
        expect(app.importedNights, hasLength(2));
        // The box empties and the preview goes, so the same nights cannot be
        // pasted in a second time.
        expect(app.importedNights, isNotEmpty);
        expect(find.text('Import 2 nights'), findsNothing);
      });
    });

    testWidgets('a matched name becomes a playerId, a guest keeps its text',
        (tester) async {
      // §B12 matching: trim and lower-case both sides, accents kept.
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        await pasteAndCheck(tester, '2026-06-27; Nina KOWALSKI , Tomás Bekele');
        await tapImport(tester, 'Import 1 night');

        final night = app.importedNights.single;
        // Case is ignored.
        expect(night.entries.first.playerId, 'u2');
        // An unmatched name keeps the text exactly as typed, accents
        // included, and is never re-linked later.
        expect(night.entries.last.playerId, isNull);
        expect(night.entries.last.guestName, 'Tomás Bekele');
      });
    });

    testWidgets('surrounding spaces are trimmed but inner ones are not',
        (tester) async {
      // The spec says trim and lower-case, then compare for equality. It does
      // not say collapse runs of spaces, so "nina  kowalski" with a double
      // space is a different string and stays a guest. Reading this as
      // "tidy the whitespace" would silently re-link a guest row.
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        await pasteAndCheck(
          tester,
          '2026-06-27;   Nina  Kowalski  , Alex Morgan',
        );
        await tapImport(tester, 'Import 1 night');

        final night = app.importedNights.single;
        expect(night.entries.first.playerId, isNull);
        expect(night.entries.first.guestName, 'Nina  Kowalski');
        // The member spelled correctly in the same line still matches, so the
        // previous entry is a genuine miss and not a broken index.
        expect(night.entries.last.playerId, 'u1');
      });
    });

    testWidgets('a date already in the season is refused up front',
        (tester) async {
      final app = provider(
        members: [host, member],
        imported: [
          ImportedNight(
            id: ImportedNight.idForDate('2026-06-27'),
            date: '2026-06-27',
            entries: const [],
          ),
        ],
      );

      await screen(tester, app, () async {
        await pasteAndCheck(
          tester,
          '2026-06-27; Alex Morgan, Nina Kowalski',
        );

        expect(
          find.textContaining('already in the season - skipped'),
          findsOneWidget,
        );
        expect(find.text('1 ready'), findsNothing);
        expect(find.text('Import 1 night'), findsNothing);
      });
    });

    testWidgets('a night landing between Check and Import is skipped',
        (tester) async {
      // `importNights` re-checks dates against what is stored, so a night that
      // arrives after the preview cannot be double-counted. The screen must
      // say so rather than claim a success it did not have.
      final app = provider(members: [host, member]);

      await screen(tester, app, () async {
        await pasteAndCheck(
          tester,
          '2026-06-27; Alex Morgan, Nina Kowalski',
        );
        expect(find.text('1 ready'), findsOneWidget);

        // The other device imports the same night while this one was parked
        // on the preview.
        app.setImportedNightsForTesting([
          ImportedNight(
            id: ImportedNight.idForDate('2026-06-27'),
            date: '2026-06-27',
            entries: const [],
          ),
        ]);
        await tester.pumpAndSettle();

        await tapImport(tester, 'Import 1 night');

        expect(find.textContaining('Nothing was imported'), findsOneWidget);
        // Still exactly one night in the season, counted once.
        expect(app.importedNights, hasLength(1));
      });
    });
  });
}
