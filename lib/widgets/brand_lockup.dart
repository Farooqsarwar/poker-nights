import 'package:flutter/material.dart';

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
    return Image.asset(
      'assets/logo.png',
      width: size,
      fit: BoxFit.contain,
    );
  }
}
