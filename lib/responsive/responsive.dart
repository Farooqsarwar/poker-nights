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
/// Uses flutter_screenutil for fluid sizing, clamping up-scaling on large
/// screens so desktop layouts stay proportionate. Falls back to the raw design
/// value when screenutil has not been initialized yet (e.g. isolated widget
/// tests that pump [PokerNightApp] without [ScreenUtilInit]).
class AppScale {
  AppScale._();

  static const double maxWidthScale = 1.5;
  static const double maxHeightScale = 1.5;

  /// Font sizes grow to at most [maxTextScale]x the design value.
  static const double maxTextScale = 1.35;

  static double _rawOr(double Function() compute, num value) {
    try {
      return compute();
    } catch (_) {
      return value.toDouble();
    }
  }

  static double _clamped(num value, double scaled, double maxScale) =>
      scaled > value * maxScale ? value * maxScale : scaled;

  /// Fluid width (clamped to avoid runaway growth on desktop).
  static double w(num value) => _rawOr(
        () => _clamped(value, ScreenUtil().setWidth(value), maxWidthScale),
        value,
      );

  /// Fluid height (clamped).
  static double h(num value) => _rawOr(
        () => _clamped(value, ScreenUtil().setHeight(value), maxHeightScale),
        value,
      );

  /// Fluid font size, capped at [maxScale]x the design value.
  static double sp(num value, {double maxScale = maxTextScale}) => _rawOr(
        () => _clamped(value, ScreenUtil().setSp(value), maxScale),
        value,
      );
}
