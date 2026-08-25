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

  final Widget child;
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
        child: Padding(padding: effectivePadding, child: content),
      );
    }

    return ColoredBox(
      color: effectiveColor,
      child: SingleChildScrollView(padding: effectivePadding, child: content),
    );
  }
}
