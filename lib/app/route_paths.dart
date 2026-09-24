/// Central route path registry used by GoRouter and nav widgets.
/// Mirrors the screen ids from the web app's `AppContext` navigate().
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
  static const String notifications = '/notifications';
  static const String history = '/history';

  // ── Tournament flow ────────────────────────────────────────────────────────
  static const String createTournament = '/create-tournament';
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
  static const String adminDashboard = '/admin-dashboard';
  static const String playerLive = '/player-live';
  static const String rebuySettlement = '/rebuy-settlement';
  static const String finalTable = '/final-table';
  static const String completeTournament = '/complete-tournament';
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

  // Premium (specification v11 section 3).
  static const String upgrade = '/upgrade';
  static const String checkout = '/checkout';
}
