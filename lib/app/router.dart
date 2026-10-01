import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import 'typography.dart';

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
import '../screens/public/tools_screen.dart';
import '../screens/shell/chat_screen.dart';
import '../screens/shell/group_screen.dart';
import '../screens/shell/history_screen.dart';
import '../screens/shell/home_screen.dart';
import '../screens/shell/join_group_screen.dart';
import '../screens/shell/group_chips_screen.dart';
import '../screens/shell/group_settings_screen.dart';
import '../screens/shell/import_results_screen.dart';
import '../screens/shell/members_screen.dart';
import '../screens/shell/notifications_screen.dart';
import '../screens/shell/polls_screen.dart';
import '../screens/shell/reports_screen.dart';
import '../screens/shell/standings_screen.dart';
import '../screens/shell/profile_screen.dart';
import '../screens/shell/settings_screen.dart';
import '../screens/shell/stats_screen.dart';
import '../screens/shell/chip_sets_screen.dart';
import '../screens/premium/checkout_screen.dart';
import '../screens/premium/upgrade_screen.dart';
import '../screens/shell/edit_chip_set_screen.dart';
import '../screens/shell/presets_screen.dart';
import '../screens/tournament/admin_dashboard_screen.dart';
import '../screens/tournament/check_in_screen.dart';
import '../screens/tournament/complete_tournament_screen.dart';
import '../screens/tournament/deal_screen.dart';
import '../screens/tournament/create_tournament_screen.dart';
import '../screens/tournament/quick_start_screen.dart';
import '../screens/tournament/final_table_screen.dart';
import '../screens/tournament/invitation_screen.dart';
import '../screens/tournament/payouts_screen.dart';
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
  RoutePaths.quick,
  RoutePaths.joinGroup,
  RoutePaths.privacy,
  RoutePaths.terms,
  RoutePaths.support,
  RoutePaths.join,
  RoutePaths.tools,
  RoutePaths.toolBlinds,
  RoutePaths.toolClock,
  RoutePaths.toolIcm,
  RoutePaths.toolPayouts,
  RoutePaths.toolQuickBlind,
};

/// Build Spec section C2 paths that map onto an existing screen live in
/// `SpecRoutes.registered` and `SpecRoutes.redirected` (spec `route_paths.dart`),
/// so there is one table rather than one here and one there. C3 step 1's
/// `/game/{CODE}` and `/j/{CODE}` rewrites are `SpecRoutes.joinRewrites`.
///
/// Every set below is written in flat paths, because that is what the app
/// navigates by. The guard folds a C2-shaped URL onto its flat twin with
/// `SpecRoutes.flatFor` before it consults any of them, so `/t/9f3a/dashboard`
/// is gated exactly as `/host-dashboard` is.

/// Host-only routes — non-hosts are bounced to invitation (if a game exists)
/// or home.
const _adminPaths = {
  RoutePaths.createTournament,
  RoutePaths.checkIn,
  RoutePaths.hostDashboard,
  RoutePaths.finalTable,
  RoutePaths.rebuySettlement,
  RoutePaths.completeTournament,
  RoutePaths.deal,
  RoutePaths.importResults,
  RoutePaths.groupSettings,
  RoutePaths.groupChips,
  RoutePaths.structureReview,
};

/// Routes a tournament co-host may open, not just the group owner.
///
/// Kept separate from [_adminPaths] on purpose. D15 gives a co-host the bust,
/// rebuy, pause, clock and check-in actions, but NOT tournament creation or
/// group settings — so widening [_adminPaths] wholesale would hand a co-host
/// `createTournament`, `groupSettings` and `delete` rights it must not have.
const _coHostPaths = {
  RoutePaths.rebuySettlement,
};

/// Shell routes a guest session (no account) may enter — mirrors
/// `ScreenShell._guestAllowed`, which is the set that actually draws the guest
/// shell. The two sets are kept identical on purpose: widening one alone
/// would pass the router guard and then be refused by `ScreenShell`'s gate
/// a frame later (or vice versa).
///
/// C3 lists `/t/:id/me` (C4p, "guest shell for guests") as a guest route, so
/// `/t/:id/me` folds onto `RoutePaths.invitation` and both sets admit it. The
/// builder below still sends link guests to the guest flow — the invitation
/// screen itself stays member-oriented.
const _guestAllowed = {
  RoutePaths.playerLive,
  RoutePaths.resultPodium,
  RoutePaths.invitation,
};

/// Builds the app router wired to [app] so the auth guard re-evaluates on
/// every provider change (sign-in/out and the initial `authReady` flip).
/// Adapts [AppProvider] into a [Listenable] that fires only when a field the
/// router's `redirect` reads has actually changed. Collapses the provider's
/// high-frequency notifications (clock tick, every Firestore snapshot) down to
/// the handful of transitions that can change routing.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._app) {
    _last = _snapshot();
    _app.addListener(_onProviderChanged);
  }

  final AppProvider _app;
  late List<Object?> _last;

  List<Object?> _snapshot() => <Object?>[
        _app.authReady,
        _app.isAuthenticated,
        _app.hasGuestSession,
        _app.isAdmin,
        _app.canOperateTheClock,
        _app.currentGame?.id,
        _app.currentGame?.status,
        _app.currentGroup.id,
      ];

  void _onProviderChanged() {
    final next = _snapshot();
    var changed = next.length != _last.length;
    for (var i = 0; !changed && i < next.length; i++) {
      changed = next[i] != _last[i];
    }
    if (changed) {
      _last = next;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _app.removeListener(_onProviderChanged);
    super.dispose();
  }
}

GoRouter buildAppRouter(AppProvider app) {
  // Preserve deep-link paths that arrive before Firebase resolves.
  String? pendingDeepLink;

  return GoRouter(
  initialLocation: RoutePaths.splash,
  // Re-evaluate `redirect` only when something the guard actually reads
  // changes — NOT on every AppProvider.notifyListeners(). The provider notifies
  // once per second from the tournament clock and again on every one of ~15
  // Firestore stream deliveries; feeding all of that straight into GoRouter
  // re-ran the guard constantly and let a one-frame blip in `isAdmin` /
  // `currentGame` (e.g. while a group bundle re-subscribes) bounce the user
  // out of the screen they were mid-flow on.
  refreshListenable: _RouterRefresh(app),
  redirect: (context, state) {
    final path = state.uri.path;
    // The same screen has two names: the one this app has always navigated by
    // and the one Build Spec section C2 writes. `flat` is the first, so every
    // guard below reads it — otherwise a deep link to `/t/9f3a/dashboard`
    // would reach a host-only screen without the host check `/host-dashboard`
    // gets. What the guard *returns* is unaffected: the location the caller
    // asked for still resolves, so the URL in the bar is the one they opened.
    final flat = SpecRoutes.flatFor(path);
    final ready = app.authReady;
    final authed = app.isAuthenticated;

    // Legacy shared game links, C3 step 1: "`/game/{CODE}` or `/j/{CODE}` →
    // rewrite to `/join/{CODE}`". Resolved through the public unified join
    // screen before the auth guard can bounce a guest. `/j/{CODE}` is the half
    // this router never had; `/join/:code` is a route in its own right below,
    // so the code arrives there as a path parameter rather than as a query.
    for (final prefix in SpecRoutes.joinRewrites) {
      if (path.startsWith(prefix) && path.length > prefix.length) {
        final code = Uri.encodeComponent(path.substring(prefix.length));
        return '${SpecRoutes.join}/$code';
      }
    }

    // The seven C2 paths that are only a renaming of a screen the app already
    // routes to: `/start` → `/`, `/games` → `/group`, `/premium/checkout` →
    // `/checkout` and so on. The query string rides along untouched.
    //
    // A C2 path that is a route in its own right — every parameterised one, plus
    // `/t/new` and `/cash/new` — is *not* here: it is registered below with its
    // own `GoRoute`, so its `state.pathParameters` survive to the builder and
    // the URL stays the one the user opened. [flatFor] above still folds those
    // onto their flat twin so every guard below reads a path it recognises.
    final alias = SpecRoutes.redirected[path];
    if (alias != null) {
      final query = state.uri.query.isEmpty ? '' : '?${state.uri.query}';
      return '$alias$query';
    }

    // Single navigation layer: the old hub tabs are now top-level screens.
    // Rewrite legacy `/group?tab=X` links to their dedicated route.
    if (path == RoutePaths.group) {
      switch (state.uri.queryParameters['tab']) {
        case 'chat':
          return RoutePaths.chat;
        case 'members':
          return RoutePaths.members;
        case 'polls':
          return RoutePaths.polls;
        case 'history':
          return RoutePaths.history;
      }
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

    // Co-host routes: D15 lets a co-host do the rebuy work, so the screen's own
    // gate would never be reached if this bounced them first.
    if (_coHostPaths.contains(flat) && !app.canOperateTheClock) {
      return app.currentGame != null ? RoutePaths.invitation : RoutePaths.home;
    }

    // Host-only routes: bounce non-hosts away before the screen renders.
    if (_adminPaths.contains(flat) && !app.isAdmin) {
      return app.currentGame != null ? RoutePaths.invitation : RoutePaths.home;
    }

    // Auto-redirect members from invitation to live game when game goes live.
    // GoRouter re-evaluates redirect on every notifyListeners() call, so this
    // fires automatically when the admin starts the tournament (P1 fix).
    final game = app.currentGame;
    if (authed &&
        !app.isAdmin &&
        flat == RoutePaths.invitation &&
        game != null &&
        game.status.isActiveLive) {
      return RoutePaths.playerLive;
    }
    // Guard: prevent admin from back-navigating to pre-game screens during live tournament.
    if (authed &&
        app.isAdmin &&
        game != null &&
        game.status.isActiveLive &&
        (flat == RoutePaths.structureReview)) {
      return RoutePaths.hostDashboard;
    }

    final guestOk = app.hasGuestSession && _guestAllowed.contains(flat);
    if (!authed && !guestOk && !_publicPaths.contains(flat)) {
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
          _publicPaths.contains(SpecRoutes.flatFor(deepPath)) ||
          SpecRoutes.joinRewrites.any(deepPath.startsWith)) {
        return deepLink;
      }
      return '${RoutePaths.login}?next=${Uri.encodeComponent(deepLink)}';
    }
    if (authed &&
        (flat == RoutePaths.splash ||
            flat == RoutePaths.login ||
            flat == RoutePaths.register ||
            flat == RoutePaths.forgotPassword)) {
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
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Page not found',
            style: AppTypography.body(
              size: 20,
              weight: FontWeight.w600,
            ).copyWith(color: AppColors.foreground),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.uri.toString(),
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 12).copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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

    // D3 — the TV pairing code, deep-linkable. `/tv-mode` is the screen itself;
    // `/tv/:code` is the link a host shares: it opens the scoreboard directly
    // (read-only, no account) with the code pre-filled and auto-connecting.
    // Game/player codes (`/g/:code`, `/game/`, `/j/`) still land on `/join`.
    GoRoute(
      path: SpecRoutes.tvCode,
      builder: (context, state) => TVModeScreen(
        initialCode: state.pathParameters[SpecRoutes.codeParam],
      ),
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
      builder: (context, state) => TermsScreen(
        fromSignUp: state.uri.queryParameters['from'] == 'signup',
      ),
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

    // ── Spec C2 · A · the join routes that carry a code ──────────────────────
    // `/join/:code` is the A7 deep link: the same screen, with the code arriving
    // as a path parameter instead of `?code=` — which is exactly what
    // `JoinScreen.initialCode` documents.
    GoRoute(
      path: SpecRoutes.joinCode,
      builder: (context, state) => JoinScreen(
        initialCode: state.pathParameters[SpecRoutes.codeParam],
      ),
    ),

    // `/g/:gameCode` is A6, the guest's game link, and D3's `/tv/:code` below is
    // the TV pairing code. Both are a bare code, and `GuestFlowScreen` (A6) and
    // `TVModeScreen` (D3) take no parameter, so both hand the code to `/join` —
    // the one screen that can read a code out of a URL. It classifies the code
    // and opens the guest flow for a game (`join_screen.dart` `_resolve`) or the
    // TV display for a TV code, which is C2's own note on `/join/:code`:
    // "resolves to group invite, game (guest) or TV".
    GoRoute(
      path: SpecRoutes.guestGame,
      builder: (context, state) => JoinScreen(
        initialCode: state.pathParameters[SpecRoutes.gameCodeParam],
      ),
    ),

    // The public tools (section 2). No account, no shell, no guard -- a
    // visitor who came to settle a chop should get the answer, not a login.
    GoRoute(
      path: RoutePaths.tools,
      builder: (context, state) => const ToolsScreen(),
    ),
    GoRoute(
      path: RoutePaths.toolBlinds,
      builder: (context, state) => const ToolBlindsScreen(),
    ),
    GoRoute(
      path: RoutePaths.toolClock,
      builder: (context, state) => const ToolClockScreen(),
    ),
    GoRoute(
      path: RoutePaths.toolIcm,
      builder: (context, state) => const ToolIcmScreen(),
    ),
    GoRoute(
      path: RoutePaths.toolPayouts,
      builder: (context, state) => const ToolPayoutsScreen(),
    ),
    GoRoute(
      path: RoutePaths.toolQuickBlind,
      builder: (context, state) => const ToolQuickBlindScreen(),
    ),

    // ── App shell ────────────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.home,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const HomeScreen(), path: RoutePaths.home)),
    ),
    GoRoute(
      path: RoutePaths.group,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const GroupScreen(), path: RoutePaths.group),
      ),
    ),
    GoRoute(
      path: RoutePaths.chat,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const ChatScreen(), path: RoutePaths.chat)),
    ),
    GoRoute(
      path: RoutePaths.members,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const MembersScreen(), path: RoutePaths.members)),
    ),
    GoRoute(
      path: RoutePaths.importResults,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const ImportResultsScreen(), path: RoutePaths.importResults)),
    ),
    GoRoute(
      path: RoutePaths.groupSettings,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const GroupSettingsScreen(), path: RoutePaths.groupSettings)),
    ),
    GoRoute(
      path: RoutePaths.groupChips,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const GroupChipsScreen(), path: RoutePaths.groupChips)),
    ),

    // ── Spec C2 · B · the group-scoped screens ───────────────────────────────
    // B9, B11, B12 and B10 are the four rows under a group in C2's table. Each
    // builds the same widget as its flat twin and reports that flat path to
    // `ScreenShell.requiredPath`, so the host gate, the custom mobile top bar
    // and the nav all behave identically whichever name the URL used.
    //
    // `:gid` is not read: the app holds one *current* group, and every one of
    // these screens reads it from the provider. That is the honest behaviour for
    // this app — a link for a group you are not in cannot silently switch the
    // session — but it does mean `/groups/<other-gid>/settings` opens the
    // current group's settings rather than an error. Noted in the route matrix
    // report.
    GoRoute(
      path: SpecRoutes.groupSettings,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          const GroupSettingsScreen(),
          path: RoutePaths.groupSettings,
        ),
      ),
    ),
    GoRoute(
      path: SpecRoutes.groupStandings,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          const StandingsScreen(),
          path: RoutePaths.standings,
        ),
      ),
    ),
    GoRoute(
      path: SpecRoutes.groupImport,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          const ImportResultsScreen(),
          path: RoutePaths.importResults,
        ),
      ),
    ),
    GoRoute(
      path: SpecRoutes.groupChips,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          const GroupChipsScreen(),
          path: RoutePaths.groupChips,
        ),
      ),
    ),
    GoRoute(
      path: RoutePaths.polls,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const PollsScreen(), path: RoutePaths.polls)),
    ),
    GoRoute(
      path: RoutePaths.reports,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const ReportsScreen(), path: RoutePaths.reports)),
    ),
    GoRoute(
      path: RoutePaths.standings,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const StandingsScreen(), path: RoutePaths.standings)),
    ),
    GoRoute(
      path: RoutePaths.joinGroup,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(
        JoinGroupScreen(code: state.uri.queryParameters['code'] ?? ''), path: RoutePaths.joinGroup,
      )),
    ),

    // A8 — the group invite link a host shares. Same screen as `/join-group`,
    // with the group's code as a path parameter, so `/invite/FP2608` is a link
    // that works without a query string appended to it. This is the one
    // group-scoped path that consumes its parameter.
    GoRoute(
      path: SpecRoutes.inviteCode,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          JoinGroupScreen(
            code: state.pathParameters[SpecRoutes.codeParam] ?? '',
          ),
          path: RoutePaths.joinGroup,
        ),
      ),
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
      path: RoutePaths.upgrade,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const UpgradeScreen(), path: RoutePaths.upgrade),
      ),
    ),
    GoRoute(
      path: RoutePaths.checkout,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          CheckoutScreen(
            planId: state.uri.queryParameters['plan'] ?? 'demo-monthly',
          ),
          path: RoutePaths.checkout,
        ),
      ),
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

    // F5 — the chip-set editor, deep-linkable by id. Unlike every other `:id`
    // in C2 this one is a real lookup rather than the current session: F5 edits
    // a *saved* chip set, so the parameter is handed to the screen. The flat
    // `/edit-chip-set` still takes its id from `state.extra`, which is how the
    // app has always passed it.
    GoRoute(
      path: SpecRoutes.chipSet,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          EditChipSetScreen(
            chipSetId: state.pathParameters[SpecRoutes.gameIdParam],
          ),
          path: RoutePaths.editChipSet,
        ),
      ),
    ),

    // ── Tournament flow ──────────────────────────────────────────────────────
    GoRoute(
      path: RoutePaths.createTournament,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          CreateTournamentScreen(
            presetId: state.uri.queryParameters['preset'],
            repostGameId: state.uri.queryParameters['repost'],
          ),
          path: RoutePaths.createTournament,
        ),
      ),
    ),

    // C1 — C2 spells the wizard `/t/new`. Declared before `/t/:id` below so the
    // literal segment wins the match: go_router takes the first route whose
    // pattern fits, and both fit `new`.
    GoRoute(
      path: SpecRoutes.newTournament,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          CreateTournamentScreen(
            presetId: state.uri.queryParameters['preset'],
            repostGameId: state.uri.queryParameters['repost'],
          ),
          path: RoutePaths.createTournament,
        ),
      ),
    ),
    GoRoute(
      path: RoutePaths.quick,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(
        const QuickStartScreen(), path: RoutePaths.quick,
      )),
    ),
    GoRoute(
      path: RoutePaths.structureReview,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(
        const StructureReviewScreen(), path: RoutePaths.structureReview,
      )),
    ),

    // ── Spec C2 · C · the game-scoped screens ────────────────────────────────
    // C2's tournament table nests fifteen rows under `/t/:id`. Every one builds
    // the same widget as the flat route above it and reports that flat path to
    // `ScreenShell`, so `context.go('/host-dashboard')` and a shared
    // `/t/9f3a/dashboard` land on one screen under one guard.
    //
    // `:id` is not read by any of them. The app holds one *current* game rather
    // than one per id, so each screen reads `AppProvider.currentGame`; a link
    // for a game that is not loaded opens the current game's screen. Recorded
    // in the route matrix report.
    //
    // `/t/new` is declared above, before `/t/:id`, so the literal segment wins.

    // C2 — the invitation, the RSVP and the waitlist. Also `/t/:id/me`, C4p:
    // the player's own check-in, which this screen draws as its primary action
    // (locked until the window opens, then "Check In", then "Waiting for
    // Confirmation", then the seat). A link guest (session, no account) gets
    // the guest flow instead — the invitation screen stays member-oriented.
    GoRoute(
      path: SpecRoutes.tournament,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const InvitationScreen(), path: RoutePaths.invitation),
      ),
    ),
    GoRoute(
      path: SpecRoutes.tournamentMe,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          app.hasGuestSession && !app.isAuthenticated
              ? const GuestFlowScreen()
              : const InvitationScreen(),
          path: RoutePaths.invitation,
        ),
      ),
    ),

    // C2 — the level editor. C2's own variant of it for a host.
    GoRoute(
      path: SpecRoutes.tournamentReview,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          const StructureReviewScreen(),
          path: RoutePaths.structureReview,
        ),
      ),
    ),
    GoRoute(
      path: SpecRoutes.tournamentLevels,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          const StructureReviewScreen(),
          path: RoutePaths.structureReview,
        ),
      ),
    ),

    // C-cfg — reopen the wizard's editor on a game that already exists.
    GoRoute(
      path: SpecRoutes.tournamentConfigure,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          CreateTournamentScreen(
            presetId: state.uri.queryParameters['preset'],
            repostGameId: state.uri.queryParameters['repost'],
          ),
          path: RoutePaths.createTournament,
        ),
      ),
    ),

    // C4 (host) — `/t/:id/checkin` is C2's alias for the Active tab of
    // `/t/:id/players`, so both open the check-in screen.
    GoRoute(
      path: SpecRoutes.tournamentCheckIn,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const CheckInScreen(), path: RoutePaths.checkIn),
      ),
    ),
    GoRoute(
      path: SpecRoutes.tournamentPlayers,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const CheckInScreen(), path: RoutePaths.checkIn),
      ),
    ),

    // C5 — the host's live dashboard.
    GoRoute(
      path: SpecRoutes.tournamentDashboard,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          const AdminDashboardScreen(),
          path: RoutePaths.hostDashboard,
        ),
      ),
    ),

    // C10 · C11 — the player's live view.
    GoRoute(
      path: SpecRoutes.tournamentLive,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const PlayerLiveScreen(), path: RoutePaths.playerLive),
      ),
    ),
    // C-payouts — its own screen (pool, entries, medal rows, KO pot, host
    // view toggle). Same shell path as the live view, so nav highlighting
    // and guards behave exactly as before.
    GoRoute(
      path: SpecRoutes.tournamentPayouts,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const PayoutsScreen(), path: RoutePaths.playerLive),
      ),
    ),

    // C6 — the rebuy settlement, the add-on break.
    GoRoute(
      path: SpecRoutes.tournamentRebuys,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          const RebuySettlementScreen(),
          path: RoutePaths.rebuySettlement,
        ),
      ),
    ),

    // C7 — the final table, redrawing the seats.
    GoRoute(
      path: SpecRoutes.tournamentFinalTable,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const FinalTableScreen(), path: RoutePaths.finalTable),
      ),
    ),

    // C8 — confirm the finish order.
    GoRoute(
      path: SpecRoutes.tournamentFinish,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(
          const CompleteTournamentScreen(),
          path: RoutePaths.completeTournament,
        ),
      ),
    ),

    // C9 — podium, story and share card.
    GoRoute(
      path: SpecRoutes.tournamentResults,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const ResultPodiumScreen(), path: RoutePaths.resultPodium),
      ),
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
      path: RoutePaths.hostDashboard,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const AdminDashboardScreen(), path: RoutePaths.hostDashboard)),
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
      path: RoutePaths.deal,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(
        const DealScreen(), path: RoutePaths.deal,
      )),
    ),

    // C-deal — the ICM chop, the chip chop and the equal-plus-agreed deals.
    GoRoute(
      path: SpecRoutes.tournamentDeal,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const DealScreen(), path: RoutePaths.deal),
      ),
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

    // D1 — C2 spells the setup screen `/cash/new`.
    GoRoute(
      path: SpecRoutes.newCashGame,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const CashGameScreen(), path: RoutePaths.cashGame),
      ),
    ),

    GoRoute(
      path: RoutePaths.cashGameLive,
      pageBuilder: (context, state) => NoTransitionPage(key: ValueKey(state.uri.path), child: shell(const CashGameLiveScreen(), path: RoutePaths.cashGameLive)),
    ),

    // D2 — the session itself. `:id` is not read: the app holds one current
    // cash session, which this screen reads from the provider.
    GoRoute(
      path: SpecRoutes.cashGame,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(state.uri.path),
        child: shell(const CashGameLiveScreen(), path: RoutePaths.cashGameLive),
      ),
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
      .fadeIn(duration: AppDurations.normal, curve: Curves.easeOut)
      .slideY(begin: 0.05),
);

/// Reads the `?next=` query param so auth can redirect back to the page the
/// user originally tried to reach.
String? _nextParam(GoRouterState state) {
  final next = state.uri.queryParameters['next'];
  return (next == null || !next.startsWith('/')) ? null : next;
}
