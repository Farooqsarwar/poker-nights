import 'package:flutter/material.dart';
import '../app/colors.dart';

import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/live_game.dart';
import '../utils/automations_service.dart';
import '../utils/formatters.dart';
import '../utils/voice_service.dart';
import 'app_timer.dart';
import 'brand_lockup.dart';

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
    final avgStack = Formatters.averageStack(
      game.totalChipsInPlay,
      activeCount,
    );

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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: (!isPaused && !isBreak)
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.shadowSoft,
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Logo + Status
          RepaintBoundary(
            child: Row(
              children: [
                const PokerNightLogo(size: 16),
                const SizedBox(width: 8),
                Text(
                  isBreak
                      ? 'BREAK'
                      : isPaused
                      ? 'PAUSED'
                      : 'RUNNING',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 14),

          // "LEVEL X" Tracking Text
          Center(
            child: Semantics(
              liveRegion: true,
              excludeSemantics: true,
              // Same words as the voice, and it only changes with the level --
              // never with the second (Addendum 2 #2).
              label: isBreak
                  ? 'Break'
                  : VoiceService.levelChangeMessage(
                      level: game.currentLevel,
                      sb: level?.sb ?? 0,
                      bb: level?.bb ?? 0,
                      ante: level?.ante,
                      durationMins: level?.durationMins ?? 0,
                    ),
              child: LevelEventPulse(
                level: game.currentLevel,
                pulseKey: 'level-label-pulse',
                child: Text(
                  isBreak ? 'BREAK' : 'LEVEL ${game.currentLevel}',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Giant Digital Timer: White Minutes & Red Seconds
          // Rule 15 visual twin: last 5s stay large with live-region semantics
          // (spoken 5-4-3-2-1 already fires in AppProviderTimer). Client-only.
          LiveTimerBuilder(
            game: game,
            builder: (context, remaining) {
              final urgency = AutomationsService.isCountdownUrgency(remaining);

              return Semantics(
                liveRegion: urgency,
                label: urgency ? '$remaining' : null,
                child: SizedBox(
                  // The previous one-piece clock naturally scaled to roughly
                  // this height on compact dashboards. Keep that footprint so
                  // the host controls remain visible at 844 px.
                  height: urgency ? 82 : 64,
                  child: AnimatedTimerDigits(
                    secondsRemaining: remaining,
                    size: urgency ? 96 : 82,
                    minutesColor: AppColors.foreground,
                    secondsColor: AppColors.primary,
                    glow: urgency,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Blinds Trio: SB (white), ANTE (coral), BB (white)
          RepaintBoundary(
            child: LevelEventPulse(
              level: game.currentLevel,
              pulseKey: 'blinds-pulse',
              child: Row(
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
                      value: level?.ante == null
                          ? '—'
                          : Formatters.chips(level!.ante!),
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
            ),
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
                  color: AppColors.borderSubtle,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryHover],
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
                final currentElapsed = (levelDurationSeconds - remaining).clamp(
                  0,
                  levelDurationSeconds,
                );
                final totalSeconds = totalElapsedSeconds + currentElapsed;

                return Row(
                  children: [
                    Expanded(
                      child: _SubStatItem(
                        label: 'TOTAL TIME',
                        value: Formatters.time(totalSeconds),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: AppColors.borderSubtle,
                    ),
                    Expanded(
                      child: _SubStatItem(
                        label: 'AVG STACK',
                        value: Formatters.chips(avgStack),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: AppColors.borderSubtle,
                    ),
                    Expanded(
                      child: _SubStatItem(
                        label: 'PLAYERS',
                        customValue: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: AppTypography.monoFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                              children: [
                                TextSpan(text: '$activeCount'),
                                TextSpan(
                                  text: '/',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                                TextSpan(
                                  text: '$totalCount',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ],
                            ),
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
            color: highlighted
                ? AppColors.primaryText
                : AppColors.mutedForeground,
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
              color: highlighted ? AppColors.primaryText : AppColors.foreground,
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
  const _SubStatItem({required this.label, this.value, this.customValue});

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
          style: TextStyle(
            color: AppColors.mutedForeground,
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
              style: TextStyle(
                fontFamily: AppTypography.monoFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
      ],
    );
  }
}
