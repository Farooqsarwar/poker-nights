import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../models/live_game.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';

/// Timer display styled like the TV dashboard: plain mono digits where the
/// minutes are drawn in the foreground and the seconds in the accent color.
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
    final secondsColor = danger
        ? AppColors.destructive
        : (warning ? AppColors.warning : AppColors.primary);
    final minutesColor = danger
        ? AppColors.destructive
        : (warning ? AppColors.warning : AppColors.foreground);

    return AnimatedTimerDigits(
      secondsRemaining: secondsRemaining,
      size: size,
      minutesColor: minutesColor,
      secondsColor: secondsColor,
      glow: danger,
    );
  }
}

/// Shared per-position tournament clock for dashboard, player, TV and tools.
///
/// Only characters whose values change animate. The five- and one-minute
/// warning pulses wrap the seconds group alone, never the whole clock.
class AnimatedTimerDigits extends StatefulWidget {
  const AnimatedTimerDigits({
    super.key,
    required this.secondsRemaining,
    required this.size,
    required this.minutesColor,
    required this.secondsColor,
    this.glow = false,
    this.verticalPadding = 0,
  });

  final int secondsRemaining;
  final double size;
  final Color minutesColor;
  final Color secondsColor;
  final bool glow;
  final double verticalPadding;

  @override
  State<AnimatedTimerDigits> createState() => _AnimatedTimerDigitsState();
}

class _AnimatedTimerDigitsState extends State<AnimatedTimerDigits> {
  int _warningPulse = 0;

  @override
  void didUpdateWidget(AnimatedTimerDigits oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRemaining = oldWidget.secondsRemaining;
    final remaining = widget.secondsRemaining;
    final crossedFiveMinutes = oldRemaining > 300 && remaining <= 300;
    final crossedOneMinute = oldRemaining > 60 && remaining <= 60;
    if (remaining < oldRemaining && (crossedFiveMinutes || crossedOneMinute)) {
      _warningPulse++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = Formatters.time(widget.secondsRemaining);
    final colon = value.lastIndexOf(':');
    final secondsStart = colon < 0 ? value.length : colon + 1;

    Widget digits(Iterable<int> positions, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (final position in positions)
          _TimerDigit(
            key: ValueKey('timer-position-$position'),
            char: value[position],
            size: widget.size,
            color: color,
            glow: widget.glow,
            isColon: value[position] == ':',
          ),
      ],
    );

    final minutePositions = Iterable<int>.generate(secondsStart);
    final secondPositions = Iterable<int>.generate(
      value.length - secondsStart,
      (index) => secondsStart + index,
    );

    // Fixed-width digits would overflow narrow parents without this scale-down
    // wrapper (notably a half-width column on a 320 px phone).
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            digits(minutePositions, widget.minutesColor),
            _PulseOnToken(
              eventToken: _warningPulse,
              pulseKey: 'clock-seconds-pulse',
              child: digits(secondPositions, widget.secondsColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerDigit extends StatelessWidget {
  const _TimerDigit({
    super.key,
    required this.char,
    required this.size,
    required this.color,
    required this.glow,
    required this.isColon,
  });

  final String char;
  final double size;
  final Color color;
  final bool glow;
  final bool isColon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isColon ? size * 0.05 : 0),
      width: isColon ? null : size * 0.6,
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final isNew = child.key == ValueKey(char);
          return ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: isNew ? const Offset(0, -1) : const Offset(0, 1),
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
                height: 1,
              ).copyWith(
                letterSpacing: size * -0.05,
                shadows: glow
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

/// Pulses a level-specific child when the level identity changes.
///
/// The motion path is exactly two 300 ms pulses. With reduced motion enabled,
/// scaling is replaced by a three-second [AppColors.destructiveText] outline.
class LevelEventPulse extends StatelessWidget {
  const LevelEventPulse({
    super.key,
    required this.level,
    required this.pulseKey,
    required this.child,
  });

  final int level;
  final String pulseKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => _PulseOnToken(
    eventToken: level,
    pulseKey: pulseKey,
    ignoreFirstChangeFromZero: true,
    child: child,
  );
}

class _PulseOnToken extends StatefulWidget {
  const _PulseOnToken({
    required this.eventToken,
    required this.pulseKey,
    required this.child,
    this.ignoreFirstChangeFromZero = false,
  });

  final int eventToken;
  final String pulseKey;
  final Widget child;
  final bool ignoreFirstChangeFromZero;

  @override
  State<_PulseOnToken> createState() => _PulseOnTokenState();
}

class _PulseOnTokenState extends State<_PulseOnToken>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_PulseOnToken oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventToken == oldWidget.eventToken ||
        (widget.ignoreFirstChangeFromZero && oldWidget.eventToken == 0)) {
      return;
    }
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller.duration = reduceMotion
        ? const Duration(seconds: 3)
        : const Duration(milliseconds: 600);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final outlined = reduceMotion && _controller.isAnimating;
        return Container(
          key: ValueKey('${widget.pulseKey}-outline'),
          decoration: outlined
              ? BoxDecoration(
                  border: Border.all(
                    color: AppColors.destructiveText,
                    width: 2,
                  ),
                )
              : null,
          child: Transform.scale(
            key: ValueKey('${widget.pulseKey}-scale'),
            scale: reduceMotion ? 1 : _scale.value,
            child: child,
          ),
        );
      },
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
        final offset = context.read<AppProvider>().serverTimeOffset;
        final current = widget.game.currentSecondsRemaining(offset);
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
      final offset = context.read<AppProvider>().serverTimeOffset;
      _lastSeconds = widget.game.currentSecondsRemaining(offset);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offset = context.select<AppProvider, Duration>(
      (app) => app.serverTimeOffset,
    );
    return widget.builder(context, widget.game.currentSecondsRemaining(offset));
  }
}
