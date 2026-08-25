import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';

/// Centralized glassmorphism design tokens.
///
/// Provides reusable decorations, shadows, and gradient helpers that layer
/// frosted-glass effects on top of the existing palette. Every token reads
/// from [AppColors] so it automatically follows the active [ThemePalette].
class Glass {
  Glass._();

  // ── Surface opacities ────────────────────────────────────────────────────
  /// Primary card / panel background opacity (lowered for more theme bleed).
  static double get surfaceOpacity => 0.40;
  /// Secondary / nested panel opacity.
  static double get surfaceSecondaryOpacity => 0.25;
  /// Sidebar / nav rail opacity.
  static double get navOpacity => 0.55;
  /// Bottom navigation opacity.
  static double get bottomNavOpacity => 0.55;
  /// Modal / dialog surface opacity.
  static double get modalOpacity => 0.65;
  /// Input / select field opacity.
  static double get inputOpacity => 0.35;
  /// Badge / chip opacity.
  static double get badgeOpacity => 0.25;
  /// Small control (toggle) opacity.
  static double get controlOpacity => 0.20;
  /// Top-bar / app-bar opacity.
  static double get topBarOpacity => 0.55;
  /// Tab bar surface opacity.
  static double get tabBarOpacity => 0.30;

  // ── Blur radii ───────────────────────────────────────────────────────────
  /// Light blur for small surfaces (badges, chips, tab underlines).
  static double get blurLight => 8.0;
  /// Medium blur for cards and panels.
  static double get blurMedium => 18.0;
  /// Heavy blur for large surfaces (sidebar, modals, top bar).
  static double get blurHeavy => 28.0;
  /// Extra-heavy blur for backdrops (modal overlays).
  static double get blurXHeavy => 40.0;

  // ── Border opacity ───────────────────────────────────────────────────────
  /// Subtle frosted border for glass surfaces (reduced for cleaner look).
  static double get borderOpacity => 0.08;
  /// Active / highlighted border.
  static double get borderActiveOpacity => 0.18;
  /// Inner highlight opacity (reduced to prevent milky wash).
  static double get highlightOpacity => 0.04;
  /// Inner highlight at the very top — slightly stronger for depth.
  static double get highlightTopOpacity => 0.10;

  // ── Shadow helpers ───────────────────────────────────────────────────────

  /// Default card-level glass shadow.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.05),
      blurRadius: 48,
      offset: const Offset(0, 4),
    ),
  ];

  /// Elevated card / hover shadow.
  static List<BoxShadow> get cardElevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.55),
      blurRadius: 40,
      offset: const Offset(0, 20),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.10),
      blurRadius: 56,
      offset: const Offset(0, 8),
    ),
  ];

  /// Primary button glow shadow.
  static List<BoxShadow> get primaryGlow => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.32),
      blurRadius: 22,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.12),
      blurRadius: 44,
    ),
  ];

  /// Subtle neumorphic shadow for small controls.
  static List<BoxShadow> get neumorphicUp => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.32),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.05),
      blurRadius: 6,
      offset: const Offset(0, -1),
    ),
  ];

  /// Inset neumorphic shadow for pressed state.
  static List<BoxShadow> get neumorphicDown => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.42),
      blurRadius: 10,
      offset: const Offset(0, 2),
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, -1),
    ),
  ];

  /// Sidebar / nav panel shadow.
  static List<BoxShadow> get navShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 32,
      offset: const Offset(6, 0),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.05),
      blurRadius: 60,
    ),
  ];

  /// Bottom navigation shadow.
  static List<BoxShadow> get bottomNavShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, -4),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.08),
      blurRadius: 40,
      offset: const Offset(0, -2),
    ),
  ];

  /// Modal / dialog shadow.
  static List<BoxShadow> get modalShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 48,
      offset: const Offset(0, 20),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.10),
      blurRadius: 72,
      offset: const Offset(0, 10),
    ),
  ];

  /// Top bar / app bar shadow.
  static List<BoxShadow> get topBarShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.05),
      blurRadius: 40,
      offset: const Offset(0, 2),
    ),
  ];

  /// Active-player / focus ring glow.
  static List<BoxShadow> glowFor(Color color, {double intensity = 1.0}) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25 * intensity),
      blurRadius: 20,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.08 * intensity),
      blurRadius: 40,
    ),
  ];

  // ── Gradient helpers ─────────────────────────────────────────────────────

  /// Subtle top-down inner highlight for glass surfaces.
  static LinearGradient get innerHighlight => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.white.withValues(alpha: highlightTopOpacity),
      Colors.white.withValues(alpha: 0.02),
      Colors.transparent,
    ],
    stops: const [0.0, 0.15, 0.45],
  );

  /// Strong top-left corner sheen for elevated glass surfaces.
  static LinearGradient get sheenHighlight => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: highlightTopOpacity),
      Colors.white.withValues(alpha: 0.03),
      Colors.transparent,
    ],
    stops: const [0.0, 0.2, 0.5],
  );

  /// Primary-tinted ambient gradient (bottom-left glow).
  static RadialGradient get ambientGlow => RadialGradient(
    center: const Alignment(-0.8, 0.9),
    radius: 1.2,
    colors: [
      AppColors.primary.withValues(alpha: 0.10),
      Colors.transparent,
    ],
  );

  /// Subtle gradient overlay using primary color for hover / focus.
  static LinearGradient get primarySheen => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primary.withValues(alpha: 0.12),
      Colors.transparent,
      AppColors.primary.withValues(alpha: 0.05),
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  /// Subtle horizontal gradient for top-bar surface.
  static LinearGradient topBarGradient() => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.card.withValues(alpha: topBarOpacity + 0.05),
      AppColors.card.withValues(alpha: topBarOpacity),
    ],
  );

  // ── Decoration builders ──────────────────────────────────────────────────

  /// Primary glass surface decoration (cards, panels).
  static BoxDecoration glassCard({Color? color, Color? borderColor}) {
    return BoxDecoration(
      color: (color ?? AppColors.card).withValues(alpha: surfaceOpacity),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: (borderColor ?? AppColors.border)
            .withValues(alpha: borderOpacity),
      ),
      boxShadow: cardShadow,
      gradient: innerHighlight,
    );
  }

  /// Sidebar / navigation panel glass decoration.
  static BoxDecoration glassNav() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.card.withValues(alpha: navOpacity + 0.05),
          AppColors.card.withValues(alpha: navOpacity - 0.05),
        ],
      ),
      border: Border(
        right: BorderSide(
          color: AppColors.border.withValues(alpha: borderOpacity),
        ),
      ),
      boxShadow: navShadow,
    );
  }

  /// Bottom navigation glass decoration.
  static BoxDecoration glassBottomNav() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.card.withValues(alpha: bottomNavOpacity - 0.05),
          AppColors.card.withValues(alpha: bottomNavOpacity),
        ],
      ),
      border: Border(
        top: BorderSide(
          color: AppColors.primary.withValues(alpha: borderOpacity * 0.6),
        ),
      ),
      boxShadow: bottomNavShadow,
    );
  }

  /// Mobile top-bar glass decoration.
  static BoxDecoration glassTopBar() {
    return BoxDecoration(
      gradient: topBarGradient(),
      border: Border(
        bottom: BorderSide(
          color: AppColors.primary.withValues(alpha: borderOpacity * 0.8),
        ),
      ),
      boxShadow: topBarShadow,
    );
  }

  /// Modal / dialog glass surface.
  static BoxDecoration glassModal() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.card.withValues(alpha: modalOpacity),
          AppColors.card.withValues(alpha: modalOpacity - 0.08),
        ],
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: borderActiveOpacity * 0.6),
      ),
      boxShadow: modalShadow,
    );
  }

  /// Input / select field glass surface.
  static BoxDecoration glassInput({bool focused = false, bool hasError = false}) {
    final borderColor = hasError
        ? AppColors.destructive.withValues(alpha: 0.70)
        : focused
            ? AppColors.ring.withValues(alpha: 0.80)
            : AppColors.border.withValues(alpha: borderOpacity + 0.06);
    return BoxDecoration(
      color: AppColors.card.withValues(alpha: inputOpacity),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: borderColor),
      boxShadow: focused
          ? [
              BoxShadow(
                color: AppColors.ring.withValues(alpha: 0.10),
                blurRadius: 12,
                spreadRadius: -1,
              ),
              ...neumorphicUp,
            ]
          : neumorphicUp,
      gradient: innerHighlight,
    );
  }

  /// Badge / chip glass surface.
  static BoxDecoration glassBadge({Color? tint}) {
    return BoxDecoration(
      color: (tint ?? AppColors.primary).withValues(alpha: badgeOpacity),
      borderRadius: BorderRadius.circular(AppRadius.xs),
      border: Border.all(
        color: (tint ?? AppColors.primary)
            .withValues(alpha: borderActiveOpacity),
      ),
      boxShadow: [
        BoxShadow(
          color: (tint ?? AppColors.primary).withValues(alpha: 0.10),
          blurRadius: 8,
        ),
      ],
    );
  }

  /// Pill button glass (primary variant).
  static BoxDecoration glassButtonPrimary() {
    return BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.14),
      ),
      boxShadow: primaryGlow,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.14),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.08),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }

  /// Ghost / secondary button glass.
  static BoxDecoration glassButtonSecondary() {
    return BoxDecoration(
      color: AppColors.card.withValues(alpha: surfaceSecondaryOpacity),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(
        color: AppColors.border.withValues(alpha: borderOpacity),
      ),
      boxShadow: neumorphicUp,
      gradient: innerHighlight,
    );
  }

  /// Danger button glass.
  static BoxDecoration glassButtonDanger() {
    return BoxDecoration(
      color: AppColors.destructive.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(
        color: AppColors.destructive.withValues(alpha: borderActiveOpacity),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.destructive.withValues(alpha: 0.10),
          blurRadius: 12,
        ),
      ],
    );
  }

  /// Toggle track glass.
  static BoxDecoration glassToggle({required bool active}) {
    return BoxDecoration(
      color: active
          ? AppColors.primary.withValues(alpha: 0.85)
          : AppColors.border.withValues(alpha: controlOpacity),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(
        color: active
            ? Colors.white.withValues(alpha: 0.18)
            : AppColors.border.withValues(alpha: borderOpacity),
      ),
      boxShadow: active ? primaryGlow : neumorphicUp,
      gradient: active
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.transparent,
              ],
            )
          : null,
    );
  }

  /// Toggle thumb glass.
  static BoxDecoration glassToggleThumb() {
    return BoxDecoration(
      color: AppColors.foreground,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.12),
          blurRadius: 3,
          offset: const Offset(0, -0.5),
        ),
      ],
    );
  }

  /// Active navigation item glass highlight.
  static BoxDecoration glassNavActive() {
    return BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: borderActiveOpacity),
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6],
      ),
    );
  }

  /// Avatar ring glass.
  static BoxDecoration glassAvatarRing({required Color accent}) {
    return BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: accent.withValues(alpha: borderActiveOpacity + 0.10),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.22),
          blurRadius: 14,
        ),
      ],
    );
  }

  /// Divider glass (subtle gradient line).
  static BoxDecoration glassDivider() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.border.withValues(alpha: borderOpacity),
          AppColors.primary.withValues(alpha: 0.07),
          AppColors.border.withValues(alpha: borderOpacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ),
    );
  }

  /// Quick-action pill glass.
  static BoxDecoration glassPill() {
    return BoxDecoration(
      color: AppColors.card.withValues(alpha: surfaceSecondaryOpacity),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(
        color: AppColors.border.withValues(alpha: borderOpacity),
      ),
      boxShadow: neumorphicUp,
      gradient: innerHighlight,
    );
  }

  /// Group row glass.
  static BoxDecoration glassGroupRow({required bool selected}) {
    return BoxDecoration(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.card.withValues(alpha: surfaceSecondaryOpacity),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color: selected
            ? AppColors.primary.withValues(alpha: borderActiveOpacity)
            : AppColors.border.withValues(alpha: borderOpacity),
      ),
      boxShadow: selected
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                spreadRadius: -2,
              ),
            ]
          : null,
      gradient: selected
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            )
          : null,
    );
  }

  /// Notification badge pill.
  static BoxDecoration glassNotificationBadge() {
    return BoxDecoration(
      color: AppColors.primary,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.45),
          blurRadius: 10,
          spreadRadius: -1,
        ),
      ],
    );
  }

  /// Tab indicator bar decoration.
  static BoxDecoration glassTabIndicator() {
    return BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(2),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.55),
          blurRadius: 8,
          spreadRadius: -1,
        ),
      ],
    );
  }

  /// Tab bar container decoration.
  static BoxDecoration glassTabBar() {
    return BoxDecoration(
      color: AppColors.card.withValues(alpha: tabBarOpacity),
      border: Border(
        bottom: BorderSide(
          color: AppColors.border.withValues(alpha: borderOpacity),
        ),
      ),
    );
  }
}
