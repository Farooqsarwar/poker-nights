import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Device categories used across the app.
enum AppDevice { mobile, tablet, desktop, largeDesktop }

extension AppDeviceX on AppDevice {
  bool get isMobile => this == AppDevice.mobile;
  bool get isTablet => this == AppDevice.tablet;
  bool get isDesktop => this == AppDevice.desktop;
  bool get isLargeDesktop => this == AppDevice.largeDesktop;

  /// Whether this device gets the COMPACT layout: the mobile top bar, the
  /// floating bottom nav and the tighter page padding.
  ///
  /// The single source of truth for that question. [ScreenShell] and
  /// [AppPage] used to answer it independently — the shell routed tablet to
  /// the mobile chrome while the page gave tablet the desktop padding, which
  /// has no bottom-nav clearance. Between 480 and 768 logical pixels that
  /// combination put page content underneath the floating nav.
  bool get isCompact => isMobile || isTablet;
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

  /// Widths/heights may shrink a little on very narrow devices, but not without
  /// limit — below this the layout stops being a smaller layout and starts
  /// being an unusable one.
  static const double minSizeScale = 0.9;

  /// Font sizes grow to at most [maxTextScale]x the design value.
  ///
  /// Raised from 1.15: widths scale to 1.5x on a desktop, so capping text at
  /// 1.15x left type visibly lagging behind the layout it sits in — the
  /// containers grew, the words did not, and the result read as small.
  static const double maxTextScale = 1.3;

  /// Text NEVER renders below its design value.
  ///
  /// The design size is 390x844 — already a small phone. Anything smaller than
  /// the design value is smaller than the smallest screen we designed for, so
  /// there is no case where shrinking below 1.0 is the right answer.
  ///
  /// This floor exists because [ScreenUtil] is initialised with
  /// `minTextAdapt: true`, which sizes text by the SMALLER of the width and
  /// height scale factors. With an 844px design height, every viewport shorter
  /// than that shrank all app text, and the only clamp here was an upper one:
  ///
  ///   phone portrait  390x844 -> 1.00x   (fine)
  ///   laptop window  1400x700 -> 0.83x   (small)
  ///   iPhone SE       320x568 -> 0.67x   (bad)
  ///   phone landscape 844x390 -> 0.46x   (a 12px label renders at 5.5px)
  ///
  /// Landscape was the worst case and the easiest to hit: rotating the phone
  /// during a live tournament halved the size of every number on the screen.
  static const double minTextScale = 1.0;

  static double _rawOr(double Function() compute, num value) {
    try {
      return compute();
    } catch (_) {
      return value.toDouble();
    }
  }

  static double _clamped(
    num value,
    double scaled,
    double maxScale, {
    double minScale = 0,
  }) {
    final double upper = value * maxScale;
    final double lower = value * minScale;
    if (scaled > upper) return upper;
    if (scaled < lower) return lower;
    return scaled;
  }

  /// Fluid width (clamped to avoid runaway growth on desktop).
  static double w(num value) => _rawOr(
    () => _clamped(
      value,
      ScreenUtil().setWidth(value),
      maxWidthScale,
      minScale: minSizeScale,
    ),
    value,
  );

  /// Fluid height (clamped).
  static double h(num value) => _rawOr(
    () => _clamped(
      value,
      ScreenUtil().setHeight(value),
      maxHeightScale,
      minScale: minSizeScale,
    ),
    value,
  );

  /// Fluid font size, held between [minTextScale] and [maxScale] times the
  /// design value.
  static double sp(num value, {double maxScale = maxTextScale}) => _rawOr(
    () => _clamped(
      value,
      ScreenUtil().setSp(value),
      maxScale,
      minScale: minTextScale,
    ),
    value,
  );
}
