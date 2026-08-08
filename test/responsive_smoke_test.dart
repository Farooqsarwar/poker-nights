import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:localstore/localstore.dart';
import 'package:provider/provider.dart';

import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/app/router.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/utils/mock_data.dart';
import 'package:poker_night/main.dart';

const _fontDir = r'C:\Users\farooq sarwar\AppData\Local\Temp\opencode\fonts';

/// google_fonts resolves text through family names like `Inter_regular` or
/// `Nunito_700` (and falls back to the plain `Inter`). Register the real font
/// under every variant name the app can request so layout metrics match
/// production instead of the wide Ahem test glyphs.
Future<void> _loadFont(String baseFamily, String fileName) async {
  final bytes = File('$_fontDir\\$fileName').readAsBytesSync();
  final data = Future.value(ByteData.view(bytes.buffer));
  final names = <String>{
    baseFamily,
    '${baseFamily}_regular',
    for (var w = 100; w <= 900; w += 100) '${baseFamily}_$w',
  };
  for (final family in names) {
    final loader = FontLoader(family)..addFont(data);
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // AppProvider restores recovery/active_game (+ cash/guest sessions) from the
    // real localstore on construction; earlier runs leave those docs behind and
    // would flip tvMode/guestFlow into their live-game variants mid-test. Clear
    // them so every size starts from a clean, signed-out state.
    final db = Localstore.instance;
    await db.collection('recovery').doc('active_game').delete();
    await db.collection('recovery').doc('active_cash').delete();
    await db.collection('recovery').doc('guest_session').delete();
  });

  Future<void> loadFonts() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFont('Inter', 'Inter-Variable.ttf');
    await _loadFont('Nunito', 'Nunito-Variable.ttf');
    await _loadFont('JetBrains Mono', 'JetBrainsMono-Variable.ttf');
  }

  /// Renders the real app (ScreenUtilInit + ResponsiveScaledBox + BouncingScroll
  /// wrapper + ScreenShell) at the given size and walks every screen through the
  /// real router, failing on any layout exception / overflow.
  
  Future<void> go(WidgetTester tester, String path, Size size, {Object? extra}) async {
    if (extra != null) {
      appRouter.go(path, extra: extra);
    } else {
      appRouter.go(path);
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull, reason: '$path at $size');
  }


  Future<void> driveApp(WidgetTester tester, Size size) async {
    // appRouter is a module-level singleton that keeps its location across
    // tests; reset it to splash so each size starts from a clean slate.
    appRouter.go(RoutePaths.splash);
    await loadFonts();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Mirror production wire-up exactly: ScreenUtilInit + ChangeNotifierProvider
    // above PokerNightApp (main() builds the same stack; pumping PokerNightApp
    // bare would leave no AppProvider for screens to read).
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      splitScreenMode: true,
      minTextAdapt: true,
      builder: (context, child) => ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const PokerNightApp(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(seconds: 1));

    // The provider sits above PokerNightApp; grab it before any route changes.
    final app = Provider.of<AppProvider>(
      tester.element(find.byType(PokerNightApp)),
      listen: false,
    );

    if (find.text('Create Account').evaluate().isEmpty) {
      fail('Landing screen did not render at $size');
    }
    expect(tester.takeException(), isNull, reason: 'landing at $size');

    // Walk the public, signed-out screens first (login / register / forgot are
    // only reachable signed-out; the shell gate would otherwise block them).
    for (final path in const [
      RoutePaths.login,
      RoutePaths.register,
      RoutePaths.forgotPassword,
      RoutePaths.privacy,
      RoutePaths.terms,
      RoutePaths.support,
      RoutePaths.join,
      RoutePaths.guestFlow,
      RoutePaths.tvMode,
    ]) {
      await go(tester, path, size);
    }

    // Sign in as the seeded admin and set up an active tournament + cash game.
    expect(app.login('daniel@example.com', AppProvider.seedPassword), isTrue);
    app.createGame(MockData.demoSettings);
    app.startCashGame(MockData.cashSettings, const ['Daniel', 'Marcus', 'Sarah']);
    await tester.pump(const Duration(milliseconds: 400));

    // Walk the signed-in shell, tournament and cash screens. tvMode and
    // guestFlow render their live-game variants now that a game exists.
    for (final path in const [
      RoutePaths.home,
      RoutePaths.group,
      RoutePaths.notifications,
      RoutePaths.history,
      RoutePaths.profile,
      RoutePaths.settings,
      RoutePaths.stats,
      RoutePaths.chipSets,
      RoutePaths.presets,
      RoutePaths.createTournament,
      RoutePaths.structureReview,
      RoutePaths.invitation,
      RoutePaths.checkIn,
      RoutePaths.adminDashboard,
      RoutePaths.playerLive,
      RoutePaths.rebuySettlement,
      RoutePaths.finalTable,
      RoutePaths.completeTournament,
      RoutePaths.cashGame,
      RoutePaths.cashGameLive,
      RoutePaths.tvMode,
      RoutePaths.guestFlow,
    ]) {
      await go(tester, path, size);
    }

    // editChipSet expects a chip set id via route extra ('cs-default' is the
    // provider's default set).
    await go(tester, RoutePaths.editChipSet, size, extra: 'cs-default');

    // Complete the tournament, then render the result podium.
    final game = app.currentGame!;
    app.recordFinishOrder(game.players.map((p) => p.id).toList());
    await go(tester, RoutePaths.resultPodium, size);
    // The '1st'/'2nd'/'3rd' labels live only in the podium slots, so their
    // presence proves the top-3 podium rendered (regression: it used to build
    // from the wrong end of the finish order and crash for >3 players).
    for (final label in const ['1st', '2nd', '3rd']) {
      expect(find.text(label), findsOneWidget, reason: '$label podium slot at $size');
    }
  }

  testWidgets('Responsive smoke: phone 390x844', (tester) async {
    await driveApp(tester, const Size(390, 844));
  });

  testWidgets('Responsive smoke: tablet 600x1024', (tester) async {
    await driveApp(tester, const Size(600, 1024));
  });

  testWidgets('Responsive smoke: desktop 1024x768', (tester) async {
    await driveApp(tester, const Size(1024, 768));
  });

  testWidgets('Responsive smoke: laptop 1280x720', (tester) async {
    await driveApp(tester, const Size(1280, 720));
  });
}
