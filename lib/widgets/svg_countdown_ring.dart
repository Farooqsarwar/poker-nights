import 'package:flutter/material.dart';

import '../app/colors.dart';

/// SVG countdown ring (implemented natively via CustomPainter for crisp scaling).
class SvgCountdownRing extends StatelessWidget {
  const SvgCountdownRing({
    super.key,
    required this.progress,
    required this.scale,
  });

  final double progress;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48 * scale,
      height: 48 * scale,
      child: CustomPaint(
        size: Size(48 * scale, 48 * scale),
        painter: _CountdownRingPainter(
          progress: progress,
          strokeWidth: 4 * scale,
          color: AppColors.primary,
          backgroundColor: AppColors.border,
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159265358979323846 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159265358979323846 / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
