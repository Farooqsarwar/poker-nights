import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/app/theme.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:provider/provider.dart';

import 'design_probe.dart' as design show loadRealFonts;

/// Phase E (public tools) camera: every free tool at phone and desktop width,
/// mounted on its own public route exactly as the router does (no shell).
///
///   flutter test test/phase_e_probe.dart --update-goldens
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

  final tools = <String, (String, Widget)>{
    'e1_hub': (RoutePaths.tools, const ToolsScreen()),
    'e2_blinds': (RoutePaths.toolBlinds, const ToolBlindsScreen()),
    'e3_clock': (RoutePaths.toolClock, const ToolClockScreen()),
    'e4_icm': (RoutePaths.toolIcm, const ToolIcmScreen()),
    'e5_payouts': (RoutePaths.toolPayouts, const ToolPayoutsScreen()),
    'e6_quick_blind': (RoutePaths.toolQuickBlind, const ToolQuickBlindScreen()),
  };

  Future<void> shoot(WidgetTester t, String name, String path, Widget screen,
      Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final app = AppProvider();
    final router = GoRouter(
      initialLocation: path,
      routes: [GoRoute(path: path, builder: (_, _) => screen)],
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
      matchesGoldenFile('goldens/phase_e/$name.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await t.pump();
    while (t.takeException() != null) {}
  }

  for (final e in tools.entries) {
    testWidgets('${e.key} phone', (t) async {
      await shoot(t, '${e.key}_phone', e.value.$1, e.value.$2,
          const Size(390, 844));
    });
    testWidgets('${e.key} desktop', (t) async {
      await shoot(t, '${e.key}_desktop', e.value.$1, e.value.$2,
          const Size(1280, 860));
    });
  }
}
