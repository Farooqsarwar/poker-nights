/// Spec-board capture harness: screenshots the REAL widgets, SEEDED with a
/// realistic Friday-night session (see board_fixtures.dart), at two viewports.
///
/// Mobile  = 390x844 logical @2x  -> spec_boards/mobile/captures/`<id>`.png
/// Desktop = 1440x900 logical @1x -> spec_boards/desktop/captures/`<id>`.png
///
/// Never fails: per-screen exceptions go to spec_boards/capture_log.txt for
/// review. Run explicitly: flutter test tool/capture_boards_test.dart
library;

// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart'
    show pendingFontFutures;
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/theme.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:provider/provider.dart';

import 'board_fixtures.dart';

void main() {
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
    RecoveryService.enabled = false;
    GoogleFonts.config.allowRuntimeFetching = false;
    // Captures, not assertions: async environment noise (connectivity
    // channel, font fetch) is logged per screen, never thrown.
    FlutterError.onError = (_) {};
  });
  tearDown(() {
    RecoveryService.enabled = true;
    FlutterError.onError = FlutterError.presentError;
  });

  setUpAll(() async {
    await registerBoardFonts();
    for (final f in ['mobile', 'desktop']) {
      Directory('spec_boards/$f/captures').createSync(recursive: true);
    }
    File('spec_boards/capture_log.txt')
        .writeAsStringSync('capture log\n', mode: FileMode.write);
  });

  final entries = boardEntries;

  const factors = {
    'mobile': (Size(390, 844), 2.0),
    'desktop': (Size(1440, 900), 1.0),
  };

  for (final factor in factors.entries) {
    group('capture ${factor.key}', () {
      for (final entry in entries.entries) {
        testWidgets('${entry.key} @ ${factor.key}', (t) async {
          final logical = factor.value.$1;
          final dpr = factor.value.$2;
          t.view.physicalSize =
              Size(logical.width * dpr, logical.height * dpr);
          t.view.devicePixelRatio = dpr;
          addTearDown(t.view.reset);

          final app = AppProvider();
          seedBoardProvider(app,
              game: entry.value.game, cash: entry.value.cash);

          final shotKey = GlobalKey();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => RepaintBoundary(
                  key: shotKey,
                  child: entry.value.shelled
                      ? Scaffold(
                          // ScreenShell's own ground (§B1 bg #0A0A0A).
                          backgroundColor: const Color(0xFF0A0A0A),
                          body: entry.value.build(),
                        )
                      : entry.value.build(),
                ),
              ),
            ],
            errorBuilder: (_, _) => const Scaffold(body: SizedBox.shrink()),
          );

          await t.pumpWidget(
            ChangeNotifierProvider<AppProvider>.value(
              value: app,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.forPalette(
                  ThemePalettes.forId('red'),
                  brightness: Brightness.dark,
                ),
                routerConfig: router,
              ),
            ),
          );
          await t.pump();
          if (entry.key == '01_01_splash') {
            // Settle on the wordmark face: past the flip, before exit fade.
            await t.pump(const Duration(milliseconds: 3200));
          } else {
            await t.pump(const Duration(milliseconds: 800));
          }
          // Dummy input on the auth boards so captures show completed forms.
          await fillAuthForms(t, entry.key);
          // Same font settle as the responsive audit: capture final metrics.
          await t.runAsync(() async {
            for (final f in List.of(pendingFontFutures)) {
              try {
                await f.timeout(const Duration(seconds: 5));
              } catch (_) {}
            }
          });
          await t.pump(const Duration(milliseconds: 600));

          final problems = <String>[];
          Object? e;
          while ((e = t.takeException()) != null) {
            problems.add(e.toString().split('\n').first);
          }

          await t.runAsync(() async {
            final obj = shotKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
            final img = await obj.toImage(
                pixelRatio: t.view.devicePixelRatio);
            final bytes =
                await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'spec_boards/${factor.key}/captures/${entry.key}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
            final line =
                '${entry.key} @ ${factor.key}: ${problems.isEmpty ? 'clean' : problems.join(' | ')}';
            await File('spec_boards/capture_log.txt')
                .writeAsString('$line\n', mode: FileMode.append);
          });
          print('captured ${entry.key} @ ${factor.key}');

          await t.pumpWidget(const SizedBox.shrink());
          app.dispose();
          await t.pump();
          while (t.takeException() != null) {}
        });
      }
    });
  }
}
