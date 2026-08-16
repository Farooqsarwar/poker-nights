import 'package:flutter/material.dart';

/// ============================================================
/// pokernighttools — Primary Logo Widget
/// Scan-corner frame + spade mark, with optional wordmark below.
/// Matches the moodboard: red (#D53032) on black, white/black variants.
/// ============================================================

class PokerNightLogo extends StatelessWidget {
  final double size;
  final Color frameColor;
  final Color spadeColor;
  final bool showWordmark;
  final double wordmarkFontSize;

  const PokerNightLogo({
    super.key,
    this.size = 160,
    this.frameColor = const Color(0xFFD53032),
    this.spadeColor = const Color(0xFFD53032),
    this.showWordmark = true,
    this.wordmarkFontSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _ScanFramePainter(
                  frameColor: frameColor,
                ),
              ),
              Transform.translate(
                offset: Offset(0, size * 0.035), // Optical adjustment to push it down
                child: Text(
                  '♠',
                  style: TextStyle(
                    fontSize: size * 0.6,
                    color: spadeColor,
                    height: 1.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showWordmark) ...[
          SizedBox(height: size * 0.18),
          _Wordmark(fontSize: wordmarkFontSize),
        ],
      ],
    );
  }
}

/// "poker" (white) + "night" (red) + "tools" (white)
/// Font: Space Grotesk Mono — register in pubspec.yaml (see bottom of file).
class _Wordmark extends StatelessWidget {
  final double fontSize;
  const _Wordmark({required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'SpaceMono', // updated to match our pubspec/typography
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.0,
        ),
        children: const [
          TextSpan(text: 'poker ', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'night ', style: TextStyle(color: Color(0xFFD53032))),
          TextSpan(text: 'tools', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

/// Draws the four corner brackets (scan-viewfinder style)
class _ScanFramePainter extends CustomPainter {
  final Color frameColor;

  _ScanFramePainter({
    required this.frameColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ---------- Scan-corner frame ----------
    final framePaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final inset = w * 0.06;
    final cornerLen = w * 0.22;
    final r = w * 0.07;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(inset, inset + cornerLen)
        ..lineTo(inset, inset + r)
        ..quadraticBezierTo(inset, inset, inset + r, inset)
        ..lineTo(inset + cornerLen, inset),
      framePaint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - inset - cornerLen, inset)
        ..lineTo(w - inset - r, inset)
        ..quadraticBezierTo(w - inset, inset, w - inset, inset + r)
        ..lineTo(w - inset, inset + cornerLen),
      framePaint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - inset, h - inset - cornerLen)
        ..lineTo(w - inset, h - inset - r)
        ..quadraticBezierTo(w - inset, h - inset, w - inset - r, h - inset)
        ..lineTo(w - inset - cornerLen, h - inset),
      framePaint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(inset + cornerLen, h - inset)
        ..lineTo(inset + r, h - inset)
        ..quadraticBezierTo(inset, h - inset, inset, h - inset - r)
        ..lineTo(inset, h - inset - cornerLen),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) {
    return oldDelegate.frameColor != frameColor;
  }
}
