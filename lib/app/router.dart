import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_provider.dart';

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
import '../screens/shell/join_group_screen.dart';
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
import '../app/colors.dart';
import 'route_paths.dart';

/// Routes reachable without a signed-in account.
const _publicPaths = {
  RoutePaths.splash,
  RoutePaths.landing,
  RoutePaths.login,
  RoutePaths.register,
  RoutePaths.forgotPassword,
  RoutePaths.tvMode,
  RoutePaths.guestFlow,
  RoutePaths.privacy,
  RoutePaths.terms,
  RoutePaths.support,
  RoutePaths.join,
};

/// Admin-only routes — non-admins are bounced to invitation (if a game exists)
/// or home.
const _adminPaths = {
  RoutePaths.createTournament,
  RoutePaths.checkIn,
  RoutePaths.adminDashboard,
  RoutePaths.finalTable,
  RoutePaths.rebuySettlement,
  RoutePaths.completeTournament,
  RoutePaths.structureReview,
};

/// Shell routes a guest session (no account) may enter — mirrors
/// `ScreenShell._guestAllowed`.
const _guestAllowed = {RoutePaths.playerLive, RoutePaths.resultPodium};

/// Builds the app router wired to [app] so the auth guard re-evaluates on
/// every provider change (sign-in/out and the initial `authReady` flip).
GoRouter buildAppRouter(AppProvider app) {
  // Preserve deep-link paths that arrive before Firebase resolves.
  String? pendingDeepLink;

  return GoRouter(
  initialLocation: RoutePaths.splash,
  refreshListenable: app,
  redirect: (context, state) {
    final path = state.uri.path;
    final ready = app.authReady;
    final authed = app.isAuthenticated;

    // Legacy shared game links (`/game/FP2608`) resolve through the public
    // unified join screen — rewrite before the auth guard can bounce a guest.
    if (path.startsWith('/game/')) {
      final code = path.substring('/game/'.length);
      return '${RoutePaths.join}?code=${Uri.encodeComponent(code)}';
    }

    // Hold every navigation at splash until Firebase resolves the persisted
    // session, so guards never run against a half-initialised auth state.
    if (!ready) {
      // Save the original deep-link only once (the splash screen may navigate
      // to / before Firebase resolves, which must not overwrite it).
      if (path != RoutePaths.splash && pendingDeepLink == null) {
        pendingDeepLink = state.uri.toString();
      }
      return path == RoutePaths.splash ? null : RoutePaths.splash;
    }

    // Admin-only routes: bounce non-admins away before the screen renders.
    if (_adminPaths.contains(path) && !app.isAdmin) {
      return app.currentGame != null ? RoutePaths.invitation : RoutePaths.home;
    }

    final guestOk = app.hasGuestSession && _guestAllowed.contains(path);
    if (!authed && !guestOk && !_publicPaths.contains(path)) {
      final query = state.uri.query.isEmpty ? '' : '?${state.uri.query}';
      return '${RoutePaths.login}?next=${Uri.encodeComponent('$path$query')}';
    }

    // Consume a saved deep link as soon as auth resolves — the splash screen
    // may have already navigated to landing (/) before we could redirect.
    if (pendingDeepLink != null) {
      final deepLink = pendingDeepLink!;
      pendingDeepLink = null;
      // Public deep links (guest join, game links, TV) resolve for everyone;
      // only protected targets route through sign-in first.
      final deepPath = Uri.tryParse(deepLink)?.path ?? deepLink;
      if (authed ||
          _publicPaths.contains(deepPath) ||
          deepPath.startsWith('/game/')) {
        return deepLink;
      }
      return '${RoutePaths.login}?next=${Uri.encodeComponent(deepLink)}';
    }
    if (authed &&
        (path == RoutePaths.splash ||
            path == RoutePaths.login ||
            path == RoutePaths.register ||
            path == RoutePaths.forgotPassword)) {
      // If the auth screen captured a ?next= deep link, honour it so that
      // join-via-link and other protected-route flows survive the sign-in.
      final next = state.uri.queryParameters['next'];
      if (next != null && next.startsWith('/')) return next;
      return RoutePaths.home;
    }
    return null;
  },
  // Catch bad/unknown routes and show a friendly page instead of a red crash.
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppColors.mutedForeground, size: 48),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.uri.toString(),
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => context.go(RoutePaths.home),
            child: const Text('Go to Home'),
          ),
        ],
      ),
    ),
  ),
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
      builder: (context, state) =>
          JoinScreen(initialCode: state.uri.queryParameters['code']),
    ),

    // ── App shell ────────────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.home,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const HomeScreen(), path: RoutePaths.home)),
    ),
    GoRoute(
      path: RoutePaths.group,
      pageBuilder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        return NoTransitionPage(
          key: ValueKey(state.uri.path),
          child: shell(GroupScreen(initialTab: tab), path: RoutePaths.group),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.joinGroup,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(
        JoinGroupScreen(code: state.uri.queryParameters['code'] ?? ''), path: RoutePaths.joinGroup,
      )),
    ),
    GoRoute(
      path: RoutePaths.notifications,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const NotificationsScreen(), path: RoutePaths.notifications)),
    ),
    GoRoute(
      path: RoutePaths.history,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const HistoryScreen(), path: RoutePaths.history)),
    ),
    GoRoute(
      path: RoutePaths.profile,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const ProfileScreen(), path: RoutePaths.profile)),
    ),
    GoRoute(
      path: RoutePaths.settings,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const SettingsScreen(), path: RoutePaths.settings)),
    ),
    GoRoute(
      path: RoutePaths.stats,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const StatsScreen(), path: RoutePaths.stats)),
    ),
    GoRoute(
      path: RoutePaths.chipSets,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const ChipSetsScreen(), path: RoutePaths.chipSets)),
    ),
    GoRoute(
      path: RoutePaths.presets,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const PresetsScreen(), path: RoutePaths.presets)),
    ),
    GoRoute(
      path: RoutePaths.editChipSet,
      pageBuilder: (context, state) {
        final id = state.extra as String?;
        return NoTransitionPage(
          key: ValueKey(state.uri.path),
          child: shell(
          EditChipSetScreen(chipSetId: id), path: RoutePaths.editChipSet,
        ),
        );
      },
    ),

    // ── Tournament flow ──────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.createTournament,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(
        CreateTournamentScreen(presetId: state.uri.queryParameters['preset']), path: RoutePaths.createTournament,
      )),
    ),
    GoRoute(
      path: RoutePaths.structureReview,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(
        const StructureReviewScreen(), path: RoutePaths.structureReview,
      )),
    ),
    GoRoute(
      path: RoutePaths.invitation,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const InvitationScreen(), path: RoutePaths.invitation)),
    ),
    GoRoute(
      path: RoutePaths.checkIn,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const CheckInScreen(), path: RoutePaths.checkIn)),
    ),
    GoRoute(
      path: RoutePaths.adminDashboard,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const AdminDashboardScreen(), path: RoutePaths.adminDashboard)),
    ),
    GoRoute(
      path: RoutePaths.playerLive,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const PlayerLiveScreen(), path: RoutePaths.playerLive)),
    ),
    GoRoute(
      path: RoutePaths.rebuySettlement,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(
        const RebuySettlementScreen(), path: RoutePaths.rebuySettlement,
      )),
    ),
    GoRoute(
      path: RoutePaths.finalTable,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const FinalTableScreen(), path: RoutePaths.finalTable)),
    ),
    GoRoute(
      path: RoutePaths.completeTournament,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(
        const CompleteTournamentScreen(), path: RoutePaths.completeTournament,
      )),
    ),
    GoRoute(
      path: RoutePaths.resultPodium,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const ResultPodiumScreen(), path: RoutePaths.resultPodium)),
    ),

    // ── Cash game ────────────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.cashGame,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const CashGameScreen(), path: RoutePaths.cashGame)),
    ),
    GoRoute(
      path: RoutePaths.cashGameLive,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const CashGameLiveScreen(), path: RoutePaths.cashGameLive)),
    ),
  ],
);
}

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
