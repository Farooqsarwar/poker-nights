import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';

class PokerNightLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? frameColor;
  final Color? spadeColor;
  final bool showWordmark;
  final double wordmarkFontSize;

  const PokerNightLogo({
    super.key,
    this.size = 160,
    this.color,
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
      color: color,
      fit: BoxFit.contain,
    );
  }
}

/// The brand lockup featuring the real asset logo and two-tone wordmark.
class PokerNightBrand extends StatelessWidget {
  const PokerNightBrand({
    super.key,
    this.logoSize = 28,
    this.fontSize = 20,
    this.iconColor = Colors.white,
    this.primaryText = 'pokernight',
    this.accentText = 'tools',
    this.accentColor,
  });

  final double logoSize;
  final double fontSize;
  final Color? iconColor;
  final String primaryText;
  final String accentText;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? AppColors.redText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PokerNightLogo(
          size: logoSize,
          color: iconColor,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: primaryText,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: accentText,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: effectiveAccentColor,
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
