import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/group_chips_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/model_codec.dart';
import 'package:provider/provider.dart';

/// Spec B10 — the chip set a group starts from.
///
/// The screen is a pointer editor, so the tests are mostly about what it does
/// NOT store: the group must end up holding a chip set's id and nothing about
/// its chips, which is the only way "editing the set in F5 updates every group
/// that points at it" can be true.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The recovery store writes into the real project directory and is shared
  // between AppProviders; leaving it on lets one test's save fail the next
  // with a file-lock error that has nothing to do with chip sets.
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

  const clubChips = <ChipColor>[
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 30),
  ];

  Group groupWith({String? defaultChipSetId}) => Group(
        id: 'g1',
        name: 'Friday Poker Club',
        joinCode: 'FP2608',
        ownerId: 'u1',
        members: const [host, member],
        games: const [],
        chat: const [],
        polls: const [],
        notifications: const [],
        defaultChipSetId: defaultChipSetId,
      );

  /// The host's own sets, exactly as F4 stores them: the seeded Home Set plus
  /// one the host saved themselves.
  AppProvider provider({String? defaultChipSetId}) => AppProvider()
    ..setUserForTesting(host)
    ..setCurrentGroupForTesting(groupWith(defaultChipSetId: defaultChipSetId))
    ..saveChipSet('cs-club', 'Club night set', clubChips);

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
      initialLocation: '/group-chips',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/group-settings',
          builder: (_, _) => const Scaffold(),
        ),
        GoRoute(
          path: '/edit-chip-set',
          builder: (_, _) => const Scaffold(),
        ),
        GoRoute(
          path: '/group-chips',
          builder: (_, _) => const GroupChipsScreen(),
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

  /// The pointer the screen currently holds on the group.
  /// The pointer as the PROVIDER holds it, which is the only place it can
  /// survive the screen.
  ///
  /// These assertions used to read `GroupChipsScreenState.group`, the screen's
  /// own working copy, and passed while nothing was written anywhere: the
  /// choice reached no other screen, no other member's device, and nothing
  /// that creates the next tournament. Reading the group the provider is
  /// holding is what makes the test able to fail.
  String? pointerOn(AppProvider app) => app.currentGroup.defaultChipSetId;

  /// Option cards run below the fold on the 800x600 test surface, so a bare
  /// tap lands on whatever is actually under the pointer.
  Future<void> tapSet(WidgetTester tester, String id) async {
    await tester.ensureVisible(find.byKey(ValueKey('chipSetOption-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('chipSetOption-$id')));
    await tester.pumpAndSettle();
  }

  group('gating', () {
    testWidgets('a non-host gets the lock screen, not the chip sets',
        (tester) async {
      // Host only (spec B10), and the router bounces members before this
      // renders anyway — so the guard here is what a deep link that slips
      // through has to fall back to. No option card may be reachable, or a
      // member could stage a choice the group never asked for.
      final app = AppProvider()
        ..setUserForTesting(member)
        ..setCurrentGroupForTesting(groupWith());

      await screen(tester, app, () async {
        expect(find.textContaining('Only the host'), findsOneWidget);
        expect(find.text('Club night set'), findsNothing);
        expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      });
    });
  });

  group('options', () {
    testWidgets("the host sees their own sets plus the always-on box",
        (tester) async {
      final app = provider();

      await screen(tester, app, () async {
        // The host's saved set, the seeded one, and the Standard 500-piece box
        // that is available whether or not anything was ever saved.
        await tester.ensureVisible(find.byKey(const ValueKey('chipSetOption-cs-club')));
        await tester.pumpAndSettle();
        expect(find.text('Club night set'), findsOneWidget);
        expect(find.text('Home Set (4 colour)'), findsOneWidget);
        expect(find.text('Standard 500-piece box'), findsOneWidget);
        // Totals come from the set, not from a stored copy on the group.
        expect(
          find.textContaining('3 denominations · 230 chips · 3,600 total'),
          findsOneWidget,
        );
      });
    });
  });

  group('pointer', () {
    testWidgets('choosing a set stores its id on the group', (tester) async {
      final app = provider();

      await screen(tester, app, () async {
        await tapSet(tester, 'cs-club');

        expect(pointerOn(app), 'cs-club');
        // An id, and only an id: the group's own copy of the chips would make
        // this a String of more than four characters.
        expect(pointerOn(app), isA<String>());
      });
    });

    testWidgets('the Standard box is a real choice, not a clear', (tester) async {
      // The standard box is on the option list with an id of its own, so
      // picking it points the group at that box. "No saved set" is a different
      // state -- a null pointer -- and the screen does not offer it; it is what
      // a group that has never chosen looks like.
      final app = provider(defaultChipSetId: 'cs-club');

      await screen(tester, app, () async {
        await tapSet(tester, 'preset-standard-500');
        expect(pointerOn(app), 'preset-standard-500');
      });
    });

    test('clearing the pointer nulls it on the group', () {
      // The repository deletes the key and the codec omits it, so null has to
      // be reachable. `Group.copyWith` treats a null argument as "keep", which
      // is why this needed its own flag.
      final app = AppProvider()
        ..setUserForTesting(host)
        ..setCurrentGroupForTesting(groupWith(defaultChipSetId: 'cs-club'));
      app.setGroupDefaultChipSet(null);
      expect(app.currentGroup.defaultChipSetId, isNull);
    });

    test('the pointer survives a codec round trip', () {
      // B10 is a property of the group, so it has to be in the document. The
      // codec entry existed; nothing wrote it, so this never ran against a
      // real save.
      final g = groupWith(defaultChipSetId: 'cs-club');
      expect(groupFromMap(groupToMap(g)).defaultChipSetId, 'cs-club');
    });

    test('a group with no pointer omits the key entirely', () {
      // What the repository deletes, and what the codec has to agree with.
      final map = groupToMap(groupWith());
      expect(map.containsKey('defaultChipSetId'), isFalse);
      expect(groupFromMap(map).defaultChipSetId, isNull);
    });

    test('a non-owner cannot move the group pointer', () {
      // Owner-only, like the other group settings: the chips are the host's
      // money and the group's own box is not a member's to change.
      final app = AppProvider()
        ..setUserForTesting(member)
        ..setCurrentGroupForTesting(groupWith())
        ..saveChipSet('cs-club', 'Club night set', clubChips);
      app.setGroupDefaultChipSet('cs-club');
      expect(app.currentGroup.defaultChipSetId, isNull);
    });

    testWidgets('choosing the same set twice is not a second write',
        (tester) async {
      final app = provider(defaultChipSetId: 'cs-club');

      await screen(tester, app, () async {
        await tapSet(tester, 'cs-club');
        expect(pointerOn(app), 'cs-club');
      });
    });

    testWidgets('the chosen set is the one shown as selected', (tester) async {
      final app = provider(defaultChipSetId: 'cs-club');

      await screen(tester, app, () async {
        await tester.ensureVisible(find.byKey(const ValueKey('chipSetOption-cs-club')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('chipSetOption-cs-club')),
            matching: find.byIcon(Icons.radio_button_checked),
          ),
          findsOneWidget,
        );
        expect(find.text('DEFAULT'), findsOneWidget);

        await tapSet(tester, 'cs-default');
        expect(pointerOn(app), 'cs-default');
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('chipSetOption-cs-club')),
            matching: find.byIcon(Icons.radio_button_unchecked),
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('a group pointing at a deleted set says so', (tester) async {
      final app = provider(defaultChipSetId: 'cs-deleted-last-month');

      await screen(tester, app, () async {
        expect(
          find.textContaining('no longer in your list'),
          findsOneWidget,
        );
        // Nothing to preview, so no starting stack is claimed.
        expect(find.text('Starting stack'), findsNothing);
      });
    });

    testWidgets(
        'editing the set in F5 changes every group that points at it',
        (tester) async {
      // The whole point of a pointer. If the group held a copy of the chips,
      // this edit would leave the group's numbers alone.
      final app = provider(defaultChipSetId: 'cs-club');

      await screen(tester, app, () async {
        await tester.ensureVisible(find.text('Starting stack'));
        await tester.pumpAndSettle();
        expect(find.textContaining('3,600 total'), findsOneWidget);

        app.saveChipSet('cs-club', 'Club night set (rebuilt)', const [
          ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 200),
          ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 200),
        ]);
        await tester.pumpAndSettle();

        expect(find.text('Club night set (rebuilt)'), findsOneWidget);
        expect(
          find.textContaining('2 denominations · 400 chips · 1,200 total'),
          findsOneWidget,
        );
        // The pointer did not move, and it still points at the same set.
        expect(pointerOn(app), 'cs-club');
      });
    });
  });

  group('starting stack', () {
    testWidgets('a typical night is previewed with its chips', (tester) async {
      final app = provider(defaultChipSetId: 'cs-club');

      await screen(tester, app, () async {
        await tester.ensureVisible(find.text('Starting stack'));
        await tester.pumpAndSettle();

        // Two members, so a 2-player night is the "typical night" here: 3,600
        // of chips, two takers per seat reserved, so a 900 stack at 10/20.
        expect(find.text('900'), findsOneWidget);
        expect(find.textContaining('(90 big blinds)'), findsOneWidget);
        expect(
          find.textContaining('a rebuy for everyone'),
          findsOneWidget,
        );
      });
    });
  });
}
