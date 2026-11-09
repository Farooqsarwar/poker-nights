// Verification for C9's share image (checklist row 56: "Tap Share on C9 ->
// fixed 1,080 x 1,350 canvas layout - verified exact"). The card must
// rasterise to EXACTLY 1,080 x 1,350 px and must not be blank.
//
// The dimensions are not asserted from the widget's own measure — the image is
// captured through the same `captureShareCard()` the Share action uses, so what
// is checked here is what is actually shared.
//
// ## Every capture goes through `tester.runAsync`
//
// This is the whole reason the file used to hang. `RenderRepaintBoundary
// .toImage()` resolves on the engine's raster path, which does not resolve
// inside the fake-async zone a `testWidgets` body runs in. The failure is
// silent and total: the body runs to its last line, then `flutter test` never
// returns — the binding's end-of-test `runApp`/`pump` never completes, so not
// even `--timeout` fires and the reporter prints nothing. `runAsync` runs the
// call in the real event loop, where it completes in milliseconds.
//
// ## google_fonts
//
// `google_fonts` cannot fetch inside the test sandbox, so the per-style load
// errors it throws are tolerated: text then renders in the engine's fallback
// face, which is fine — this test is about pixels and geometry, not type.
// The card never goes through `GoogleFonts.*` anyway; it names the family
// directly (see `share_card.dart`).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/utils/share_card.dart';

ShareCardData _fixture() => const ShareCardData(
  eyebrow: 'FRIDAY REGULARS · 2 OCT',
  headline: 'Alexey wins',
  metaLine: '11 players · 189 prize pool',
  podium: [
    SharePodiumEntry(
      place: 1,
      name: 'Alexey R.',
      prizeText: '97',
      seasonPointsText: '+34.6 pts',
    ),
    SharePodiumEntry(
      place: 2,
      name: 'Nina T.',
      prizeText: '58',
      seasonPointsText: '+24.5 pts',
    ),
    SharePodiumEntry(
      place: 3,
      name: 'Hugo M.',
      prizeText: '34',
      seasonPointsText: '+20.0 pts',
    ),
  ],
  mostKnockouts: ShareAward(
    label: 'MOST KNOCKOUTS',
    valueText: 'Alexey R. · 4 KOs',
  ),
);

/// google_fonts cannot fetch in the sandbox and throws once per text style.
/// Those are environment noise; anything else is a real failure, so they are
/// separated rather than all swallowed — the same split `screen_smoke_test`
/// makes.
void _drainFontErrors(WidgetTester tester) {
  final real = <Object>[];
  while (true) {
    final e = tester.takeException();
    if (e == null) break;
    final text = e.toString();
    if (text.contains('google_fonts') || text.contains('Failed to load font')) {
      continue;
    }
    real.add(e);
  }
  if (real.isNotEmpty) {
    fail('Share card raised: $real');
  }
}

/// A 1:1 pixel ratio on the 1,080 x 1,350 surface, so the logical canvas the
/// widget lays out on IS the pixel canvas that gets captured.
void _useCardSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(
    ShareCardSpec.imageWidth,
    ShareCardSpec.imageHeight,
  );
  addTearDown(tester.view.reset);
}

/// The rows the PNT lockup occupies on the canvas, as `_ShareCardView` lays it
/// out: the logo is the last 120px of a column that ends 64px above the bottom
/// edge, so 1350 - 64 - 120 .. 1350 - 64.
const int _logoBandTop = 1350 - 64 - 120;
const int _logoBandBottom = 1350 - 64;

/// Packed 32-bit colour at (`x`, `y`) in a `rawRgba` buffer.
int _pixelAt(Uint8List pixels, int x, int y) {
  final i = (y * ShareCardSpec.imageWidth.toInt() + x) * 4;
  return pixels[i] << 24 |
      pixels[i + 1] << 16 |
      pixels[i + 2] << 8 |
      pixels[i + 3];
}

/// Distinct colours in the rows `fromY`..`toY`, sampled every `step` bytes.
///
/// A stride, not a full histogram: 5.8 MB is more than enough to tell "the
/// card painted" from "the card is one flat colour", and a full pass costs
/// more than it proves. Stops at 65 because every assertion here is `> N`.
int _distinctColours(
  Uint8List pixels, {
  int fromY = 0,
  int toY = 1350,
  int step = 4 * 37,
}) {
  final width = ShareCardSpec.imageWidth.toInt();
  final colours = <int>{};
  final end = toY * width * 4;
  for (var i = fromY * width * 4; i + 3 < end; i += step) {
    colours.add(
      pixels[i] << 24 |
          pixels[i + 1] << 16 |
          pixels[i + 2] << 8 |
          pixels[i + 3],
    );
    if (colours.length > 64) return colours.length;
  }
  return colours.length;
}

void main() {
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
    // The repo's pattern (`phase_*_probe.dart`): a sandbox with no network
    // must not start a font fetch at all, rather than failing each one.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('share card rasterises to exactly 1080 x 1350', (
    WidgetTester tester,
  ) async {
    _useCardSurface(tester);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: key, child: buildShareCard(_fixture())),
      ),
    );
    _drainFontErrors(tester);

    // The same step `shareResults` takes before it inserts the overlay: the
    // card draws the PNT lockup from an asset, and the capture reads the layer
    // as it stands, so the image has to be decoded first. In the running app
    // this is already warm — the shell's top bar draws the same lockup — which
    // is exactly why it is easy to forget, and why it is asserted below.
    await tester.runAsync(
      () => precacheImage(brandLockupImage(), key.currentContext!),
    );
    await tester.pumpAndSettle();
    _drainFontErrors(tester);

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    expect(boundary.size.width, ShareCardSpec.imageWidth);
    expect(boundary.size.height, ShareCardSpec.imageHeight);

    final captured = (await tester.runAsync(() => captureShareCard(boundary)))!;
    addTearDown(captured.dispose);

    // The contract, asserted on the bitmap and not on the render box.
    expect(captured.width, 1080);
    expect(captured.height, 1350);
    expect(captured.pngBytes, isNotEmpty);
    // A PNG's magic number: proof these are PNG bytes and not an empty or
    // half-written buffer.
    expect(captured.pngBytes.sublist(0, 8), <int>[
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);

    final rgba = (await tester.runAsync(
      () => captured.image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final pixels = rgba.buffer.asUint8List();
    expect(pixels.length, 1080 * 1350 * 4);

    // A silently blank bitmap is the other way this feature fails: `toImage`
    // on an unpainted boundary still returns a correctly-sized, uniformly
    // transparent image. Real colour variety proves the rule, the type and the
    // podium all painted.
    expect(_distinctColours(pixels), greaterThan(8));

    // The red top rule is the spec's first element; 4px down is inside it and
    // 700px down is page background, so the two must differ. This is the "did
    // anything paint in the right place" check, not just "not one colour".
    expect(_pixelAt(pixels, 540, 4), isNot(equals(_pixelAt(pixels, 540, 700))));

    // The bottom band carries the PNT lockup — the one thing on the card that
    // is an asset rather than a primitive. If it did not decode before the
    // capture, the exported image is a results table with no brand on it and
    // nothing above would notice.
    expect(
      _distinctColours(
        pixels,
        fromY: _logoBandTop,
        toY: _logoBandBottom,
        step: 4,
      ),
      greaterThan(3),
    );
  });

  testWidgets('deal variant swaps the headline on the same canvas', (
    WidgetTester tester,
  ) async {
    _useCardSurface(tester);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: buildShareCard(
            const ShareCardData(
              eyebrow: 'FRIDAY REGULARS · 2 OCT',
              headline: 'Deal at 3 players',
              metaLine: '11 players · 189 prize pool',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _drainFontErrors(tester);

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final captured = (await tester.runAsync(() => captureShareCard(boundary)))!;
    addTearDown(captured.dispose);

    // Same canvas, so the layout that holds at 1,080 x 1,350 with a full
    // podium also holds with nothing on it.
    expect(captured.width, 1080);
    expect(captured.height, 1350);
  });

  // The first two tests drive `buildShareCard` directly, which proves the card
  // is right. This one drives `mountShareCard` — the function the Share button
  // actually calls — because the off-screen overlay dance has its own ways to
  // fail that no assertion on the card can see: an entry that never lays out,
  // a frame that has not painted, an asset that has not decoded. Each of those
  // still yields a correctly-sized 1,080 x 1,350 PNG, so the only way to catch
  // them is to capture the real mount and look at the pixels.
  testWidgets('the off-screen mount the Share action captures is the same card', (
    WidgetTester tester,
  ) async {
    _useCardSurface(tester);

    late OverlayState overlay;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            overlay = Overlay.of(context, rootOverlay: true);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    _drainFontErrors(tester);

    // Started, not awaited: `mountShareCard` waits on `endOfFrame`, so the test
    // has to be the thing that produces the frames it is waiting for.
    final mount = mountShareCard(overlay, _fixture());
    await tester.pump();
    await tester.pump();
    final mounted = await mount;
    addTearDown(mounted.dispose);
    _drainFontErrors(tester);

    // Laid out at the card's own size even while parked off the left edge: the
    // canvas is the widget's size, not a scaled-down fit to the phone.
    expect(mounted.boundary.size.width, ShareCardSpec.imageWidth);
    expect(mounted.boundary.size.height, ShareCardSpec.imageHeight);
    expect(mounted.boundary.hasSize, isTrue);

    final captured = (await tester.runAsync(
      () => captureShareCard(mounted.boundary),
    ))!;
    addTearDown(captured.dispose);

    expect(captured.width, 1080);
    expect(captured.height, 1350);
    expect(captured.pngBytes.sublist(0, 8), <int>[
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);

    final rgba = (await tester.runAsync(
      () => captured.image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final pixels = rgba.buffer.asUint8List();
    expect(pixels.length, 1080 * 1350 * 4);
    expect(_distinctColours(pixels), greaterThan(8));
    // The same logo band as the first test, and the reason `mountShareCard`
    // precaches: nothing else on the card is an asset, so a missing logo is the
    // one regression that leaves an otherwise-painted card looking complete.
    expect(
      _distinctColours(
        pixels,
        fromY: _logoBandTop,
        toY: _logoBandBottom,
        step: 4,
      ),
      greaterThan(3),
    );

    mounted.dispose();
    await tester.pump();
    // The whole point of parking it off-screen: it must be gone from the tree,
    // not left covering whatever the user was looking at. Asserted on the
    // render object rather than a `find.byType` count, because the app's own
    // boundaries would make a count unreadable.
    expect(mounted.boundary.attached, isFalse);
    // And disposing twice must not trip `OverlayEntry.remove`'s "should be
    // removed only once" assert — `shareResults` disposes in a `finally`.
    mounted.dispose();
  });
}
