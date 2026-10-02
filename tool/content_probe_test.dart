/// Content probe (tool): dumps every rendered Text per seeded screen so empty
/// screens can be identified precisely. Report: spec_boards/content_audit.txt
/// Run: flutter test tool/content_probe_test.dart
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter/material.dart';
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
    FlutterError.onError = (_) {};
  });
  tearDown(() {
    RecoveryService.enabled = true;
    FlutterError.onError = FlutterError.presentError;
  });

  setUpAll(() async {
    await registerBoardFonts();
    File('spec_boards/content_audit.txt')
        .writeAsStringSync('content audit\n', mode: FileMode.write);
  });

  for (final factor in ['mobile', 'desktop']) {
    group('content $factor', () {
      for (final entry in boardEntries.entries) {
        testWidgets('${entry.key} @ $factor', (t) async {
          t.view.physicalSize = factor == 'mobile'
              ? const Size(390, 844)
              : const Size(1440, 900);
          t.view.devicePixelRatio = 1.0;
          addTearDown(t.view.reset);

          final app = AppProvider();
          seedBoardProvider(app,
              game: entry.value.game, cash: entry.value.cash);
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => entry.value.shelled
                    ? Scaffold(
                        backgroundColor: const Color(0xFF0A0A0A),
                        body: entry.value.build(),
                      )
                    : entry.value.build(),
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
          await t.pump(const Duration(milliseconds: 800));
          await fillAuthForms(t, entry.key);
          await t.runAsync(() async {
            for (final f in List.of(pendingFontFutures)) {
              try {
                await f.timeout(const Duration(seconds: 5));
              } catch (_) {}
            }
          });
          await t.pump();

          final texts = t
              .widgetList<Text>(find.byType(Text))
              .map((w) =>
                  (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll(
                      RegExp(r'\s+'), ' ').trim())
              .where((s) => s.isNotEmpty)
              .toSet()
              .take(45)
              .toList();
          final loading = find
              .byType(CircularProgressIndicator)
              .evaluate()
              .isNotEmpty;
          final errors =
              find.byType(ErrorWidget).evaluate().isNotEmpty;
          final edits = t
              .widgetList<EditableText>(find.byType(EditableText))
              .map((w) => w.controller.text)
              .where((s) => s.isNotEmpty)
              .toList();
          File('spec_boards/content_audit.txt').writeAsStringSync(
              '${entry.key} @$factor loading=$loading errors=$errors '
              'ntext=${texts.length} inputs=${edits.join(' | ')} :: ${texts.join(' | ')}\n',
              mode: FileMode.append);

          await t.pumpWidget(const SizedBox.shrink());
          app.dispose();
          await t.pump();
          while (t.takeException() != null) {}
        });
      }
    });
  }
}
