import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';
import 'interactive_scale.dart';

/// Button mirroring the web `Btn` component.
enum AppButtonVariant { primary, secondary, danger, ghost, gold, light, destructive }

enum AppButtonSize { sm, md, lg, xl }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.width,
    this.disabled = false,
    this.loading = false,
    this.fullWidth = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final double? width;
  final bool disabled;
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !disabled && !loading && onPressed != null;
    final colors = _colorsFor(context);
    final sizes = _sizesFor();

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Semantics(
        button: true,
        enabled: isEnabled,
        child: InteractiveScale(
          enabled: isEnabled,
          child: AnimatedOpacity(
            duration: AppDurations.fast,
            opacity: disabled ? 0.4 : 1,
            child: SizedBox(
              width: width ?? (fullWidth ? double.infinity : null),
              height: sizes.height,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isEnabled ? onPressed : null,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  splashColor: AppColors.primarySoftStrong,
                  highlightColor: Colors.transparent,
                  hoverColor: colors.hover ?? AppColors.surfaceHover,
                  child: Ink(
                    width: width ?? (fullWidth ? double.infinity : null),
                    height: sizes.height,
                    decoration: BoxDecoration(
                      color: colors.background,
                      border: colors.border,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: variant == AppButtonVariant.primary && size == AppButtonSize.xl
                          ? AppShadows.primaryGlow
                          : null,
                    ),
                    child: Container(
                      padding: sizes.padding,
                      alignment: Alignment.center,
                      child: loading
                          ? _spinner(colors)
                          : DefaultTextStyle(
                              style: AppTypography.buttonStyle.copyWith(
                                fontSize: sizes.fontSize,
                                color: colors.foreground,
                                fontWeight: variant == AppButtonVariant.gold ? FontWeight.w700 : FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              child: child,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _spinner(_BtnColors colors) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: colors.foreground,
      ),
    );
  }

  _BtnColors _colorsFor(BuildContext context) {
    switch (variant) {
      case AppButtonVariant.primary:
        return const _BtnColors(
          background: AppColors.primary,
          foreground: AppColors.primaryForeground,
          hover: AppColors.primaryHover,
        );
      case AppButtonVariant.secondary:
        return _BtnColors(
          background: Colors.transparent,
          foreground: AppColors.secondaryForeground,
          border: Border.all(color: AppColors.border),
        );
      case AppButtonVariant.danger:
        return _BtnColors(
          background: Colors.transparent,
          foreground: AppColors.destructive,
          border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
        );
      case AppButtonVariant.destructive:
        return const _BtnColors(
          background: AppColors.destructive,
          foreground: AppColors.destructiveForeground,
        );
      case AppButtonVariant.ghost:
        return const _BtnColors(
          background: Colors.transparent,
          foreground: AppColors.mutedForeground,
        );
      case AppButtonVariant.gold:
        return const _BtnColors(
          background: AppColors.primary,
          foreground: AppColors.primaryForeground,
        );
      case AppButtonVariant.light:
        return const _BtnColors(
          background: AppColors.foreground,
          foreground: AppColors.background,
        );
    }
  }

  _BtnSizes _sizesFor() {
    switch (size) {
      case AppButtonSize.sm:
        return const _BtnSizes(
          fontSize: AppFontSizes.sm,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          height: 32,
        );
      case AppButtonSize.md:
        return const _BtnSizes(
          fontSize: AppFontSizes.sm,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 38,
        );
      case AppButtonSize.lg:
        return const _BtnSizes(
          fontSize: AppFontSizes.md,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          height: 44,
        );
      case AppButtonSize.xl:
        return const _BtnSizes(
          fontSize: AppFontSizes.lg,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          height: 52,
        );
    }
  }
}

class _BtnColors {
  const _BtnColors({
    required this.background,
    required this.foreground,
    this.border,
    this.hover,
  });

  final Color background;
  final Color foreground;
  final Border? border;
  final Color? hover;
}

class _BtnSizes {
  const _BtnSizes({
    required this.fontSize,
    required this.padding,
    required this.height,
  });

  final double fontSize;
  final EdgeInsets padding;
  final double height;
}
