import 'package:flutter/material.dart';

import '../app/colors.dart';
class PokerNightLogo extends StatelessWidget {
  final double size;
  final Color? frameColor;
  final Color? spadeColor;
  final bool showWordmark;
  final double wordmarkFontSize;

  const PokerNightLogo({
    super.key,
    this.size = 160,
    this.frameColor,
    this.spadeColor,
    this.showWordmark = true,
    this.wordmarkFontSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final logoPath = 'assets/logo_${AppColors.currentPalette.id.replaceAll("-", "_")}.png';
    return Image.asset(logoPath, width: size, fit: BoxFit.contain);
  }
}
