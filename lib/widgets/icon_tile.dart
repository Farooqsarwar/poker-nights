import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';

enum IconTileTone { primary, soft, success, danger, warning, neutral }

/// Rounded square carrying a glyph, an icon, initials or a small widget —
/// the redesign's crimson ♠ tile (A6/A7), the group-initials tile (A8), and
/// the tinted icon tiles on notifications, tools and state cards.
///
/// Exactly one of [icon], [label] or [child] should be given.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    this.icon,
    this.label,
    this.child,
    this.size = 56,
    this.tone = IconTileTone.primary,
    this.glow,
    this.semanticLabel,
  });

  final IconData? icon;

  /// Text content — a glyph such as '♠' or initials such as 'FP'.
  final String? label;
  final Widget? child;
  final double size;
  final IconTileTone tone;

  /// Accent glow beneath the tile. Defaults to on for [IconTileTone.primary].
  final bool? glow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final (fill, border, fg) = switch (tone) {
      IconTileTone.primary => (
        AppColors.primary,
        Colors.white.withValues(alpha: 0.10),
        AppColors.primaryForeground,
      ),
      IconTileTone.soft => (
        AppColors.primarySoft,
        AppColors.primarySoftBorder,
        AppColors.primaryText,
      ),
      IconTileTone.success => (
        AppColors.successSoft,
        AppColors.successSoftBorder,
        AppColors.successText,
      ),
      IconTileTone.danger => (
        AppColors.destructiveSoft,
        AppColors.destructive.withValues(alpha: 0.30),
        AppColors.destructiveText,
      ),
      IconTileTone.warning => (
        AppColors.warningSoft,
        AppColors.warningSoftBorder,
        AppColors.warningText,
      ),
      IconTileTone.neutral => (
        AppColors.muted,
        AppColors.border.withValues(alpha: 0.75),
        AppColors.mutedForeground,
      ),
    };
    final showGlow = glow ?? tone == IconTileTone.primary;

    final Widget content;
    if (child != null) {
      content = IconTheme.merge(
        data: IconThemeData(color: fg, size: size * 0.46),
        child: child!,
      );
    } else if (icon != null) {
      content = Icon(icon, size: size * 0.46, color: fg);
    } else {
      content = Text(
        label ?? '',
        style: AppTypography.display(
          size: size * 0.40,
          weight: FontWeight.w700,
          color: fg,
          height: 1.0,
          letterSpacing: 0,
        ),
      );
    }

    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(size * 0.26),
          border: Border.all(color: border),
          boxShadow: showGlow
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: size * 0.55,
                    spreadRadius: -size * 0.10,
                    offset: Offset(0, size * 0.10),
                  ),
                ]
              : null,
        ),
        child: content,
      ),
    );
  }
}
