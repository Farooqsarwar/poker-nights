import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../responsive/responsive.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_timer.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/chat_sheet.dart';
import '../../models/game.dart';

/// Player live view mirroring the web `PlayerLivePage`.
class PlayerLiveScreen extends StatelessWidget {
  const PlayerLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    if (game == null) {
      return AppPage(
        maxWidth: 480,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            Text('No active game.', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              onPressed: () => context.go(RoutePaths.home),
              child: const Text('Go home'),
            ),
          ],
        ),
      );
    }

    final level = game.currentLevelData;
    final next = game.nextLevelData;
    final activePlayers = game.activePlayers;
    Player? myPlayer = game.players.where((p) => p.id == app.user?.id).firstOrNull;
    if (myPlayer == null && app.guestSession != null) {
      final s = app.guestSession!;
      myPlayer = game.players.where((p) => p.isGuest && p.name == s.name && p.inviterId == s.inviterId && p.guestSlot == s.slot).firstOrNull;
    }
    
    final avgStack = Formatters.averageStack(game.totalChipsInPlay, activePlayers.length);
    final timerDanger = game.secondsRemaining <= 60;
    final timerWarning = game.secondsRemaining <= 300;
    final latestAnn = game.announcements.isEmpty ? null : game.announcements.last;
    final statusText = switch (game.status) {
      LiveGameStatus.running => '● RUNNING',
      LiveGameStatus.paused => 'PAUSED',
      LiveGameStatus.rebuypause => 'REBUY CLOSE — BREAK',
      LiveGameStatus.finaltable => 'FINAL TABLE',
      _ => '',
    };

    final device = AppBreakpoints.deviceOf(context);
    final timerSize = device.isMobile ? 64.0 : 72.0;

    final levelDurationSecs = (level?.durationMins ?? 1) * 60;
    final levelPct = level == null
        ? 0.0
        : (((levelDurationSecs - game.secondsRemaining) / levelDurationSecs) * 100).clamp(0, 100).toDouble();

    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.settings.name, style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(game.status.label, style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ChatSheet.show(context, game.id),
                icon: const Icon(Icons.chat_bubble_outline, color: AppColors.mutedForeground),
                tooltip: 'Chat',
              ),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  AppButton(
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.ghost,
                    onPressed: () => context.go(RoutePaths.tvMode),
                    child: const AppIconLabel(label: 'TV Mode', icon: Icons.tv_outlined),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Main timer card
          AppCard(
            glow: timerDanger,
            borderColor: timerDanger
                ? AppColors.destructive.withValues(alpha: 0.4)
                : timerWarning
                    ? AppColors.warning.withValues(alpha: 0.3)
                    : null,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(
                  'Level ${game.currentLevel}',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTimer(
                  secondsRemaining: game.secondsRemaining,
                  size: timerSize,
                  danger: timerDanger,
                  warning: timerWarning,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  statusText,
                  style: AppTypography.bodyXs.copyWith(
                    color: game.status == LiveGameStatus.running ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (level != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppProgressBar(
                    value: levelPct,
                    max: 100,
                    color: timerDanger
                        ? AppProgressColor.destructive
                        : AppProgressColor.primary,
                    height: 6,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${Formatters.chips(level.sb)} / ${Formatters.chips(level.bb)}',
                    style: AppTypography.mono(
                      size: AppFontSizes.display,
                      weight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  if (level.ante != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${Formatters.chips(level.ante!)} ante (big blind)',
                        style: AppTypography.bodySm.copyWith(color: AppColors.accent),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Next level
          if (next != null)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text('Next level', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '${Formatters.chips(next.sb)} / ${Formatters.chips(next.bb)}',
                          style: AppTypography.monoSm.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (next.ante != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text('+ ante', style: AppTypography.bodyXs.copyWith(color: AppColors.accent)),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    'Level ${game.currentLevel + 1}',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          // Stats row
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Players left', value: '${activePlayers.length}')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _StatCard(label: 'Avg stack', value: Formatters.chips(avgStack))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  label: game.prizePoolLabel,
                  value: Formatters.chips(game.structure.prizePool),
                  valueColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // My seat
          if (myPlayer != null)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your seat', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Table ${myPlayer.table} · Seat ${myPlayer.seat}',
                        style: AppTypography.monoXl.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          myPlayer.eliminated
                              ? const AppBadge(label: 'Eliminated', variant: AppBadgeVariant.red)
                              : const AppBadge(label: 'Active', variant: AppBadgeVariant.green),
                          if (myPlayer.rebuys > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${myPlayer.rebuys} rebuy${myPlayer.rebuys > 1 ? 's' : ''}',
                                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          // Latest announcement
          if (latestAnn != null)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderColor: AppColors.primary.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latest announcement', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                  const SizedBox(height: 2),
                  Text(latestAnn.text, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          // Players remaining
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activePlayers.length} players remaining',
                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.xs,
                    crossAxisSpacing: AppSpacing.xs,
                    childAspectRatio: 3,
                  ),
                  itemCount: activePlayers.length,
                  itemBuilder: (context, i) {
                    final p = activePlayers[i];
                    final isMe = p.id == app.user?.id;
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primarySoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: isMe ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border),
                      ),
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          color: isMe ? AppColors.primary : AppColors.mutedForeground,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Announcement feed
          if (game.announcements.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Announcements', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final a in game.announcements.reversed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.arrow_forward, size: AppFontSizes.xs, color: AppColors.primary),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      a.text,
                                      style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Rebuy break info
          if (game.status == LiveGameStatus.rebuypause) ...[
            const SizedBox(height: AppSpacing.md),
            const AppAlertBanner(
              type: AppAlertType.info,
              message: 'Rebuy period has ended. Add-ons are available. Wait for the host to start the next level.',
            ),
          ],
          // Guest account prompt
          if (game.status == LiveGameStatus.completed && myPlayer != null && myPlayer.isGuest) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderColor: AppColors.primary.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Join the Group', style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Create an account to track your stats and get invited to future games directly.',
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    onPressed: () {
                      app.logout();
                      context.go(RoutePaths.landing);
                    },
                    child: const Text('Create Account'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.monoXl.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
