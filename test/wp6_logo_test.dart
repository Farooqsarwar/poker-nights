import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/utils/share_card.dart';
import 'package:poker_night/widgets/brand_lockup.dart';

const _paletteIds = [
  'cosmic_ai',
  'crimson_glass',
  'dark_orange',
  'dark_yellow',
  'red',
];

Future<({int width, int height, Rect visible})> _visibleBounds(
  String path,
) async {
  final asset = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(asset.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(rgba, isNotNull);

  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (rgba!.getUint8((y * image.width + x) * 4 + 3) == 0) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  image.dispose();
  codec.dispose();
  return (
    width: image.width,
    height: image.height,
    visible: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      (maxX + 1).toDouble(),
      (maxY + 1).toDouble(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all five logo assets have matching transparent safe space', (
    tester,
  ) async {
    ({int width, int height})? dimensions;
    for (final paletteId in _paletteIds) {
      final result = await _visibleBounds(brandLogoAssetPath(paletteId));
      dimensions ??= (width: result.width, height: result.height);
      expect(
        (width: result.width, height: result.height),
        dimensions,
        reason: paletteId,
      );
      expect(result.visible.left, greaterThanOrEqualTo(result.width * .08));
      expect(result.visible.top, greaterThanOrEqualTo(result.height * .08));
      expect(
        result.width - result.visible.right,
        greaterThanOrEqualTo(result.width * .08),
      );
      expect(
        result.height - result.visible.bottom,
        greaterThanOrEqualTo(result.height * .08),
      );
    }
  });

  testWidgets('logo renderer stays contained at every production size', (
    tester,
  ) async {
    for (final size in <double>[16, 22, 40, 52, 60, 200]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: PokerNightLogo(size: size)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size px');
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(PokerNightLogo),
          matching: find.byType(Image),
        ),
      );
      expect(image.fit, BoxFit.contain);
      expect(image.width, size);
      expect(image.height, size);
    }
  });

  test('share-card precache uses the central palette asset path', () {
    expect(brandLockupImage().assetName, brandLogoAssetPath());
  });
}
