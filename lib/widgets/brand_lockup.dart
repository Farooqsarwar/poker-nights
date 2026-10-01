import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';

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
    final logoPath =
        'assets/logo_${AppColors.currentPalette.id.replaceAll("-", "_")}.png';
    return Image.asset(
      logoPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// The "pokernighttools" brand lockup featuring the real asset logo according to theme.
class PokerNightBrand extends StatelessWidget {
  const PokerNightBrand({
    super.key,
    this.logoSize = 28,
    this.fontSize = 20,
  });

  final double logoSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PokerNightLogo(
          size: logoSize,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'pokernight',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'tools',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
