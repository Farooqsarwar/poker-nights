import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/live_game.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../utils/formatters.dart';

/// Timer display styled like the TV dashboard: plain mono digits where the
/// minutes are drawn in the foreground and the seconds in the accent color.
///
/// The display scales down with [FittedBox] so it always fits the available
/// width, on phones, tablets and TV screens alike.
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
    final secsColor = danger
        ? AppColors.destructive
        : (warning ? AppColors.warning : AppColors.primary);

    final minsColor = danger
        ? AppColors.destructive
        : (warning ? AppColors.warning : AppColors.foreground);

    final timeStr = Formatters.time(secondsRemaining);
    final lastColonIdx = timeStr.lastIndexOf(':');

    return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (var i = 0; i < timeStr.length; i++)
              _TimerDigit(
                char: timeStr[i],
                size: size,
                color: (lastColonIdx != -1 && i >= lastColonIdx)
                    ? secsColor
                    : minsColor,
                danger: danger,
              ),
          ],
        )
        .animate(
          key: ValueKey(danger ? 'danger' : 'normal'),
          onPlay: (controller) =>
              danger ? controller.repeat(reverse: true) : null,
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

    // We want all digits to be roughly the same width for stability
    final digitWidth = size * 0.6;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isColon ? size * 0.05 : 0),
      width: isColon ? null : digitWidth,
      alignment: Alignment.center,
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
              child: FadeTransition(opacity: animation, child: child),
            ),
          );
        },
        child: Text(
          char,
          key: ValueKey<String>(char),
          style:
              AppTypography.mono(
                size: size,
                weight: FontWeight.w400,
                color: color,
                height: 1.0,
              ).copyWith(
                letterSpacing: size * -0.05,
                shadows: danger
                    ? [
                        Shadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
        ),
      ),
    );
  }
}

class LiveTimerBuilder extends StatefulWidget {
  const LiveTimerBuilder({
    super.key,
    required this.game,
    required this.builder,
  });

  final LiveGame game;
  final Widget Function(BuildContext context, int secondsRemaining) builder;

  @override
  State<LiveTimerBuilder> createState() => _LiveTimerBuilderState();
}

class _LiveTimerBuilderState extends State<LiveTimerBuilder>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  int _lastSeconds = -1;
  bool _tickerActive = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (widget.game.timerRunning) {
        final current = widget.game.currentSecondsRemaining;
        if (current != _lastSeconds) {
          _lastSeconds = current;
          setState(() {});
        }
      }
    });
    if (widget.game.timerRunning) {
      _ticker.start();
      _tickerActive = true;
    }
  }

  @override
  void didUpdateWidget(LiveTimerBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.game.timerRunning && !_tickerActive) {
      _ticker.start();
      _tickerActive = true;
    } else if (!widget.game.timerRunning && _tickerActive) {
      _ticker.stop();
      _tickerActive = false;
      _lastSeconds = widget.game.currentSecondsRemaining;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.game.currentSecondsRemaining);
  }
}
