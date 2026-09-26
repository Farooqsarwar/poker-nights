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
    required this.child,
    this.maxWidth = 1280,
    this.padding,
    this.color,
    this.scrollable = true,
  });

<<<<<<< Updated upstream
  final Widget child;
=======
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
  }) : child = null,
       scrollable = true;

  final Widget? child;
  final List<Widget>? slivers;
>>>>>>> Stashed changes
  final double maxWidth;
  final EdgeInsets? padding;
  final Color? color;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final device = AppBreakpoints.deviceOf(context);
    final effectivePadding =
        padding ??
        (device.isMobile
            ? AppSpacing.mobileContentPadding
            : AppSpacing.desktopContentPadding);

    final effectiveColor = color ?? AppColors.background;

    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    if (!scrollable) {
      return ColoredBox(
        color: effectiveColor,
        child: SafeArea(
          bottom: true, 
          top: false, 
          child: Padding(padding: effectivePadding, child: content)
        ),
      );
    }

<<<<<<< Updated upstream
    return ColoredBox(
      color: effectiveColor,
      child: SafeArea(
        bottom: true, 
        top: false, 
        child: SingleChildScrollView(padding: effectivePadding, child: content)
      ),
=======
    return Scaffold(
      backgroundColor: effectiveColor,
      body: SafeArea(top: topInset, bottom: true, child: body),
>>>>>>> Stashed changes
    );
  }
}
