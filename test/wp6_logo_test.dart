import 'dart:ui' as ui;
import 'dart:io';

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

  test('rounded palette marks keep their full transparent canvas', () async {
    const colours = <String, int>{
      'cosmic_ai': 0xff3b82f6,
      'crimson_glass': 0xffe11d48,
      'dark_orange': 0xffff6b00,
      'dark_yellow': 0xfff5a623,
      'red': 0xffd32727,
    };
    for (final entry in colours.entries) {
      final asset = await rootBundle.load(brandLogoAssetPath(entry.key));
      final codec = await ui.instantiateImageCodec(asset.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      try {
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        expect(rgba, isNotNull);
        int pixel(int x, int y) => rgba!.getUint32((y * image.width + x) * 4);
        expect(pixel(0, 0) & 0xff, 0, reason: '${entry.key} margin');
        expect(pixel(1213, 200) & 0xff, 0, reason: '${entry.key} top gap');
        for (final x in <int>[900, 1213, 1526]) {
          final offset = (1300 * image.width + x) * 4;
          expect(rgba!.getUint8(offset), (entry.value >> 16) & 0xff);
          expect(rgba.getUint8(offset + 1), (entry.value >> 8) & 0xff);
          expect(rgba.getUint8(offset + 2), entry.value & 0xff);
          expect(rgba.getUint8(offset + 3), 255);
        }
      } finally {
        image.dispose();
        codec.dispose();
      }
    }
  });

  test('web and iOS launcher icons use the approved Poker Night mark', () async {
    const icons = <String, int>{
      'web/favicon.png': 32,
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png':
          1024,
    };
    for (final entry in icons.entries) {
      final bytes = File(entry.key).readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      try {
        expect((image.width, image.height), (entry.value, entry.value));
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        expect(data, isNotNull);
        final center =
            ((entry.value ~/ 2) * entry.value + entry.value ~/ 2) * 4;
        expect(data!.getUint8(center), 0xd3, reason: entry.key);
        expect(data.getUint8(center + 1), 0x27, reason: entry.key);
        expect(data.getUint8(center + 2), 0x27, reason: entry.key);
        expect(data.getUint8(center + 3), 255, reason: entry.key);
      } finally {
        image.dispose();
        codec.dispose();
      }
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
      expect(
        find.descendant(
          of: find.byType(PokerNightLogo),
          matching: find.byType(ClipOval),
        ),
        findsNothing,
        reason: 'The complete mark remains visible at $size px',
      );
    }
  });

  test('share-card precache uses the central palette asset path', () {
    expect(brandLockupImage().assetName, brandLogoAssetPath());
  });
}
