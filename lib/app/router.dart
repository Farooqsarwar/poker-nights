import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../screens/cash/cash_game_live_screen.dart';
import '../screens/cash/cash_game_screen.dart';
import '../screens/public/auth_screen.dart';
import '../screens/public/guest_flow_screen.dart';
import '../screens/public/landing_screen.dart';
import '../screens/public/splash_screen.dart';
import '../screens/public/tv_mode_screen.dart';
import '../screens/public/privacy_screen.dart';
import '../screens/public/terms_screen.dart';
import '../screens/public/support_screen.dart';
import '../screens/public/join_screen.dart';
import '../screens/shell/group_screen.dart';
import '../screens/shell/history_screen.dart';
import '../screens/shell/home_screen.dart';
import '../screens/shell/notifications_screen.dart';
import '../screens/shell/profile_screen.dart';
import '../screens/shell/settings_screen.dart';
import '../screens/shell/stats_screen.dart';
import '../screens/shell/chip_sets_screen.dart';
import '../screens/shell/edit_chip_set_screen.dart';
import '../screens/shell/presets_screen.dart';
import '../screens/tournament/admin_dashboard_screen.dart';
import '../screens/tournament/check_in_screen.dart';
import '../screens/tournament/complete_tournament_screen.dart';
import '../screens/tournament/create_tournament_screen.dart';
import '../screens/tournament/final_table_screen.dart';
import '../screens/tournament/invitation_screen.dart';
import '../screens/tournament/player_live_screen.dart';
import '../screens/tournament/rebuy_settlement_screen.dart';
import '../screens/tournament/result_podium_screen.dart';
import '../screens/tournament/structure_review_screen.dart';
import '../widgets/screen_shell.dart';
import 'route_paths.dart';

/// App-wide route table. Screens mirror the web `AppContext` screen ids:
/// public and TV/guest screens are full-screen; everything else sits inside
/// the persistent app shell (sidebar on desktop, drawer + bottom nav on mobile).
final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.splash,
  routes: [
    GoRoute(
      path: RoutePaths.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RoutePaths.landing,
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: RoutePaths.login,
      builder: (context, state) =>
          AuthScreen(mode: AuthMode.login, next: _nextParam(state)),
    ),
    GoRoute(
      path: RoutePaths.register,
      builder: (context, state) =>
          AuthScreen(mode: AuthMode.register, next: _nextParam(state)),
    ),
    GoRoute(
      path: RoutePaths.forgotPassword,
      builder: (context, state) =>
          AuthScreen(mode: AuthMode.forgotPassword, next: _nextParam(state)),
    ),
    GoRoute(
      path: RoutePaths.tvMode,
      builder: (context, state) => const TVModeScreen(),
    ),
    GoRoute(
      path: RoutePaths.guestFlow,
      builder: (context, state) => const GuestFlowScreen(),
    ),
    GoRoute(
      path: RoutePaths.privacy,
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: RoutePaths.terms,
      builder: (context, state) => const TermsScreen(),
    ),
    GoRoute(
      path: RoutePaths.support,
      builder: (context, state) => const SupportScreen(),
    ),
    GoRoute(
      path: RoutePaths.join,
      builder: (context, state) => const JoinScreen(),
    ),

    // ── App shell ────────────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.home,
      builder: (context, state) => shell(const HomeScreen(), path: RoutePaths.home),
    ),
    GoRoute(
      path: RoutePaths.group,
      builder: (context, state) => shell(const GroupScreen(), path: RoutePaths.group),
    ),
    GoRoute(
      path: RoutePaths.notifications,
      builder: (context, state) =>
          shell(const NotificationsScreen(), path: RoutePaths.notifications),
    ),
    GoRoute(
      path: RoutePaths.history,
      builder: (context, state) => shell(const HistoryScreen(), path: RoutePaths.history),
    ),
    GoRoute(
      path: RoutePaths.profile,
      builder: (context, state) => shell(const ProfileScreen(), path: RoutePaths.profile),
    ),
    GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => shell(const SettingsScreen(), path: RoutePaths.settings),
    ),
    GoRoute(
      path: RoutePaths.stats,
      builder: (context, state) => shell(const StatsScreen(), path: RoutePaths.stats),
    ),
    GoRoute(
      path: RoutePaths.chipSets,
      builder: (context, state) => shell(const ChipSetsScreen(), path: RoutePaths.chipSets),
    ),
    GoRoute(
      path: RoutePaths.presets,
      builder: (context, state) => shell(const PresetsScreen(), path: RoutePaths.presets),
    ),
    GoRoute(
      path: RoutePaths.editChipSet,
      builder: (context, state) {
        final id = state.extra as String?;
        return shell(EditChipSetScreen(chipSetId: id), path: RoutePaths.editChipSet);
      },
    ),

    // ── Tournament flow ──────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.createTournament,
      builder: (context, state) => shell(
        CreateTournamentScreen(
          presetId: state.uri.queryParameters['preset'],
        ),
        path: RoutePaths.createTournament,
      ),
    ),
    GoRoute(
      path: RoutePaths.structureReview,
      builder: (context, state) =>
          shell(const StructureReviewScreen(), path: RoutePaths.structureReview),
    ),
    GoRoute(
      path: RoutePaths.invitation,
      builder: (context, state) =>
          shell(const InvitationScreen(), path: RoutePaths.invitation),
    ),
    GoRoute(
      path: RoutePaths.checkIn,
      builder: (context, state) => shell(const CheckInScreen(), path: RoutePaths.checkIn),
    ),
    GoRoute(
      path: RoutePaths.adminDashboard,
      builder: (context, state) =>
          shell(const AdminDashboardScreen(), path: RoutePaths.adminDashboard),
    ),
    GoRoute(
      path: RoutePaths.playerLive,
      builder: (context, state) =>
          shell(const PlayerLiveScreen(), path: RoutePaths.playerLive),
    ),
    GoRoute(
      path: RoutePaths.rebuySettlement,
      builder: (context, state) =>
          shell(const RebuySettlementScreen(), path: RoutePaths.rebuySettlement),
    ),
    GoRoute(
      path: RoutePaths.finalTable,
      builder: (context, state) => shell(const FinalTableScreen(), path: RoutePaths.finalTable),
    ),
    GoRoute(
      path: RoutePaths.completeTournament,
      builder: (context, state) =>
          shell(const CompleteTournamentScreen(), path: RoutePaths.completeTournament),
    ),
    GoRoute(
      path: RoutePaths.resultPodium,
      builder: (context, state) =>
          shell(const ResultPodiumScreen(), path: RoutePaths.resultPodium),
    ),

    // ── Cash game ────────────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.cashGame,
      builder: (context, state) => shell(const CashGameScreen(), path: RoutePaths.cashGame),
    ),
    GoRoute(
      path: RoutePaths.cashGameLive,
      builder: (context, state) =>
          shell(const CashGameLiveScreen(), path: RoutePaths.cashGameLive),
    ),
  ],
);

/// Wraps a content page in the persistent app shell with a smooth entrance
/// animation and records the route path for the shell's access guard.
Widget shell(Widget child, {required String path}) => ScreenShell(
      requiredPath: path,
      child: child
          .animate(key: ValueKey(child.runtimeType))
          .fadeIn(duration: 300.ms, curve: Curves.easeOut)
          .slideY(begin: 0.05),
    );

/// Reads the `?next=` query param so auth can redirect back to the page the
/// user originally tried to reach.
String? _nextParam(GoRouterState state) {
  final next = state.uri.queryParameters['next'];
  return (next == null || !next.startsWith('/')) ? null : next;
}
