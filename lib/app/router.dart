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
import '../screens/shell/group_screen.dart';
import '../screens/shell/history_screen.dart';
import '../screens/shell/home_screen.dart';
import '../screens/shell/notifications_screen.dart';
import '../screens/shell/profile_screen.dart';
import '../screens/shell/settings_screen.dart';
import '../screens/shell/stats_screen.dart';
import '../screens/shell/chip_sets_screen.dart';
import '../screens/shell/edit_chip_set_screen.dart';
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
      builder: (context, state) => const AuthScreen(mode: AuthMode.login),
    ),
    GoRoute(
      path: RoutePaths.register,
      builder: (context, state) => const AuthScreen(mode: AuthMode.register),
    ),
    GoRoute(
      path: RoutePaths.forgotPassword,
      builder: (context, state) => const AuthScreen(mode: AuthMode.forgotPassword),
    ),
    GoRoute(
      path: RoutePaths.tvMode,
      builder: (context, state) => const TVModeScreen(),
    ),
    GoRoute(
      path: RoutePaths.guestFlow,
      builder: (context, state) => const GuestFlowScreen(),
    ),

    // ── App shell ────────────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.home,
      builder: (context, state) => shell(const HomeScreen()),
    ),
    GoRoute(
      path: RoutePaths.group,
      builder: (context, state) => shell(const GroupScreen()),
    ),
    GoRoute(
      path: RoutePaths.notifications,
      builder: (context, state) => shell(const NotificationsScreen()),
    ),
    GoRoute(
      path: RoutePaths.history,
      builder: (context, state) => shell(const HistoryScreen()),
    ),
    GoRoute(
      path: RoutePaths.profile,
      builder: (context, state) => shell(const ProfileScreen()),
    ),
    GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => shell(const SettingsScreen()),
    ),
    GoRoute(
      path: RoutePaths.stats,
      builder: (context, state) => shell(const StatsScreen()),
    ),
    GoRoute(
      path: RoutePaths.chipSets,
      builder: (context, state) => shell(const ChipSetsScreen()),
    ),
    GoRoute(
      path: RoutePaths.editChipSet,
      builder: (context, state) {
        final id = state.extra as String?;
        return shell(EditChipSetScreen(chipSetId: id));
      },
    ),

    // ── Tournament flow ──────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.createTournament,
      builder: (context, state) => shell(const CreateTournamentScreen()),
    ),
    GoRoute(
      path: RoutePaths.structureReview,
      builder: (context, state) => shell(const StructureReviewScreen()),
    ),
    GoRoute(
      path: RoutePaths.invitation,
      builder: (context, state) => shell(const InvitationScreen()),
    ),
    GoRoute(
      path: RoutePaths.checkIn,
      builder: (context, state) => shell(const CheckInScreen()),
    ),
    GoRoute(
      path: RoutePaths.adminDashboard,
      builder: (context, state) => shell(const AdminDashboardScreen()),
    ),
    GoRoute(
      path: RoutePaths.playerLive,
      builder: (context, state) => shell(const PlayerLiveScreen()),
    ),
    GoRoute(
      path: RoutePaths.rebuySettlement,
      builder: (context, state) => shell(const RebuySettlementScreen()),
    ),
    GoRoute(
      path: RoutePaths.finalTable,
      builder: (context, state) => shell(const FinalTableScreen()),
    ),
    GoRoute(
      path: RoutePaths.completeTournament,
      builder: (context, state) => shell(const CompleteTournamentScreen()),
    ),
    GoRoute(
      path: RoutePaths.resultPodium,
      builder: (context, state) => shell(const ResultPodiumScreen()),
    ),

    // ── Cash game ────────────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.cashGame,
      builder: (context, state) => shell(const CashGameScreen()),
    ),
    GoRoute(
      path: RoutePaths.cashGameLive,
      builder: (context, state) => shell(const CashGameLiveScreen()),
    ),
  ],
);

/// Wraps a content page in the persistent app shell with a smooth entrance animation.
Widget shell(Widget child) => ScreenShell(
      child: child
          .animate(key: ValueKey(child.runtimeType))
          .fadeIn(duration: 300.ms, curve: Curves.easeOut)
          .slideY(begin: 0.05),
    );
