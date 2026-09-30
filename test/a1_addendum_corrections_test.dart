import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/chat_report.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/chip_palette.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/group_settings_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/app_badge.dart';
import 'package:provider/provider.dart';

/// Addendum 1 §2 — "Corrections to v3.1", rows 2 and 3.
///
/// **Row 2** (spec `:5458`) replaces v3.1 §F5's eight-colour palette:
///
///   "v3.1 says: a fixed palette of named chip colours (White, Red, Green,
///   Black, Blue, Purple, Pink, Grey; no yellow or gold)"
///   "Read instead: The mock's ten named colours: White, Red, Green, Black,
///   Blue, Yellow, Pink, Purple, Orange, Grey. A chip swatch shows a real chip,
///   so it is the one place yellow may appear; the no-yellow rule (T141) covers
///   the app's own colours."
///
/// The correction is *additive* — two names — but it is also a reordering, and
/// the order is what a chip-set editor lists, so it is asserted as an exact
/// sequence rather than a set. The clause that matters more than the names is
/// the exception it carves out: yellow is legal here and nowhere else.
///
/// **Row 3** (spec `:5459`) adds two things to §E10 moderation / B9: a push to
/// the group host when a report is filed, and a count badge on the Reports row.
/// The push needs two devices to observe and is reported rather than tested; the
/// badge is here, because it is the half that is a one-device widget assertion
/// and nothing in the suite covered it — `group_settings_screen_test.dart`
/// asserts only that the row HIDES at zero, and `report_message_test.dart`
/// reaches the badges with `.last`, which is the per-report reason, so the count
/// badge was never the subject of a test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  group('Addendum 1 row 2 — the ten named chip colours', () {
    test('the palette is the ten names, in the addendum\'s order', () {
      // Exact sequence, not a set: an editor that lists these in the addendum's
      // order is what a host comparing their screen against the correction will
      // be checking.
      expect(
        kChipPalette.map((c) => c.name).toList(),
        [
          'White',
          'Red',
          'Green',
          'Black',
          'Blue',
          'Yellow',
          'Pink',
          'Purple',
          'Orange',
          'Grey',
        ],
      );
    });

    test('there are ten of them, and no eleventh', () {
      expect(kChipPalette, hasLength(10));
    });

    test('every name is unique, so a swatch is identified by its name', () {
      // §B5 requires chip colours to be named in text as well as shown, because
      // the owner is colour blind. Two entries sharing a name would make the
      // name useless as the label.
      final names = kChipPalette.map((c) => c.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('every hex is distinct, so a swatch is identified by its colour', () {
      final hexes = kChipPalette.map((c) => c.hex).toList();
      expect(hexes.toSet(), hasLength(hexes.length));
    });

    test('Yellow and Orange are in the palette', () {
      // The two the correction adds. v3.1 said "no yellow or gold" and omitted
      // orange entirely; the read-instead text is what makes both legal.
      expect(chipPaletteEntryForName('Yellow'), isNotNull);
      expect(chipPaletteEntryForName('Orange'), isNotNull);
      expect(kChipPalette.map((c) => c.name), contains('Yellow'));
      expect(kChipPalette.map((c) => c.name), contains('Orange'));
    });

    test('the names v3.1 listed are all still there', () {
      // The correction replaces a list, and a careless reading of "read instead"
      // could drop one of the original eight. Pink before Purple is the one
      // ordering detail worth naming: v3.1 had "Blue, Purple, Pink, Grey" and
      // the correction moves Pink ahead of Purple.
      for (final name in [
        'White',
        'Red',
        'Green',
        'Black',
        'Blue',
        'Pink',
        'Purple',
        'Grey',
      ]) {
        expect(chipPaletteEntryForName(name), isNotNull, reason: name);
      }
      expect(
        kChipPalette.indexWhere((c) => c.name == 'Pink'),
        lessThan(kChipPalette.indexWhere((c) => c.name == 'Purple')),
      );
    });

    test('lookup by name ignores case and surrounding space', () {
      // Names come from a host's typing and from older saved chip sets, so
      // " red " has to resolve to the same entry as "Red".
      expect(chipPaletteEntryForName('red')!.name, 'Red');
      expect(chipPaletteEntryForName('  RED  ')!.name, 'Red');
      expect(chipPaletteEntryForName('Blue')!.name, 'Blue');
    });

    test('a name from outside the palette resolves to nothing', () {
      // A saved set may carry free text from before the palette was fixed.
      // Returning the nearest entry would be a lie; returning null lets the
      // caller keep the stored name.
      expect(chipPaletteEntryForName('Gold'), isNull);
      expect(chipPaletteEntryForName(''), isNull);
      expect(chipPaletteEntryForName('   '), isNull);
    });

    test('lookup by hex finds the entry, and an unknown hex finds nothing', () {
      final blue = chipPaletteEntryForName('Blue')!;
      expect(chipPaletteEntryForHex(blue.hex)!.name, 'Blue');
      expect(chipPaletteEntryForHex(0xFF123456), isNull);
    });

    test('every hex carries a full opaque alpha channel', () {
      // A chip swatch that renders translucent or invisible is worse than no
      // swatch, and the missing alpha is invisible in a source diff.
      for (final c in kChipPalette) {
        expect(
          c.hex >> 24,
          0xFF,
          reason: '${c.name} is 0x${c.hex.toRadixString(16)}',
        );
      }
    });
  });

  group('Addendum 1 row 2 — a chip with a name off the palette', () {
    ChipColor chip(String name, int hex) =>
        ChipColor(color: name, hex: hex, value: 25, quantity: 120);

    test('a chip on the palette displays under the palette name', () {
      // The host's saved colour is the record of the chips they own, so the hex
      // is what resolves; the stored text is only a fallback.
      final pink = chipPaletteEntryForName('Pink')!;
      final result = chipDisplayName(chip('some old name', pink.hex));

      expect(result, 'Pink');
    });

    test('a chip off the palette keeps the name the host gave it', () {
      expect(chipDisplayName(chip('Gold', 0xFFD4AF37)), 'Gold');
    });

    test('an unnamed chip off the palette gets a neutral label, not an empty '
        'one', () {
      // A blank row in the chip-set list is unreadable; the spec's B5
      // requirement is that every chip is named in text.
      expect(chipDisplayName(chip('', 0xFFD4AF37)), 'Chip');
      expect(chipDisplayName(chip('   ', 0xFFD4AF37)), 'Chip');
    });

    test('a palette chip with a blank stored name still gets its palette name',
        () {
      final red = chipPaletteEntryForName('Red')!;
      expect(chipDisplayName(chip('  ', red.hex)), 'Red');
    });
  });

  group('Addendum 1 row 3 — the Reports count badge', () {
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

    ChatReport reportWith(String id, {String? reason}) => ChatReport(
          id: id,
          messageId: 'm$id',
          authorId: 'u3',
          authorName: 'Rory Vance',
          reporterId: 'u2',
          excerpt: 'that was a ridiculous call, honestly ($id)',
          createdAt: DateTime(2026, 3, 4, 21, 30),
          reason: reason,
        );

    AppProvider provider(List<ChatReport> reports) => AppProvider()
      ..setUserForTesting(host)
      ..setCurrentGroupForTesting(club)
      ..setReportsForTesting(reports);

    /// Pumps the settings screen, runs [body], then always unmounts and
    /// disposes — AppProvider runs a periodic ticker, and the framework checks
    /// for pending timers after the test body but before any tearDown, so a
    /// provider left running fails with "A Timer is still pending" and masks
    /// whatever the test was actually about.
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

    /// The badge in the card's header row — the count, not a per-report reason.
    ///
    /// Located through the widget tree rather than by index or by text, because
    /// the card renders the count first and then one reason badge per report, so
    /// `byType(AppBadge).last` is a report's reason whenever any report has one.
    /// The header is the row holding the "Reports" title.
    AppBadge countBadge(WidgetTester tester) {
      final row = find.ancestor(
        of: find.text('Reports'),
        matching: find.byType(Row),
      );
      expect(row, findsOneWidget, reason: 'the Reports header row');
      final badge = find.descendant(of: row, matching: find.byType(AppBadge));
      expect(badge, findsOneWidget, reason: 'one count badge in the header');
      return tester.widget<AppBadge>(badge);
    }

    Future<void> scrollToCard(WidgetTester tester) async {
      // The card is low on a long settings column, so it is not built until it
      // is scrolled into view.
      await tester.ensureVisible(find.text('Reports'));
      await tester.pumpAndSettle();
    }

    testWidgets('one report shows a count of 1', (tester) async {
      final app = provider([reportWith('a', reason: 'Spam')]);

      await screen(tester, app, () async {
        await scrollToCard(tester);
        expect(countBadge(tester).label, '1');
      });
    });

    testWidgets('three reports show a count of 3, not the last reason',
        (tester) async {
      // The failure this pins: a badge carrying the most recent report's
      // reason, or a count of 1 because only one report was ever rendered. A
      // host triaging three reports needs to know there are three without
      // counting the cards.
      final app = provider([
        reportWith('a', reason: 'Spam'),
        reportWith('b', reason: 'Offensive'),
        reportWith('c', reason: 'Other'),
      ]);

      await screen(tester, app, () async {
        await scrollToCard(tester);
        expect(countBadge(tester).label, '3');
        // Every report is still listed; the count is a summary, not a cap.
        expect(find.textContaining('(a)'), findsOneWidget);
        expect(find.textContaining('(b)'), findsOneWidget);
        expect(find.textContaining('(c)'), findsOneWidget);
      });
    });

    testWidgets('the count matches the provider\'s open-report total',
        (tester) async {
      final reports = [reportWith('a'), reportWith('b')];
      final app = provider(reports);

      await screen(tester, app, () async {
        await scrollToCard(tester);
        expect(countBadge(tester).label, '${app.reportCount}');
        expect(app.reportCount, 2);
      });
    });

    testWidgets('reports with no reason still count', (tester) async {
      // Every report filed before the reason field existed has none. If the
      // count were derived from reasons, the backlog would read as zero and the
      // host would see an empty-looking Reports card.
      final app = provider([reportWith('a'), reportWith('b')]);

      await screen(tester, app, () async {
        await scrollToCard(tester);
        expect(countBadge(tester).label, '2');
        expect(
          find.byType(AppBadge),
          findsOneWidget,
          reason: 'with no reasons on the reports, the count is the only badge',
        );
      });
    });

    testWidgets('the count is a number, never the word none or zero',
        (tester) async {
      // The card only renders when `reportCount > 0`, so a zero here would mean
      // the gate and the badge disagree.
      final app = provider([reportWith('a')]);

      await screen(tester, app, () async {
        await scrollToCard(tester);
        final label = countBadge(tester).label;
        expect(label, isNot('0'));
        expect(label, isNot('No reports'));
        expect(int.parse(label), greaterThan(0));
      });
    });

    testWidgets('a two-digit count is not truncated to one digit', (tester) async {
      // Ten reports is an ordinary week for a busy group and is the first
      // count that is more than one character.
      final app = provider([for (var i = 0; i < 12; i++) reportWith('$i')]);

      await screen(tester, app, () async {
        await scrollToCard(tester);
        expect(countBadge(tester).label, '12');
      });
    });
  });
}
