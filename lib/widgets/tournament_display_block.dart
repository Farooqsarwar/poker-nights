import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/live_game.dart';
import '../utils/formatters.dart';
import 'app_timer.dart';

/// Continuously interpolates [minV]->[maxV] as [width] goes from [minW]->[maxW].
/// This replaces the old binary isMobile switch with real responsiveness:
/// there's no snap point, everything scales smoothly with the container.
double _scale(
    double width,
    double minV,
    double maxV, {
      double minW = 360,
      double maxW = 1100,
    }) {
  final t = ((width - minW) / (maxW - minW)).clamp(0.0, 1.0);
  return minV + (maxV - minV) * t;
}

class TournamentDisplayBlock extends StatelessWidget {
  final LiveGame game;

  const TournamentDisplayBlock({super.key, required this.game});

  static const Color pureBlack = Color(0xFF000000);
  static const Color pureRed = Color(0xFFFF0015);
  static const Color darkGrey = Color(0xFF222222);
  static const Color textGrey = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    final timerDanger = game.secondsRemaining <= 60;
    final timerWarning = game.secondsRemaining <= 300;
    final level = game.currentLevelData;

    int totalTimeSecs = 0;
    for (int i = 0; i < game.currentLevel - 1; i++) {
      if (i < game.structure.levels.length) {
        totalTimeSecs += game.structure.levels[i].durationMins * 60;
      }
    }
    final levelDurationSecs = level?.durationMins == null ? 1 : level!.durationMins * 60;
    final pct = level == null
        ? 0.0
        : ((levelDurationSecs - game.secondsRemaining) / levelDurationSecs).clamp(0.0, 1.0);

    if (level != null) {
      totalTimeSecs += (levelDurationSecs - game.secondsRemaining);
    }
    final active = game.activePlayers.length;
    final avgStack = Formatters.averageStack(game.totalChipsInPlay, active);
    final next = game.nextLevelData;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 1100.0;

        // Single set of scaled tokens driving the whole layout — no more
        // duplicated mobile/desktop trees, no more stacked fixed gaps.
        final outerPad = _scale(width, 12, 32);
        final gapXs = _scale(width, 4, 8);
        final gapSm = _scale(width, 8, 16);
        final gapMd = _scale(width, 12, 24);

        final levelFont = _scale(width, 16, 32);
        final timerSize = _scale(width, 64, 160);
        final bigStatLabelFont = _scale(width, 12, 20);
        final bigStatFont = _scale(width, 28, 60);
        final blindGap = _scale(width, 20, 96);

        final smallStatLabelFont = _scale(width, 10, 14);
        final smallStatFont = _scale(width, 18, 32);
        final miniBlindLabelFont = _scale(width, 9, 12);
        final miniBlindFont = _scale(width, 14, 24);
        final payoutFont = _scale(width, 18, 32);
        final sectionLabelFont = _scale(width, 11, 14);

        Widget divider() => Container(height: 1, color: darkGrey, width: double.infinity);

        return Container(
          color: pureBlack,
          padding: EdgeInsets.symmetric(vertical: outerPad, horizontal: outerPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LEVEL HEADER
              Text(
                game.status == LiveGameStatus.rebuypause ? 'BREAK' : 'LEVEL ${game.currentLevel}',
                style: GoogleFonts.shareTechMono(
                  fontSize: levelFont,
                  fontWeight: FontWeight.w400,
                  color: pureRed,
                  letterSpacing: 6.4,
                  height: 1.0,
                ),
              ),
              SizedBox(height: gapMd),

              // TIMER
              AppTimer(
                secondsRemaining: game.secondsRemaining,
                size: timerSize,
                danger: timerDanger,
                warning: timerWarning,
              ),
              SizedBox(height: gapMd),

              // BLINDS
              Wrap(
                spacing: blindGap,
                runSpacing: gapSm,
                alignment: WrapAlignment.center,
                children: [
                  _bigStat('SB', level == null ? '—' : Formatters.chips(level.sb), false,
                      bigStatLabelFont, bigStatFont),
                  if (level?.ante != null)
                    _bigStat('ANTE', Formatters.chips(level!.ante!), true, bigStatLabelFont, bigStatFont),
                  _bigStat('BB', level == null ? '—' : Formatters.chips(level.bb), false,
                      bigStatLabelFont, bigStatFont),
                ],
              ),
              SizedBox(height: gapMd),

              // PROGRESS BAR
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(color: darkGrey, borderRadius: BorderRadius.circular(999)),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: pureRed,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(color: pureRed.withValues(alpha: 0.5), blurRadius: 15),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: gapMd),
              divider(),
              SizedBox(height: gapSm),

              // TOTAL TIME / PLAYERS / AVG STACK / TOTAL CHIPS / NEXT LEVEL
              Wrap(
                spacing: _scale(width, 16, 48),
                runSpacing: gapSm,
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  _smallStat('TOTAL TIME', Formatters.time(totalTimeSecs), smallStatLabelFont, smallStatFont),
                  _smallStat(
                    'PLAYERS',
                    '$active / ${game.activePlayers.length + game.eliminatedPlayers.length}',
                    smallStatLabelFont,
                    smallStatFont,
                    highlight: ' / ',
                  ),
                  _smallStat('AVG STACK', Formatters.chips(avgStack), smallStatLabelFont, smallStatFont),
                  _smallStat('TOTAL CHIPS', Formatters.chips(game.totalChipsInPlay), smallStatLabelFont, smallStatFont),
                  _smallStat(
                    game.status == LiveGameStatus.rebuypause ? 'BREAK' : 'NEXT LEVEL',
                    Formatters.time(game.secondsRemaining),
                    smallStatLabelFont,
                    smallStatFont,
                  ),
                ],
              ),
              SizedBox(height: gapSm),
              divider(),
              SizedBox(height: gapSm),

              // NEXT LEVEL
              Text(
                'LEVEL ${game.currentLevel + 1}',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: sectionLabelFont,
                  color: pureRed,
                  letterSpacing: 2.0,
                  height: 1.1,
                ),
              ),
              SizedBox(height: gapXs),
              Wrap(
                spacing: _scale(width, 16, 40),
                runSpacing: gapXs,
                alignment: WrapAlignment.center,
                children: [
                  if (next != null) ...[
                    _miniBlind('SB', Formatters.chips(next.sb), miniBlindLabelFont, miniBlindFont),
                    _miniBlind('BB', Formatters.chips(next.bb), miniBlindLabelFont, miniBlindFont),
                    if (next.ante != null)
                      _miniBlind('ANTE', Formatters.chips(next.ante!), miniBlindLabelFont, miniBlindFont),
                  ] else
                    Text('END', style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: miniBlindFont, height: 1.0)),
                ],
              ),
              SizedBox(height: gapSm),
              divider(),
              SizedBox(height: gapSm),

              // PAYOUTS
              Text(
                'PAYOUTS',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  fontSize: sectionLabelFont,
                  color: textGrey,
                  letterSpacing: 2.0,
                  height: 1.1,
                ),
              ),
              SizedBox(height: gapXs),
              Wrap(
                spacing: _scale(width, 20, 48),
                runSpacing: gapSm,
                alignment: WrapAlignment.center,
                children: [
                  for (int i = 0; i < game.structure.prizes.length && i < 4; i++)
                    _payout(
                      ['1ST', '2ND', '3RD', '4TH'][i],
                      Formatters.chips(game.structure.prizes[i].amount),
                      sectionLabelFont,
                      payoutFont,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _payout(String label, String value, double labelFont, double valueFont) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontFamily: 'sans-serif', fontSize: labelFont, color: pureRed, height: 1.1)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.shareTechMono(fontSize: valueFont, color: Colors.white, height: 1.0)),
      ],
    );
  }

  Widget _smallStat(String label, String value, double labelFont, double valueFont, {String? highlight}) {
    final spans = <TextSpan>[];
    if (highlight != null && value.contains(highlight)) {
      final parts = value.split(highlight);
      spans.add(TextSpan(text: parts[0]));
      spans.add(TextSpan(text: highlight, style: const TextStyle(color: pureRed)));
      if (parts.length > 1) spans.add(TextSpan(text: parts[1]));
    } else {
      spans.add(TextSpan(text: value));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontFamily: 'sans-serif', fontSize: labelFont, color: textGrey, letterSpacing: 2.0, height: 1.1)),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: GoogleFonts.shareTechMono(fontSize: valueFont, color: Colors.white, height: 1.0),
            children: spans,
          ),
        ),
      ],
    );
  }

  Widget _miniBlind(String label, String value, double labelFont, double valueFont) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontFamily: 'sans-serif', fontSize: labelFont, color: textGrey, height: 1.1)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.shareTechMono(fontSize: valueFont, color: Colors.white, height: 1.0)),
      ],
    );
  }

  Widget _bigStat(String label, String value, bool isPrimary, double labelFont, double valueFont) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: labelFont,
            fontWeight: FontWeight.w600,
            color: isPrimary ? pureRed : textGrey,
            letterSpacing: 2.0,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.shareTechMono(
            fontSize: valueFont,
            color: isPrimary ? pureRed : Colors.white,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}