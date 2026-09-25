import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/app/theme.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/chip_sets_screen.dart';
import 'package:poker_night/screens/shell/edit_chip_set_screen.dart';
import 'package:poker_night/screens/shell/presets_screen.dart';
import 'package:poker_night/screens/shell/profile_screen.dart';
import 'package:poker_night/screens/shell/settings_screen.dart';
import 'package:poker_night/screens/shell/stats_screen.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/widgets/screen_shell.dart';
import 'package:provider/provider.dart';

import 'design_probe.dart' as design show loadRealFonts;

/// Phase F (account) camera: each account screen inside the real
/// [ScreenShell] for a signed-in member, at phone, 320px and desktop width.
///
///   flutter test test/phase_f_probe.dart --update-goldens
///
/// Not a `*_test.dart`: a camera, not an assertion (see design_probe.dart).
void main() {
  setUpAll(design.loadRealFonts);
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterError.onError = (_) {};
  });
  tearDown(() => FlutterError.onError = FlutterError.presentError);

  const me = AppUser(
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
  const group = Group(
    id: 'g1',
    name: 'Friday Poker Club',
    joinCode: 'FP2608',
    ownerId: 'u1',
    members: [me],
    games: [],
    chat: [],
    polls: [],
    notifications: [],
  );

  final screens = <String, (String, Widget)>{
    'f1_profile': (RoutePaths.profile, const ProfileScreen()),
    'f2_settings': (RoutePaths.settings, const SettingsScreen()),
    'f3_stats': (RoutePaths.stats, const StatsScreen()),
    'f4_chip_sets': (RoutePaths.chipSets, const ChipSetsScreen()),
    'f5_edit_chip_set': (RoutePaths.editChipSet, const EditChipSetScreen()),
    'f6_presets': (RoutePaths.presets, const PresetsScreen()),
  };

  Future<void> shoot(
    WidgetTester t,
    String name,
    String path,
    Widget screen,
    Size size,
  ) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final app = AppProvider()
      ..setUserForTesting(me)
      ..setCurrentGroupForTesting(group);
    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(
          path: path,
          builder: (_, _) => ScreenShell(requiredPath: path, child: screen),
        ),
      ],
      errorBuilder: (_, _) => const Scaffold(body: SizedBox.shrink()),
    );
    await t.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.forPalette(ThemePalettes.forId('red')),
          routerConfig: router,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 700));
    while (t.takeException() != null) {}
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/phase_f/$name.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await t.pump();
    while (t.takeException() != null) {}
  }

  for (final e in screens.entries) {
    final (path, screen) = e.value;
    testWidgets('${e.key} phone', (t) async {
      await shoot(t, '${e.key}_phone', path, screen, const Size(390, 844));
    });
    testWidgets('${e.key} 320', (t) async {
      await shoot(t, '${e.key}_320', path, screen, const Size(320, 700));
    });
    testWidgets('${e.key} desktop', (t) async {
      await shoot(t, '${e.key}_desktop', path, screen, const Size(1280, 860));
    });
  }
}
