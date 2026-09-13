import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

/// How healthy the average stack is, measured in big blinds.
///
/// Specification §12: "Green/amber/red depth indicator around AVG STACK."
/// The number on its own does not tell a player anything — 12,000 chips is
/// deep at 50/100 and desperate at 1000/2000. The colour is what makes it
/// readable at a glance from across a room.
///
/// The thresholds are the ordinary tournament ones: below roughly 20 big
/// blinds a player is into push-or-fold territory, and between 20 and 40 they
/// have stopped being able to play post-flop poker comfortably.
enum StackDepth {
  healthy,
  shortening,
  critical;

  static const int criticalBelowBB = 20;
  static const int shorteningBelowBB = 40;

  static StackDepth fromBigBlinds(double bb) {
    if (bb < criticalBelowBB) return StackDepth.critical;
    if (bb < shorteningBelowBB) return StackDepth.shortening;
    return StackDepth.healthy;
  }

  /// Null when there is no blind to measure against yet.
  static StackDepth? of({required int avgStack, required int bigBlind}) {
    if (avgStack <= 0 || bigBlind <= 0) return null;
    return fromBigBlinds(avgStack / bigBlind);
  }

  Color get color => switch (this) {
        StackDepth.healthy => AppColors.success,
        StackDepth.shortening => AppColors.warning,
        StackDepth.critical => AppColors.destructive,
      };

  String get label => switch (this) {
        StackDepth.healthy => 'Deep',
        StackDepth.shortening => 'Shortening',
        StackDepth.critical => 'Short',
      };
}

/// The coloured ring §12 asks for, wrapped around whatever it is given.
///
/// Deliberately a border rather than a filled background: the average stack
/// sits beside other stat tiles, and filling it would make it shout louder
/// than the timer, which §12 says is the prominent element.
class StackDepthRing extends StatelessWidget {
  const StackDepthRing({
    super.key,
    required this.depth,
    required this.child,
    this.showLabel = true,
  });

  final StackDepth? depth;
  final Widget child;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final d = depth;
    if (d == null) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: d.color, width: 2),
          ),
          child: child,
        ),
        if (showLabel)
          Positioned(
            top: -8,
            right: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: d.color,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                d.label,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
