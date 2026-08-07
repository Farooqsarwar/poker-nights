import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import '../responsive/responsive.dart';
import 'app_button.dart';
import 'bottom_nav.dart';
import 'nav_drawer.dart';
import 'sidebar.dart';

/// App shell that renders the persistent navigation for the four main tabs.
///
///  - Desktop (≥768px): fixed left sidebar + content.
///  - Mobile (<768px): slim top bar + content + bottom nav + slide-in drawer.
///
/// Also acts as a lightweight route guard: signed-in and data guest-less users
/// are redirected to sign-in, and a guest session is only allowed through to
/// the live-game view (checklist §6.4/§15.14).
class ScreenShell extends StatelessWidget {
  const ScreenShell({super.key, required this.child, required this.requiredPath});

  final Widget child;

  /// The route path this shell wraps (e.g. `/group`), used for access control.
  final String requiredPath;

  /// Routes a guest (no account) may access inside the shell.
  static const _guestAllowed = {RoutePaths.playerLive};

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final signedIn = app.isAuthenticated;
    final guestOk = app.hasGuestSession && _guestAllowed.contains(requiredPath);

    // Route guard: block access when the user cannot enter this path.
    if (!signedIn && !guestOk) {
      return _Gate(path: requiredPath);
    }

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

/// Shown when a user (or guest) lands on a route they can't access — the
/// effective route guard. Offers a way back to sign-in or the live game.
class _Gate extends StatelessWidget {
  const _Gate({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_outline, size: 40, color: AppColors.mutedForeground),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Signed out',
                  textAlign: TextAlign.center,
                  style: AppTypography.display(size: AppFontSizes.xl),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This page needs a signed-in account. Guests can only watch the live game.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  fullWidth: true,
                  onPressed: () => context.go('${RoutePaths.login}?next=$path'),
                  child: const Text('Sign in'),
                ),
                AppButton(
                  fullWidth: true,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => context.go(RoutePaths.landing),
                  child: const Text('Back to start'),
                ),
              ],
            ),
          ),
        ),
      ),
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