import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Device categories used across the app.
enum AppDevice { mobile, tablet, desktop, largeDesktop }

extension AppDeviceX on AppDevice {
  bool get isMobile => this == AppDevice.mobile;
  bool get isTablet => this == AppDevice.tablet;
  bool get isDesktop => this == AppDevice.desktop;
  bool get isLargeDesktop => this == AppDevice.largeDesktop;
}

/// Breakpoint-aware helpers.
class AppBreakpoints {
  AppBreakpoints._();

  /// Tailwind `md:` threshold — sidebar switches on/off here.
  static const double tablet = 480;
  static const double desktop = 768;
  static const double largeDesktop = 1200;

  static AppDevice deviceOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > largeDesktop) return AppDevice.largeDesktop;
    if (width > desktop) return AppDevice.desktop;
    if (width > tablet) return AppDevice.tablet;
    return AppDevice.mobile;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  static bool isLarge(BuildContext context) =>
      MediaQuery.sizeOf(context).width > largeDesktop;
}

/// LayoutBuilder-driven responsive builder.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, AppDevice device) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final device = width > AppBreakpoints.largeDesktop
            ? AppDevice.largeDesktop
            : width > AppBreakpoints.desktop
                ? AppDevice.desktop
                : width > AppBreakpoints.tablet
                    ? AppDevice.tablet
                    : AppDevice.mobile;
        return builder(context, device);
      },
    );
  }
}

/// Scaled spacing/text helpers.
///
/// Keeps pixel-perfect sizes on mobile and clamps up-scaling on large
/// screens so desktop layouts stay proportionate (uses flutter_screenutil).
class AppScale {
  AppScale._();

  static double _clamp(double value) => value > 1.5 ? 1.5 : value;

  /// Fluid width (clamped to avoid runaway growth on desktop).
  static double w(num value) => ScreenUtil().setWidth(value) * _clamp(1);

  /// Fluid height (clamped).
  static double h(num value) => ScreenUtil().setHeight(value);

  /// Fluid font size, capped at [maxScale]x the design value.
  static double sp(num value, {double maxScale = 1.35}) {
    final scaled = ScreenUtil().setSp(value);
    final cap = value * maxScale;
    return scaled > cap ? cap : scaled;
  }
}
