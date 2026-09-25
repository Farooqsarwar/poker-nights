import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../models/app_notification.dart';
import '../../models/live_game.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_page.dart';

/// Notifications mirroring the mobile-first B6 design.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  (Color, Color, IconData) _styleFor(NotificationType type) {
    switch (type) {
      case NotificationType.game:
        return (
          const Color(0xFF381E20),
          const Color(0xFFD53032),
          Icons.access_time,
        );
      case NotificationType.invite:
      case NotificationType.rsvp:
        return (
          const Color(0xFF1F3826),
          const Color(0xFF4ADE80),
          Icons.person_add_alt_1,
        );
      case NotificationType.result:
        return (
          const Color(0xFF261C0D),
          const Color(0xFFF59E0B),
          Icons.emoji_events_outlined,
        );
      case NotificationType.chat:
      case NotificationType.admin:
      case NotificationType.system:
        return (
          const Color(0xFF1E2024),
          const Color(0xFF8E8E93),
          Icons.chat_bubble_outline,
        );
    }
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
          // Top bar: Squircle back button <, Title with unread count, Mark all read action
          Row(
            children: [
              InkWell(
                onTap: () => context.go(RoutePaths.home),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF242428)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Notifications',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2024),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unreadCount unread',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (unreadCount > 0)
                InkWell(
                  onTap: app.markAllRead,
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      color: Color(0xFFE5797A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (notifications.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF242428)),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    size: 48,
                    color: Color(0xFF8E8E93),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "You'll see game invites, RSVP updates, and announcements here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                  ),
                ],
              ),
            )
          else ...[
            if (unreadList.isNotEmpty) ...[
              const Text(
                'NEW',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              for (final n in unreadList) ...[
                _NotificationCard(
                  notification: n,
                  styleInfo: _styleFor(n.type),
                  onTap: () {
                    app.markNotificationRead(n.id);
                    _openLink(context, n.link);
                  },
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
            ],
            if (readList.isNotEmpty) ...[
              const Text(
                'EARLIER',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              for (final n in readList) ...[
                _NotificationCard(
                  notification: n,
                  styleInfo: _styleFor(n.type),
                  onTap: () {
                    app.markNotificationRead(n.id);
                    _openLink(context, n.link);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
          if (notifications.isNotEmpty && unreadCount == 0)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                "You're all caught up.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
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
  final (Color, Color, IconData) styleInfo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;
    final (bgColor, iconColor, icon) = styleInfo;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF242428)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: unread
                                ? Colors.white
                                : const Color(0xFFD1D1D6),
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD53032),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.relativeTime(notification.timestamp),
                    style: const TextStyle(
                      color: Color(0xFF636366),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (notification.link != null)
              const Padding(
                padding: EdgeInsets.only(top: 2, left: 6),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFF636366),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
