import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/theme.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/widgets/app_button.dart';
import 'package:poker_night/widgets/app_card.dart';
import 'package:poker_night/widgets/app_modal.dart';
import 'package:poker_night/widgets/shell_insets.dart';

/// Renders the real widgets to PNG so their appearance can be inspected
/// rather than reasoned about:
///   flutter test test/visual_probe.dart --update-goldens
///
/// Deliberately NOT named `*_test.dart`, so `flutter test` skips it: golden
/// images depend on the host's font rendering and would fail on any other
/// machine. Run it by path when you need to look at something.
/// then look at test/goldens/*.png. Not an assertion — a camera.
///
/// google_fonts cannot fetch in the sandbox and throws per text style, so the
/// recorded exceptions are drained before the capture. The text renders in the
/// fallback face, which is fine: this is about layout and opacity, not type.
void drainFontErrors(WidgetTester t) {
  while (t.takeException() != null) {}
}

void main() {
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
  });

  Widget host(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.forPalette(
      ThemePalettes.forId('red'),
      brightness: Brightness.dark,
    ),
    home: Scaffold(
      body: Stack(
        children: [
          // Page content behind, so anything see-through is obvious and any
          // off-centre panel is easy to measure against.
          Positioned.fill(
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  26,
                  (i) => Text(
                    '|<-- LEFT EDGE   page text behind $i   '
                    'if you can read this through a panel it is see-through',
                    style: TextStyle(color: AppColors.foreground, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    ),
  );

  // Mirrors the REAL structure: the dialog lives on the root navigator, so it
  // is laid out over the WHOLE window, while it reads its inset from a
  // context inside the shell. Placing it inside the content area instead
  // would offset it twice.
  Widget shellHost(Widget Function(BuildContext shellCtx) build) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.forPalette(
      ThemePalettes.forId('red'),
      brightness: Brightness.dark,
    ),
    home: Builder(
      builder: (rootCtx) {
        late Widget overlay;
        final base = Scaffold(
          body: Row(
            children: [
              Container(
                width: 264,
                color: AppColors.card,
                child: Center(
                  child: Text(
                    'SIDEBAR',
                    style: TextStyle(color: AppColors.foreground),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ShellInsets(
                  left: 265,
                  child: Builder(
                    builder: (shellCtx) {
                      overlay = build(shellCtx);
                      return Container(
                        color: AppColors.background,
                        alignment: Alignment.topCenter,
                        child: Text(
                          'v CONTENT AREA CENTRE v',
                          style: TextStyle(color: AppColors.foreground),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
        return Stack(children: [base, Builder(builder: (_) => overlay)]);
      },
    ),
  );

  testWidgets('modal', (t) async {
    await t.binding.setSurfaceSize(const Size(1400, 860));
    await t.pumpWidget(
      host(
        AppModal(
          open: true,
          onClose: () {},
          title: 'Cancel tournament',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'This ends the event for everyone. Give a reason so members '
                'know what happened.',
                style: TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 20),
              AppButton(onPressed: () {}, child: const Text('Cancel event')),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    drainFontErrors(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/probe_modal.png'),
    );
  });

  testWidgets('cards', (t) async {
    await t.binding.setSurfaceSize(const Size(1400, 860));
    await t.pumpWidget(
      host(
        Center(
          child: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Card heading',
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Body copy on a card — this is the text that reads '
                        'badly when the surface is washed out.',
                        style: TextStyle(color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(24),
                  glow: true,
                  child: Text(
                    'A second, glowing card',
                    style: TextStyle(color: AppColors.foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    drainFontErrors(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/probe_cards.png'),
    );
  });

  testWidgets('modal on a shell route', (t) async {
    await t.binding.setSurfaceSize(const Size(1400, 860));
    await t.pumpWidget(
      shellHost(
        (ctx) => AppModal(
          open: true,
          onClose: () {},
          title: 'RSVPs',
          insetPadding: appDialogInsets(ctx),
          child: Text(
            'Should sit centred over the content area, not the window.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    drainFontErrors(t);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/probe_shell_modal.png'),
    );
  });
}
