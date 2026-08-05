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

  // ── App shell ──────────────────────────────────────────────────────────────
  static const String home = '/home';
  static const String group = '/group';
  static const String notifications = '/notifications';
  static const String history = '/history';

  // ── Tournament flow ────────────────────────────────────────────────────────
  static const String createTournament = '/create-tournament';
  static const String structureReview = '/structure-review';
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
}
