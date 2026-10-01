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
  final Color? color;

  const PokerNightLogo({
    super.key,
    this.size = 160,
    this.frameColor,
    this.spadeColor,
    this.showWordmark = true,
    this.wordmarkFontSize = 28,
    this.color,
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
      colorBlendMode: color != null ? BlendMode.srcIn : null,
      fit: BoxFit.contain,
    );
  }
}

/// The "pokernighttools" brand lockup matching WhatsApp mockup.
/// Renders:
///   LOGO (eyebrow)
///   [ ♠ ] (white logo)  pokernight (white) + tools (primary crimson)
class PokerNightBrand extends StatelessWidget {
  const PokerNightBrand({
    super.key,
    this.logoSize = 28,
    this.fontSize = 20,
    this.showEyebrow = false,
  });

  final double logoSize;
  final double fontSize;
  final bool showEyebrow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showEyebrow) ...[
          Text(
            'LOGO',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground.withValues(alpha: 0.7),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PokerNightLogo(
              size: logoSize,
              color: Colors.white,
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
        ),
      ],
    );
  }
}
