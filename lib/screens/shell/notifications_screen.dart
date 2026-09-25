import 'package:flutter/material.dart';
import '../../app/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../models/app_notification.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_eyebrow.dart';
import '../../widgets/app_page.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/page_header.dart';
import '../../widgets/prompt_link.dart';

/// Notifications mirroring the mobile-first B6 design.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  (IconTileTone, IconData) _styleFor(NotificationType type) {
    return switch (type) {
      NotificationType.game => (IconTileTone.soft, Icons.access_time),
      NotificationType.invite ||
      NotificationType.rsvp => (IconTileTone.success, Icons.person_add_alt_1),
      NotificationType.result =>
        (IconTileTone.warning, Icons.emoji_events_outlined),
      NotificationType.chat ||
      NotificationType.admin ||
      NotificationType.system =>
        (IconTileTone.neutral, Icons.chat_bubble_outline),
    };
  }

  void _openLink(BuildContext context, String? link) {
    if (link == null) return;

    // Parse link to separate path and query parameters
    final uri = Uri.tryParse(link.startsWith('/') ? link : '/$link');
    final pathOnly = uri?.path ?? link;

    final target = _routeFor(pathOnly);
    if (target == null) return;
    // For game-specific screens, ensure the current game is set in the
    // provider so the destination screen has data to display.
    const gameScreens = {
      RoutePaths.adminDashboard,
      RoutePaths.playerLive,
      RoutePaths.checkIn,
      RoutePaths.invitation,
      RoutePaths.rebuySettlement,
      RoutePaths.finalTable,
      RoutePaths.completeTournament,
      RoutePaths.resultPodium,
    };
    if (gameScreens.contains(target)) {
      final app = context.read<AppProvider>();
      final gameId = uri?.queryParameters['gameId'];

      LiveGame? gameToSet;
      if (gameId != null) {
        gameToSet = app.currentGroup.games
            .where((g) => g.id == gameId)
            .firstOrNull;
      }
      // Fallback if gameId is not found or not in link
      gameToSet ??= app.currentGroup.games
          .where((g) => g.status != LiveGameStatus.cancelled)
          .firstOrNull;

      if (gameToSet != null) app.setCurrentGame(gameToSet);
    }
    context.go(target);
  }

  String? _routeFor(String link) {
    final slug = link.replaceFirst('/', '').replaceFirst('#/', '');
    switch (slug) {
      case 'home':
        return RoutePaths.home;
      case 'group':
        return RoutePaths.group;
      case 'notifications':
        return RoutePaths.notifications;
      case 'history':
        return RoutePaths.history;
      case 'create-tournament':
        return RoutePaths.createTournament;
      case 'structure-review':
        return RoutePaths.structureReview;
      case 'invitation':
        return RoutePaths.invitation;
      case 'check-in':
        return RoutePaths.checkIn;
      case 'admin-dashboard':
        return RoutePaths.adminDashboard;
      case 'player-live':
        return RoutePaths.playerLive;
      case 'rebuy-settlement':
        return RoutePaths.rebuySettlement;
      case 'final-table':
        return RoutePaths.finalTable;
      case 'complete-tournament':
        return RoutePaths.completeTournament;
      case 'result-podium':
        return RoutePaths.resultPodium;
      case 'cash-game':
        return RoutePaths.cashGame;
      case 'cash-game-live':
        return RoutePaths.cashGameLive;
      case 'profile':
        return RoutePaths.profile;
      case 'settings':
        return RoutePaths.settings;
      case 'stats':
        return RoutePaths.stats;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final notifications = app.notifications;
    final unreadCount = notifications.where((n) => !n.read).length;
    final unreadList = notifications.where((n) => !n.read).toList();
    final readList = notifications.where((n) => n.read).toList();

    return AppPage(
      maxWidth: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.go(RoutePaths.home),
            title: 'Notifications',
            subtitle: unreadCount > 0 ? '$unreadCount unread' : null,
            titleAction: unreadCount > 0
                ? PromptLink(action: 'Mark all read', onTap: app.markAllRead)
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (notifications.isEmpty)
            const AppEmptyState(
              icon: Icons.notifications_outlined,
              title: 'No notifications yet.',
              description:
                  "You'll see game invites, RSVP updates, and announcements here.",
            )
          else ...[
            if (unreadList.isNotEmpty) ...[
              const AppEyebrow('New', muted: true),
              const SizedBox(height: AppSpacing.sm),
              for (final n in unreadList) ...[
                _NotificationCard(
                  notification: n,
                  styleInfo: _styleFor(n.type),
                  onTap: () {
                    app.markNotificationRead(n.id);
                    _openLink(context, n.link);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
            if (readList.isNotEmpty) ...[
              const AppEyebrow('Earlier', muted: true),
              const SizedBox(height: AppSpacing.sm),
              for (final n in readList) ...[
                _NotificationCard(
                  notification: n,
                  styleInfo: _styleFor(n.type),
                  onTap: () {
                    app.markNotificationRead(n.id);
                    _openLink(context, n.link);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ],
          if (notifications.isNotEmpty && unreadCount == 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: Text(
                "You're all caught up.",
                textAlign: TextAlign.center,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.styleInfo,
    required this.onTap,
  });

  final AppNotification notification;
  final (IconTileTone, IconData) styleInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    final (tone, icon) = styleInfo;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 40, tone: tone, glow: false),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: unread
                              ? AppColors.foreground
                              : AppColors.secondaryForeground,
                        ),
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 6),
                      Semantics(
                        label: 'Unread',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${notification.body} · '
                  '${Formatters.relativeTime(notification.timestamp)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (notification.link != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 6),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.onSurfaceHint,
              ),
            ),
        ],
      ),
    );
  }
}
