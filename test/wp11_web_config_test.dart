import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web boot layer, CanvasKit preload and cache rules stay wired', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('id="pn-boot"'));
    expect(
      index,
      contains(
        '<link rel="preload" href="canvaskit/canvaskit.wasm" '
        'as="fetch" type="application/wasm" crossorigin>',
      ),
    );
    expect(index, contains('addEventListener("flutter-first-frame"'));
    expect(index, contains('el.remove()'));

    final firebase =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    final hosting = firebase['hosting'] as Map<String, dynamic>;
    final headers = (hosting['headers'] as List).cast<Map<String, dynamic>>();
    final sources = [for (final rule in headers) rule['source'] as String];

    expect(sources.where((source) => source == '/canvaskit/**'), hasLength(1));
    expect(
      sources.where((source) => source == '/assets/**/*.@(ttf|otf|png)'),
      hasLength(1),
    );
    expect(sources.indexOf('/canvaskit/**'), lessThan(sources.indexOf('**')));
    expect(
      sources.indexOf('/assets/**/*.@(ttf|otf|png)'),
      lessThan(sources.indexOf('**')),
    );

    String cacheControl(String source) {
      final rule = headers.singleWhere((entry) => entry['source'] == source);
      final values = (rule['headers'] as List).cast<Map<String, dynamic>>();
      return values.singleWhere(
            (entry) => entry['key'] == 'Cache-Control',
          )['value']
          as String;
    }

    expect(cacheControl('/canvaskit/**'), 'public, max-age=86400');
    expect(
      cacheControl('/assets/**/*.@(ttf|otf|png)'),
      'public, max-age=604800',
    );
  });
}
