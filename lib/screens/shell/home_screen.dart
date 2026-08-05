import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/app_notification.dart';
import '../../models/group.dart';
import '../../models/live_game.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/poker_night_hero.dart';

/// Dashboard mirroring the web `HomePage`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _joinController = TextEditingController();
  final _groupNameController = TextEditingController();
  String _joinError = '';
  bool _showJoin = false;
  bool _showCreate = false;

  @override
  void dispose() {
    _joinController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  void _openGame(BuildContext context, AppProvider app, LiveGame game) {
    final isAdmin = app.user?.isAdmin ?? false;
    if (isAdmin && game.status.isActiveLive) {
      context.go(RoutePaths.adminDashboard);
    } else if (game.status == LiveGameStatus.checkin && isAdmin) {
      context.go(RoutePaths.checkIn);
    } else {
      context.go(isAdmin ? RoutePaths.adminDashboard : RoutePaths.playerLive);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;
    final group = app.currentGroup;
    final games = group.games.where((g) => g.status.isUpcoming).toList();
    final activeGame = games.where((g) => g.status.isActiveLive).firstOrNull;
    final unread = app.unreadCount;

    return Stack(
      children: [
        const _LuxuryDecorations(),
        AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard',
                          style: AppTypography.display(
                            size: AppFontSizes.display,
                            weight: FontWeight.w700,
                          ).copyWith(
                            shadows: [
                              Shadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 16),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Welcome back, ${user?.name ?? 'Guest'}',
                              style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => context.go(RoutePaths.notifications),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none, size: 22, color: AppColors.foreground),
                          if (unread > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)],
                                ),
                                child: Text(
                                  '$unread',
                                  style: AppTypography.mono(size: 10, weight: FontWeight.w700, color: AppColors.primaryForeground),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0, curve: Curves.easeOut),
              const SizedBox(height: AppSpacing.xl),
              // Hero Banner
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: const PokerNightHero(),
              ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, curve: Curves.easeOutBack),
              const SizedBox(height: AppSpacing.xl),
              // Active game banner
              if (activeGame != null) ...[
                AppAlertBanner(
                  type: AppAlertType.success,
                  message: '${activeGame.settings.name} is '
                      '${activeGame.status == LiveGameStatus.running ? 'live now' : 'in progress'}'
                      ' — Level ${activeGame.currentLevel}',
                  actionLabel: user?.isAdmin == true ? 'Open Dashboard' : 'View Game',
                  onAction: () => _openGame(context, app, activeGame),
                ).animate().fadeIn(delay: 120.ms, duration: 400.ms).scaleXY(begin: 0.97, end: 1, delay: 120.ms, curve: Curves.easeOut),
                const SizedBox(height: AppSpacing.xl),
              ],
              // Stats row
              if (user?.stats != null) ...[
                _StatsRow(stats: user!.stats),
                const SizedBox(height: AppSpacing.xl),
              ],
              // Two-column layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 960;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: _UpcomingGames(
                            games: games,
                            isAdmin: user?.isAdmin ?? false,
                            onOpen: (g) => _openGame(context, app, g),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxl),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _GroupCard(
                                group: group,
                                showJoin: () => setState(() {
                                  _joinError = '';
                                  _showJoin = true;
                                }),
                                showCreate: () => setState(() => _showCreate = true),
                                isAdmin: user?.isAdmin ?? false,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              if (app.notifications.any((n) => !n.read))
                                _AlertsPreview(notifications: app.notifications),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UpcomingGames(
                        games: games,
                        isAdmin: user?.isAdmin ?? false,
                        onOpen: (g) => _openGame(context, app, g),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _GroupCard(
                        group: group,
                        showJoin: () => setState(() {
                          _joinError = '';
                          _showJoin = true;
                        }),
                        showCreate: () => setState(() => _showCreate = true),
                        isAdmin: user?.isAdmin ?? false,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (app.notifications.any((n) => !n.read))
                        _AlertsPreview(notifications: app.notifications),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        // Modals
        AppModal(
          open: _showJoin,
          onClose: () => setState(() => _showJoin = false),
          title: 'Join a group',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _joinController,
                placeholder: 'e.g. FRIDAY7',
                error: _joinError,
                keyboardType: TextInputType.visiblePassword,
                textAlign: TextAlign.center,
                textStyle: AppTypography.mono(size: AppFontSizes.xl, weight: FontWeight.w700, letterSpacing: 3.2),
                onChanged: (_) => setState(() => _joinError = ''),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Demo code: ', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                    InkWell(
                      onTap: () => _joinController.text = AppAssets.demoGroupCode,
                      child: Text(
                        AppAssets.demoGroupCode,
                        style: AppTypography.mono(size: AppFontSizes.xs, weight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                fullWidth: true,
                size: AppButtonSize.lg,
                onPressed: () {
                  final ok = app.joinGroup(_joinController.text);
                  if (!ok) {
                    setState(() => _joinError = 'Group not found. Check the code and try again.');
                  } else {
                    setState(() {
                      _showJoin = false;
                      _joinController.clear();
                      _joinError = '';
                    });
                  }
                },
                child: const Text('Join Group'),
              ),
            ],
          ),
        ),
        AppModal(
          open: _showCreate,
          onClose: () => setState(() => _showCreate = false),
          title: 'Create a group',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _groupNameController,
                label: 'Group name',
                placeholder: 'e.g. Friday Poker Club',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                fullWidth: true,
                size: AppButtonSize.lg,
                disabled: _groupNameController.text.trim().length < 2,
                onPressed: () {
                  if (_groupNameController.text.trim().length < 2) return;
                  app.createGroup(_groupNameController.text.trim());
                  setState(() => _showCreate = false);
                  context.go(RoutePaths.group);
                },
                child: const Text('Create Group'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Games', '${stats.played}', Icons.style_outlined),
      ('Wins', '${stats.wins}', Icons.emoji_events_outlined),
      ('Podiums', '${stats.podium}', Icons.workspace_premium_outlined),
      ('Avg Finish', '#${stats.avgFinish.toStringAsFixed(1)}', Icons.leaderboard_outlined),
      ('Knockouts', '${stats.knockouts}', Icons.track_changes_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 5 : (constraints.maxWidth >= 480 ? 3 : 2);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.5,
          children: [
            for (var i = 0; i < items.length; i++)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          alignment: Alignment.center,
                          child: Icon(items[i].$3, size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            items[i].$1.toUpperCase(),
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      items[i].$2,
                      style: AppTypography.mono(
                        size: AppFontSizes.xxl,
                        weight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: (i * 80).ms, duration: 400.ms)
                  .slideY(begin: 0.15, end: 0, delay: (i * 80).ms, duration: 400.ms, curve: Curves.easeOut),
          ],
        );
      },
    );
  }
}

class _UpcomingGames extends StatelessWidget {
  const _UpcomingGames({required this.games, required this.isAdmin, required this.onOpen});

  final List<LiveGame> games;
  final bool isAdmin;
  final ValueChanged<LiveGame> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Upcoming Games',
                    style: AppTypography.display(size: AppFontSizes.xl, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              AppButton(
                size: AppButtonSize.sm,
                onPressed: () => context.go(RoutePaths.createTournament),
                child: const Text('+ New game'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (games.isEmpty)
          AppCard(
            color: Colors.transparent,
            borderColor: AppColors.border,
            child: AppEmptyState(
              icon: '🗓️', // Keeping emoji here unless AppEmptyState is updated
              title: 'No upcoming games',
              description: 'The tables are empty. Create a tournament to get the action started.',
              action: isAdmin
                  ? AppButton(
                      onPressed: () => context.go(RoutePaths.createTournament),
                      child: const Text('Create First Tournament'),
                    )
                  : null,
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < games.length; i++) ...[
                _GameRow(game: games[i], onOpen: () => onOpen(games[i]))
                    .animate()
                    .fadeIn(delay: (i * 100).ms, duration: 450.ms)
                    .slideX(begin: -0.06, end: 0, delay: (i * 100).ms, duration: 450.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.onOpen});

  final LiveGame game;
  final VoidCallback onOpen;

  AppBadgeVariant _colorFor(LiveGameStatus s) {
    switch (s) {
      case LiveGameStatus.running:
        return AppBadgeVariant.green;
      case LiveGameStatus.paused:
      case LiveGameStatus.rebuypause:
      case LiveGameStatus.finaltable:
      case LiveGameStatus.published:
      case LiveGameStatus.checkin:
        return AppBadgeVariant.accent;
      case LiveGameStatus.draft:
      case LiveGameStatus.completed:
        return AppBadgeVariant.muted;
      case LiveGameStatus.cancelled:
        return AppBadgeVariant.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final going = game.goingCount;
    return AppCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      glow: game.status == LiveGameStatus.running,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: game.status == LiveGameStatus.running ? AppColors.success : AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.settings.name,
                            style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AppBadge(label: game.status.label, variant: _colorFor(game.status), border: true),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _InfoChip(icon: Icons.calendar_today_outlined, text: game.settings.date),
                        _InfoChip(icon: Icons.access_time_outlined, text: game.settings.time),
                        _InfoChip(icon: Icons.location_on_outlined, text: game.settings.location),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'Buy-in: ${game.settings.buyIn}',
                            style: AppTypography.mono(size: AppFontSizes.xs, color: AppColors.foreground),
                          ),
                        ),
                        Text('$going going', style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
                        Text(
                          'Code: ${game.publicCode}',
                          style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                    if (game.status == LiveGameStatus.running) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'LIVE · Level ${game.currentLevel}',
                              style: AppTypography.mono(size: AppFontSizes.xs, weight: FontWeight.w700, color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.mutedForeground),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.showJoin,
    required this.showCreate,
    required this.isAdmin,
  });

  final Group? group;
  final VoidCallback showJoin;
  final VoidCallback showCreate;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_outlined, color: AppColors.primary, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'My Group',
              style: AppTypography.display(size: AppFontSizes.xl, weight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (g != null)
          AppCard(
            onTap: () => context.go(RoutePaths.group),
            glow: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.name, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text('Members', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                    ),
                    Text('${g.members.length}', style: AppTypography.bodySm.copyWith(color: AppColors.foreground, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text('Join Code', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        g.joinCode,
                        style: AppTypography.mono(size: AppFontSizes.sm, weight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          AppCard(
            color: Colors.transparent,
            borderColor: AppColors.border,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xs),
                const Icon(Icons.handshake_outlined, size: 48, color: AppColors.mutedForeground),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No group yet. Join with a code or create your own.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  fullWidth: true,
                  onPressed: showJoin,
                  child: const Text('Join Existing Group'),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (isAdmin)
                  AppButton(
                    fullWidth: true,
                    variant: AppButtonVariant.secondary,
                    onPressed: showCreate,
                    child: const Text('Create New Group'),
                  ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ),
          ),
      ],
    );
  }
}

class _AlertsPreview extends StatelessWidget {
  const _AlertsPreview({required this.notifications});

  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => !n.read).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Alerts',
                    style: AppTypography.display(size: AppFontSizes.xl, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => context.go(RoutePaths.notifications),
              child: Text(
                'See all',
                style: AppTypography.bodyXs.copyWith(color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Column(
          children: [
            for (var i = 0; i < unread.length; i++)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(unread[i].title, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  unread[i].type == NotificationType.game ? 'Game update' : 'Alert',
                                  style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '· ${Formatters.relativeTime(unread[i].timestamp)}',
                                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: (i * 90).ms, duration: 400.ms)
                  .slideX(begin: 0.08, end: 0, delay: (i * 90).ms, duration: 400.ms, curve: Curves.easeOut),
          ],
        ),
      ],
    );
  }
}

class _LuxuryDecorations extends StatelessWidget {
  const _LuxuryDecorations();

  @override
  Widget build(BuildContext context) {
    final rng = Random(7);
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Deep background glow - Primary color pulsing
            Positioned(
              top: -150,
              right: -150,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.15), Colors.transparent],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.15, duration: 4.seconds, curve: Curves.easeInOut),
            ),
            // Deep background glow - Destructive color pulsing
            Positioned(
              bottom: -200,
              left: -150,
              child: Container(
                width: 700,
                height: 700,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.destructive.withValues(alpha: 0.12), Colors.transparent],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.2, duration: 5.seconds, curve: Curves.easeInOut),
            ),

            // Spinning Wheel / Rays effect
            Positioned(
              top: -150,
              right: -150,
              child: _SpinningRays(),
            ),

            // Floating elements
            for (var i = 0; i < 14; i++)
              Positioned(
                left: rng.nextInt(100) / 100 * 2000 - 400,
                top: rng.nextInt(90) / 100 * 700,
                child: i % 3 == 0
                    ? _FloatCard(delay: Duration(milliseconds: i * 600))
                    : _FloatChip(
                        delay: Duration(milliseconds: i * 600),
                        label: i % 2 == 0 ? '500' : '100',
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpinningRays extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      height: 600,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(12, (index) {
          return Transform.rotate(
            angle: (index * pi) / 6,
            child: Container(
              height: 600,
              width: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.0),
                    AppColors.primary.withValues(alpha: 0.04),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .rotate(duration: 40.seconds, curve: Curves.linear);
  }
}

class _FloatCard extends StatefulWidget {
  const _FloatCard({required this.delay});

  final Duration delay;

  @override
  State<_FloatCard> createState() => _FloatCardState();
}

class _FloatCardState extends State<_FloatCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final rng = Random();
  late final String suit;
  late final bool isRed;
  late final double _rotationOffset;

  @override
  void initState() {
    super.initState();
    final suits = ['♠', '♥', '♦', '♣'];
    suit = suits[rng.nextInt(4)];
    isRed = suit == '♥' || suit == '♦';
    _rotationOffset = rng.nextDouble() * 0.5 - 0.25;

    _controller = AnimationController(vsync: this, duration: Duration(seconds: 7 + rng.nextInt(3)))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _controller.repeat();
      });
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.4).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
        TweenSequenceItem(tween: ConstantTween(0.4), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 0.4, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
      ]).animate(_controller),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 1.2), end: const Offset(0, -0.8)).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linear),
        ),
        child: RotationTransition(
          turns: Tween(begin: _rotationOffset, end: _rotationOffset + 0.5).animate(
            CurvedAnimation(parent: _controller, curve: Curves.linear),
          ),
          child: Container(
            width: 32,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(color: AppColors.card.withValues(alpha: 0.5), blurRadius: 4),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              suit,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isRed ? AppColors.destructive : AppColors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatChip extends StatefulWidget {
  const _FloatChip({required this.delay, required this.label});

  final Duration delay;
  final String label;

  @override
  State<_FloatChip> createState() => _FloatChipState();
}

class _FloatChipState extends State<_FloatChip> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _controller.repeat();
      });
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
        TweenSequenceItem(tween: ConstantTween(0.5), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
      ]).animate(_controller),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 1.0), end: const Offset(0, -0.6)).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linear),
        ),
        child: RotationTransition(
          turns: Tween(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _controller, curve: Curves.linear),
          ),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.card,
              border: Border.all(color: AppColors.border, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: widget.label == '500' ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                  blurRadius: 8,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: AppTypography.mono(size: 9, weight: FontWeight.w700, color: AppColors.mutedForeground),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedForeground),
        const SizedBox(width: 4),
        Text(text, style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground)),
      ],
    );
  }
}
