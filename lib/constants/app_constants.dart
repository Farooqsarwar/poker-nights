import 'package:flutter/material.dart';

/// Centralized spacing scale (mirrors Tailwind spacing).
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double page = 24;
  static const double section = 32;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: xl,
  );

  static const EdgeInsets mobileContentPadding = EdgeInsets.only(
    left: lg,
    right: lg,
    top: lg,
    bottom: 96,
  );

  static const EdgeInsets desktopContentPadding = EdgeInsets.only(
    left: xxl,
    right: xxl,
    top: xxl,
    bottom: xxl,
  );
}

/// Centralized border radius scale (mirrors Tailwind radius utilities).
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 6; // rounded-md
  static const double md = 8; // rounded-lg
  static const double lg = 12; // rounded-xl
  static const double xl = 16; // rounded-2xl
  static const double pill = 999;
}

/// Centralized shadows (mirrors .card-glow / .card-glow-active / glass).
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> cardGlow = [
    BoxShadow(
      color: Color(0x1A7F1D1D),
      blurRadius: 1,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 24,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardGlowActive = [
    BoxShadow(
      color: Color(0x667F1D1D),
      blurRadius: 1,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x1F7F1D1D),
      blurRadius: 32,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> glassPanel = [
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x337F1D1D),
      blurRadius: 15,
    ),
  ];

  static const List<BoxShadow> successGlow = [
    BoxShadow(
      color: Color(0x26166534),
      blurRadius: 20,
    ),
  ];

  static const List<BoxShadow> softCard = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];
}

/// Centralized motion durations.
class AppDurations {
  AppDurations._();

  static const Duration fastest = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

/// Centralized font sizes (Tailwind text scale).
class AppFontSizes {
  AppFontSizes._();

  static const double xs = 12;
  static const double sm = 14;
  static const double md = 16;
  static const double lg = 18;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 30;
  static const double display = 36;
  static const double displayLg = 48;
  static const double displayXl = 60;
  static const double displayHero = 72;
}

/// Centralized asset paths.
class AppAssets {
  AppAssets._();

  static const String spade = '♠';
  static const String heart = '♥';
  static const String diamond = '♦';
  static const String club = '♣';

  static const String demoCode = 'FP2608';
  static const String demoGroupCode = 'FRIDAY7';
  static const String demoTvCode = 'TV-FP';
}
