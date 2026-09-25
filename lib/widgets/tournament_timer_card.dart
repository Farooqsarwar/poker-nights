import 'package:flutter/material.dart';

import '../app/typography.dart';
import '../models/live_game.dart';
import '../utils/formatters.dart';
import 'app_timer.dart';

/// Pixel-perfect tournament live scoreboard timer card matching screens C5 & C10.
///
/// Features:
/// - Spade icon with coral "RUNNING" / "BREAK" / "PAUSED" status header
/// - Coral "LEVEL X" tracking text
/// - Giant digital clock with white minutes and crimson red seconds
/// - Blinds Trio: SB (white), ANTE (coral red), BB (white)
/// - Red progress bar indicator line
/// - Optional bottom sub-stats row: TOTAL TIME, AVG STACK, PLAYERS (active/total with red slash)
class TournamentTimerCard extends StatelessWidget {
  const TournamentTimerCard({
    super.key,
    required this.game,
    this.showSubStats = true,
  });

  final LiveGame game;
  final bool showSubStats;

  @override
  Widget build(BuildContext context) {
    final level = game.currentLevelData;
    final isBreak = game.status == LiveGameStatus.rebuypause;
    final isPaused = game.status == LiveGameStatus.paused;
    final activeCount = game.activePlayers.length;
    final totalCount = game.players.length;
    final avgStack = Formatters.averageStack(game.totalChipsInPlay, activeCount);

    // Calculate total elapsed time across completed levels + current level elapsed
    int totalElapsedSeconds = 0;
    for (int i = 0; i < game.currentLevel - 1; i++) {
      if (i < game.structure.levels.length) {
        totalElapsedSeconds += game.structure.levels[i].durationMins * 60;
      }
    }
    final levelDurationSeconds = (level?.durationMins ?? 1) * 60;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF242428), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Red Spade + Status
          Row(
            children: [
              const Text(
                '♠',
                style: TextStyle(
                  color: Color(0xFFD53032),
                  fontSize: 16,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isBreak
                    ? 'BREAK'
                    : isPaused
                        ? 'PAUSED'
                        : 'RUNNING',
                style: const TextStyle(
                  color: Color(0xFFE24446),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF242428)),
          const SizedBox(height: 14),

          // "LEVEL X" Tracking Text
          Center(
            child: Text(
              isBreak ? 'BREAK' : 'LEVEL ${game.currentLevel}',
              style: const TextStyle(
                color: Color(0xFFE24446),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.5,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Giant Digital Timer: White Minutes & Red Seconds
          LiveTimerBuilder(
            game: game,
            builder: (context, remaining) {
              final formatted = Formatters.time(remaining);
              final colonIndex = formatted.lastIndexOf(':');
              final minutesPart = colonIndex >= 0 ? formatted.substring(0, colonIndex + 1) : formatted;
              final secondsPart = colonIndex >= 0 ? formatted.substring(colonIndex + 1) : '';

              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: AppTypography.monoFamily,
                      fontSize: 82,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2,
                      height: 1.0,
                    ),
                    children: [
                      TextSpan(
                        text: minutesPart,
                        style: const TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: secondsPart,
                        style: const TextStyle(color: Color(0xFFD53032)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Blinds Trio: SB (white), ANTE (coral), BB (white)
          Row(
            children: [
              Expanded(
                child: _BlindColumn(
                  label: 'SB',
                  value: level == null ? '—' : Formatters.chips(level.sb),
                  highlighted: false,
                ),
              ),
              Expanded(
                child: _BlindColumn(
                  label: 'ANTE',
                  value: level?.ante == null ? '—' : Formatters.chips(level!.ante!),
                  highlighted: true,
                ),
              ),
              Expanded(
                child: _BlindColumn(
                  label: 'BB',
                  value: level == null ? '—' : Formatters.chips(level.bb),
                  highlighted: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Red Progress Bar Line
          LiveTimerBuilder(
            game: game,
            builder: (context, remaining) {
              final progress = levelDurationSeconds > 0
                  ? (1.0 - (remaining / levelDurationSeconds)).clamp(0.0, 1.0)
                  : 0.0;

              return ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 4,
                  width: double.infinity,
                  color: const Color(0xFF242428),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFD53032), Color(0xFFFF5252)],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Sub-stats Row: TOTAL TIME | AVG STACK | PLAYERS (C5 only)
          if (showSubStats) ...[
            const SizedBox(height: 16),
            LiveTimerBuilder(
              game: game,
              builder: (context, remaining) {
                final currentElapsed = (levelDurationSeconds - remaining).clamp(0, levelDurationSeconds);
                final totalSeconds = totalElapsedSeconds + currentElapsed;

                return Row(
                  children: [
                    Expanded(
                      child: _SubStatItem(
                        label: 'TOTAL TIME',
                        value: Formatters.time(totalSeconds),
                      ),
                    ),
                    Container(width: 1, height: 32, color: const Color(0xFF242428)),
                    Expanded(
                      child: _SubStatItem(
                        label: 'AVG STACK',
                        value: Formatters.chips(avgStack),
                      ),
                    ),
                    Container(width: 1, height: 32, color: const Color(0xFF242428)),
                    Expanded(
                      child: _SubStatItem(
                        label: 'PLAYERS',
                        customValue: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: AppTypography.monoFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            children: [
                              TextSpan(text: '$activeCount'),
                              const TextSpan(
                                text: '/',
                                style: TextStyle(color: Color(0xFFD53032)),
                              ),
                              TextSpan(
                                text: '$totalCount',
                                style: const TextStyle(color: Color(0xFFD53032)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _BlindColumn extends StatelessWidget {
  const _BlindColumn({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: highlighted ? const Color(0xFFE24446) : const Color(0xFF8E8E93),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontFamily: AppTypography.monoFamily,
              color: highlighted ? const Color(0xFFE24446) : Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubStatItem extends StatelessWidget {
  const _SubStatItem({
    required this.label,
    this.value,
    this.customValue,
  });

  final String label;
  final String? value;
  final Widget? customValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        if (customValue != null)
          customValue!
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value ?? '',
              style: const TextStyle(
                fontFamily: AppTypography.monoFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
