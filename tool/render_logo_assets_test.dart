import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

// Run explicitly with: flutter test tool/render_logo_assets_test.dart
// The checked-in SVG is the editable source for the five palette PNGs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render rounded logo assets from the approved vector source', () async {
    final source = File('assets/logo_rounded_candidate.svg').readAsStringSync();
    final paths = RegExp(
      r'<path d="([^"]+)"/>',
      dotAll: true,
    ).allMatches(source).map((match) => _parsePath(match.group(1)!)).toList();
    expect(paths.length, 5);

    const palette = <String, int>{
      'cosmic_ai': 0xff3b82f6,
      'crimson_glass': 0xffe11d48,
      'dark_orange': 0xffff6b00,
      'dark_yellow': 0xfff5a623,
      'red': 0xffd32727,
    };

    for (final entry in palette.entries) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..color = ui.Color(entry.value)
        ..isAntiAlias = true;
      for (final path in paths) {
        canvas.drawPath(path, paint);
      }
      final image = await recorder.endRecording().toImage(2426, 2312);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      File(
        'assets/logo_${entry.key}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    }

    // DECISION: Launcher icons use the same red mark on the app's dark
    // background, with extra safe space for browser maskable icons.
    Future<void> writeLauncherIcon(
      String path,
      int size, {
      bool maskable = false,
    }) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        ui.Paint()..color = const ui.Color(0xff0a0a0a),
      );
      final scale = size / 2426 * (maskable ? 0.78 : 1.0);
      canvas.translate((size - 2426 * scale) / 2, (size - 2312 * scale) / 2);
      canvas.scale(scale);
      final redPaint = ui.Paint()
        ..color = const ui.Color(0xffd32727)
        ..isAntiAlias = true;
      for (final markPath in paths) {
        canvas.drawPath(markPath, redPaint);
      }
      final image = await recorder.endRecording().toImage(size, size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    }

    await writeLauncherIcon('web/favicon.png', 32);
    await writeLauncherIcon('web/icons/Icon-192.png', 192);
    await writeLauncherIcon('web/icons/Icon-512.png', 512);
    await writeLauncherIcon(
      'web/icons/Icon-maskable-192.png',
      192,
      maskable: true,
    );
    await writeLauncherIcon(
      'web/icons/Icon-maskable-512.png',
      512,
      maskable: true,
    );

    final iosDirectory = Directory(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    );
    for (final file in iosDirectory.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      final match = RegExp(
        r'Icon-App-(\d+(?:\.\d+)?)x\d+(?:\.\d+)?@(\d)x\.png',
      ).firstMatch(name);
      if (match == null) continue;
      final size = (double.parse(match.group(1)!) * int.parse(match.group(2)!))
          .round();
      await writeLauncherIcon(file.path, size);
    }
  });
}

ui.Path _parsePath(String source) {
  final tokens = RegExp(
    r'[MCHVZ]|-?\d+(?:\.\d+)?',
  ).allMatches(source).map((match) => match.group(0)!).toList();
  final path = ui.Path();
  var index = 0;
  var x = 0.0;
  var y = 0.0;
  while (index < tokens.length) {
    final command = tokens[index++];
    double number() => double.parse(tokens[index++]);
    switch (command) {
      case 'M':
        x = number();
        y = number();
        path.moveTo(x, y);
      case 'H':
        x = number();
        path.lineTo(x, y);
      case 'V':
        y = number();
        path.lineTo(x, y);
      case 'C':
        final x1 = number();
        final y1 = number();
        final x2 = number();
        final y2 = number();
        x = number();
        y = number();
        path.cubicTo(x1, y1, x2, y2, x, y);
      case 'Z':
        path.close();
      default:
        throw FormatException('Unexpected logo path token: $command');
    }
  }
  return path;
}
