import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';

import '../../utils/formatters.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_tabs.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/chat_sheet.dart';
import '../../widgets/medal_icon.dart';
import '../../widgets/tournament_display_block.dart';
import '../../responsive/responsive.dart';
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
    final isAdmin = app.isAdmin;
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
    final latestAnn = game.announcements.isEmpty
        ? null
        : game.announcements.last;

    final isFinalTable = game.status == LiveGameStatus.finaltable;

    final device = AppBreakpoints.deviceOf(context);

    return AppPage(
      maxWidth: 1200,
      child: Container(
        decoration: isFinalTable
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.destructive, AppColors.background],
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isFinalTable)
              Container(height: 4, color: AppColors.destructive),
            // Connection status banner (tech spec §4.2 — stale-state).
            Consumer<AppProvider>(
              builder: (_, app, x) {
                if (app.isOffline) {
                  return AppAlertBanner(
                    type: AppAlertType.warning,
                    message:
                        'Connection interrupted — showing last known state.',
                    onDismiss: null,
                  );
                }
                if (app.hasReconnected) {
                  return AppAlertBanner(
                    type: AppAlertType.success,
                    message: 'Back online — data is live.',
                    actionLabel: 'Dismiss',
                    onAction: () => app.clearReconnectedBanner(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            if (game.status == LiveGameStatus.paused)
              const AppAlertBanner(
                type: AppAlertType.warning,
                message: 'Tournament is paused. Wait for the admin to resume.',
              ),
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBackButton(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RoutePaths.home);
                    }
                  },
                ),
                const SizedBox(width: AppSpacing.md),
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
                            decoration: BoxDecoration(
                              color: game.status == LiveGameStatus.paused || game.status == LiveGameStatus.rebuypause
                                  ? AppColors.warning
                                  : game.status == LiveGameStatus.cancelled
                                      ? AppColors.destructive
                                      : game.status == LiveGameStatus.completed
                                          ? AppColors.mutedForeground
                                          : AppColors.success,
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
                    // Guests have no chat (Tech §3.3/§6.6 — audit fix C1).
                    if (!isGuest)
                      AppButton(
                        size: AppButtonSize.sm,
                        variant: AppButtonVariant.ghost,
                        onPressed: () => ChatSheet.show(context, game.id),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppIconLabel(
                              label: 'Chat',
                              icon: Icons.chat_bubble_outline,
                            ),
                            if (app.unreadGameChatCount(game.id) > 0) ...[
                              const SizedBox(width: 4),
                              ChatUnreadBadge(
                                count: app.unreadGameChatCount(game.id),
                              ),
                            ],
                          ],
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
              ],
              active: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_tab == 'dashboard') ...[
              // Main timer card
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: TournamentDisplayBlock(
                  game: game,
                  showPayoutAmounts: false,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (game.status == LiveGameStatus.completed) ...[
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 48,
                        color: AppColors.icon,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Tournament Complete!',
                        style: AppTypography.display(
                          size: AppFontSizes.xl,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        fullWidth: true,
                        onPressed: () => context.go(RoutePaths.resultPodium),
                        child: const Text('View Final Results'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                myPlayer.eliminated && myPlayer.eliminationPos != null
                                    ? _ordinalPlace(myPlayer.eliminationPos!)
                                    : 'Table ${myPlayer.table} · Seat ${myPlayer.seat}',
                                style: AppTypography.monoXl.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if ((myPlayer.knockouts ?? 0) > 0)
                                Text(
                                  '${myPlayer.knockouts} knockout${myPlayer.knockouts! > 1 ? 's' : ''}',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
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
                              if (myPlayer.hasAddOn)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Add-on taken',
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
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: device.isMobile ? 2 : 4,
                            mainAxisSpacing: AppSpacing.xs,
                            crossAxisSpacing: AppSpacing.xs,
                            childAspectRatio: 3,
                          ),
                      itemCount: activePlayers.length,
                      itemBuilder: (context, i) {
                        final p = activePlayers[i];
                        final isMe = p.id == myPlayer?.id;
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
                      'Rebuy period has ended. Add-ons are available. Wait for the admin to start the next level.',
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
                        onPressed: () =>
                            _showCreateAccountDialog(context, app),
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
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(1.5),
                        3: FlexColumnWidth(1.5),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text(
                                'Lv',
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text(
                                'Blinds',
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text(
                                'Ante',
                                textAlign: TextAlign.right,
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text(
                                'Time',
                                textAlign: TextAlign.right,
                                style: AppTypography.bodyXs.copyWith(
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        for (final l in game.structure.levels)
                          TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.border,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                child: Text(
                                  '${l.level}',
                                  style: AppTypography.monoSm.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                child: Text(
                                  '${Formatters.chips(l.sb)} / ${Formatters.chips(l.bb)}',
                                  style: AppTypography.monoSm.copyWith(
                                    color: AppColors.foreground,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                child: Text(
                                  l.ante == null ? '—' : Formatters.chips(l.ante!),
                                  textAlign: TextAlign.right,
                                  style: AppTypography.monoXs.copyWith(
                                    color: l.ante == null
                                        ? AppColors.mutedForeground
                                        : AppColors.accent,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
                      ],
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
                          decoration: BoxDecoration(
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

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  /// §6.7 guest conversion: links credentials onto the anonymous uid so the
  /// recorded result and stats carry over to the new account.
  void _showCreateAccountDialog(BuildContext context, AppProvider app) {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final err = await app.convertGuestAccount(
                name.text.trim(),
                email.text.trim(),
                password.text,
              );
              if (!ctx.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(err)),
                );
                return;
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Create Account'),
          ),
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
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
