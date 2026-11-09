import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/theme.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/public/auth_screen.dart';
import 'package:poker_night/screens/public/guest_flow_screen.dart';
import 'package:poker_night/screens/public/join_screen.dart';
import 'package:poker_night/screens/public/landing_screen.dart';
import 'package:poker_night/screens/public/splash_screen.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/screens/premium/upgrade_screen.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:provider/provider.dart';

/// Renders the §8 priority screens to PNG so their APPEARANCE can be looked
/// at rather than argued about from source.
///
///   flutter test test/design_probe.dart --update-goldens
///
/// then open test/goldens/design/*.png.
///
/// Deliberately NOT named `*_test.dart`, so `flutter test` skips it — golden
/// images depend on host font rendering and would fail on another machine.
/// This is a camera, not an assertion, exactly like visual_probe.dart.
///
/// CAVEAT worth knowing before judging what comes out: google_fonts cannot
/// fetch in a sandbox, so every screen renders in a FALLBACK typeface. Layout,
/// spacing, hierarchy, colour and contrast are all faithful; the actual letter
/// shapes are not. Do not judge the typography choice from these.
/// Registers a real system typeface under the family names the app asks
/// google_fonts for.
///
/// Without this the capture is worthless. `flutter_test` ships the Ahem test
/// font, whose glyphs are solid squares roughly two to three times wider than
/// real letters — so every copy-heavy screen renders as unreadable blocks AND
/// blows its own layout apart, which looks like a design defect that does not
/// exist. Substituting a real face makes width, wrapping and hierarchy
/// faithful. The letter shapes are Segoe UI rather than Space Grotesk, so
/// judge layout and hierarchy from these, not the typeface itself.
Future<void> loadRealFonts() async {
  ByteData font(String file) =>
      ByteData.view(File('C:\\Windows\\Fonts\\$file').readAsBytesSync().buffer);
  Future<void> register(String family, ByteData data) async {
    final loader = FontLoader(family)..addFont(Future.value(data));
    await loader.load();
  }

  final regular = font('segoeui.ttf');
  for (final family in const [
    'SpaceGrotesk',
    'SpaceMono',
    'Space Grotesk',
    'Space Mono',
  ]) {
    await register(family, regular);
  }
  // google_fonts registers each weight as its own family, named
  // `<Family>_<variant>` (`SpaceGrotesk_regular`, `SpaceGrotesk_700`, …).
  // Registering only the bare names above left every styled run unresolved,
  // which is why earlier captures rendered as test-font blocks.
  final byWeight = {
    'regular': regular,
    '300': font('segoeuil.ttf'),
    '400': regular,
    '500': font('seguisb.ttf'),
    '600': font('seguisb.ttf'),
    '700': font('segoeuib.ttf'),
    '800': font('segoeuib.ttf'),
  };
  for (final e in byWeight.entries) {
    await register('SpaceGrotesk_${e.key}', e.value);
  }
  // Material icons, from the Flutter SDK's own cache.
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent
      .parent.parent.parent.path;
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (icons.existsSync()) {
    await register(
      'MaterialIcons',
      ByteData.view(icons.readAsBytesSync().buffer),
    );
  }
}

void main() {
  setUpAll(loadRealFonts);

  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
    // Without this every glyph renders as a filled block: google_fonts cannot
    // reach fonts.gstatic.com from a test binding, and the failed typeface
    // falls back to something with no glyph coverage. Turning runtime
    // fetching off makes it resolve to the bundled default instead, so the
    // captures show readable text and the hierarchy can actually be judged.
    // The letter SHAPES are still not the shipped ones — only the layout,
    // weight and size relationships are faithful.
    GoogleFonts.config.allowRuntimeFetching = false;
    // AppProvider opens a connectivity_plus event channel and google_fonts
    // tries to fetch; neither exists in a test binding, and both report
    // asynchronously — after the capture, where they fail the golden rather
    // than say anything about the screen. This file only takes pictures, so
    // errors are swallowed wholesale rather than filtered by name.
    FlutterError.onError = (_) {};
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
  });

  /// [needsProvider] is opt-in on purpose. Constructing an [AppProvider] opens
  /// a connectivity_plus event channel that does not exist in a test binding
  /// and reports its failure asynchronously — after the capture, where it
  /// fails the golden while saying nothing about the screen. Most of these
  /// screens are public and never touch the provider, so they simply do not
  /// build one.
  Future<void> shoot(
    WidgetTester t,
    String name,
    Widget screen, {
    Size size = const Size(1280, 1600),
    bool needsProvider = false,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final theme = AppTheme.forPalette(
      ThemePalettes.forId('red'),
      brightness: Brightness.dark,
    );
    final host = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      // Shell routes (the ones needing the provider) get their Scaffold from
      // ScreenShell in the app; without one they render an error panel here.
      home: needsProvider ? Scaffold(body: screen) : screen,
    );

    AppProvider? app;
    if (needsProvider) {
      app = AppProvider();
      await t.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(value: app, child: host),
      );
    } else {
      await t.pumpWidget(host);
    }

    // Long enough for entrance fades (flutter_animate, 400ms) to finish.
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 700));
    // google_fonts throws once per text style in the sandbox; drain so the
    // capture is not lost to environment noise.
    while (t.takeException() != null) {}

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/design/$name.png'),
    );

    await t.pumpWidget(const SizedBox.shrink());
    app?.dispose();
    await t.pump();
    while (t.takeException() != null) {}
  }

  testWidgets('landing', (t) async {
    await shoot(t, 'landing_desktop', const LandingScreen());
  });

  testWidgets('landing phone', (t) async {
    await shoot(
      t,
      'landing_phone',
      const LandingScreen(),
      size: const Size(390, 1400),
    );
  });

  testWidgets('landing phone full', (t) async {
    await shoot(
      t,
      'a2_landing_phone_full',
      const LandingScreen(),
      size: const Size(390, 5200),
    );
  });

  testWidgets('landing 320', (t) async {
    await shoot(
      t,
      'landing_320',
      const LandingScreen(),
      size: const Size(320, 1200),
    );
  });

  // ── Phase A · Onboarding & access ──────────────────────────────────────────
  const phone = Size(390, 844);
  const desktop = Size(1280, 860);

  testWidgets('A1 splash (settled on the wordmark face)', (t) async {
    t.view.physicalSize = phone;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.forPalette(ThemePalettes.forId('red')),
        home: const SplashScreen(),
      ),
    );
    // 3.2s: past the flip (ends at 72% of 4.2s), before the exit fade.
    await t.pump(const Duration(milliseconds: 3200));
    while (t.takeException() != null) {}
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/design/a1_splash_phone.png'),
    );
    // Unmount before the redirect timer fires — there is no router here.
    await t.pumpWidget(const SizedBox.shrink());
    while (t.takeException() != null) {}
  });

  for (final (id, mode) in const [
    ('a3_login', AuthMode.login),
    ('a4_register', AuthMode.register),
    ('a5_forgot', AuthMode.forgotPassword),
  ]) {
    testWidgets('$id phone', (t) async {
      await shoot(t, '${id}_phone', AuthScreen(mode: mode), size: phone);
    });
    testWidgets('$id desktop', (t) async {
      await shoot(t, '${id}_desktop', AuthScreen(mode: mode), size: desktop);
    });
  }

  testWidgets('a6 guest code entry phone', (t) async {
    await shoot(
      t,
      'a6_guest_phone',
      const GuestFlowScreen(),
      size: phone,
      needsProvider: true,
    );
  });

  testWidgets('a7 join phone', (t) async {
    await shoot(
      t,
      'a7_join_phone',
      const JoinScreen(),
      size: phone,
      needsProvider: true,
    );
  });

  testWidgets('a7 join desktop', (t) async {
    await shoot(
      t,
      'a7_join_desktop',
      const JoinScreen(),
      size: desktop,
      needsProvider: true,
    );
  });

  testWidgets('tools index', (t) async {
    await shoot(t, 'tools_desktop', const ToolsScreen());
  });

  testWidgets('blind generator', (t) async {
    await shoot(t, 'blinds_desktop', const ToolBlindsScreen());
  });

  testWidgets('tournament clock', (t) async {
    await shoot(t, 'clock_desktop', const ToolClockScreen());
  });

  testWidgets('icm calculator', (t) async {
    await shoot(t, 'icm_desktop', const ToolIcmScreen());
  });

  testWidgets('payout calculator', (t) async {
    await shoot(t, 'payouts_desktop', const ToolPayoutsScreen());
  });

  testWidgets('upgrade', (t) async {
    await shoot(t, 'upgrade_desktop', const UpgradeScreen(), needsProvider: true);
  });

  testWidgets('upgrade phone', (t) async {
    await shoot(
      t,
      'upgrade_phone',
      const UpgradeScreen(),
      size: const Size(390, 1400),
      needsProvider: true,
    );
  });
}
