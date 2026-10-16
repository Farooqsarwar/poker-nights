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

Future<({int width, int height, int colorType})> _pngHeader(String path) async {
  final asset = await rootBundle.load(path);
  // PNG's IHDR starts at byte 8 + chunk-length/type (8 bytes). Width and
  // height are the first two big-endian fields; color type follows bit depth.
  return (
    width: asset.getUint32(16),
    height: asset.getUint32(20),
    colorType: asset.getUint8(25),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all five logo assets have matching transparent safe space', (
    tester,
  ) async {
    ({int width, int height})? dimensions;
    for (final paletteId in _paletteIds) {
      final result = await _pngHeader(brandLogoAssetPath(paletteId));
      dimensions ??= (width: result.width, height: result.height);
      expect(
        (width: result.width, height: result.height),
        dimensions,
        reason: paletteId,
      );
      expect((result.width, result.height), (2426, 2312), reason: paletteId);
      expect(result.colorType, 6, reason: '$paletteId keeps RGBA transparency');
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
