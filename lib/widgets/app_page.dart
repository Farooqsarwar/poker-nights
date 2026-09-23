import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../responsive/responsive.dart';

/// Standard scrollable page container.
///
/// Mirrors the web `max-w-screen-xl mx-auto` wrapper plus responsive padding.
/// Content is centered with a max width so desktop stays readable.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required Widget this.child,
    this.maxWidth = 1280,
    this.padding,
    this.color,
    this.scrollable = true,
    this.topInset = false,
  }) : slivers = null;

  /// Same page chrome — padding, max width, safe area — but the content is a
  /// sliver list, so off-screen rows are never built.
  ///
  /// Use this when a list has no upper bound (game history, cash sessions).
  /// The default [AppPage] puts its child in a `SingleChildScrollView`, which
  /// builds and lays out every row whether or not it is on screen; on a group
  /// with a few hundred past games that is the whole list on every rebuild.
  ///
  /// `shrinkWrap: true` is NOT the shortcut it looks like — inside a scroll
  /// view it still builds every child in order to measure them, so it buys
  /// the sliver's awkwardness with none of its benefit.
  const AppPage.slivers({
    super.key,
    required List<Widget> this.slivers,
    this.maxWidth = 1280,
    this.padding,
    this.color,
    this.topInset = false,
  })  : child = null,
        scrollable = true;

  final Widget? child;
  final List<Widget>? slivers;
  final double maxWidth;
  final EdgeInsets? padding;
  final Color? color;
  final bool scrollable;

  /// Whether this page must reserve the status-bar / notch inset itself.
  ///
  /// Defaults to false because the common case is a page inside `ScreenShell`,
  /// whose top bar already consumes that inset — reserving it twice leaves a
  /// visible gap under the bar. Pages rendered OUTSIDE the shell (the public
  /// tools, landing, guest flow, TV mode) have no such bar, so they must opt
  /// in or their first line of content renders underneath the status bar.
  final bool topInset;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final device = AppBreakpoints.deviceOf(context);
    // `isCompact`, not `isMobile`: the shell gives every compact device the
    // mobile chrome, so the padding has to agree with it or tablet-width
    // screens get desktop insets under a mobile layout.
    final effectivePadding =
        padding ??
        (device.isCompact
            ? AppSpacing.mobileContentPadding
            : AppSpacing.desktopContentPadding);

    final effectiveColor = color ?? AppColors.background;

    final Widget body;
    if (slivers != null) {
      // The max-width clamp wraps the scroll view rather than sitting inside
      // it, because a sliver list cannot be centred by a box widget the way
      // the single-child case is.
      body = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: effectivePadding,
                sliver: SliverMainAxisGroup(slivers: slivers!),
              ),
            ],
          ),
        ),
      );
    } else {
      final content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
      body = scrollable
          ? SingleChildScrollView(padding: effectivePadding, child: content)
          : Padding(padding: effectivePadding, child: content);
    }

    return ColoredBox(
      color: effectiveColor,
      child: SafeArea(top: topInset, bottom: true, child: body),
    );
  }
}
