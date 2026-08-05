import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import '../responsive/responsive.dart';
import 'bottom_nav.dart';
import 'nav_drawer.dart';
import 'sidebar.dart';

/// App shell that renders the persistent navigation for the four main tabs.
///
///  - Desktop (≥768px): fixed left sidebar + content.
///  - Mobile (<768px): slim top bar + content + bottom nav + slide-in drawer.
class ScreenShell extends StatelessWidget {
  const ScreenShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, device) {
        if (device.isMobile || device.isTablet) {
          return _MobileShell(child: child);
        }
        return Scaffold(
          body: Row(
            children: [
              const Sidebar(),
              const VerticalDivider(width: 1, color: AppColors.border),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              _MobileTopBar(onMenu: app.toggleDrawer),
              Expanded(child: child),
            ],
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: BottomNav()),
          const NavDrawer(),
        ],
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      color: AppColors.card,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: onMenu,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
                child: Icon(Icons.menu, color: AppColors.foreground, size: 22),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(AppAssets.spade, style: AppTypography.body(size: AppFontSizes.lg)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Poker Night',
              style: AppTypography.crimsonShimmer(size: AppFontSizes.md, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
