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
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_tabs.dart';
import '../../widgets/app_timer.dart';
import '../../widgets/blinds_trio.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/chat_sheet.dart';
import '../../widgets/medal_icon.dart';
import '../../models/game.dart';

/// Player live view mirroring the web `PlayerLivePage`.
class PlayerLiveScreen extends StatefulWidget {
  const PlayerLiveScreen({super.key});

  @override
  State<PlayerLiveScreen> createState() => _PlayerLiveScreenState();
}

class _PlayerLiveScreenState extends State<PlayerLiveScreen> {
  String _tab = 'dashboard';

  String _ordinalPlace(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th place';
    return switch (n % 10) {
      1 => '${n}st place',
      2 => '${n}nd place',
      3 => '${n}rd place',
      _ => '${n}th place',
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isAdmin = app.user?.isAdmin == true;
    // Guests get the LIMITED live view: timer, blinds, next level, players
    // remaining, average stack, their seat and announcements — no chat,
    // polls, payouts or full structure (Tech §6.6/§17, audit fix C1).
    final isGuest = app.hasGuestSession;
    final baseGame = app.currentGame;
    final game = baseGame == null
        ? null
        : (isAdmin ? baseGame : app.viewerProjection);

    if (game == null) {
      return AppPage(
        maxWidth: 480,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              'No active game.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
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
    Player? myPlayer = game.players
        .where((p) => p.id == app.user?.id)
        .firstOrNull;
    if (myPlayer == null && app.guestSession != null) {
      final s = app.guestSession!;
      myPlayer = game.players
          .where(
            (p) =>
                p.isGuest &&
                p.name == s.name &&
                p.inviterId == s.inviterId &&
                p.guestSlot == s.slot,
          )
          .firstOrNull;
    }

    // Everyone seated at my table, so I know exactly where to sit (07-016).
    final me = myPlayer;
    final tableMates = me == null || me.table <= 0
        ? const <Player>[]
        : (game.players
              .where((p) => p.table == me.table && p.table > 0)
              .toList()
            ..sort((a, b) => a.seat.compareTo(b.seat)));

    final avgStack = Formatters.averageStack(
      game.totalChipsInPlay,
      activePlayers.length,
    );
    final timerDanger = game.secondsRemaining <= 60;
    final timerWarning = game.secondsRemaining <= 300;
    final latestAnn = game.announcements.isEmpty
        ? null
        : game.announcements.last;
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
        : (((levelDurationSecs - game.secondsRemaining) / levelDurationSecs) *
                  100)
              .clamp(0, 100)
              .toDouble();

    final isFinalTable = game.status == LiveGameStatus.finaltable;

    return AppPage(
      maxWidth: 560,
      child: Container(
        decoration: isFinalTable
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A0A10), Color(0xFF000000)],
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isFinalTable)
              Container(height: 4, color: const Color(0xFFFF2A2A)),
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.settings.name,
                        style: AppTypography.display(
                          size: AppFontSizes.xxxl,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            game.status.label,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Guests have no chat (Tech §3.3/§6.6 — audit fix C1).
                if (!isGuest)
                  IconButton(
                    onPressed: () => ChatSheet.show(context, game.id),
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.mutedForeground,
                    ),
                    tooltip: 'Chat',
                  ),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    AppButton(
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => context.go(RoutePaths.tvMode),
                      child: const AppIconLabel(
                        label: 'TV Mode',
                        icon: Icons.tv_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTabs(
              tabs: [
                const AppTabItem(id: 'dashboard', label: 'Dashboard'),
                if (!isGuest)
                  const AppTabItem(id: 'structure', label: 'Structure'),
                if (isAdmin) const AppTabItem(id: 'payouts', label: 'Payouts'),
                if (!isGuest) const AppTabItem(id: 'chat', label: 'Chat'),
              ],
              active: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_tab == 'dashboard') ...[
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
                    LiveTimerBuilder(
                      game: game,
                      builder: (context, remaining) => AppTimer(
                        secondsRemaining: remaining,
                        size: timerSize,
                        danger: remaining <= 60,
                        warning: remaining <= 300,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      statusText,
                      style: AppTypography.bodyXs.copyWith(
                        color: game.status == LiveGameStatus.running
                            ? AppColors.success
                            : AppColors.warning,
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
                      const SizedBox(height: AppSpacing.md),
                      BlindsTrio(
                        sb: level.sb,
                        bb: level.bb,
                        ante: level.ante,
                        valueSize: AppFontSizes.displayLg,
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
                      Text(
                        'Next level',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              '${Formatters.chips(next.sb)} / ${Formatters.chips(next.bb)}',
                              style: AppTypography.monoSm.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (next.ante != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '+ ante',
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        'Level ${game.currentLevel + 1}',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              // Stats row — the limited live view for players/guests.
              // (Audit fix C2: removed the un-specced "Rank" card.)
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Players left',
                      value: '${activePlayers.length}',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _StatCard(
                      label: 'Avg stack',
                      value: Formatters.chips(avgStack),
                    ),
                  ),
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
                      Text(
                        'Your seat',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Table ${myPlayer.table} · Seat ${myPlayer.seat}',
                            style: AppTypography.monoXl.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              myPlayer.eliminated
                                  ? const AppBadge(
                                      label: 'Eliminated',
                                      variant: AppBadgeVariant.red,
                                    )
                                  : const AppBadge(
                                      label: 'Active',
                                      variant: AppBadgeVariant.green,
                                    ),
                              if (myPlayer.rebuys > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${myPlayer.rebuys} rebuy${myPlayer.rebuys > 1 ? 's' : ''}',
                                    style: AppTypography.bodyXs.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (game.settings.rebuys) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Rebuys: ${myPlayer.rebuys} used · open until Level ${game.settings.rebuysCloseLevel}',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                      // Rebuys and add-ons are recorded by the host, never
                      // self-served (Tech §3 permission matrix, UAT: "a member
                      // attempts to self-record a rebuy; the backend denies
                      // the action") — so no request buttons here.
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              // My table — who I'm sitting with
              if (tableMates.isNotEmpty)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Table ${myPlayer!.table}',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final p in tableMates)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              AppAvatar(name: p.name, size: AppAvatarSize.sm),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySm.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: p.id == myPlayer.id
                                        ? AppColors.foreground
                                        : AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                              if (p.id == myPlayer.id)
                                const AppBadge(
                                  label: 'You',
                                  variant: AppBadgeVariant.gold,
                                )
                              else
                                Text(
                                  'Seat ${p.seat}',
                                  style: AppTypography.bodyXs.copyWith(
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
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
                      Text(
                        'Latest announcement',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        latestAnn.text,
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                            color: isMe
                                ? AppColors.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: isMe
                                  ? AppColors.primary.withValues(alpha: 0.5)
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySm.copyWith(
                              color: isMe
                                  ? AppColors.primary
                                  : AppColors.mutedForeground,
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
                      Text(
                        'Announcements',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final a in game.announcements.reversed)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.arrow_forward,
                                        size: AppFontSizes.xs,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          a.text,
                                          style: AppTypography.bodySm.copyWith(
                                            color: AppColors.mutedForeground,
                                          ),
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
                  message:
                      'Rebuy period has ended. Add-ons are available. Wait for the host to start the next level.',
                ),
              ],
              // Guest account prompt
              if (game.status == LiveGameStatus.completed &&
                  myPlayer != null &&
                  myPlayer.isGuest) ...[
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  borderColor: AppColors.primary.withValues(alpha: 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Join the Group',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Create an account to track your stats and get invited to future games directly.',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
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
            ],
            if (_tab == 'structure') ...[
              // Blind schedule
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            'Level',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Blinds',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            'Ante',
                            textAlign: TextAlign.right,
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            'Duration',
                            textAlign: TextAlign.right,
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final l in game.structure.levels)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.border,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text(
                                'Level ${l.level}',
                                style: AppTypography.monoSm.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${Formatters.chips(l.sb)} / ${Formatters.chips(l.bb)}',
                                style: AppTypography.monoSm.copyWith(
                                  color: AppColors.foreground,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                l.ante == null
                                    ? '—'
                                    : Formatters.chips(l.ante!),
                                textAlign: TextAlign.right,
                                style: AppTypography.monoXs.copyWith(
                                  color: l.ante == null
                                      ? AppColors.mutedForeground
                                      : AppColors.accent,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 64,
                              child: Text(
                                '${l.durationMins}m',
                                textAlign: TextAlign.right,
                                style: AppTypography.monoXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (game.settings.rebuys) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          'Rebuys remain open until after Level ${game.settings.rebuysCloseLevel}.',
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_tab == 'payouts') ...[
              if (!isAdmin)
                const AppAlertBanner(
                  type: AppAlertType.warning,
                  message:
                      'Payout amounts are private — only organisers can see them.',
                )
              else
                const AppAlertBanner(
                  type: AppAlertType.info,
                  message: 'Admin view — payout amounts are shown.',
                ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Payouts',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (game.structure.prizes.isEmpty)
                      Text(
                        'No prizes set yet.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      )
                    else
                      for (final p in game.structure.prizes)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.border,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: p.place <= 3
                                    ? MedalIcon(p.place, size: AppFontSizes.lg)
                                    : Text(
                                        '${p.place}.',
                                        style: AppTypography.monoSm.copyWith(
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _ordinalPlace(p.place),
                                  style: AppTypography.bodySm,
                                ),
                              ),
                              Text(
                                isAdmin ? Formatters.chips(p.amount) : '—',
                                style: AppTypography.monoSm.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Text(
                          game.prizePoolLabel,
                          style: AppTypography.bodyXs.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isAdmin
                              ? Formatters.chips(game.structure.prizePool)
                              : '—',
                          style: AppTypography.monoXs.copyWith(
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (_tab == 'chat') ...[
              if (game.chat.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: Column(
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        color: AppColors.mutedForeground,
                        size: AppFontSizes.xxl,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'No messages yet.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final m in game.chat)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppAvatar(
                                    name: m.authorName,
                                    size: AppAvatarSize.sm,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      m.authorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySm.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    Formatters.relativeTime(m.timestamp),
                                    style: AppTypography.bodyXs.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                m.body,
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
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
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
