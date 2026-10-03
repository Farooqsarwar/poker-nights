import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import '../responsive/responsive.dart';
import 'glass_styles.dart';
import 'app_avatar.dart';
import 'app_button.dart';
import 'bottom_nav.dart';
import 'brand_lockup.dart';
import 'connection_banner.dart';
import 'min_tap_target.dart';
import 'nav_drawer.dart';
import 'shell_insets.dart';
import 'sidebar.dart';
import 'backgrounds.dart';

/// App shell that renders the persistent navigation for the four main tabs.
///
///  - Desktop (≥768px): fixed left sidebar + content.
///  - Mobile (<768px): slim top bar + content + bottom nav + slide-in drawer.
///
/// Also acts as a lightweight route guard: signed-in and data guest-less users
/// are redirected to sign-in, and a guest session is only allowed through to
/// the live-game view (checklist §6.4/§15.14).
class ScreenShell extends StatelessWidget {
  const ScreenShell({
    super.key,
    required this.child,
    required this.requiredPath,
  });

  final Widget child;

  /// The route path this shell wraps (e.g. `/group`), used for access control.
  final String requiredPath;

  /// Routes a guest (no account) may access inside the shell.
  ///
  /// C4p (`/t/:id/me`) rides along: a link guest opens their own check-in
  /// (GuestFlowScreen) in this minimal shell, never the member invitation.
  static const guestAllowed = {
    RoutePaths.playerLive,
    RoutePaths.resultPodium,
    RoutePaths.invitation,
    RoutePaths.hostDashboard,
    RoutePaths.structureReview,
    RoutePaths.deal,
    RoutePaths.completeTournament,
  };

  /// Routes that open for a signed-out visitor (Build Spec C3): the quick
  /// start creates its own anonymous session, and the invite link previews the
  /// group before anyone signs in. They draw their own header, so a signed-out
  /// visitor gets the page with no navigation chrome.
  static const _openToSignedOut = {RoutePaths.quick, RoutePaths.joinGroup};

  static void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Leave live game?',
          style: AppTypography.display(
            size: AppFontSizes.lg,
            weight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Your game will continue running on this device. You can create an account to save your results permanently, or exit.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              GoRouter.of(context).go(RoutePaths.register);
            },
            child: const Text('Create account'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              GoRouter.of(context).go(RoutePaths.landing);
            },
            child: Text(
              'Exit to start',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRegisteredUser = context.select<AppProvider, bool>(
      (a) => a.isAuthenticated && !a.isGuest,
    );
    final isGuest = context.select<AppProvider, bool>(
      (a) => a.isGuest || a.hasGuestSession,
    );

    if (!isRegisteredUser && _openToSignedOut.contains(requiredPath)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: ThemedAppBackground(child: SafeArea(child: child)),
      );
    }
    final guestOk = isGuest && guestAllowed.contains(requiredPath);

    // Route guard: block access when the user cannot enter this path.
    if (!isRegisteredUser && !guestOk) {
      return _Gate(path: requiredPath);
    }

    // Guests get a minimal scaffold: no member bottom nav, no group drawer,
    // and no member desktop sidebar (Spec §A2b, §C4).
    if (!isRegisteredUser && guestOk) {
      final isDashboard = requiredPath == RoutePaths.hostDashboard;
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: isDashboard
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Exit',
                  onPressed: () {
                    final app = context.read<AppProvider>();
                    if (app.isGuest &&
                        app.currentGame?.status.isActiveLive == true) {
                      _showExitDialog(context);
                    } else {
                      GoRouter.of(context).go(RoutePaths.landing);
                    }
                  },
                ),
              ),
        body: ThemedAppBackground(child: child),
      );
    }

    return ResponsiveBuilder(
      builder: (context, device) {
        if (device.isCompact) {
          return _MobileShell(requiredPath: requiredPath, child: child);
        }
        return Scaffold(
          backgroundColor: Colors.transparent, // Background provided by ThemedAppBackground
          body: ThemedAppBackground(
            child: Row(
              children: [
                const Sidebar(),
                VerticalDivider(width: 1, color: AppColors.border),
                // Tell dialogs how much chrome sits to their left, so they
                // centre over the CONTENT rather than over the window — see
                // ShellInsets.
                Expanded(
                  child: ShellInsets(
                    left: kSidebarWidth + 1,
                    child: Column(
                      children: [
                        const ConnectionBanner(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            0,
                          ),
                        ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    final app = context.watch<AppProvider>();
    final hasActiveGame = app.currentGame?.status.isActiveLive == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemedAppBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    app.isGuest ? 'Account needed' : 'Signed out',
                    textAlign: TextAlign.center,
                    style: AppTypography.display(size: AppFontSizes.xl),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    app.isGuest
                        ? 'To create groups, join group chat, and view club standings, create a free account.'
                        : 'This page needs a signed-in account. Guests can only watch or run the live game.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    fullWidth: true,
                    onPressed: () => context.go(RoutePaths.register),
                    child: const Text('Create account'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (hasActiveGame) ...[
                    AppButton(
                      fullWidth: true,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => context.go(
                        app.isAdmin ? RoutePaths.hostDashboard : RoutePaths.playerLive,
                      ),
                      child: const Text('Return to live game'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
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
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.child, required this.requiredPath});

  final Widget child;
  final String requiredPath;

  static const _hasCustomTopBarPaths = {
    RoutePaths.home,
    RoutePaths.group,
    RoutePaths.chat,
    RoutePaths.members,
    RoutePaths.polls,
    RoutePaths.reports,
    RoutePaths.notifications,
    RoutePaths.history,
    RoutePaths.joinGroup,
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hasCustomBar = _hasCustomTopBarPaths.contains(requiredPath);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ThemedAppBackground(
        child: Stack(
          children: [
            Column(
              children: [
                if (!hasCustomBar) _MobileTopBar(onMenu: app.toggleDrawer),
                const ConnectionBanner(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                ),
                Expanded(
                  // The bottom nav floats over the content, so give every
                  // screen clearance equal to the nav's own height plus the
                  // device inset, and nothing — like a chat composer — hides
                  // behind it. This is the ONLY place that clearance is
                  // added; `AppSpacing.mobileContentPadding` deliberately
                  // stays a plain page padding.
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: kBottomNavHeight + bottomInset,
                    ),
                    child: hasCustomBar
                        ? SafeArea(bottom: false, child: child)
                        : child,
                  ),
                ),
              ],
            ),
            const Positioned(left: 0, right: 0, bottom: 0, child: BottomNav()),
            const NavDrawer(),
          ],
        ),
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: Glass.blurMedium,
          sigmaY: Glass.blurMedium,
        ),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          decoration: Glass.glassTopBar(),
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Semantics(
                    label: 'Open navigation menu',
                    button: true,
                    child: InkWell(
                      onTap: onMenu,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: MinTapTarget(
                        child: Icon(
                          Icons.menu,
                          color: AppColors.foreground,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const PokerNightBrand(
                    logoSize: 22,
                    fontSize: 16,
                  ),
                  const Spacer(),
                  const SizedBox(width: AppSpacing.sm),
                  if (user != null)
                    Semantics(
                      label: 'Your profile, ${user.name}',
                      button: true,
                      child: InkWell(
                        onTap: () => context.go(RoutePaths.profile),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: MinTapTarget(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: AppAvatar(name: user.name),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

  }
}
