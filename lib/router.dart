import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/splash/views/splash_view.dart';
import 'features/auth/views/login_view.dart';
import 'features/auth/views/register_view.dart';
import 'features/auth/views/forgot_password_view.dart';
import 'features/home/views/home_view.dart';
import 'features/groups/views/group_list_view.dart';
import 'features/groups/views/create_group_view.dart';
import 'features/groups/views/join_group_view.dart';
import 'features/groups/views/group_home_view.dart';
import 'features/tournament/views/create_tournament_view.dart';
import 'features/tournament/views/structure_review_view.dart';
import 'features/tournament/views/tournament_lobby_view.dart';
import 'features/tournament/views/rsvp_view.dart';
import 'features/tournament/views/check_in_view.dart';
import 'features/tournament/views/settlement_view.dart';
import 'features/tournament/views/results_view.dart';
import 'features/live_game/views/admin_game_view.dart';
import 'features/live_game/views/player_game_view.dart';
import 'features/guests/views/guest_join_view.dart';
import 'features/guests/views/guest_management_view.dart';
import 'features/tv_mode/views/tv_mode_view.dart';
import 'features/chat/views/chat_view.dart';
import 'features/polls/views/poll_view.dart';
import 'features/history/views/history_view.dart';
import 'features/cash_game/views/cash_game_view.dart';
import 'features/settings/views/settings_view.dart';
import 'features/seating/views/seating_view.dart';
import 'features/public/views/landing_view.dart';
import 'features/public/views/privacy_view.dart';
import 'features/public/views/terms_view.dart';
import 'features/tournament/views/chip_inventory_view.dart';
import 'features/tournament/views/preset_list_view.dart';

bool appHasShownSplash = false;

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _navKey,
  initialLocation: '/',
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Page not found', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          TextButton(onPressed: () => context.go('/home'), child: const Text('Go Home')),
        ],
      ),
    ),
  ),
  redirect: (context, state) {
    if (!appHasShownSplash) {
      if (state.matchedLocation != '/') return '/';
      return null;
    }
    
    // Check if auth controller is registered, otherwise assume not logged in during init
    final isLoggedIn = Get.isRegistered<AuthController>() ? Get.find<AuthController>().isAuthenticated : false;

    if (state.matchedLocation == '/') {
      return isLoggedIn ? '/home' : '/landing';
    }
    if (state.matchedLocation == '/privacy' || state.matchedLocation == '/terms') return null;
    final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register' || state.matchedLocation == '/forgot-password';
    if (!isLoggedIn && !isAuthRoute && !state.matchedLocation.startsWith('/game/')) {
      return '/landing';
    }
    if (isLoggedIn && (isAuthRoute || state.matchedLocation == '/landing')) {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashView()),
    GoRoute(path: '/landing', builder: (_, _) => LandingView()),
    GoRoute(path: '/login', builder: (_, _) => const LoginView()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterView()),
    GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordView()),
    GoRoute(path: '/home', builder: (_, _) => const HomeView()),
    GoRoute(path: '/groups', builder: (_, _) => const GroupListView()),
    GoRoute(path: '/groups/create', builder: (_, _) => const CreateGroupView()),
    GoRoute(path: '/groups/join', builder: (_, _) => const JoinGroupView()),
    GoRoute(path: '/groups/:groupId', builder: (_, state) => GroupHomeView(groupId: state.pathParameters['groupId']!)),
    GoRoute(path: '/groups/:groupId/create-tournament', builder: (_, state) => CreateTournamentView(groupId: state.pathParameters['groupId']!)),
    GoRoute(path: '/groups/:groupId/tournament/:gameId/review', builder: (_, state) => StructureReviewView(
      groupId: state.pathParameters['groupId']!,
      gameId: state.pathParameters['gameId']!,
    )),
    GoRoute(path: '/groups/:groupId/tournament/:gameId/lobby', builder: (_, state) => TournamentLobbyView(
      groupId: state.pathParameters['groupId']!,
      gameId: state.pathParameters['gameId']!,
    )),
    GoRoute(path: '/groups/:groupId/tournament/:gameId/rsvp', builder: (_, state) => RsvpView(
      groupId: state.pathParameters['groupId']!,
      gameId: state.pathParameters['gameId']!,
    )),
    GoRoute(path: '/groups/:groupId/tournament/:gameId/check-in', builder: (_, state) => CheckInView(
      groupId: state.pathParameters['groupId']!,
      gameId: state.pathParameters['gameId']!,
    )),
    GoRoute(path: '/groups/:groupId/tournament/:gameId/admin', builder: (_, state) => AdminGameView(
      tournamentId: state.pathParameters['gameId']!,
      groupId: state.pathParameters['groupId'],
    )),
    GoRoute(path: '/game/:gameId/player', builder: (_, state) => PlayerGameView(tournamentId: state.pathParameters['gameId']!, playerId: 'player')),
    GoRoute(path: '/game/:gameId/guest', builder: (_, state) => GuestJoinView(tournamentId: state.pathParameters['gameId']!)),
    GoRoute(path: '/game/:gameId/guests', builder: (_, state) => GuestManagementView(gameId: state.pathParameters['gameId']!)),
    GoRoute(path: '/game/:gameId/tv', builder: (_, state) => TvModeView(tournamentId: state.pathParameters['gameId']!)),
    GoRoute(path: '/game/join/:code', builder: (_, state) => GuestJoinView(tournamentId: state.pathParameters['code']!)),
    GoRoute(path: '/groups/:groupId/tournament/:gameId/settlement', builder: (_, state) => SettlementView(
      groupId: state.pathParameters['groupId']!,
      gameId: state.pathParameters['gameId']!,
    )),
    GoRoute(path: '/groups/:groupId/tournament/:gameId/results', builder: (_, state) => ResultsView(
      groupId: state.pathParameters['groupId']!,
      gameId: state.pathParameters['gameId']!,
    )),
    GoRoute(path: '/groups/:groupId/chat', builder: (_, state) => ChatView(groupId: state.pathParameters['groupId']!)),
    GoRoute(path: '/groups/:groupId/polls', builder: (_, state) => PollView(groupId: state.pathParameters['groupId']!)),
    GoRoute(path: '/groups/:groupId/history', builder: (_, state) => HistoryView(groupId: state.pathParameters['groupId']!)),
    GoRoute(path: '/groups/:groupId/cash-game', builder: (_, state) => CashGameView(groupId: state.pathParameters['groupId']!)),
    GoRoute(path: '/groups/:groupId/tournament/:gameId/seating', builder: (_, state) => SeatingView(
      tournamentId: state.pathParameters['gameId']!,
    )),
    GoRoute(path: '/privacy', builder: (_, _) => const PrivacyView()),
    GoRoute(path: '/terms', builder: (_, _) => const TermsView()),
    GoRoute(path: '/groups/:groupId/presets', builder: (_, state) => PresetListView(groupId: state.pathParameters['groupId']!)),
    GoRoute(path: '/groups/:groupId/chip-inventory', builder: (_, state) => ChipInventoryView(
      groupId: state.pathParameters['groupId']!,
      chipSetId: state.pathParameters['chipSetId'] ?? 'default',
    )),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsView()),
  ],
);
