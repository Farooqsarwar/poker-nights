import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/app_notification.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';

/// Notifications mirroring the web `NotificationsPage`.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.game:
        return '🃏';
      case NotificationType.invite:
        return '📨';
      case NotificationType.rsvp:
        return '✅';
      case NotificationType.chat:
        return '💬';
      case NotificationType.admin:
        return '⚙️';
      case NotificationType.result:
        return '🏆';
      case NotificationType.system:
        return '🔔';
    }
  }

  void _openLink(BuildContext context, String? link) {
    if (link == null) return;
    final target = _routeFor(link);
    if (target != null) context.go(target);
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

    return AppPage(
      maxWidth: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: AppTypography.display(size: AppFontSizes.xxxl, weight: FontWeight.w700),
                    ),
                    if (unreadCount > 0)
                      Text(
                        '$unreadCount unread',
                        style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                      ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  onPressed: app.markAllRead,
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (notifications.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                children: [
                  const Text('🔔', style: TextStyle(fontSize: AppFontSizes.display)),
                  const SizedBox(height: AppSpacing.md),
                  Text('No notifications yet.', style: AppTypography.bodyStyle.copyWith(color: AppColors.mutedForeground)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "You'll see game invites, RSVP updates, and announcements here.",
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < notifications.length; i++)
                    _NotificationRow(
                      notification: notifications[i],
                      showDivider: i < notifications.length - 1,
                      icon: _iconFor(notifications[i].type),
                      onTap: () {
                        app.markNotificationRead(notifications[i].id);
                        _openLink(context, notifications[i].link);
                      },
                    ),
                ],
              ),
            ),
          if (notifications.isNotEmpty && unreadCount == 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Text(
                "You're all caught up.",
                textAlign: TextAlign.center,
                style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.icon,
    required this.showDivider,
    required this.onTap,
  });

  final AppNotification notification;
  final String icon;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: unread ? AppColors.primary.withValues(alpha: 0.04) : Colors.transparent,
          border: showDivider ? const Border(bottom: BorderSide(color: AppColors.border)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: unread ? AppColors.primarySoft : AppColors.muted,
                shape: BoxShape.circle,
                border: Border.all(color: unread ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: AppFontSizes.lg)),
            ),
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
                            fontWeight: FontWeight.w500,
                            color: unread ? AppColors.foreground : AppColors.mutedForeground,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.relativeTime(notification.timestamp),
                    style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            if (notification.link != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('→', style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground.withValues(alpha: 0.5))),
              ),
          ],
        ),
      ),
    );
  }
}
