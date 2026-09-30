/// Central route path registry used by GoRouter and nav widgets.
/// Mirrors the screen ids from the web app's `AppContext` navigate().
///
/// These are the paths the app navigates by. The specification's own paths —
/// `/t/:id/live`, `/groups/:gid/settings`, `/start` and the rest of its C2
/// table — are [SpecRoutes] below, registered beside these rather than in
/// place of them.
abstract final class RoutePaths {
  // ── Public ─────────────────────────────────────────────────────────────────
  static const String splash = '/splash';
  static const String landing = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String tvMode = '/tv-mode';
  static const String guestFlow = '/guest-flow';
  static const String privacy = '/privacy';
  static const String terms = '/terms';
  static const String support = '/support';
  static const String join = '/join';

  /// The public tools (specification section 2).
  ///
  /// Each has its own URL because they are meant to be found and linked
  /// individually — somebody searching for an ICM calculator should land on
  /// the ICM calculator, not on a hub they then have to navigate.
  static const String tools = '/tools';
  static const String toolBlinds = '/tools/blind-structure';
  static const String toolClock = '/tools/clock';
  static const String toolIcm = '/tools/icm';
  static const String toolPayouts = '/tools/payouts';
  static const String toolQuickBlind = '/tools/quick-blind';

  /// Group invite deep link (`?code=CODE`) — shared as a link or encoded in
  /// the group's QR code. Requires sign-in; unauthenticated visitors are
  /// bounced through login with `?next=` and land back here to complete the
  /// join.
  static const String joinGroup = '/join-group';

  // ── App shell ──────────────────────────────────────────────────────────────
  static const String home = '/home';
  static const String group = '/group';
  static const String chat = '/chat';
  static const String members = '/members';
  static const String polls = '/polls';

  /// Reported chat messages, host only (Addendum 1 / Apple 1.2).
  static const String reports = '/reports';
  static const String notifications = '/notifications';
  static const String history = '/history';

  /// B11 -- the current group's standings and (Premium) seasons.
  static const String standings = '/standings';

  // ── Tournament flow ────────────────────────────────────────────────────────
  static const String createTournament = '/create-tournament';

  /// C0 -- start a game now, no RSVP step (spec section C2 `/quick`).
  static const String quick = '/quick';
  static const String structureReview = '/structure-review';

  /// The `?from=` query parameter [structureReview] accepts so the back arrow
  /// returns wherever a host came from (e.g. check-in) instead of always
  /// landing on invitation.
  static const String structureReviewFromParam = 'from';

  /// [structureReview] tagged with `?from=` for callers that know where they
  /// are coming from. Omitted when [from] is empty so a bare link keeps a
  /// clean URL.
  static String structureReviewWith(String? from) {
    if (from == null || from.isEmpty) return structureReview;
    return '$structureReview?$structureReviewFromParam='
        '${Uri.encodeComponent(from)}';
  }

  /// Resolves a structure-review location's `?from=` value, or null when the
  /// host arrived bare. Used by the review screen's back arrow.
  static String? structureReviewFrom(Uri uri) {
    final from = uri.queryParameters[structureReviewFromParam];
    return (from == null || from.isEmpty) ? null : from;
  }

  static const String invitation = '/invitation';
  static const String checkIn = '/check-in';
  static const String hostDashboard = '/host-dashboard';
  static const String playerLive = '/player-live';
  static const String rebuySettlement = '/rebuy-settlement';
  static const String finalTable = '/final-table';
  static const String completeTournament = '/complete-tournament';
  /// Spec route `/t/:id/deal` (C-deal). Flat here, like every other game
  /// route, because the game is already the current session — there is one
  /// live game per app, not one per id.
  static const String deal = '/deal';
  /// Spec route `/groups/:gid/import` (B12). Flat, like the other group
  /// routes — the group is the current session, not an id in the path.
  static const String importResults = '/import-results';
  /// Spec route `/groups/:gid/settings` (B9). Every row here edits the group
  /// itself, which is host work, so this sits in the host-only route set.
  static const String groupSettings = '/group-settings';
  /// Spec route `/chips` (B10). Host only — it points the group at one of the
  /// host's own chip sets.
  static const String groupChips = '/group-chips';
  static const String resultPodium = '/result-podium';

  // ── Cash game ──────────────────────────────────────────────────────────────
  static const String cashGame = '/cash-game';
  static const String cashGameLive = '/cash-game-live';

  // ── Account ────────────────────────────────────────────────────────────────
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String stats = '/stats';
  static const String chipSets = '/chip-sets';
  static const String editChipSet = '/edit-chip-set';
  static const String presets = '/presets';

  // Premium (Build Spec v3.1 D4, D12).
  static const String upgrade = '/upgrade';
  static const String checkout = '/checkout';
}

/// The specification's route table, transcribed path for path from Build
/// Specification v3.1 section C2 (101-page combined doc, source 2 pages 17-18),
/// plus the two link rewrites section C3 step 1 names. Addendum 1 changes only
/// the *Who* column of `/history`, and Addendum 2 changes no route, so C2 stands
/// as written.
///
/// The app has always navigated by its own flat paths — `/host-dashboard` rather
/// than `/t/:id/dashboard` — and every `context.go(...)`, every
/// `AppNotification.link` and every existing test names those. So a C2 path is
/// registered *beside* its flat twin, never in place of it, and the three tables
/// below partition all 59 C2 rows:
///
///  * [registered] — 50 rows. C2 names a path the router answers under that
///    name, literal or parameterised. `router.dart` has a `GoRoute` for each.
///  * [redirected] — 7 rows. C2's name differs from the app's and needs no
///    parameter, so the router's `redirect` sends it to its flat twin.
///  * [unimplemented] — 2 rows. C2 names a screen this app does not have, with
///    the reason recorded so the gap is named rather than quietly dropped.
///
/// 50 + 7 + 2 = 59, and `test/route_matrix_test.dart` asserts that partition is
/// the whole of C2, that every row in [registered] and [redirected] resolves
/// through a router built from `router.dart`, and that every flat path in
/// [RoutePaths] still does.
///
/// The maps are keyed by C2's *template* and valued by the flat path the rest
/// of the app uses, which is what lets [flatFor] fold a concrete URL such as
/// `/t/9f3a/dashboard` onto `/host-dashboard` for the route guard.
abstract final class SpecRoutes {
  // The parameter names C2 uses, so a builder reads
  // `state.pathParameters[SpecRoutes.gameIdParam]` rather than a bare `'id'`.
  static const String groupIdParam = 'gid';
  static const String gameIdParam = 'id';
  static const String codeParam = 'code';
  static const String gameCodeParam = 'gameCode';

  // ── A · onboarding and access ─────────────────────────────────────────────
  static const String splash = '/splash';
  static const String start = '/start';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgot = '/forgot';
  static const String join = '/join';
  static const String joinCode = '/join/:code';
  static const String inviteCode = '/invite/:code';
  static const String guestGame = '/g/:gameCode';
  static const String quick = '/quick';

  // ── B · the group hub ─────────────────────────────────────────────────────
  static const String home = '/home';
  static const String games = '/games';
  static const String members = '/members';
  static const String chat = '/chat';
  static const String polls = '/polls';
  static const String notifications = '/notifications';
  static const String history = '/history';
  static const String newGroup = '/groups/new';
  static const String groupSettings = '/groups/:gid/settings';
  static const String groupStandings = '/groups/:gid/standings';
  static const String groupImport = '/groups/:gid/import';
  static const String groupChips = '/groups/:gid/chips';
  static const String groupInvite = '/groups/:gid/invite';

  // ── C · hosting a tournament ──────────────────────────────────────────────
  static const String newTournament = '/t/new';
  static const String tournamentReview = '/t/:id/review';
  static const String tournament = '/t/:id';
  static const String tournamentConfigure = '/t/:id/configure';
  static const String tournamentCheckIn = '/t/:id/checkin';
  static const String tournamentDashboard = '/t/:id/dashboard';
  static const String tournamentLevels = '/t/:id/levels';
  static const String tournamentPlayers = '/t/:id/players';
  static const String tournamentPayouts = '/t/:id/payouts';
  static const String tournamentRebuys = '/t/:id/rebuys';
  static const String tournamentDeal = '/t/:id/deal';
  static const String tournamentFinalTable = '/t/:id/final-table';
  static const String tournamentFinish = '/t/:id/finish';
  static const String tournamentResults = '/t/:id/results';
  static const String tournamentLive = '/t/:id/live';
  static const String tournamentMe = '/t/:id/me';

  // ── D · cash game and TV ──────────────────────────────────────────────────
  static const String tvCode = '/tv/:code';
  static const String newCashGame = '/cash/new';
  static const String cashGame = '/cash/:id';

  // ── E · public tools ──────────────────────────────────────────────────────
  static const String tools = '/tools';
  static const String toolBlinds = '/tools/blinds';
  static const String toolClock = '/tools/clock';
  static const String toolIcm = '/tools/icm';
  static const String toolPayouts = '/tools/payouts';
  static const String toolQuickBlind = '/tools/quick-blind';

  // ── F · account ───────────────────────────────────────────────────────────
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String stats = '/stats';
  static const String chipSets = '/chipsets';
  static const String chipSet = '/chipsets/:id';
  static const String presets = '/presets';

  // ── G · premium ───────────────────────────────────────────────────────────
  static const String premium = '/premium';
  static const String premiumCheckout = '/premium/checkout';

  // ── H · legal and support ─────────────────────────────────────────────────
  static const String privacy = '/privacy';
  static const String terms = '/terms';
  static const String support = '/support';

  /// C3 step 1: "`/game/{CODE}` or `/j/{CODE}` → rewrite to `/join/{CODE}`".
  /// These two are share links, not destinations, so they are rewritten rather
  /// than registered. `/join/:code` *is* a route in its own right, so the
  /// rewrite hands the code straight to it instead of turning it into a query.
  static const List<String> joinRewrites = <String>['/game/', '/j/'];

  /// Every C2 path the router answers under C2's own name, paired with the flat
  /// path the rest of the app navigates by. Fifty rows: every C2 row that is
  /// neither [redirected] nor [unimplemented].
  ///
  /// Rows whose two values are equal are kept so the table reads like C2 in
  /// full. A row whose C2 path carries a parameter names that parameter in the
  /// template, and `router.dart` registers the template as a real `GoRoute`, so
  /// `/t/9f3a/dashboard` resolves and `state.pathParameters['id']` holds
  /// `9f3a` when the page is built.
  ///
  /// The value is what the guard reads, not what the URL becomes: [flatFor]
  /// folds a concrete C2 URL onto this value so the host set, the co-host set,
  /// the public set and `ScreenShell.requiredPath` all apply unchanged to the
  /// C2-shaped URL.
  static const Map<String, String> registered = <String, String>{
    // ── A · onboarding and access ───────────────────────────────────────────
    // A8's `/invite/:code` is A8's join preview, which is the screen the app
    // exposes at `/join-group?code=`; A6's `/g/:gameCode` and D3's `/tv/:code`
    // both arrive as a code, and `/join` is the screen that classifies a code
    // into group / game / TV (C2's note on `/join/:code`) before the guest
    // shell opens.
    splash: RoutePaths.splash,
    login: RoutePaths.login,
    register: RoutePaths.register,
    join: RoutePaths.join,
    joinCode: RoutePaths.join,
    inviteCode: RoutePaths.joinGroup,
    guestGame: RoutePaths.join,
    quick: RoutePaths.quick,

    // ── B · the group hub ───────────────────────────────────────────────────
    home: RoutePaths.home,
    members: RoutePaths.members,
    chat: RoutePaths.chat,
    polls: RoutePaths.polls,
    notifications: RoutePaths.notifications,
    history: RoutePaths.history,
    groupSettings: RoutePaths.groupSettings,
    groupStandings: RoutePaths.standings,
    groupImport: RoutePaths.importResults,
    groupChips: RoutePaths.groupChips,

    // ── C · hosting a tournament ────────────────────────────────────────────
    // `/t/:id/configure` is C-cfg, which reopens the wizard's editor on the game
    // that exists; the app's wizard screen is the one that does it. `/t/:id/levels`
    // is C2's host variant of C11 and draws the same editor as `/t/:id/review`.
    // `/t/:id/me` is C4p, the player's own check-in, which the app draws inside
    // the invitation screen as a primary action whose state is the roster row.
    newTournament: RoutePaths.createTournament,
    tournament: RoutePaths.invitation,
    tournamentReview: RoutePaths.structureReview,
    tournamentConfigure: RoutePaths.createTournament,
    tournamentCheckIn: RoutePaths.checkIn,
    tournamentDashboard: RoutePaths.hostDashboard,
    tournamentLevels: RoutePaths.structureReview,
    tournamentPlayers: RoutePaths.checkIn,
    tournamentPayouts: RoutePaths.playerLive,
    tournamentRebuys: RoutePaths.rebuySettlement,
    tournamentDeal: RoutePaths.deal,
    tournamentFinalTable: RoutePaths.finalTable,
    tournamentFinish: RoutePaths.completeTournament,
    tournamentResults: RoutePaths.resultPodium,
    tournamentLive: RoutePaths.playerLive,
    tournamentMe: RoutePaths.invitation,

    // ── D · cash game and TV ────────────────────────────────────────────────
    tvCode: RoutePaths.join,
    newCashGame: RoutePaths.cashGame,
    cashGame: RoutePaths.cashGameLive,

    // ── E · public tools ────────────────────────────────────────────────────
    // `/tools/blinds` is the one tool C2 spells differently from the app; it is
    // in [redirected], not here.
    tools: RoutePaths.tools,
    toolClock: RoutePaths.toolClock,
    toolIcm: RoutePaths.toolIcm,
    toolPayouts: RoutePaths.toolPayouts,
    toolQuickBlind: RoutePaths.toolQuickBlind,

    // ── F · account ─────────────────────────────────────────────────────────
    profile: RoutePaths.profile,
    settings: RoutePaths.settings,
    stats: RoutePaths.stats,
    chipSet: RoutePaths.editChipSet,
    presets: RoutePaths.presets,

    // ── H · legal and support ───────────────────────────────────────────────
    privacy: RoutePaths.privacy,
    terms: RoutePaths.terms,
    support: RoutePaths.support,
  };

  /// The seven C2 paths that are a *renaming* of a screen the app already routes
  /// to, paired with that flat path. None of them carries a parameter, so the
  /// router's `redirect` sends them to their flat twin and the query string
  /// rides along.
  ///
  /// Every other C2 row is in [registered] or [unimplemented] — there is no
  /// fourth case, which `test/route_matrix_test.dart` asserts.
  ///
  /// The keys below are the C2 templates, not symbolic row names. Inside this
  /// class a bare `start` resolves to [start] above, so `start:` here means
  /// `'/start':` — which is what [flatFor] matches a concrete URL against. The
  /// `SpecRoutes.` prefix is written out anyway: it reads as a constant rather
  /// than as a name that happens to be defined twice, and it stops a future
  /// rename from quietly turning a key into a lookup that no longer compiles.
  static const Map<String, String> redirected = <String, String>{
    SpecRoutes.start: RoutePaths.landing,
    SpecRoutes.forgot: RoutePaths.forgotPassword,
    SpecRoutes.games: RoutePaths.group,
    SpecRoutes.toolBlinds: RoutePaths.toolBlinds,
    SpecRoutes.chipSets: RoutePaths.chipSets,
    SpecRoutes.premium: RoutePaths.upgrade,
    SpecRoutes.premiumCheckout: RoutePaths.checkout,
  };

  /// The C2 paths this app has no screen for, each with the reason.
  ///
  /// They are listed rather than dropped so the matrix has a closed set, and
  /// they are deliberately *not* in [registered] or [redirected]: a row there is
  /// a promise that the path resolves, and these two do not. A URL in either
  /// shape reaches the router's `errorBuilder` and says so, rather than landing
  /// somewhere plausible and wrong.
  static const Map<String, String> unimplemented = <String, String>{
    newGroup:
        'no create-group screen — B8 is a dialog (widgets/create_group_dialog.dart) '
            'opened from the drawer, the FAB and the nav, and a dialog cannot be a '
            'route target without a screen that hosts it',
    groupInvite:
        'no invite screen — B13 is the "Invite link / QR" modal on B2 '
            '(group_screen.dart `_showInviteModal`), which the router cannot open '
            'on arrival; `/invite/:code` (A8) is the shared link\'s target and is '
            'implemented',
  };

  /// Folds a concrete specification URL onto the path the rest of the app uses:
  /// `/t/9f3a/live` → `/player-live`, `/start` → `/`, and anything these tables
  /// do not know → [path] unchanged.
  ///
  /// The router's guard — the host set, the co-host set, the public set, and
  /// `ScreenShell.requiredPath` — is written in flat paths because that is what
  /// the app navigates by. Without this fold a deep link to `/t/9f3a/dashboard`
  /// would reach a host-only screen without the host check `/host-dashboard`
  /// gets.
  ///
  /// A literal C2 path is looked up first, or `/t/new` would be read as a
  /// tournament id and folded onto `/invitation`.
  static String flatFor(String path) {
    final registeredAlias = registered[path];
    if (registeredAlias != null) return registeredAlias;
    final redirectedAlias = redirected[path];
    if (redirectedAlias != null) return redirectedAlias;
    for (final entry in registered.entries) {
      if (_isInstanceOf(entry.key, path)) return entry.value;
    }
    for (final entry in redirected.entries) {
      if (_isInstanceOf(entry.key, path)) return entry.value;
    }
    return path;
  }

  /// Whether [path] is an instance of the [template] C2 writes: the same
  /// number of segments, the same literal segments, and any non-empty value
  /// for each `:name`.
  static bool _isInstanceOf(String template, String path) {
    final want = template.split('/');
    final got = path.split('/');
    if (want.length != got.length) return false;
    for (var i = 0; i < want.length; i++) {
      final segment = want[i];
      // A leading '/' splits to an empty first segment in both, and no
      // template carries a trailing '/'.
      if (segment.isEmpty) continue;
      if (segment.startsWith(':')) {
        if (got[i].isEmpty) return false;
      } else if (segment != got[i]) {
        return false;
      }
    }
    return true;
  }
}
