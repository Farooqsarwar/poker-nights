import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/colors.dart';
import '../../constants/app_constants.dart';
import '../../app/typography.dart';

/// The one hero visual allowed felt green, card motifs and suit icons —
/// an explicit, scoped exception to BRIEF.md §7's "no card/felt/suit
/// clichés" rule, confirmed for this element only (user: "Build the hero
/// as specified"). Everywhere else in the app that rule still holds, the
/// same way [ChipDisc] is the one place literal chip colours appear.
///
/// A true square, sized off the available width — not a fixed-height
/// banner — capped so it can't take over the screen on wide desktops.
class PokerNightHero extends StatefulWidget {
  const PokerNightHero({super.key});

  static const double minHeight = 300;
  static const double maxHeight = 520;

  @override
  State<PokerNightHero> createState() => _PokerNightHeroState();
}

class _PokerNightHeroState extends State<PokerNightHero>
    with SingleTickerProviderStateMixin {
  // Eager, not lazy — see `PnLiveDot` for why: `dispose()` must never be
  // the first place this is touched.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;

    if (reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final viewportHeight = MediaQuery.sizeOf(context).height;
        final height = (viewportHeight * 0.54).clamp(
          PokerNightHero.minHeight,
          PokerNightHero.maxHeight,
        );
        return ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
          child: SizedBox(
            height: isMobile ? null : height,
            width: double.infinity,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.background),
              child: isMobile
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeroCopy(isMobile: isMobile),
                        SizedBox(
                          height: 320, // Taller canvas for mobile
                          width: double.infinity, // Must expand horizontally so CustomPaint has a size
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) => CustomPaint(
                                painter: _TablePainter(
                                  t: reduced ? 0 : _controller.value,
                                  isMobile: isMobile,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) => CustomPaint(
                              painter: _TablePainter(
                                t: reduced ? 0 : _controller.value,
                                isMobile: false,
                              ),
                            ),
                          ),
                        ),
                        IgnorePointer(child: _HeroCopy(isMobile: isMobile)),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final textShadow = Shadow(
      color: Colors.black.withValues(alpha: 0.85),
      offset: const Offset(0, 2),
      blurRadius: 10,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isMobile ? AppColors.background : null,
        gradient: isMobile
            ? null
            : LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0.92),
                  AppColors.background.withValues(alpha: 0.52),
                  AppColors.background.withValues(alpha: 0),
                ],
                stops: const [0, 0.48, 0.86],
              ),
      ),
      child: Padding(
        padding: isMobile
            ? const EdgeInsets.all(AppSpacing.xl)
            : const EdgeInsets.only(
                left: AppSpacing.xxl,
                right: AppSpacing.lg,
              ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.xs),
                RichText(
                  text: TextSpan(
                    style: AppTypography.display(
                      size: AppFontSizes.display,
                      weight: FontWeight.w700,
                    ).copyWith(
                      color: AppColors.foreground,
                      shadows: [textShadow],
                    ),
                    children: const [
                      TextSpan(text: 'Run your perfect'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Blinds, buy-ins, seating and settlement — one app for the whole table.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                    shadows: [textShadow],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Literal, non-token colours — scoped to this file only.
abstract final class _HeroPalette {
  static const rail = Color(0xFF3C2A1E);
  static const railLight = Color(0xFF5C4230);
  static const felt = Color(0xFF0A3D2A);
  static const feltLight = Color(0xFF135239);
  static const cardBack = Color(0xFF7A1420);
  static const cardFace = Color(0xFFF3EEE2);
  static const suitRed = Color(0xFFD1273D);
  static const suitBlack = Color(0xFF1C1C1E);
  static const chipWhite = Color(0xFFEDEAE2);
  static const chipRed = Color(0xFFC7273D);
  static const chipBlue = Color(0xFF2C5CC7);
  static const chipGreen = Color(0xFF1F8A5C);
  static const chipDark = Color(0xFF2A2A30);
}

class _TablePainter extends CustomPainter {
  _TablePainter({required this.t, required this.isMobile});

  /// 0..1, looping.
  final double t;
  final bool isMobile;

  static const _suits = ['♠', '♥', '♦', '♣', '♠'];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // A square mat, not a circle or a stretched oval — clean, right-angle
    // corners, sized off whichever dimension is tighter so it's never
    // cropped, then centered with margin either side.
    final tableWidth = size.width;
    final tableHeight = size.height;
    final tableReference = math.min(tableWidth, tableHeight);
    final cornerRadius = Radius.circular(tableReference * 0.09);
    final railRect = Rect.fromCenter(
      center: center,
      width: tableWidth,
      height: tableHeight,
    );
    final railRRect = RRect.fromRectAndRadius(railRect, cornerRadius);
    final railThickness = tableReference * 0.07;
    final feltRect = railRect.deflate(railThickness);
    final feltRRect = RRect.fromRectAndRadius(
      feltRect,
      Radius.circular(cornerRadius.x * 0.8),
    );

    _paintShadow(canvas, railRRect);
    _paintRail(canvas, railRRect);
    _paintFelt(canvas, feltRRect);
    
    // Draw elements in proper Z-order (back to front)
    
    if (isMobile) {
      // Center both rows completely, tighter layout, scaled up, no coins
      _paintCardsRow(canvas, center, feltRect, 'POKER', -feltRect.shortestSide * 0.15, 0.05, 0.60);
      final nightsCenter = center + Offset(0, feltRect.shortestSide * 0.18);
      _paintCardsRow(canvas, nightsCenter, feltRect, 'NIGHT', 0, 0.28, 0.75);
    } else {
      // Position POKER higher up to perfectly align with the "Run your perfect" text baseline
      _paintCardsRow(canvas, center, feltRect, 'POKER', -feltRect.shortestSide * 0.05, 0.05, 0.60);
      
      // Position NIGHTS below and shifted to the right
      final nightsCenter = center + Offset(feltRect.shortestSide * 0.20, feltRect.shortestSide * 0.15);
      _paintCardsRow(canvas, nightsCenter, feltRect, 'NIGHT', 0, 0.28, 0.75);
      
      _paintPot(canvas, center, feltRect);
    }
  }

  void _paintShadow(Canvas canvas, RRect railRRect) {
    final shadowRRect = railRRect
        .shift(Offset(0, railRRect.height * 0.05))
        .inflate(4);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawRRect(shadowRRect, shadow);
  }

  void _paintRail(Canvas canvas, RRect railRRect) {
    final rail = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_HeroPalette.railLight, _HeroPalette.rail],
      ).createShader(railRRect.outerRect);
    canvas.drawRRect(railRRect, rail);

    final rim = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(railRRect.deflate(1), rim);
  }

  void _paintFelt(Canvas canvas, RRect feltRRect) {
    final feltRect = feltRRect.outerRect;
    final felt = Paint()
      ..shader = const RadialGradient(
        colors: [_HeroPalette.feltLight, _HeroPalette.felt],
      ).createShader(feltRect);
    canvas.drawRRect(feltRRect, felt);

    final sheen = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 0.1),
        radius: 0.85,
        colors: [Colors.white.withValues(alpha: 0.15), Colors.transparent],
      ).createShader(feltRect);
    canvas.drawRRect(feltRRect, sheen);

    final trim = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(feltRRect.deflate(1), trim);
  }

  void _paintCardsRow(
    Canvas canvas,
    Offset center,
    Rect feltRect,
    String letters,
    double offsetY,
    double upStartBase,
    double downStartBase,
  ) {
    final count = letters.length;
    final mobileScale = isMobile ? 1.4 : 1.0;
    final cardHeight = feltRect.shortestSide * 0.17 * mobileScale;
    final cardWidth = cardHeight * 0.68;
    final spacing = cardWidth * 1.12;
    
    final totalWidth = spacing * (count - 1);
    final startX = center.dx - totalWidth / 2;
    final cardsCenterY = center.dy + offsetY;

    for (var i = 0; i < count; i++) {
      final cardCenter = Offset(startX + spacing * i, cardsCenterY);
      final flip = _cardFlip(upStartBase + i * 0.03, downStartBase + i * 0.03);
      final scaleX = (2 * flip - 1).abs().clamp(0.06, 1.0);
      final faceUp = flip > 0.5;

      final lift = 1.0 - scaleX;
      final shadowOffset = Offset(0, cardHeight * 0.04 + lift * cardHeight * 0.12);
      final shadowSigma = 2.0 + lift * 6.0;
      final shadowOpacity = 0.45 - lift * 0.25;

      canvas.save();
      canvas.translate(cardCenter.dx, cardCenter.dy);
      
      // Draw dynamic floating drop shadow
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: cardWidth,
        height: cardHeight,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      
      canvas.drawRRect(
        rrect.shift(shadowOffset),
        Paint()
          ..color = Colors.black.withValues(alpha: shadowOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowSigma),
      );

      canvas.scale(scaleX, 1);

      if (faceUp) {
        canvas.drawRRect(rrect, Paint()..color = _HeroPalette.cardFace);
      } else {
        canvas.drawRRect(rrect, Paint()..color = _HeroPalette.cardBack);
        
        final innerRRect = RRect.fromRectAndRadius(rect.deflate(cardWidth * 0.08), const Radius.circular(2));
        canvas.drawRRect(
          innerRRect,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        
        final backPainter = TextPainter(
          text: TextSpan(
            text: letters[i],
            style: TextStyle(
              fontSize: cardHeight * 0.55,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
                Shadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  offset: const Offset(-1, -1),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        
        backPainter.paint(
          canvas,
          Offset(-backPainter.width / 2, -backPainter.height / 2),
        );
      }

      // Glossy sheen that sweeps across the card as it catches the light while flipping
      if (lift > 0.0) {
        canvas.drawRRect(
          rrect,
          Paint()..color = Colors.white.withValues(alpha: lift * 0.2),
        );
      }

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      if (faceUp && scaleX > 0.5) {
        // Just use a random consistent suit for visual flair
        final suit = _suits[i % 4];
        final suitColor = (suit == '♥' || suit == '♦')
            ? _HeroPalette.suitRed
            : _HeroPalette.suitBlack;
        final suitPainter = TextPainter(
          text: TextSpan(
            text: suit,
            style: TextStyle(fontSize: cardHeight * 0.42, color: suitColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        suitPainter.paint(
          canvas,
          Offset(-suitPainter.width / 2, -suitPainter.height / 2),
        );
      }

      canvas.restore();
    }
  }

  double _cardFlip(double upStart, double downStart) {
    final upEnd = upStart + 0.08;
    final downEnd = downStart + 0.08;

    if (t < upStart) return 0;
    if (t < upEnd) return (t - upStart) / (upEnd - upStart);
    if (t < downStart) return 1;
    if (t < downEnd) return 1 - (t - downStart) / (downEnd - downStart);
    return 0;
  }

  void _paintPot(Canvas canvas, Offset center, Rect feltRect) {
    // Pushed much further out to the right side so it feels separated from the cards
    final potCenter = center + Offset(feltRect.shortestSide * 0.85, feltRect.shortestSide * 0.15);
    const colors = [
      _HeroPalette.chipRed,
      _HeroPalette.chipWhite,
      _HeroPalette.chipBlue,
    ];
    
    // Smooth, elegant floating effect instead of a fast jittery bounce
    for (var i = 0; i < colors.length; i++) {
      final floatAnim = math.sin(t * math.pi * 4 + i * 1.5) * feltRect.shortestSide * 0.015;
      _drawChipStack(
        canvas,
        potCenter + Offset((i - 1) * feltRect.shortestSide * 0.07, floatAnim),
        colors[i],
        3 + i,
        feltRect.shortestSide * 0.045, // Slightly larger, more imposing chips
      );
    }
  }

  void _drawChipStack(
    Canvas canvas,
    Offset base,
    Color color,
    int count,
    double radius,
  ) {
    // Calculate a darker shade for the rim to give real 3D depth
    final hsl = HSLColor.fromColor(color);
    final darkColor = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();

    final rimPaint = Paint()..color = darkColor;
    final facePaint = Paint()..color = color;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (var i = 0; i < count; i++) {
      final chipCenter = base - Offset(0, radius * 0.75 * i);
      
      // Deep 3D Shadow
      canvas.drawOval(
        Rect.fromCenter(
          center: chipCenter + Offset(0, radius * 0.4),
          width: radius * 2.2,
          height: radius * 1.3,
        ),
        shadowPaint,
      );
      
      // Extruded Rim
      canvas.drawOval(
        Rect.fromCenter(
          center: chipCenter + Offset(0, radius * 0.3),
          width: radius * 2,
          height: radius * 1.1,
        ),
        rimPaint,
      );
      
      // Top Face
      canvas.drawOval(
        Rect.fromCenter(
          center: chipCenter,
          width: radius * 2,
          height: radius * 1.1,
        ),
        facePaint,
      );
      
      // Inner clay ring detail
      canvas.drawOval(
        Rect.fromCenter(
          center: chipCenter,
          width: radius * 1.4,
          height: radius * 0.77,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Sweeping white shimmer across the chips for a premium casino sheen
      final shimmerOffset = Offset(
        radius * 0.8 * math.cos(t * math.pi * 4 + i * 0.5),
        radius * 0.4 * math.sin(t * math.pi * 4 + i * 0.5),
      );
      
      canvas.drawOval(
        Rect.fromCenter(
          center: chipCenter + shimmerOffset,
          width: radius * 0.4,
          height: radius * 0.2,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  Offset _pointOnEllipse(Rect rect, double angle, double scale) {
    final rx = rect.width / 2 * scale;
    final ry = rect.height / 2 * scale;
    return rect.center + Offset(rx * math.cos(angle), ry * math.sin(angle));
  }

  @override
  bool shouldRepaint(covariant _TablePainter oldDelegate) => oldDelegate.t != t;
}
