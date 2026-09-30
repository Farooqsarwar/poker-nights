import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/app/router.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/table_settings.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';

/// Concrete values substituted for C2's `:id`, `:gid` and `:code` templates.
///
/// One value serves every `:code` - `/join/:code`, `/invite/:code` and
/// `/tv/:code` are all "whatever the invite, the game link or the TV link
/// carried", and the router does not know which was which until the join
/// screen classifies it.
const game = '9f3a';
// Not named `group`: that would shadow `flutter_test`'s own `group()` and every
// `group('...')` call in this file would stop resolving.
const gid = 'g1';
const code = 'FP2608';
const gameCode = 'ABC123';

/// Fills a C2 template's parameters, so the expectation list below and the
/// `SpecRoutes` tables cannot be written without agreeing.
String concretise(String template) => template
    .replaceAll(':id', game)
    .replaceAll(':gid', gid)
    .replaceAll(':gameCode', gameCode)
    .replaceAll(':code', code);

/// Build Spec section C2 - the 59-row route matrix.
///
/// C2 names a URL for every screen, and for a long time this app only had its
/// own flat paths: `/invitation`, `/host-dashboard`, `/rebuy-settlement`. A
/// deep link written from the spec landed on "page not found", and a shared
/// link to `/t/9f3a/live` reached a game only if the recipient happened to
/// already be inside one. C3 then adds the rewrites that make a pasted code
/// resolve, and the two naming schemes have to coexist, because everything the
/// app itself navigates by - and every notification link hard-coded in
/// `lib/providers/**` - is flat.
///
/// So this file pins four things, in increasing order of what a break costs:
///
///   1. the three tables partition C2 - 50 registered, 7 redirected, 2 with no
///      screen - and no row is counted twice;
///   2. [SpecRoutes.flatFor] folds a concrete C2 URL onto the flat path the
///      guard reads, including the `/t/new`-before-`/t/:id` ordering that a
///      template matcher gets wrong;
///   3. every row in [SpecRoutes.registered] and [SpecRoutes.redirected]
///      resolves through the real router built by [buildAppRouter] - the guard,
///      the C3 rewrites and the `errorBuilder` included, so "registered" means
///      reachable rather than merely declared;
///   4. every legacy flat path in [RoutePaths] still resolves.
///
/// Point 3 is a widget test on purpose. The failures worth catching here are
/// the ones a table assertion cannot see: a route declared but shadowed by a
/// sibling, a row whose guard bounces it, a C2 path that still 404s. None of
/// that exists until the redirect has run, so this drives the real `GoRouter`.
///
/// Its pages are never built. The harness mounts a bare [Router] whose builder
/// discards its child, so the delegate parses and the guard runs - the part
/// under test - while the screens, their periodic clock tickers and their
/// Firestore reads stay out of it. `screen_smoke_test.dart` covers whether the
/// screens themselves build; this file covers whether the router can get to
/// them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The recovery store writes `recovery/active_game` into the process working
  // directory, which under `flutter test` is the repo root, and every
  // AppProvider in this file shares it. Nothing here depends on it.
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

  Group fridayClub() => Group(
        id: gid,
        name: 'Friday Poker Club',
        joinCode: code,
        ownerId: host.id,
        members: const [host],
        games: const [],
        chat: const [],
        polls: const [],
        notifications: const [],
        tableSettings: TableSettings.fallback,
      );

  /// A signed-in group owner with no game loaded.
  ///
  /// This is the state every expectation below is written against, and each
  /// part of it is load-bearing:
  ///
  ///   * `authReady` - `AppProvider` reads it in its constructor, and in a
  ///     widget test `FirebaseAuth.instance` throws `[core/no-app]` before
  ///     `authStateChanges()` is ever subscribed, so the catch that already
  ///     exists sets it true. Were it false the router would hold every location
  ///     at `/splash` and this file would pass while testing nothing.
  ///   * `isAdmin` - `isAdmin: true` *and* `ownerId` matching, because the
  ///     host-only set is checked with both.
  ///   * `currentGame == null` - so `canOperateTheClock` is false and the
  ///     co-host gate is live. That is the one guard that legitimately moves a
  ///     registered row (`/t/:id/rebuys` to `/home`), and it is pinned below
  ///     rather than worked around.
  AppProvider signedInHost() => AppProvider()
    ..setUserForTesting(host)
    ..setCurrentGroupForTesting(fridayClub());

  /// Resolves [location] through the real router and reports where it landed.
  ///
  /// Takes ownership of [app]: the caller passes one in when the resolution
  /// depends on its auth state, and it is disposed here along with everything
  /// else. Nothing survives the call, so a second [resolve] on the same
  /// provider would see a disposed one.
  Future<({String path, bool isError})> resolve(
    WidgetTester tester,
    String location, {
    AppProvider? app,
  }) async {
    final provider = app ?? signedInHost();
    final router = buildAppRouter(provider);
    // The parser needs a real BuildContext, but nothing else about a mounted
    // router is wanted here: `MaterialApp.router` or `Router` would go on to
    // BUILD every matched page, so a route whose screen wanted a provider it
    // does not have would fail for reasons that have nothing to do with where
    // the URL resolves. `parseRouteInformationWithDependencies` is the same
    // entry point the widget calls, with a context borrowed from a one-frame
    // widget that renders nothing. `lib/app/router.dart`'s redirect never
    // dereferences its `context` (it decides on `state.uri` and the provider),
    // so borrowing an unrelated one is safe.
    late BuildContext ctx;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    try {
      final matches = await router.routeInformationParser
          .parseRouteInformationWithDependencies(
        RouteInformation(
          uri: Uri.parse(location),
          // Required, and the reason the state is passed explicitly: the parser
          // asserts on it, and reads `.type` to know this is a fresh
          // navigation rather than a state restoration.
          state: RouteInformationState(type: NavigatingType.go),
        ),
        ctx,
      );
      return (path: matches.uri.toString(), isError: matches.isError);
    } finally {
      // Unmount before disposing, for the reason `group_settings_screen_test`
      // documents: AppProvider runs a periodic ticker, and the framework checks
      // for pending timers before any tearDown, so a provider left running
      // fails with "A Timer is still pending" - which says nothing about
      // routing and masks the assertion that did.
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      provider.dispose();
      await tester.pump();
    }
  }

  // ---------------------------------------------------------------------------
  // 1. The tables are a closed partition of C2.
  // ---------------------------------------------------------------------------

  group('the C2 tables partition the spec', () {
    test('50 registered, 7 redirected, 2 unimplemented, no row twice', () {
      expect(SpecRoutes.registered.length, 50);
      expect(SpecRoutes.redirected.length, 7);
      expect(SpecRoutes.unimplemented.length, 2);
      expect(
        SpecRoutes.registered.length +
            SpecRoutes.redirected.length +
            SpecRoutes.unimplemented.length,
        59,
      );

      // A key in two tables is legal Dart - two maps, one name - and would make
      // `flatFor` answer with whichever is looked up first, so it is pinned.
      final keys = <String>{
        ...SpecRoutes.registered.keys,
        ...SpecRoutes.redirected.keys,
        ...SpecRoutes.unimplemented.keys,
      };
      expect(keys.length, 59, reason: 'a C2 row is listed in two tables');
    });

    test('the rows are the C2 paths, written out so a typo cannot pass', () {
      // The keys are C2's URL TEMPLATES, not symbolic row names. That is what
      // `flatFor` needs — it matches a concrete `/t/9f3a/dashboard` against
      // `/t/:id/dashboard` — and it is why the tables in `route_paths.dart`
      // write `start:` where the value is the constant `start` of the same
      // class. Written out here by hand, so a mistyped template is a failure
      // rather than a route that quietly 404s.
      const spec = <String>{
        // A - onboarding and access
        '/splash', '/start', '/login', '/register', '/forgot', '/join',
        '/join/:code', '/invite/:code', '/g/:gameCode', '/quick',
        // B - group
        '/home', '/games', '/members', '/chat', '/polls', '/notifications',
        '/history', '/groups/new', '/groups/:gid/settings',
        '/groups/:gid/standings', '/groups/:gid/import', '/groups/:gid/chips',
        '/groups/:gid/invite',
        // C - tournament
        '/t/new', '/t/:id', '/t/:id/review', '/t/:id/configure',
        '/t/:id/checkin', '/t/:id/dashboard', '/t/:id/levels', '/t/:id/players',
        '/t/:id/payouts', '/t/:id/rebuys', '/t/:id/deal', '/t/:id/final-table',
        '/t/:id/finish', '/t/:id/results', '/t/:id/live', '/t/:id/me',
        // D - cash game and TV
        '/tv/:code', '/cash/new', '/cash/:id',
        // E - tools
        '/tools', '/tools/blinds', '/tools/clock', '/tools/icm', '/tools/payouts',
        '/tools/quick-blind',
        // F - account
        '/profile', '/settings', '/stats', '/chipsets', '/chipsets/:id',
        '/presets',
        // G - premium
        '/premium', '/premium/checkout',
        // H - legal
        '/privacy', '/terms', '/support',
      };
      expect(
        {
          ...SpecRoutes.registered.keys,
          ...SpecRoutes.redirected.keys,
          ...SpecRoutes.unimplemented.keys,
        },
        spec,
      );
    });

    test('the two tables make their different promises explicitly', () {
      // `redirected` is a renaming: the old path opens the same screen. Nothing
      // is mounted at the source, and the query string rides along.
      expect(SpecRoutes.redirected['/start'], RoutePaths.landing);
      expect(SpecRoutes.redirected['/forgot'], RoutePaths.forgotPassword);
      expect(SpecRoutes.redirected['/games'], RoutePaths.group);
      expect(
        SpecRoutes.redirected['/premium/checkout'],
        RoutePaths.checkout,
      );

      // `registered` is a second door onto a screen that already exists: the
      // source is a real route, so its parameters reach the builder.
      expect(
        SpecRoutes.registered['/t/:id/dashboard'],
        RoutePaths.hostDashboard,
      );
      expect(
        SpecRoutes.registered['/t/:id/live'],
        RoutePaths.playerLive,
      );
      expect(SpecRoutes.registered['/invite/:code'], RoutePaths.joinGroup);
    });

    test('the two unimplemented rows say why, not just that they are missing',
        () {
      // `/groups/new` (B8) is the create-group dialog and `/groups/:gid/invite`
      // (B13) is a modal on the group screen. A dialog cannot be a route target
      // without a screen to host it, and adding one is a screen change, which
      // is out of scope for a routing task. The reason lives in the table so
      // the gap is named rather than quietly dropped.
      expect(
        SpecRoutes.unimplemented.keys.toList(),
        ['/groups/new', '/groups/:gid/invite'],
      );
      for (final entry in SpecRoutes.unimplemented.entries) {
        expect(
          entry.value,
          contains('no '),
          reason: '${entry.key} must record why it is not implemented',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 2. flatFor - the fold the whole guard depends on.
  // ---------------------------------------------------------------------------

  group('SpecRoutes.flatFor folds a C2 URL onto the flat path', () {
    test('a template folds onto the screen the guard knows', () {
      expect(SpecRoutes.flatFor('/t/$game/live'), RoutePaths.playerLive);
      expect(
        SpecRoutes.flatFor('/t/$game/dashboard'),
        RoutePaths.hostDashboard,
      );
      expect(SpecRoutes.flatFor('/t/$game'), RoutePaths.invitation);
      expect(
        SpecRoutes.flatFor('/groups/$gid/settings'),
        RoutePaths.groupSettings,
      );
      expect(SpecRoutes.flatFor('/chipsets/$game'), RoutePaths.editChipSet);
      expect(SpecRoutes.flatFor('/g/$gameCode'), RoutePaths.join);
    });

    test('a renamed path folds onto its target', () {
      expect(SpecRoutes.flatFor('/start'), RoutePaths.landing);
      expect(SpecRoutes.flatFor('/premium/checkout'), RoutePaths.checkout);
    });

    test('a literal beats a template that would also match', () {
      // `/t/new` and `/t/:id` are the same shape, so whichever the matcher tries
      // first decides whether "new tournament" opens the create form or the
      // invitation screen of a game whose id happens to be "new". `/cash/new`
      // and `/cash/:id` have the same trap.
      expect(SpecRoutes.flatFor('/t/new'), RoutePaths.createTournament);
      expect(SpecRoutes.flatFor('/cash/new'), RoutePaths.cashGame);
    });

    test('an unknown path comes back untouched', () {
      // `flatFor` is the guard's first statement, so a path it does not know has
      // to emerge unchanged rather than folding onto something arbitrary.
      expect(SpecRoutes.flatFor('/reports'), '/reports');
      expect(SpecRoutes.flatFor('/game/$gameCode'), '/game/$gameCode');
      expect(SpecRoutes.flatFor('/groups/new'), '/groups/new');
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Every row resolves through the real router.
  // ---------------------------------------------------------------------------

  group('the router resolves every C2 row', () {
    /// Each row is a C2 path with its parameters filled in, and the location it
    /// is expected to end up at.
    ///
    /// Five rows do not end up where they started, and each is a real guard
    /// rather than a defect, so they are spelled out here rather than assumed:
    ///
    ///   * `/splash`, `/login`, `/register` and `/forgot` send a signed-in user
    ///     to `/home` - there is nothing on them for someone who already has a
    ///     session, and `/forgot` reaches `/home` by way of `/forgot-password`;
    ///   * `/t/:id/rebuys` folds to `/rebuy-settlement`, which is in the
    ///     co-host set, and `canOperateTheClock` is false without a loaded
    ///     game, so the guard sends them home. D15 gives a co-host the rebuy
    ///     work, and the point of that gate is that it must not open for
    ///     someone with no game to rebuy into.
    const matrix = <(String, String, String)>[
      // A - onboarding and access
      ('A1 splash', '/splash', RoutePaths.home),
      ('A2 start', '/start', RoutePaths.landing),
      ('A3 login', '/login', RoutePaths.home),
      ('A4 register', '/register', RoutePaths.home),
      ('A5 forgot', '/forgot', RoutePaths.home),
      ('A6 guest game', '/g/$gameCode', '/g/$gameCode'),
      ('A7 join', '/join', '/join'),
      ('A7 join carrying a code', '/join/$code', '/join/$code'),
      ('A8 invite link', '/invite/$code', '/invite/$code'),

      // B - group
      ('B1 home', '/home', '/home'),
      ('B2 games', '/games', '/group'),
      ('B3 members', '/members', '/members'),
      ('B4 chat', '/chat', '/chat'),
      ('B5 polls', '/polls', '/polls'),
      ('B6 notifications', '/notifications', '/notifications'),
      ('B7 history', '/history', '/history'),
      ('B9 host settings (no board)', '/groups/$gid/settings', '/groups/$gid/settings'),
      ('B10 standings (no board)', '/groups/$gid/standings', '/groups/$gid/standings'),
      ('B11 import results (no board)', '/groups/$gid/import', '/groups/$gid/import'),
      ('B12 group chips (no board)', '/groups/$gid/chips', '/groups/$gid/chips'),

      // C - tournament
      ('C0 quick add', '/quick', '/quick'),
      ('C1 new tournament', '/t/new', '/t/new'),
      ('C2 review', '/t/$game/review', '/t/$game/review'),
      ('C3 tournament', '/t/$game', '/t/$game'),
      ('C3 configure (no board)', '/t/$game/configure', '/t/$game/configure'),
      ('C4 check in', '/t/$game/checkin', '/t/$game/checkin'),
      ('C5 dashboard', '/t/$game/dashboard', '/t/$game/dashboard'),
      ('C11 levels, host variant', '/t/$game/levels', '/t/$game/levels'),
      ('C4 players (no board)', '/t/$game/players', '/t/$game/players'),
      ('C9 payouts (no board)', '/t/$game/payouts', '/t/$game/payouts'),
      ('C6 rebuys', '/t/$game/rebuys', RoutePaths.home),
      ('ICM deal (no board)', '/t/$game/deal', '/t/$game/deal'),
      ('C7 final table', '/t/$game/final-table', '/t/$game/final-table'),
      ('C8 finish', '/t/$game/finish', '/t/$game/finish'),
      ('C9 results', '/t/$game/results', '/t/$game/results'),
      ('C10-C11 live', '/t/$game/live', '/t/$game/live'),
      ('C4p me (no board)', '/t/$game/me', '/t/$game/me'),

      // D - cash game and TV
      ('D1 new cash game', '/cash/new', '/cash/new'),
      ('D2 cash game', '/cash/$game', '/cash/$game'),
      ('D3 tv', '/tv/$code', '/tv/$code'),

      // E - tools
      ('E1 tools', '/tools', '/tools'),
      ('E2 blinds', '/tools/blinds', '/tools/blind-structure'),
      ('E3 clock', '/tools/clock', '/tools/clock'),
      ('E4 icm', '/tools/icm', '/tools/icm'),
      ('E5 payouts', '/tools/payouts', '/tools/payouts'),
      ('E6 quick blind', '/tools/quick-blind', '/tools/quick-blind'),

      // F - account
      ('F1 profile', '/profile', '/profile'),
      ('F2 settings', '/settings', '/settings'),
      ('F3 stats', '/stats', '/stats'),
      ('F4 chip sets', '/chipsets', '/chip-sets'),
      ('F5 one chip set', '/chipsets/$game', '/chipsets/$game'),
      ('F6 presets', '/presets', '/presets'),

      // G - premium
      ('G1 premium', '/premium', '/upgrade'),
      ('G2 checkout', '/premium/checkout', '/checkout'),

      // H - legal
      ('H1 privacy', '/privacy', '/privacy'),
      ('H2 terms', '/terms', '/terms'),
      ('H3 support', '/support', '/support'),
    ];

    test('this list covers all 57 reachable rows and no others', () {
      // Without this the list above could quietly fall behind the tables, and
      // the two would disagree about what "resolved" means.
      final covered = matrix.map((row) => row.$2).toSet();
      expect(covered.length, matrix.length, reason: 'a URL is asserted twice');
      expect(
        covered,
        {
          ...SpecRoutes.registered.keys.map(concretise),
          ...SpecRoutes.redirected.keys.map(concretise),
        },
        reason: 'this list and the C2 tables have drifted apart',
      );
    });

    for (final (name, url, expected) in matrix) {
      testWidgets('$name resolves', (tester) async {
        final result = await resolve(tester, url);
        expect(result.isError, isFalse, reason: '$url hit the errorBuilder');
        expect(result.path, expected);
      });
    }

    for (final row in SpecRoutes.unimplemented.entries) {
      testWidgets('${row.key} has no screen, so it 404s', (tester) async {
        final url = concretise(row.key);
        final result = await resolve(tester, url);
        expect(
          result.isError,
          isTrue,
          reason: '$url is listed as unimplemented but resolved to '
              '${result.path}. Either the row is wrong, or a route that should '
              'be registered is being hidden behind the guard.',
        );
      });
    }
  });

  // ---------------------------------------------------------------------------
  // 4. C3's rewrites, which are not rows in the C2 table.
  // ---------------------------------------------------------------------------

  group('C3 rewrites a pasted code onto the unified join screen', () {
    testWidgets('/game/{CODE} becomes /join/{CODE}', (tester) async {
      final result = await resolve(tester, '/game/$gameCode');
      expect(result.isError, isFalse);
      expect(result.path, '/join/$gameCode');
    });

    testWidgets('/j/{CODE} becomes /join/{CODE}', (tester) async {
      // `/j/{CODE}` is the half this router never had.
      final result = await resolve(tester, '/j/$gameCode');
      expect(result.isError, isFalse);
      expect(result.path, '/join/$gameCode');
    });

    testWidgets('a signed-out guest still gets a code onto the join screen',
        (tester) async {
      // `/join` is public, so a shared link resolves for anyone. The rewrite
      // sits above the auth check for exactly that reason, and a guest arriving
      // at `/t/$game/live` must instead reach sign-in with the deep link
      // preserved - otherwise a shared game link is a dead end for anyone
      // without an account.
      final guest = AppProvider()..setCurrentGroupForTesting(fridayClub());
      final joined = await resolve(tester, '/j/$gameCode', app: guest);
      expect(joined.isError, isFalse);
      expect(joined.path, '/join/$gameCode');
    });

    testWidgets('a signed-out guest deep link survives sign-in', (tester) async {
      final guest = AppProvider()..setCurrentGroupForTesting(fridayClub());
      final live = await resolve(tester, '/t/$game/live', app: guest);
      expect(live.isError, isFalse);
      expect(live.path, startsWith('${RoutePaths.login}?next='));
      expect(
        Uri.decodeQueryComponent(
          live.path.substring('${RoutePaths.login}?next='.length),
        ),
        '/t/$game/live',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 5. The legacy flat paths must keep working.
  // ---------------------------------------------------------------------------

  group('every legacy flat path still resolves', () {
    // Written out because Dart has no reflection: `RoutePaths` is a set of
    // constants, so a test cannot enumerate it, and the whole point is to catch
    // a constant that no route was ever registered for. `structureReviewFrom-
    // Param` is absent because it is the `from` query parameter of
    // `/structure-review`, not a path.
    const flat = <String>[
      // 11 - entry, public and utility
      RoutePaths.splash, RoutePaths.landing, RoutePaths.login,
      RoutePaths.register, RoutePaths.forgotPassword, RoutePaths.tvMode,
      RoutePaths.guestFlow, RoutePaths.privacy, RoutePaths.terms,
      RoutePaths.support, RoutePaths.join,
      // 7 - tools and join-group
      RoutePaths.tools, RoutePaths.toolBlinds, RoutePaths.toolClock,
      RoutePaths.toolIcm, RoutePaths.toolPayouts, RoutePaths.toolQuickBlind,
      RoutePaths.joinGroup,
      // 13 - the group hub
      RoutePaths.home, RoutePaths.group, RoutePaths.chat, RoutePaths.members,
      RoutePaths.polls, RoutePaths.reports, RoutePaths.notifications,
      RoutePaths.history, RoutePaths.standings, RoutePaths.createTournament,
      RoutePaths.quick, RoutePaths.structureReview, RoutePaths.invitation,
      // 12 - the tournament floor
      RoutePaths.checkIn, RoutePaths.hostDashboard, RoutePaths.playerLive,
      RoutePaths.rebuySettlement, RoutePaths.finalTable,
      RoutePaths.completeTournament, RoutePaths.deal, RoutePaths.importResults,
      RoutePaths.groupSettings, RoutePaths.groupChips, RoutePaths.resultPodium,
      RoutePaths.cashGame,
      // 9 - account, chipsets and premium
      RoutePaths.cashGameLive, RoutePaths.profile, RoutePaths.settings,
      RoutePaths.stats, RoutePaths.chipSets, RoutePaths.editChipSet,
      RoutePaths.presets, RoutePaths.upgrade, RoutePaths.checkout,
    ];

    test('the list is the whole of RoutePaths, once each', () {
      expect(flat.length, 52);
      expect(flat.toSet().length, 52, reason: 'a path is listed twice');
    });

    testWidgets('none of them 404s', (tester) async {
      for (final path in flat) {
        final result = await resolve(tester, path);
        expect(result.isError, isFalse, reason: '$path no longer resolves');
      }
    });
  });
}
