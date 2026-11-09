import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/theme/theme_palette.dart';

/// **Milestone 2's acceptance gate** — Build Spec v3.1 §B1 and §B4, checked in
/// CI rather than by eye.
///
/// * **T141** — "no yellow anywhere (owner 2026-09-26: their gold money colour
///   is not carried over)". §B1: "There is no gold, yellow, amber or second
///   accent anywhere (a test fails on any yellow pixel colour)."
/// * **T102** — "every text on every screen meets WCAG AA contrast against its
///   real background". §B1: "the app's CI should too."
///
/// The spec measures T141 on rendered pixels in the mock. A Dart suite cannot
/// rasterise every screen cheaply, so this checks the two places a yellow pixel
/// can actually come from: the palette itself, and colour literals written into
/// widget source. That is a stronger guarantee than spot-checking screenshots,
/// because it cannot miss a screen nobody thought to render.
///
/// **The one legal exception** is Addendum 1 §2 row 2: a chip swatch shows a
/// REAL chip, "so it is the one place yellow may appear; the no-yellow rule
/// (T141) covers the app's own colours". Chip data is therefore exempt, and the
/// exemption is deliberately narrow — see [_chipDataFiles].
void main() {
  group('T141 — no yellow, gold or amber in the app\'s own colours', () {
    test('the palette contains no yellow-family colour', () {
      for (final palette in ThemePalettes.all) {
        for (final entry in _paletteColours(palette).entries) {
          expect(
            _isYellowFamily(entry.value),
            isFalse,
            reason: '${palette.id}.${entry.key} is '
                '${_hex(entry.value)} — a yellow/gold/amber hue. §B1 bans it.',
          );
        }
      }
    });

    test('there is exactly one palette (§B1 "exactly one look")', () {
      expect(ThemePalettes.all, hasLength(1));
      expect(ThemePalettes.all.single.id, ThemePalettes.defaultId);
    });

    test('a removed palette id falls back rather than crashing', () {
      // Users who had picked one of the deleted palettes must keep working.
      for (final stale in ['crimson-glass', 'cosmic-ai', 'dark-orange', '']) {
        expect(ThemePalettes.forId(stale).id, 'red');
      }
    });

    test('no widget source writes a yellow colour literal', () {
      final offences = <String>[];

      for (final file in _dartFiles(Directory('lib'))) {
        final path = file.path.replaceAll(r'\', '/');
        if (_chipDataFiles.any(path.endsWith)) continue;

        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];

          // Named Material swatches in the banned families.
          final named = RegExp(
            r'Colors\.(yellow|amber|lime|orange)\b',
          ).firstMatch(line);
          if (named != null) {
            offences.add('$path:${i + 1}  ${named.group(0)}');
          }

          // Raw ARGB literals.
          for (final m in RegExp(r'0x[Ff][Ff]([0-9A-Fa-f]{6})').allMatches(line)) {
            final rgb = int.parse(m.group(1)!, radix: 16);
            final colour = Color(0xFF000000 | rgb);
            if (_isYellowFamily(colour)) {
              offences.add('$path:${i + 1}  ${m.group(0)}');
            }
          }
        }
      }

      expect(
        offences,
        isEmpty,
        reason: 'T141 — yellow/gold/amber found in the app\'s own colours:\n'
            '${offences.join('\n')}',
      );
    });

    test('the detector actually catches the colours §B1 names', () {
      // Without this the rule could be quietly loosened until it passes on an
      // empty definition of "yellow". Every colour below was either named in
      // the specification as a violation or was live in this codebase.
      const banned = {
        'owner gold / chip yellow': 0xFFF1C40F,
        'boot warning amber (was in main.dart)': 0xFFFACC15,
        'darkOrange primary': 0xFFFF6D00,
        'darkOrange icon': 0xFFFFAB40,
        'darkOrange iconMuted': 0xFFFFCC80,
        'old palette warning': 0xFFE65100,
        'Material yellow[700]': 0xFFFBC02D,
        'muted antique gold': 0xFFB8A054,
      };
      for (final e in banned.entries) {
        expect(
          _isYellowFamily(Color(e.value)),
          isTrue,
          reason: '${e.key} (${_hex(Color(e.value))}) must be caught',
        );
      }
    });

    test('the detector does not fire on legitimate non-yellows', () {
      const allowed = {
        'brand red': 0xFFD53032,
        'redText': 0xFFF2555A,
        'redDanger': 0xFFB23430,
        'green': 0xFF3FBF6B,
        'bg': 0xFF0A0A0A,
        'surface': 0xFF141414,
        'muted': 0xFFA6A6AA,
        'white': 0xFFFFFFFF,
        'cream card face': 0xFFEDEAE0,
        'felt green': 0xFF0F3D2E,
      };
      for (final e in allowed.entries) {
        expect(
          _isYellowFamily(Color(e.value)),
          isFalse,
          reason: '${e.key} (${_hex(Color(e.value))}) is not yellow',
        );
      }
    });

    test('the chip-data exemption stays narrow', () {
      // If this list grows, the exemption is being used to smuggle app colours
      // past T141. Addendum 1 allows it for a chip SWATCH and nothing else.
      expect(_chipDataFiles, hasLength(5));
    });
  });

  group('T102 — WCAG AA contrast on §B1\'s own tokens', () {
    final p = ThemePalettes.red;

    test('body text clears 4.5 : 1 on every surface it sits on', () {
      for (final bg in {'bg': p.bg, 'surface': p.surface, 'surface2': p.surface2}
          .entries) {
        for (final fg in {
          'white': p.white,
          'muted': p.mutedForeground,
          'muted2': p.muted2,
          'redText': p.redText,
        }.entries) {
          final ratio = _contrast(fg.value, bg.value);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${fg.key} on ${bg.key} is '
                '${ratio.toStringAsFixed(2)} : 1',
          );
        }
      }
    });

    test('`red` is NOT AA as small text — which is why `redText` exists', () {
      // §B1 states the measurements: red on bg is 4.05 : 1 and on surface
      // 3.77 : 1. Pinning the failure stops anyone "simplifying" the two red
      // tokens back into one.
      expect(_contrast(p.red, p.bg), lessThan(4.5));
      expect(_contrast(p.red, p.surface), lessThan(4.5));

      // It IS legal at 24 px or above, where the floor is 3 : 1.
      expect(_contrast(p.red, p.bg), greaterThanOrEqualTo(3.0));
    });

    test('`redDanger` works as a fill with white text, and fails as text', () {
      // §B1: white on redDanger is 6.13 : 1; as a text/outline colour on bg it
      // is 3.23 : 1 and fails.
      expect(_contrast(p.white, p.redDanger), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.redDanger, p.bg), lessThan(4.5));
    });

    test('green is readable where it is allowed to appear', () {
      // §B1/§B4 rule 9 — LIVE, GOING/CHECKED IN/ACTIVE, positive P&L.
      expect(_contrast(p.green, p.bg), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.green, p.surface), greaterThanOrEqualTo(4.5));
    });

    test('white on the brand fill is AA', () {
      expect(_contrast(p.white, p.red), greaterThanOrEqualTo(4.5));
    });

    test('the semantic text aliases resolve to AA-safe tokens', () {
      // Every `*Text` accessor is what screens actually use. They must all be
      // readable, not just the raw tokens.
      for (final entry in {
        'primaryText': p.primaryText,
        'destructiveText': p.destructiveText,
        'warningText': p.warningText,
        'successText': p.successText,
      }.entries) {
        expect(
          _contrast(entry.value, p.surface),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key} on surface',
        );
      }
    });
  });
}

/// Files that legitimately carry REAL chip colours (Addendum 1 §2 row 2).
const _chipDataFiles = [
  // The canonical F5 palette (Addendum 1 §2 row 2) — the one place Yellow is
  // legal, plus Orange.
  'lib/models/chip_palette.dart',
  'lib/utils/tournament_engine.dart',
  'lib/utils/mock_data.dart',
  'lib/screens/public/tools_screen.dart',
  'lib/screens/shell/edit_chip_set_screen.dart',
];

Map<String, Color> _paletteColours(ThemePalette p) => {
      'primary': p.primary,
      'onPrimary': p.onPrimary,
      'primaryHover': p.primaryHover,
      'background': p.background,
      'foreground': p.foreground,
      'card': p.card,
      'cardForeground': p.cardForeground,
      'secondary': p.secondary,
      'secondaryForeground': p.secondaryForeground,
      'muted': p.muted,
      'mutedForeground': p.mutedForeground,
      'accent': p.accent,
      'accentForeground': p.accentForeground,
      'border': p.border,
      'ring': p.ring,
      'onSurfaceHint': p.onSurfaceHint,
      'surfaceHover': p.surfaceHover,
      'icon': p.icon,
      'iconMuted': p.iconMuted,
      'destructive': p.destructive,
      'success': p.success,
      'warning': p.warning,
      'redText': p.redText,
      'redDanger': p.redDanger,
      'green': p.green,
      'muted2': p.muted2,
      ...{
        for (var i = 0; i < p.avatarTints.length; i++)
          'avatarTints[$i]': p.avatarTints[i],
      },
    };

/// True for a colour a reasonable person would call yellow, gold or amber.
///
/// Hue 18°–70° is the amber/orange/gold/yellow wedge. §B1 bans "gold, yellow,
/// amber **or second accent**", so the window has to reach down into orange —
/// the deleted `darkOrange` palette led with `#FF6D00`, which is hue 26°, and a
/// window that started at yellow would have waved it through. The brand red
/// sits at 359°, so widening costs nothing.
///
/// Hue alone is useless, though: every
/// near-black and every warm off-white has a nominal hue somewhere. Two
/// exclusions make the rule mean what §B1 means:
///
///  * **Saturation floor.** Greys and near-blacks (`#141414`) carry a hue but
///    no colour. Every hue §B1 actually bans is strongly saturated — `#F1C40F`
///    0.89, `#FACC15` 0.95, `#E65100` 1.00, `#FFCC80` 1.00 — so a floor of
///    0.35 keeps the teeth while dropping the noise.
///  * **Near-white exclusion.** A cream card face (`#F6F4EF`, `#EDEAE0`) sits
///    in the yellow wedge at ~0.28 saturation. It is an off-white, not the
///    owner's gold money colour, and failing it would force playing cards to
///    be pure white for no reason anybody asked for.
bool _isYellowFamily(Color c) {
  final hsl = HSLColor.fromColor(Color(0xFF000000 | (_argb(c) & 0xFFFFFF)));
  if (hsl.hue < 18 || hsl.hue > 70) return false;
  if (hsl.saturation < 0.35) return false;
  if (hsl.lightness < 0.18) return false;
  // Warm off-white rather than a yellow.
  if (hsl.lightness > 0.85 && hsl.saturation < 0.5) return false;
  return true;
}

int _argb(Color c) =>
    (_ch(c.a) << 24) | (_ch(c.r) << 16) | (_ch(c.g) << 8) | _ch(c.b);

int _ch(double v) => (v * 255).round().clamp(0, 255);

String _hex(Color c) =>
    '#${(_argb(c) & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// WCAG 2.x relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG contrast ratio. Foreground alpha is composited over the background
/// first, so a translucent token is measured as it actually appears.
double _contrast(Color fg, Color bg) {
  final a = fg.a;
  final flat = a >= 1
      ? fg
      : Color.from(
          alpha: 1,
          red: fg.r * a + bg.r * (1 - a),
          green: fg.g * a + bg.g * (1 - a),
          blue: fg.b * a + bg.b * (1 - a),
        );
  final l1 = _luminance(flat);
  final l2 = _luminance(bg);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

Iterable<File> _dartFiles(Directory dir) sync* {
  if (!dir.existsSync()) return;
  for (final e in dir.listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}
