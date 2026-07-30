import 'package:flutter/material.dart';

class PNResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const PNResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 800 && desktop != null) {
          return desktop!;
        }
        if (constraints.maxWidth >= 451 && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}

class PNAdaptivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? mobilePadding;
  final EdgeInsetsGeometry? tabletPadding;
  final EdgeInsetsGeometry? desktopPadding;

  const PNAdaptivePadding({
    super.key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        EdgeInsetsGeometry padding;
        if (constraints.maxWidth >= 800) {
          padding = desktopPadding ?? const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
        } else if (constraints.maxWidth >= 451) {
          padding = tabletPadding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
        } else {
          padding = mobilePadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
        }
        return Padding(padding: padding, child: child);
      },
    );
  }
}


