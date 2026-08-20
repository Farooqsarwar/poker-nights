import 'app_timer.dart';

import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';
import '../utils/formatters.dart';

/// Responsive tournament display.
///
/// Wide screens retain the proportions of the 1536 x 1024 reference without
/// scaling a fixed screenshot-sized canvas. Below 900 px the information is
/// reorganized into a phone/tablet layout.
class TournamentDisplayBlock extends StatelessWidget {
  const TournamentDisplayBlock({
    super.key,
    required this.game,
    this.showStatusChip = true,
    this.showPayoutAmounts = true,
  });

  final LiveGame game;
  final bool showStatusChip;

  /// Whether individual payout amounts are rendered. The public TV route must
  /// set this to false: payouts are private to the host (§13.1).
  final bool showPayoutAmounts;

  static const Color _black = AppColors.background;
  static const Color _red = Color(0xFFFF0015);
  static const Color _divider = Color(0xFF2A2A2A);
  static const Color _muted = Color(0xFFA8A8AD);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 1536.0;

        if (width < 900) {
          return _CompactLayout(
            game: game,
            // Mobile always includes the red status mark from the reference.
            // The green status shown above the card belongs to the parent
            // screen and should be removed there (see notes below).
            showStatusChip: true,
            showPayoutAmounts: showPayoutAmounts,
          );
        }

        // When embedded in an unconstrained vertical parent, preserve the
        // reference aspect ratio. In TV/full-screen mode use all given height.
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : width / 1.5;

        return SizedBox(
          width: width,
          height: height,
          child: _WideLayout(
            game: game,
            showStatusChip: showStatusChip,
            showPayoutAmounts: showPayoutAmounts,
          ),
        );
      },
    );
  }
}

/// Number-only style used for every numeric value.
///
/// Do not use AppTypography.mono for numbers: the configured mono font has a
/// dotted-zero glyph. This style guarantees a regular empty zero everywhere,
/// not only in the main timer.
TextStyle _numberStyle({
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w300,
  double height = 1,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: AppTypography.monoFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class _GameValues {
  _GameValues(this.game)
      : level = game.currentLevelData,
        next = game.nextLevelData,
        isBreak = game.status == LiveGameStatus.rebuypause,
        active = game.activePlayers.length,
        total = game.activePlayers.length + game.eliminatedPlayers.length,
        average = Formatters.averageStack(
          game.totalChipsInPlay,
          game.activePlayers.length,
        ) {
    for (int i = 0; i < game.currentLevel - 1; i++) {
      if (i < game.structure.levels.length) {
        totalSeconds += game.structure.levels[i].durationMins * 60;
      }
    }

    levelSeconds = (level?.durationMins ?? 1) * 60;
    if (level != null) {
      totalSeconds += levelSeconds - game.currentSecondsRemaining;
    }

    progress = level == null
        ? 0
        : ((levelSeconds - game.currentSecondsRemaining) / levelSeconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  final LiveGame game;
  final BlindLevel? level;
  final BlindLevel? next;
  final bool isBreak;
  final int active;
  final int total;
  final int average;

  int totalSeconds = 0;
  int levelSeconds = 60;
  double progress = 0;
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.game,
    required this.showStatusChip,
    required this.showPayoutAmounts,
  });

  final LiveGame game;
  final bool showStatusChip;
  final bool showPayoutAmounts;

  @override
  Widget build(BuildContext context) {
    final data = _GameValues(game);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final scale = (width / 1536).clamp(0.55, 2.0).toDouble();
        final heightScale = (height / 1024).clamp(0.55, 2.0).toDouble();
        final s = scale < heightScale ? scale : heightScale;

        // Width follows the actual screen; vertical sizes use the smaller
        // design scale so short/wide displays cannot overflow.
        final side = (width * .0267).clamp(24.0, 70.0).toDouble();
        final heroSide = (width * .0697).clamp(54.0, 130.0).toDouble();

        return ColoredBox(
          color: TournamentDisplayBlock._black,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              side,
              42 * s,
              side,
              30 * s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showStatusChip) ...[
                  SizedBox(
                    height: 54 * s,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusSpade(width: 66 * s, height: 54 * s),
                          SizedBox(width: 20 * s),
                          Text(
                            data.isBreak ? 'BREAK' : 'RUNNING',
                            style: AppTypography.mono(
                              size: 31 * s,
                              weight: FontWeight.w400,
                              color: TournamentDisplayBlock._red,
                              letterSpacing: 2.5 * s,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24 * s),
                  const _HorizontalLine(),
                ],

                // This section receives remaining height, so it responds to
                // 16:9, 16:10 and 3:2 displays without a fixed canvas.
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(height: (showStatusChip ? 49 : 18) * s),
                      Text(
                        data.isBreak
                            ? 'BREAK'
                            : 'LEVEL ${game.currentLevel}',
                        textAlign: TextAlign.center,
                        style: AppTypography.mono(
                          size: 40 * s,
                          weight: FontWeight.w400,
                          color: TournamentDisplayBlock._red,
                          letterSpacing: 5 * s,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 28 * s),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: heroSide),
                          child: LiveTimerBuilder(
                            game: game,
                            builder: (context, remaining) => _PlainNumberTimer(
                              secondsRemaining: remaining,
                              danger: remaining <= 60,
                              fontSize: 260 * s,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24 * s),
                      Row(
                        children: [
                          Expanded(
                            child: _BlindValue(
                              label: 'SB',
                              value: data.level == null
                                  ? '—'
                                  : Formatters.chips(data.level!.sb),
                              labelSize: 27 * s,
                              valueSize: 57 * s,
                            ),
                          ),
                          Expanded(
                            child: _BlindValue(
                              label: 'ANTE',
                              value: data.level?.ante == null
                                  ? '—'
                                  : Formatters.chips(data.level!.ante!),
                              highlighted: true,
                              labelSize: 27 * s,
                              valueSize: 57 * s,
                            ),
                          ),
                          Expanded(
                            child: _BlindValue(
                              label: 'BB',
                              value: data.level == null
                                  ? '—'
                                  : Formatters.chips(data.level!.bb),
                              labelSize: 27 * s,
                              valueSize: 57 * s,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 57 * s),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: heroSide - side),
                  child: _ProgressBar(
                    value: data.progress,
                    height: 14 * s,
                  ),
                ),
                SizedBox(height: 40 * s),
                const _HorizontalLine(),

                SizedBox(
                  height: 151 * s,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 304,
                        child: _StatValue(
                          label: 'TOTAL TIME',
                          value: Formatters.time(data.totalSeconds),
                          scale: s,
                        ),
                      ),
                      _InsetVerticalLine(inset: 29 * s),
                      Expanded(
                        flex: 318,
                        child: _StatValue(
                          label: 'AVG STACK',
                          value: Formatters.chips(data.average),
                          scale: s,
                        ),
                      ),
                      _InsetVerticalLine(inset: 29 * s),
                      Expanded(
                        flex: 512,
                        child: _NextLevelValue(
                          next: data.next,
                          levelNumber: game.currentLevel + 1,
                          isBreak: data.isBreak,
                          scale: s,
                        ),
                      ),
                      _InsetVerticalLine(inset: 29 * s),
                      Expanded(
                        flex: 317,
                        child: _StatValue(
                          label: 'PLAYERS',
                          value: '${data.active} / ${data.total}',
                          redSlash: true,
                          scale: s,
                        ),
                      ),
                    ],
                  ),
                ),
                const _HorizontalLine(),

                if (game.structure.prizes.isNotEmpty)
                  SizedBox(
                    height: 100 * s,
                    child: _WidePayouts(
                      game: game,
                      scale: s,
                      showPayoutAmounts: showPayoutAmounts,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Timer deliberately does not use AppTypography.mono. The project mono font
/// has a dotted-zero glyph. Roboto/Arial plus disabled OpenType `zero` renders
/// a normal, empty zero on Android, iOS, web and desktop.
class _PlainNumberTimer extends StatelessWidget {
  const _PlainNumberTimer({
    required this.secondsRemaining,
    required this.danger,
    required this.fontSize,
  });

  final int secondsRemaining;
  final bool danger;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final value = Formatters.time(secondsRemaining);
    final colon = value.lastIndexOf(':');
    final left = colon < 0 ? value : value.substring(0, colon + 1);
    final right = colon < 0 ? '' : value.substring(colon + 1);

    final style = AppTypography.mono(
      size: fontSize,
      weight: FontWeight.w400,
      color: danger ? TournamentDisplayBlock._red : Colors.white,
      letterSpacing: -fontSize * .035,
      height: .9,
    );

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: RichText(
            key: ValueKey(value),
            maxLines: 1,
            softWrap: false,
            text: TextSpan(
              style: style,
              children: [
                TextSpan(text: left),
                TextSpan(
                  text: right,
                  style: style.copyWith(color: TournamentDisplayBlock._red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlindValue extends StatelessWidget {
  const _BlindValue({
    required this.label,
    required this.value,
    required this.labelSize,
    required this.valueSize,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final double labelSize;
  final double valueSize;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? TournamentDisplayBlock._red
        : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          style: AppTypography.mono(
            size: labelSize,
            color: highlighted
                ? TournamentDisplayBlock._red
                : const Color(0xFFD7D7DA),
            letterSpacing: 1,
            height: 1,
          ),
        ),
        SizedBox(height: labelSize * .6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: _numberStyle(
                size: valueSize,
                weight: FontWeight.w300,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.height});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF1C1C1F)),
            FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TournamentDisplayBlock._red,
                      Color(0xFFFF0015),
                      Color(0xFF74131C),
                      Color(0xFF14151A),
                    ],
                    stops: [0, .48, .77, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({
    required this.label,
    required this.value,
    required this.scale,
    this.redSlash = false,
  });

  final String label;
  final String value;
  final double scale;
  final bool redSlash;

  @override
  Widget build(BuildContext context) {
    final valueStyle = _numberStyle(
      size: 34 * scale,
      weight: FontWeight.w300,
      color: Colors.white,
    );
    final slash = value.indexOf('/');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTypography.mono(
                size: 21 * scale,
                color: TournamentDisplayBlock._muted,
                letterSpacing: 1.5 * scale,
                height: 1,
              ),
            ),
          ),
          SizedBox(height: 22 * scale),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: redSlash && slash >= 0
                ? Text.rich(
              TextSpan(
                style: valueStyle,
                children: [
                  TextSpan(text: value.substring(0, slash)),
                  const TextSpan(
                    text: '/',
                    style: TextStyle(color: TournamentDisplayBlock._red),
                  ),
                  TextSpan(text: value.substring(slash + 1)),
                ],
              ),
            )
                : Text(value, maxLines: 1, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

class _NextLevelValue extends StatelessWidget {
  const _NextLevelValue({
    required this.next,
    required this.levelNumber,
    required this.isBreak,
    required this.scale,
  });

  final BlindLevel? next;
  final int levelNumber;
  final bool isBreak;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isBreak ? 'AFTER BREAK' : 'LEVEL $levelNumber',
          style: AppTypography.mono(
            size: 22 * scale,
            color: TournamentDisplayBlock._red,
            letterSpacing: 1.5 * scale,
            height: 1,
          ),
        ),
        SizedBox(height: 17 * scale),
        if (next == null)
          Text(
            'END',
            style: AppTypography.mono(
              size: 28 * scale,
              color: Colors.white,
            ),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniValue(
                  label: 'SB',
                  value: Formatters.chips(next!.sb),
                  scale: scale,
                ),
                SizedBox(width: 55 * scale),
                _MiniValue(
                  label: 'BB',
                  value: Formatters.chips(next!.bb),
                  scale: scale,
                ),
                SizedBox(width: 55 * scale),
                _MiniValue(
                  label: 'ANTE',
                  value: next!.ante == null
                      ? '—'
                      : Formatters.chips(next!.ante!),
                  scale: scale,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({
    required this.label,
    required this.value,
    required this.scale,
  });

  final String label;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.mono(
            size: 17 * scale,
            color: TournamentDisplayBlock._muted,
            height: 1,
          ),
        ),
        SizedBox(height: 12 * scale),
        Text(
          value,
          style: _numberStyle(
            size: 28 * scale,
            weight: FontWeight.w300,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _WidePayouts extends StatelessWidget {
  const _WidePayouts({
    required this.game,
    required this.scale,
    required this.showPayoutAmounts,
  });

  final LiveGame game;
  final double scale;
  final bool showPayoutAmounts;

  @override
  Widget build(BuildContext context) {
    final count = game.structure.prizes.length.clamp(0, 4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 210 * scale,
          child: Center(
            child: Text(
              'PAYOUTS',
              style: AppTypography.mono(
                size: 21 * scale,
                color: TournamentDisplayBlock._muted,
                letterSpacing: 1.5 * scale,
                height: 1,
              ),
            ),
          ),
        ),
        for (int i = 0; i < count; i++) ...[
          Expanded(
            child: _PayoutValue(
              label: const ['1ST', '2ND', '3RD', '4TH'][i],
              value: showPayoutAmounts
                  ? Formatters.chips(game.structure.prizes[i].amount)
                  : '—',
              scale: scale,
            ),
          ),
          if (i < count - 1) _InsetVerticalLine(inset: 15 * scale),
        ],
      ],
    );
  }
}

class _PayoutValue extends StatelessWidget {
  const _PayoutValue({
    required this.label,
    required this.value,
    required this.scale,
  });

  final String label;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTypography.mono(
              size: 21 * scale,
              color: TournamentDisplayBlock._red,
              letterSpacing: scale,
              height: 1,
            ),
          ),
          SizedBox(height: 15 * scale),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: _numberStyle(
                size: 28 * scale,
                weight: FontWeight.w300,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.game,
    required this.showStatusChip,
    required this.showPayoutAmounts,
  });

  final LiveGame game;
  final bool showStatusChip;
  final bool showPayoutAmounts;

  @override
  Widget build(BuildContext context) {
    final data = _GameValues(game);

    return ColoredBox(
      color: TournamentDisplayBlock._black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showStatusChip) ...[
              Row(
                children: [
                  const _StatusSpade(width: 38, height: 32),
                  const SizedBox(width: 10),
                  Text(
                    data.isBreak ? 'BREAK' : 'RUNNING',
                    style: AppTypography.mono(
                      size: 15,
                      color: TournamentDisplayBlock._red,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _HorizontalLine(),
              const SizedBox(height: 18),
            ],
            Text(
              data.isBreak ? 'BREAK' : 'LEVEL ${game.currentLevel}',
              textAlign: TextAlign.center,
              style: AppTypography.mono(
                size: 17,
                color: TournamentDisplayBlock._red,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 82,
              child: LiveTimerBuilder(
                game: game,
                builder: (context, remaining) => _PlainNumberTimer(
                  secondsRemaining: remaining,
                  danger: remaining <= 60,
                  fontSize: 104,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BlindValue(
                    label: 'SB',
                    value: data.level == null
                        ? '—'
                        : Formatters.chips(data.level!.sb),
                    labelSize: 11,
                    valueSize: 23,
                  ),
                ),
                Expanded(
                  child: _BlindValue(
                    label: 'ANTE',
                    value: data.level?.ante == null
                        ? '—'
                        : Formatters.chips(data.level!.ante!),
                    highlighted: true,
                    labelSize: 11,
                    valueSize: 23,
                  ),
                ),
                Expanded(
                  child: _BlindValue(
                    label: 'BB',
                    value: data.level == null
                        ? '—'
                        : Formatters.chips(data.level!.bb),
                    labelSize: 11,
                    valueSize: 23,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _ProgressBar(value: data.progress, height: 5),
            const SizedBox(height: 18),
            const _HorizontalLine(),
            _CompactPair(
              left: _CompactStat(
                label: 'TOTAL TIME',
                value: Formatters.time(data.totalSeconds),
              ),
              right: _CompactStat(
                label: 'AVG STACK',
                value: Formatters.chips(data.average),
              ),
            ),
            const _HorizontalLine(),
            _CompactPair(
              left: _CompactNext(
                next: data.next,
                level: game.currentLevel + 1,
              ),
              right: _CompactStat(
                label: 'PLAYERS',
                value: '${data.active} / ${data.total}',
                redSlash: true,
              ),
            ),
            if (game.structure.prizes.isNotEmpty) ...[
              const _HorizontalLine(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'PAYOUTS',
                  textAlign: TextAlign.center,
                  style: AppTypography.mono(
                    size: 11,
                    color: TournamentDisplayBlock._muted,
                    letterSpacing: 2,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    children: [
                      for (int i = 0;
                      i < game.structure.prizes.length && i < 4;
                      i++)
                        SizedBox(
                          width: constraints.maxWidth / 2,
                          height: 70,
                          child: _PayoutValue(
                            label: const ['1ST', '2ND', '3RD', '4TH'][i],
                            value: showPayoutAmounts
                                ? Formatters.chips(
                                    game.structure.prizes[i].amount,
                                  )
                                : '—',
                            scale: .55,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactPair extends StatelessWidget {
  const _CompactPair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const _InsetVerticalLine(inset: 10),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.label,
    required this.value,
    this.redSlash = false,
  });

  final String label;
  final String value;
  final bool redSlash;

  @override
  Widget build(BuildContext context) {
    final style = _numberStyle(size: 16, color: Colors.white);
    final slash = value.indexOf('/');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              label,
              style: AppTypography.mono(
                size: 10,
                color: TournamentDisplayBlock._muted,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            child: redSlash && slash >= 0
                ? Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(text: value.substring(0, slash)),
                  const TextSpan(
                    text: '/',
                    style: TextStyle(color: TournamentDisplayBlock._red),
                  ),
                  TextSpan(text: value.substring(slash + 1)),
                ],
              ),
            )
                : Text(value, style: style),
          ),
        ],
      ),
    );
  }
}

class _CompactNext extends StatelessWidget {
  const _CompactNext({required this.next, required this.level});

  final BlindLevel? next;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'LEVEL $level',
            style: AppTypography.mono(
              size: 10,
              color: TournamentDisplayBlock._red,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (next == null)
            Text(
              'END',
              style: AppTypography.mono(size: 14, color: Colors.white),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniValue(
                    label: 'SB',
                    value: Formatters.chips(next!.sb),
                    scale: .55,
                  ),
                  const SizedBox(width: 10),
                  _MiniValue(
                    label: 'BB',
                    value: Formatters.chips(next!.bb),
                    scale: .55,
                  ),
                  const SizedBox(width: 10),
                  _MiniValue(
                    label: 'ANTE',
                    value: next!.ante == null
                        ? '—'
                        : Formatters.chips(next!.ante!),
                    scale: .55,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusSpade extends StatelessWidget {
  const _StatusSpade({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

class _HorizontalLine extends StatelessWidget {
  const _HorizontalLine();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: ColoredBox(color: TournamentDisplayBlock._divider),
    );
  }
}

class _InsetVerticalLine extends StatelessWidget {
  const _InsetVerticalLine({required this.inset});

  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: inset),
      child: const SizedBox(
        width: 1,
        child: ColoredBox(color: TournamentDisplayBlock._divider),
      ),
    );
  }
}
