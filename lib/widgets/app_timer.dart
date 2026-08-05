import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../utils/formatters.dart';

class AppTimer extends StatelessWidget {
  const AppTimer({
    super.key,
    required this.secondsRemaining,
    required this.size,
    this.danger = false,
    this.warning = false,
  });

  final int secondsRemaining;
  final double size;
  final bool danger;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.destructive
        : (warning ? AppColors.warning : AppColors.primary);

    final timeStr = Formatters.time(secondsRemaining);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < timeStr.length; i++)
          _TimerDigit(
            char: timeStr[i],
            size: size,
            color: color,
            danger: danger,
          ),
      ],
    )
        .animate(
          key: ValueKey(danger ? 'danger' : 'normal'),
          onPlay: (controller) => danger ? controller.repeat(reverse: true) : null,
        )
        .scaleXY(
          end: danger ? 1.05 : 1.0,
          duration: (danger ? 500 : 0).ms,
          curve: Curves.easeInOut,
        );
  }
}

class _TimerDigit extends StatelessWidget {
  const _TimerDigit({
    required this.char,
    required this.size,
    required this.color,
    required this.danger,
  });

  final String char;
  final double size;
  final Color color;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isColon = char == ':';
    
    // We want all digits to be roughly the same width for stability,
    // so we use a fixed width for digits.
    final digitWidth = size * 0.7;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isColon ? 2 : 4),
      padding: isColon ? null : EdgeInsets.symmetric(vertical: size * 0.1),
      width: isColon ? null : digitWidth,
      alignment: Alignment.center,
      decoration: isColon
          ? null
          : BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(size * 0.15),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: danger ? 0.3 : 0.15),
                  blurRadius: size * 0.3,
                  spreadRadius: danger ? 2 : 1,
                  offset: const Offset(0, 4),
                )
              ],
            ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isNew = child.key == ValueKey(char);
          return ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: isNew ? const Offset(0.0, -1.0) : const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            ),
          );
        },
        child: Text(
          char,
          key: ValueKey<String>(char),
          style: AppTypography.mono(
            size: size,
            weight: FontWeight.w700,
            color: color,
            height: 1.1,
          ).copyWith(
            shadows: danger
                ? [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                : null,
          ),
        ),
      ),
    );
  }
}
