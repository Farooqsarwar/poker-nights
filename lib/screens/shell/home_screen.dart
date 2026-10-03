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
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/main_button.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_tag.dart';
import '../../services/payment_service.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/create_group_dialog.dart';
import '../../widgets/group_switcher.dart';

/// Dashboard mirroring the web `HomePage`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showRestoreModal = false;

  void _openJoin() => context.go(RoutePaths.join);

  static String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '♠';
    return parts.map((p) => p[0].toUpperCase()).take(2).join();
  }

  LiveGame? _repostCandidate(AppProvider app) {
    final candidates = app.currentGroup.games
        .where((g) => g.status == LiveGameStatus.completed)
        .toList()
      ..sort((a, b) => b.settings.scheduledStart == null
          ? 1
          : (a.settings.scheduledStart ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.settings.scheduledStart ?? DateTime.fromMillisecondsSinceEpoch(0)));
    final hasOpen = app.currentGroup.games.any((g) =>
        g.status != LiveGameStatus.completed && g.status != LiveGameStatus.cancelled);
    if (candidates.isEmpty || hasOpen) return null;
    return candidates.first;
  }

  void _openGame(BuildContext context, AppProvider app, LiveGame game) {
    // Always set the current game first so every destination screen
    // has the correct game in the provider (fixes navigation dead-ends).
    app.setCurrentGame(game);
    // The destination is the contextual main action (user-flow spec §9):
    // one event, one dominant next action, resolved from role + state.
    final user = app.user;
    final isAdmin = app.isAdmin;
    final me = user == null
        ? null
        : game.players.where((p) => p.id == user.id).firstOrNull;
    final action = mainActionFor(
      isAdmin ? MainButtonRole.admin : MainButtonRole.member,
      game,
      memberRow: me,
    );
    context.go(action.route ?? RoutePaths.invitation);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;
    final group = app.currentGroup;
    final isAdmin = app.isAdmin;
    // Draft games are only visible to admins (spec §3, §25).
    final games = group.games
        .where(
          (g) =>
              g.status.isUpcoming &&
              (isAdmin || g.status != LiveGameStatus.draft),
        )
        .toList();
    final activeGame = games.where((g) => g.status.isActiveLive).firstOrNull;
    final repost = app.hasCurrentGroup ? _repostCandidate(app) : null;

    return Stack(
      children: [
        AppPage(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;

              if (isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    // Desktop Header Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.successText,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Welcome back, ${user?.name.isNotEmpty == true ? user!.name : 'Player'}',
                                    style: TextStyle(
                                      color: AppColors.mutedForeground,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Home',
                                    style: TextStyle(
                                      color: AppColors.foreground,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (app.hasCurrentGroup) ...[
                                    const SizedBox(width: AppSpacing.md),
                                    InkWell(
                                      onTap: () => showGroupSwitcher(context),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.card,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.borderSubtle),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                _getInitials(group.name),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 180),
                                              child: Text(
                                                group.name,
                                                style: TextStyle(
                                                  color: AppColors.foreground,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.keyboard_arrow_down,
                                              color: AppColors.mutedForeground,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (app.hasCurrentGroup) ...[
                          if (isAdmin) ...[
                            AppButton(
                              size: AppButtonSize.sm,
                              onPressed: () => context.push(RoutePaths.quick),
                              child: const Text('Start game'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          AppButton(
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.sm,
                            onPressed: () => context.push(RoutePaths.createTournament),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: AppColors.primaryText, size: 14),
                                const SizedBox(width: AppSpacing.xs),
                                const Text('New game'),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppButton(
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.sm,
                            onPressed: () => context.go(RoutePaths.cashGame),
                            child: const Text('Cash game'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        _NotificationBellButton(app: app),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (!app.hasCurrentGroup) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppCard(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Poker tonight?',
                                    style: AppTypography.eyebrow(
                                      size: 11,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Friends already at the table? Start the clock now — no account, nothing to install.',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  AppButton(
                                    fullWidth: true,
                                    size: AppButtonSize.lg,
                                    onPressed: () => context.go(RoutePaths.quick),
                                    child: const Text('Start a game now'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(
                            child: AppCard(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Same friends every week?',
                                    style: AppTypography.eyebrow(
                                      size: 11,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Set up a recurring poker club with automatic chip calculations, member stats, chat, and season leaderboards.',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AppButton(
                                          fullWidth: true,
                                          size: AppButtonSize.lg,
                                          onPressed: () => openCreateGroupDialog(context),
                                          child: const Text('Create a group'),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: AppButton(
                                          fullWidth: true,
                                          size: AppButtonSize.lg,
                                          variant: AppButtonVariant.secondary,
                                          onPressed: () => context.go(RoutePaths.join),
                                          child: const Text('Join a group'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        'Poker Toolkit',
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Free utility calculators for your home games — no login required',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          _ToolkitCard(
                            title: 'Tournament Clock',
                            subtitle: 'Blinds, antes & sound alerts',
                            icon: Icons.timer_outlined,
                            onTap: () => context.push(RoutePaths.toolClock),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _ToolkitCard(
                            title: 'Structure Generator',
                            subtitle: 'Custom blind levels by chip count',
                            icon: Icons.format_list_numbered_rounded,
                            onTap: () => context.push(RoutePaths.toolBlinds),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _ToolkitCard(
                            title: 'ICM Calculator',
                            subtitle: 'Calculate chip equity & deals',
                            icon: Icons.show_chart_rounded,
                            onTap: () => context.push(RoutePaths.toolIcm),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _ToolkitCard(
                            title: 'Payout Calculator',
                            subtitle: 'Prize pool splits & structures',
                            icon: Icons.receipt_long_outlined,
                            onTap: () => context.push(RoutePaths.toolPayouts),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(
                                Icons.workspace_premium_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Poker Night Premium',
                                        style: AppTypography.bodySm.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      AppTag(
                                        app.premiumTier == PremiumTier.premium
                                            ? 'ACTIVE'
                                            : 'PREMIUM',
                                        tone: app.premiumTier == PremiumTier.premium
                                            ? AppTagTone.success
                                            : AppTagTone.primary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    'Two or more tables, seasons & points, custom TV layouts, bounties & unlimited templates.',
                                    style: AppTypography.bodyXs.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            AppButton(
                              size: AppButtonSize.sm,
                              variant: app.premiumTier == PremiumTier.premium
                                  ? AppButtonVariant.secondary
                                  : AppButtonVariant.primary,
                              onPressed: () => context.push(RoutePaths.upgrade),
                              child: Text(
                                app.premiumTier == PremiumTier.premium
                                    ? 'Manage'
                                    : 'See Premium',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (flex: 7)
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (app.hasOfflineConflict) ...[
                                  AppAlertBanner(
                                    type: AppAlertType.warning,
                                    message:
                                        'Remote cloud changes conflict with your local offline progress. Please choose which state to keep.',
                                    actionLabel: 'Review Conflict',
                                    onAction: () => context.go(RoutePaths.hostDashboard),
                                  ).animate().fadeIn(duration: 400.ms),
                                  const SizedBox(height: AppSpacing.lg),
                                ] else if (app.restoredFromRecovery && activeGame != null) ...[
                                  AppAlertBanner(
                                    type: AppAlertType.info,
                                    message:
                                        'An active tournament was found on this device'
                                        '${app.restoredAt != null ? ' — last saved ${_hhmm(app.restoredAt!)}' : ''}.',
                                    actionLabel: 'Review',
                                    onAction: () => setState(() => _showRestoreModal = true),
                                  ).animate().fadeIn(duration: 400.ms),
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                                _NextActionCard(
                                  app: app,
                                  group: group,
                                  isAdmin: isAdmin,
                                  onOpen: (g) => _openGame(context, app, g),
                                ),
                                if (repost != null) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  AppCard(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Same as last time?',
                                                style: TextStyle(
                                                  color: AppColors.foreground,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: AppSpacing.xs),
                                              Text(
                                                'Repost ${repost.settings.name} one week later.',
                                                style: AppTypography.bodySm.copyWith(
                                                  color: AppColors.mutedForeground,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        AppButton(
                                          variant: AppButtonVariant.secondary,
                                          onPressed: () => context.push(
                                            '${RoutePaths.createTournament}?repost=${repost.id}',
                                          ),
                                          child: const Text('Repost'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.xl),
                                _UpcomingGames(
                                  games: games,
                                  isAdmin: app.isAdmin,
                                  userId: user?.id,
                                  onOpen: (g) => _openGame(context, app, g),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          // Right Column (flex: 5)
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _GroupCard(
                                  group: group,
                                  loading: app.groupBundleLoading,
                                  showJoin: _openJoin,
                                  showCreate: () => openCreateGroupDialog(context),
                                  isAdmin: app.isAdmin,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                Text(
                                  'Group snapshot',
                                  style: TextStyle(
                                    color: AppColors.foreground,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _GroupStats(group: group, app: app, isGrid: true),
                                if (app.notifications.any((n) => !n.read)) ...[
                                  const SizedBox(height: AppSpacing.xl),
                                  _AlertsPreview(notifications: app.notifications),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              }

              // Mobile / compact layout (< 960px)
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  // Top Header Row
                  Row(
                    children: [
                      Semantics(
                        label: 'Open navigation menu',
                        button: true,
                        child: InkWell(
                          onTap: app.toggleDrawer,
                          borderRadius: BorderRadius.circular(21),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primarySoftBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              user?.name.isNotEmpty == true
                                  ? user!.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: AppColors.foreground,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: AppColors.successText,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    color: AppColors.mutedForeground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.name.isNotEmpty == true
                                  ? user!.name
                                  : '',
                              style: TextStyle(
                                color: AppColors.foreground,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _NotificationBellButton(app: app),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (!app.hasCurrentGroup) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Poker tonight?',
                            style: AppTypography.eyebrow(
                              size: 11,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Friends already at the table? Start the clock now — no account, nothing to install.',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppButton(
                            fullWidth: true,
                            onPressed: () => context.go(RoutePaths.quick),
                            child: const Text('Start a game now'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Same friends every week?',
                      style: AppTypography.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            fullWidth: true,
                            onPressed: () => openCreateGroupDialog(context),
                            child: const Text('Create a group'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            fullWidth: true,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => context.go(RoutePaths.join),
                            child: const Text('Join a group'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'Home',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InkWell(
                      onTap: () => showGroupSwitcher(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                app.hasCurrentGroup ? _getInitials(group.name) : '♠',
                                style: TextStyle(
                                  color: AppColors.foreground,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                app.hasCurrentGroup ? group.name : 'Select a group',
                                style: TextStyle(
                                  color: AppColors.foreground,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.mutedForeground,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (app.hasOfflineConflict) ...[
                      AppAlertBanner(
                        type: AppAlertType.warning,
                        message:
                            'Remote cloud changes conflict with your local offline progress. Please choose which state to keep.',
                        actionLabel: 'Review Conflict',
                        onAction: () => context.go(RoutePaths.hostDashboard),
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: AppSpacing.xl),
                    ] else if (app.restoredFromRecovery && activeGame != null) ...[
                      AppAlertBanner(
                        type: AppAlertType.info,
                        message:
                            'An active tournament was found on this device'
                            '${app.restoredAt != null ? ' — last saved ${_hhmm(app.restoredAt!)}' : ''}.',
                        actionLabel: 'Review',
                        onAction: () => setState(() => _showRestoreModal = true),
                      ).animate().fadeIn(duration: 400.ms),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    _NextActionCard(
                      app: app,
                      group: group,
                      isAdmin: isAdmin,
                      onOpen: (g) => _openGame(context, app, g),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (app.hasCurrentGroup && repost != null) ...[
                      AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Same as last time?',
                                    style: TextStyle(
                                      color: AppColors.foreground,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Repost ${repost.settings.name} one week later.',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            AppButton(
                              variant: AppButtonVariant.secondary,
                              onPressed: () => context.push(
                                '${RoutePaths.createTournament}?repost=${repost.id}',
                              ),
                              child: const Text('Repost'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    if (isAdmin) ...[
                      AppButton(
                        size: AppButtonSize.lg,
                        fullWidth: true,
                        onPressed: () => context.push(RoutePaths.quick),
                        child: const Text('Start a game now'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.lg,
                            fullWidth: true,
                            onPressed: () => context.push(RoutePaths.createTournament),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: AppColors.primaryText, size: 18),
                                const SizedBox(width: AppSpacing.sm),
                                const Flexible(
                                  child: Text(
                                    'New game',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppButton(
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.lg,
                            fullWidth: true,
                            onPressed: () => context.go(RoutePaths.cashGame),
                            child: const Text(
                              'Cash game',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Text(
                      'Group snapshot',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _GroupStats(group: group, app: app, isGrid: false),
                    const SizedBox(height: AppSpacing.xl),
                    _UpcomingGames(
                      games: games,
                      isAdmin: app.isAdmin,
                      userId: user?.id,
                      onOpen: (g) => _openGame(context, app, g),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _GroupCard(
                      group: app.hasCurrentGroup ? group : null,
                      loading: app.groupBundleLoading,
                      showJoin: _openJoin,
                      showCreate: () => openCreateGroupDialog(context),
                      isAdmin: app.isAdmin,
                    ),
                    if (app.notifications.any((n) => !n.read)) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _AlertsPreview(notifications: app.notifications),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
        // Restore-active-tournament prompt (Tech §20.1, audit fix B8):
        // shows the last-saved local time and offers Restore or Discard.
        AppModal(
          open: _showRestoreModal && app.restoredFromRecovery,
          onClose: () => setState(() => _showRestoreModal = false),
          title: 'Restore active tournament?',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppAlertBanner(
                type: AppAlertType.info,
                message: app.restoredAt != null
                    ? 'A saved game was found — last saved locally at ${_hhmm(app.restoredAt!)}.'
                    : 'A saved game was found on this device.',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                variant: AppButtonVariant.primary,
                fullWidth: true,
                onPressed: () {
                  // Keep the restored state.
                  app.resolveOfflineConflict(keepLocal: true);
                  setState(() => _showRestoreModal = false);
                },
                child: const Text('Restore and continue'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                variant: AppButtonVariant.ghost,
                fullWidth: true,
                onPressed: () {
                  app.discardRestoredGame();
                  setState(() => _showRestoreModal = false);
                },
                child: const Text('Discard saved game'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Group activity snapshot shown on Home — answers "how is the group doing?"
/// with counts that already exist in the provider (IA §7).
class _GroupStats extends StatelessWidget {
  const _GroupStats({required this.group, required this.app, this.isGrid = false});

  final Group group;
  final AppProvider app;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    final past = group.pastGames.length;
    final members = group.members.length;
    final cash = app.cashHistory.length;
    final prizeVolume = group.pastGames.fold<int>(
      0,
      (s, g) => s + g.structure.prizePool,
    );
    final cashVolume = app.cashHistory.fold<double>(
      0,
      (s, c) => s + c.totalBuyIns,
    );
    final totalVol = prizeVolume + cashVolume;
    final volumeStr = totalVol >= 1000
        ? '${(totalVol / 1000).round()}k'
        : '\$$totalVol';

    if (isGrid) {
      return Column(
        children: [
          Row(
            children: [
              _MetricCard(value: '$past', label: 'games'),
              const SizedBox(width: 8),
              _MetricCard(value: '$members', label: 'members'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetricCard(value: '$cash', label: 'cash games'),
              const SizedBox(width: 8),
              _MetricCard(value: volumeStr, label: 'volume'),
            ],
          ),
        ],
      );
    }

    // IntrinsicHeight + stretch: the four tiles size to their tallest
    // content (the two-line "cash games" label) instead of a fixed height
    // that clipped it on narrow phones.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricCard(value: '$past', label: 'games'),
          const SizedBox(width: 8),
          _MetricCard(value: '$members', label: 'members'),
          const SizedBox(width: 8),
          _MetricCard(value: '$cash', label: 'cash\ngames'),
          const SizedBox(width: 8),
          // Money is white, not gold (no-gold rule, B4.9).
          _MetricCard(
            value: volumeStr,
            label: 'volume',
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTypography.mono(
                  size: AppFontSizes.xxl,
                  weight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card that answers "what should I do next?" for the current user
/// (User Flow §4.1 — Home identifies the next required action, and shows
/// pending check-ins / confirmed attendance for the admin).
class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.app,
    required this.group,
    required this.isAdmin,
    required this.onOpen,
  });

  final AppProvider app;
  final Group group;
  final bool isAdmin;
  final ValueChanged<LiveGame> onOpen;

  LiveGame? _target() {
    final games = group.games.where((g) => g.status.isUpcoming).toList();
    if (games.isEmpty) return null;
    // Prefer a live game, then check-in/ready, then published.
    for (final s in [
      LiveGameStatus.running,
      LiveGameStatus.paused,
      LiveGameStatus.rebuypause,
      LiveGameStatus.finaltable,
      LiveGameStatus.checkin,
      LiveGameStatus.ready,
      LiveGameStatus.published,
      LiveGameStatus.draft,
    ]) {
      final g = games.where((g) => g.status == s).firstOrNull;
      if (g != null) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final game = _target();
    if (game == null) {
      if (isAdmin) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready for the next game?',
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Schedule a tournament or start a quick poker timer for your club.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                size: AppButtonSize.sm,
                onPressed: () => context.push(RoutePaths.createTournament),
                child: const Text('Schedule game'),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final going = game.goingCount;
    final (title, subtitle, actionLabel) = switch (game.status) {
      LiveGameStatus.running || LiveGameStatus.paused => (
        game.settings.name,
        '${game.settings.date} ${game.settings.time} · $going going',
        'Open dashboard',
      ),
      LiveGameStatus.rebuypause => (
        game.settings.name,
        'Settlement required · $going going',
        'Complete break',
      ),
      LiveGameStatus.finaltable => (
        game.settings.name,
        'Final table · 9 remain · $going going',
        'Redraw table',
      ),
      LiveGameStatus.checkin || LiveGameStatus.ready => (
        game.settings.name,
        '${game.settings.date} ${game.settings.time} · $going going',
        'Open check-in',
      ),
      _ => (
        game.settings.name,
        '${game.settings.date} ${game.settings.time} · $going going',
        'Open dashboard',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT UP',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isNotEmpty ? title : 'Friday Night Freezeout',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (game.status.isActiveLive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.successText,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.successText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
          ),
          if (going > group.tableSettings.maxPerTable) ...[
            const SizedBox(height: 10),
            Text(
              "That's a second table — Premium covers 2+ tables. Sort it now, days before the game, never at the door.",
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.primary,
                  onPressed: () => context.push(RoutePaths.upgrade),
                  child: const Text('See Premium'),
                ),
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    app.updateGroupTableSettings(
                      group.tableSettings.copyWith(maxPerTable: 10),
                    );
                  },
                  child:
                      const Text('Seat 10 at one table instead (free)'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            onTap: () => onOpen(game),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                actionLabel,
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingGames extends StatelessWidget {
  const _UpcomingGames({
    required this.games,
    required this.isAdmin,
    required this.userId,
    required this.onOpen,
  });

  final List<LiveGame> games;
  final bool isAdmin;
  final String? userId;
  final ValueChanged<LiveGame> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            InkWell(
              onTap: () => context.go(RoutePaths.group),
              child: Text(
                'See all',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (games.isEmpty)
          AppCard(
            color: Colors.transparent,
            borderColor: AppColors.border,
            child: AppEmptyState(
              icon: Icons.calendar_today_outlined,
              title: 'No upcoming games',
              description:
                  'The tables are empty. Create a tournament to get the action started.',
              action: isAdmin
                  ? AppButton(
                      onPressed: () => context.push(RoutePaths.createTournament),
                      child: const Text('Create First Game'),
                    )
                  : null,
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < games.length; i++) ...[
                _GameRow(
                  game: games[i],
                  isAdmin: isAdmin,
                  userId: userId,
                  onOpen: () => onOpen(games[i]),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.game,
    required this.isAdmin,
    required this.userId,
    required this.onOpen,
  });

  final LiveGame game;
  final bool isAdmin;
  final String? userId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final going = game.goingCount;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        game.settings.name,
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${game.settings.date} ${game.settings.time} · Buy-in \$${game.settings.buyIn} · $going going',
                        style: TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'RSVP',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    this.loading = false,
  });

  final Group? group;
  final VoidCallback showJoin;
  final VoidCallback showCreate;
  final bool isAdmin;

  /// A group is selected but its live bundle is still loading (e.g. just
  /// joined) — show a spinner instead of the card or the empty state.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.groups_outlined, color: AppColors.primary, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'My Group',
              style: AppTypography.display(
                size: AppFontSizes.xl,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (loading)
          AppCard(
            color: Colors.transparent,
            borderColor: AppColors.border,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Loading your group…',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (g != null) ...[
          AppCard(
            onTap: () => context.go(RoutePaths.group),
            glow: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        g.name,
                        style: AppTypography.display(
                          size: AppFontSizes.xl,
                          weight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.mutedForeground,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Member avatars overlapping row
                if (g.members.isNotEmpty) ...[
                  Row(
                    children: [
                      SizedBox(
                        height: 32,
                        width: (g.members.take(5).length * 22 + 10)
                            .toDouble()
                            .clamp(32, 130),
                        child: Stack(
                          children: [
                            for (var i = 0; i < g.members.take(5).length; i++)
                              Positioned(
                                left: i * 22.0,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.card,
                                      width: 2,
                                    ),
                                    color:
                                        AppColors.avatarPalette[(g
                                                    .members[i]
                                                    .name
                                                    .isNotEmpty
                                                ? g.members[i].name.codeUnitAt(
                                                    0,
                                                  )
                                                : 0) %
                                            AppColors.avatarPalette.length],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    g.members[i].name.isNotEmpty
                                        ? g.members[i].name[0].toUpperCase()
                                        : '?',
                                    style: AppTypography.body(
                                      size: 12,
                                      weight: FontWeight.w700,
                                    ).copyWith(color: AppColors.foreground),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${g.members.length} member${g.members.length == 1 ? '' : 's'}',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  children: [
                    Text(
                      'Join Code',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        g.joinCode,
                        style: AppTypography.mono(
                          size: AppFontSizes.sm,
                          weight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onPressed: showJoin,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 16),
                SizedBox(width: AppSpacing.xs),
                Text('Join another group'),
              ],
            ),
          ),
        ] else
          AppCard(
            color: Colors.transparent,
            borderColor: AppColors.border,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xs),
                Icon(
                  Icons.handshake_outlined,
                  size: 48,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No group yet. Join with a code or create your own.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.mutedForeground,
                  ),
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
                  Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Alerts',
                    style: AppTypography.display(
                      size: AppFontSizes.xl,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => context.go(RoutePaths.notifications),
              child: Text(
                'See all',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w500,
                ),
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
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unread[i].title,
                                style: AppTypography.bodySm.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      unread[i].type == NotificationType.game
                                          ? 'Game update'
                                          : 'Alert',
                                      style: AppTypography.bodyXs.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '· ${Formatters.relativeTime(unread[i].timestamp)}',
                                    style: AppTypography.bodyXs.copyWith(
                                      color: AppColors.mutedForeground
                                          .withValues(alpha: 0.7),
                                    ),
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
                  .slideX(
                    begin: 0.08,
                    end: 0,
                    delay: (i * 90).ms,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
          ],
        ),
      ],
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({required this.app});
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(RoutePaths.notifications),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_outlined,
              color: AppColors.foreground,
              size: 20,
            ),
            if (app.notifications.any((n) => !n.read))
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolkitCard extends StatelessWidget {
  const _ToolkitCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

