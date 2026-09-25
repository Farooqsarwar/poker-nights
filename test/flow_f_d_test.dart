import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/cash/cash_game_live_screen.dart';
import 'package:poker_night/screens/cash/cash_game_screen.dart';
import 'package:poker_night/screens/shell/chip_sets_screen.dart';
import 'package:poker_night/screens/shell/edit_chip_set_screen.dart';
import 'package:poker_night/screens/shell/profile_screen.dart';
import 'package:poker_night/screens/shell/settings_screen.dart';
import 'package:poker_night/screens/shell/stats_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/widgets/app_toggle.dart';
import 'package:poker_night/widgets/back_nav_button.dart';
import 'package:poker_night/widgets/squircle_icon_button.dart';
import 'package:provider/provider.dart';

void main() {
  late AppProvider sharedApp;

  setUpAll(() {
    RecoveryService.enabled = false;
    AppColors.currentPalette = ThemePalettes.forId('red');
    sharedApp = AppProvider();
    final user = const AppUser(
      id: 'user-1',
      name: 'Alex Morgan',
      email: 'alex@example.com',
      isAdmin: true,
      stats: UserStats(
        played: 34,
        wins: 6,
        podium: 11,
        avgFinish: 3.2,
        knockouts: 18,
      ),
    );
    final group = Group(
      id: 'grp-1',
      name: 'Friday Poker Club',
      joinCode: 'FPC123',
      ownerId: 'user-1',
      members: [user],
      games: const [],
      chat: const [],
      polls: const [],
      notifications: const [],
    );

    sharedApp.setUserForTesting(user);
    sharedApp.setCurrentGroupForTesting(group);
  });

  tearDownAll(() {
    sharedApp.dispose();
  });

  Future<void> mountScreen(WidgetTester tester, Widget screen) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(backgroundColor: const Color(0xFF0A0B0D), body: screen),
        ),
      ],
      errorBuilder: (_, _) => const Scaffold(body: SizedBox.shrink()),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: sharedApp,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    while (tester.takeException() != null) {}
  }

  testWidgets('SquircleIconButton renders with custom icon and callback', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquircleIconButton(
            icon: Icons.edit_outlined,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    await tester.tap(find.byType(SquircleIconButton));
    expect(pressed, isTrue);
  });

  testWidgets('BackNavButton renders squircle with chevron_left', (
    tester,
  ) async {
    var backPressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackNavButton(onPressed: () => backPressed = true),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    await tester.tap(find.byType(BackNavButton));
    expect(backPressed, isTrue);
  });

  testWidgets('AppToggle renders and toggles value', (tester) async {
    var toggleState = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppToggle(
                value: toggleState,
                onChanged: (v) => setState(() => toggleState = v),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(AppToggle), findsOneWidget);
    await tester.tap(find.byType(AppToggle));
    await tester.pumpAndSettle();
    expect(toggleState, isTrue);
  });

  testWidgets('F1 ProfileScreen renders mobile-first design elements', (
    tester,
  ) async {
    await mountScreen(tester, const ProfileScreen());

    expect(find.text('Alex Morgan'), findsOneWidget);
    // The group name is the header subtitle and the settings-row subtitle.
    // "Member since 2023" was placeholder copy with no data behind it and
    // is no longer shown, so it must not come back.
    expect(find.text('Friday Poker Club'), findsNWidgets(2));
    expect(find.textContaining('Member since'), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('LIFETIME P&L'), findsOneWidget);
    expect(find.text('games'), findsOneWidget);
    expect(find.text('wins'), findsOneWidget);
    expect(find.text('ITM'), findsOneWidget);
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    expect(find.text('FIRST WIN'), findsOneWidget);
    expect(find.text('3 IN A ROW'), findsOneWidget);
    expect(find.text('\$1K NIGHT'), findsOneWidget);
    expect(find.byType(SquircleIconButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'F2 SettingsScreen renders sections matching mobile-first design',
    (tester) async {
      await mountScreen(tester, const SettingsScreen());

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Account and group preferences'), findsOneWidget);
      expect(find.text('GAMEPLAY'), findsOneWidget);
      expect(find.text('Voice announcements'), findsOneWidget);
      expect(find.text('Admin app tour'), findsOneWidget);
      expect(find.text('Push notifications'), findsOneWidget);
      expect(find.text('Compact results'), findsOneWidget);
      expect(find.text('GAME ASSETS'), findsOneWidget);
      expect(find.text('Chip sets'), findsOneWidget);
      expect(find.text('Default chip set'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'F3 StatsScreen renders statistics headline cards and premium blurb',
    (tester) async {
      await mountScreen(tester, const StatsScreen());

      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('Alex Morgan · all-time results'), findsOneWidget);
      expect(find.byType(BackNavButton), findsOneWidget);
      expect(find.text('Wins'), findsOneWidget);
      expect(find.text('Avg finish'), findsOneWidget);
      expect(find.text('#3.2'), findsOneWidget);
      expect(find.text('Knockouts'), findsOneWidget);
      expect(find.text('Win rate'), findsOneWidget);
      expect(
        find.textContaining('Finishing positions over time'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('F4 ChipSetsScreen renders chip sets view with + New', (
    tester,
  ) async {
    await mountScreen(tester, const ChipSetsScreen());

    expect(find.text('Chip sets'), findsOneWidget);
    expect(find.text('+ New'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('F5 EditChipSetScreen renders editor', (tester) async {
    await mountScreen(tester, const EditChipSetScreen());

    expect(find.text('New Chip Set'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Exact inventory'), findsOneWidget);
    expect(find.text('Quick inventory'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('D1 CashGameScreen renders setup with stakes and start button', (
    tester,
  ) async {
    await mountScreen(tester, const CashGameScreen());

    expect(find.text('New cash game'), findsOneWidget);
    expect(find.text('CASH GAME'), findsOneWidget);
    expect(find.text('Stakes'), findsOneWidget);
    expect(find.text('0.5 / 1'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('Min buy-in'), findsOneWidget);
    expect(find.text('Max buy-in'), findsOneWidget);
    expect(find.text('Chip set'), findsOneWidget);
    expect(find.text('Track settlement'), findsOneWidget);
    expect(find.text('Start session'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('D2 CashGameLiveScreen renders active live cash session', (
    tester,
  ) async {
    sharedApp.startCashGame(
      const CashSessionSettings(
        name: 'Friday Cash Game',
        date: '2026-09-25',
        location: 'Home',
        smallBlind: 1,
        bigBlind: 2,
        minBuyIn: 100,
        maxBuyIn: 500,
        maxPlayers: 10,
        currency: '\$',
      ),
      ['Alex M.', 'Marcus L.', 'Ava R.'],
    );

    await mountScreen(tester, const CashGameLiveScreen());

    expect(find.text('Cash session'), findsOneWidget);
    expect(find.text('LIVE · 1 / 2'), findsOneWidget);
    expect(find.text('players'), findsOneWidget);
    expect(find.text('in play'), findsOneWidget);
    expect(find.text('elapsed'), findsOneWidget);
    expect(find.text('Expected in play'), findsOneWidget);
    expect(find.text('Difference'), findsOneWidget);
    expect(find.text('PLAYERS'), findsOneWidget);
    expect(find.text('+ Add'), findsOneWidget);

    // Verify player cards
    expect(find.text('Alex M.'), findsOneWidget);
    expect(find.text('Marcus L.'), findsOneWidget);
    expect(find.text('Ava R.'), findsOneWidget);

    // Verify Cash out & settle button
    expect(find.text('Cash out & settle'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
