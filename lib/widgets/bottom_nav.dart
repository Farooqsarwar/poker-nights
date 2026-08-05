import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';

/// Mobile bottom navigation mirroring the web `Nav` bottom bar.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final location = GoRouterState.of(context).uri.path;
    final unread = app.unreadCount;

    final items = [
      _BottomItem(RoutePaths.home, 'Home', Icons.home_outlined, null),
      _BottomItem(RoutePaths.group, app.currentGroup.name, Icons.groups_outlined, null),
      _BottomItem(RoutePaths.notifications, 'Alerts', Icons.notifications_none, unread),
      _BottomItem(RoutePaths.history, 'History', Icons.history, null),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: InkWell(
                  onTap: () => context.go(item.path),
                  child: SizedBox(
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 24,
                              color: location == item.path
                                  ? AppColors.primary
                                  : AppColors.mutedForeground,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyXs.copyWith(
                                color: location == item.path
                                    ? AppColors.primary
                                    : AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        if (item.badge != null && item.badge! > 0)
                          Positioned(
                            top: 6,
                            right: 24,
                            child: Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                item.badge! > 9 ? '9+' : '${item.badge}',
                                style: AppTypography.monoXs.copyWith(
                                  color: AppColors.primaryForeground,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem {
  const _BottomItem(this.path, this.label, this.icon, this.badge);

  final String path;
  final String label;
  final IconData icon;
  final int? badge;
}
