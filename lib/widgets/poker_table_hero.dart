import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

/// Continuously animated poker-table hero banner for the dashboard.
///
/// A green felt table with a community card row that gently "breathes"
/// (staggered float + subtle rotation) and chip stacks that bob at the
/// corners — all looping smoothly and forever. Purely decorative.
class PokerTableHero extends StatefulWidget {
  const PokerTableHero({super.key});

  @override
  State<PokerTableHero> createState() => _PokerTableHeroState();
}

class _PokerTableHeroState extends State<PokerTableHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // One long-running controller drives every element; each reads it at a
    // different phase so the loop never restarts visibly.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect reduced-motion: render the static composition without ticking.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.20),
          ),
          gradient: const RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF0F3D2E), Color(0xFF06231A), Color(0xFF041712)],
            stops: [0.0, 0.6, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 48,
              spreadRadius: -8,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.40),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = reduceMotion ? 0.0 : _controller.value;
            return Stack(
              children: [
                // Faint watermark wordmark behind the cards.
                Center(
                  child: Text(
                    'POKER NIGHT',
                    style:
                        AppTypography.display(
                          size: 44,
                          weight: FontWeight.w800,
                        ).copyWith(
                          color: Colors.white.withValues(alpha: 0.03),
                          letterSpacing: 8,
                        ),
                  ),
                ),
                // Dealer button (top center).
                Align(
                  alignment: const Alignment(0, -0.85),
                  child: _ChipStack(
                    count: 2,
                    color: const Color(0xFFEDEDED),
                    phase: t,
                    seed: 0.0,
                  ),
                ),
                // Corner chip stacks.
                Align(
                  alignment: const Alignment(-0.86, -0.35),
                  child: _ChipStack(
                    count: 4,
                    color: const Color(0xFFC0392B),
                    phase: t,
                    seed: 0.2,
                  ),
                ),
                Align(
                  alignment: const Alignment(0.86, -0.35),
                  child: _ChipStack(
                    count: 4,
                    color: const Color(0xFFC0392B),
                    phase: t,
                    seed: 0.6,
                  ),
                ),
                Align(
                  alignment: const Alignment(0.86, 0.55),
                  child: _ChipStack(
                    count: 5,
                    color: const Color(0xFF2980B9),
                    phase: t,
                    seed: 0.85,
                  ),
                ),
                // Pot in the middle, tucked under the cards.
                Align(
                  alignment: const Alignment(0, 0.42),
                  child: _ChipStack(
                    count: 6,
                    color: const Color(0xFF2C2C2C),
                    phase: t,
                    seed: 0.5,
                    mixed: true,
                  ),
                ),
                // Community card row (the hero element).
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 5; i++) ...[
                        _FloatingCard(
                          suit: _suits[i],
                          red: i == 1 || i == 2,
                          phase: t,
                          index: i,
                        ),
                        if (i < 4) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                // Hero copy overlaid bottom-left.
                Positioned(
                  left: AppSpacing.xl,
                  bottom: AppSpacing.lg,
                  right: AppSpacing.xl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Run your perfect',
                        style: AppTypography.display(
                          size: AppFontSizes.xxl,
                          weight: FontWeight.w800,
                        ).copyWith(color: Colors.white, height: 1.05),
                      ),
                      Text(
                        'poker night',
                        style: AppTypography.display(
                          size: AppFontSizes.xxl,
                          weight: FontWeight.w800,
                        ).copyWith(color: AppColors.destructive, height: 1.05),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Blinds, buy-ins, seating and settlement \n one app for the whole table.',
                        style: AppTypography.bodyXs.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const List<String> _suits = ['♠', '♥', '♦', '♣', '♠'];
}

/// A single community card that floats up/down and tilts slightly, looping.
class _FloatingCard extends StatelessWidget {
  const _FloatingCard({
    required this.suit,
    required this.red,
    required this.phase,
    required this.index,
  });

  final String suit;
  final bool red;
  final double phase;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Stagger each card's cycle so they ripple rather than move in unison.
    final local = (phase + index * 0.12) * 2 * math.pi;
    final dy = math.sin(local) * 5.0; // vertical bob
    final tilt = math.sin(local) * 0.04; // subtle rotation (radians)

    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.rotate(
        angle: tilt,
        child: Container(
          width: 46,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEDEAE0),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Glass-like inner highlight on card face
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 28,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.40),
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  suit,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1,
                    color: red ? const Color(0xFFB01722) : const Color(0xFF14110F),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small stack of chips that bobs gently up and down.
class _ChipStack extends StatelessWidget {
  const _ChipStack({
    required this.count,
    required this.color,
    required this.phase,
    required this.seed,
    this.mixed = false,
  });

  final int count;
  final Color color;
  final double phase;
  final double seed;
  final bool mixed;

  @override
  Widget build(BuildContext context) {
    final local = (phase + seed) * 2 * math.pi;
    final dy = math.sin(local) * 3.5;

    return Transform.translate(
      offset: Offset(0, dy),
      child: SizedBox(
        width: 30,
        height: count * 4.0 + 8,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (var i = 0; i < count; i++)
              Positioned(
                bottom: i * 4.0,
                child: Container(
                  width: 26,
                  height: 8,
                  decoration: BoxDecoration(
                    color: mixed && i.isOdd ? const Color(0xFFC0392B) : color,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
