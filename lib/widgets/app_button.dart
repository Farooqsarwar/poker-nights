import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';
import 'glass_styles.dart';
import 'interactive_scale.dart';

/// Button mirroring the web `Btn` component with premium glassmorphism.
///
/// Supports glass surfaces for every variant plus a subtle neumorphic
/// inset on press for tactile feedback.
enum AppButtonVariant {
  primary,
  secondary,
  danger,
  ghost,
  gold,
  light,
  destructive,
}

enum AppButtonSize { sm, md, lg, xl }

class AppButton extends StatefulWidget {
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
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressing = false;
  bool _hovering = false;

  bool get _isEnabled =>
      !widget.disabled && !widget.loading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final colors = _colorsFor();
    final sizes = _sizesFor();

    final borderRadius = BorderRadius.circular(AppRadius.md);
    final decoration = _decorationFor(colors, borderRadius);

    return MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: _isEnabled ? (_) => setState(() => _hovering = true) : null,
      onExit: _isEnabled ? (_) => setState(() => _hovering = false) : null,
      child: Semantics(
        button: true,
        enabled: _isEnabled,
        // Raw Listener (not GestureDetector) for the press-visual state: the
        // only tap recognizer in this subtree is the InkWell below, so a quick
        // tap can never be lost to a gesture-arena tie.
        child: Listener(
          onPointerDown:
              _isEnabled ? (_) => setState(() => _pressing = true) : null,
          onPointerUp:
              _isEnabled ? (_) => setState(() => _pressing = false) : null,
          onPointerCancel:
              _isEnabled ? (_) => setState(() => _pressing = false) : null,
          child: InteractiveScale(
            enabled: _isEnabled,
            child: AnimatedOpacity(
              duration: AppDurations.fast,
              opacity: widget.disabled ? 0.4 : 1,
              child: SizedBox(
                width: widget.width ?? (widget.fullWidth ? double.infinity : null),
                height: sizes.height,
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  curve: Curves.easeOut,
                  decoration: _pressing
                      ? _neumorphicPressedDecoration(colors, borderRadius)
                      : decoration,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: borderRadius,
                    child: InkWell(
                      onTap: _isEnabled ? widget.onPressed : null,
                      borderRadius: borderRadius,
                      splashColor: AppColors.primarySoftStrong,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      child: Container(
                        padding: sizes.padding,
                        alignment: Alignment.center,
                        child: widget.loading
                            ? _spinner(colors)
                            : DefaultTextStyle(
                                style: AppTypography.buttonStyle.copyWith(
                                  fontSize: sizes.fontSize,
                                  color: colors.foreground,
                                  fontWeight: widget.variant == AppButtonVariant.gold
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                                child: widget.child,
                              ),
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

  /// A top-left highlight to bottom-right shade, composited ONTO [base].
  ///
  /// Flutter ignores [BoxDecoration.color] whenever a gradient is also set —
  /// the gradient's shader replaces the paint colour outright. Every filled
  /// variant below used to set both, so the fill was silently discarded and
  /// only the sheen painted: a near-transparent button carrying a near-black
  /// label, on a near-black page. That is why the primary call to action on
  /// every screen read as washed out and barely legible.
  ///
  /// The sheen is worth keeping — it is what gives the buttons their depth —
  /// so it is blended into the fill here rather than replacing it.
  ///
  /// PASS [base] WITH ITS ALPHA INTACT. The fills are deliberately
  /// translucent (85–90%) so the page shows through — that translucency IS
  /// the glassmorphism. [Color.alphaBlend] carries a translucent base
  /// through to a translucent result, so handing this an opaque colour
  /// silently flattens the glass into a solid slab.
  LinearGradient _sheenOn(
    Color base, {
    double highlight = 0.12,
    double shade = 0.08,
  }) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(Colors.white.withValues(alpha: highlight), base),
        base,
        Color.alphaBlend(Colors.black.withValues(alpha: shade), base),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  BoxDecoration _decorationFor(_BtnColors colors, BorderRadius borderRadius) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: widget.size == AppButtonSize.xl
              ? Glass.primaryGlow
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    blurRadius: 12,
                    spreadRadius: -1,
                  ),
                ],
          gradient: _sheenOn(
            AppColors.primary.withValues(alpha: 0.85),
            highlight: _hovering ? 0.18 : 0.12,
          ),
        );
      case AppButtonVariant.gold:
        return BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
          boxShadow: Glass.primaryGlow,
          gradient: _sheenOn(
            AppColors.primary.withValues(alpha: 0.85),
            highlight: 0.15,
            shade: 0.06,
          ),
        );
      // Deliberately NOT converted to _sheenOn. The other filled variants set
      // `color` AND `gradient`, so their fill was silently dropped and they
      // rendered as washed-out ghosts of themselves — a bug, because their
      // labels are near-black and only legible on a filled background.
      //
      // This one is different: its label is `secondaryForeground` (light), it
      // carries a border, and the near-transparent result reads as a proper
      // outline button. Giving it a solid fill turned all ~117 of them into
      // filled panels and made the UI look markedly lighter. The rendering is
      // the intended look here, so it stays as it was.
      case AppButtonVariant.secondary:
        return BoxDecoration(
          color: AppColors.card.withValues(alpha: Glass.surfaceSecondaryOpacity),
          borderRadius: borderRadius,
          border: Border.all(
            color: _hovering
                ? AppColors.border.withValues(alpha: Glass.borderActiveOpacity)
                : AppColors.border.withValues(alpha: Glass.borderOpacity),
          ),
          boxShadow: Glass.neumorphicUp,
          gradient: _hovering ? Glass.primarySheen : Glass.innerHighlight,
        );
      case AppButtonVariant.danger:
        return BoxDecoration(
          color: AppColors.destructive.withValues(alpha: _hovering ? 0.20 : 0.12),
          borderRadius: borderRadius,
          border: Border.all(
            color: AppColors.destructive.withValues(
              alpha: _hovering ? 0.40 : 0.25,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.destructive.withValues(alpha: 0.10),
              blurRadius: 12,
            ),
          ],
        );
      case AppButtonVariant.destructive:
        return BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.destructive.withValues(alpha: 0.25),
              blurRadius: 16,
            ),
          ],
          gradient: _sheenOn(
            AppColors.destructive.withValues(alpha: 0.90),
            highlight: 0.10,
            shade: 0.06,
          ),
        );
      case AppButtonVariant.ghost:
        return BoxDecoration(
          color: _hovering
              ? AppColors.card.withValues(alpha: Glass.surfaceSecondaryOpacity)
              : Colors.transparent,
          borderRadius: borderRadius,
          border: _hovering
              ? Border.all(color: AppColors.border.withValues(alpha: Glass.borderOpacity))
              : null,
        );
      case AppButtonVariant.light:
        return BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
          boxShadow: Glass.neumorphicUp,
          gradient: _sheenOn(
            AppColors.foreground.withValues(alpha: 0.90),
            highlight: 0.15,
            shade: 0.05,
          ),
        );
    }
  }

  BoxDecoration _neumorphicPressedDecoration(
    _BtnColors colors,
    BorderRadius borderRadius,
  ) {
    final base = _decorationFor(colors, borderRadius);
    return base.copyWith(
      boxShadow: Glass.neumorphicDown,
      gradient: _pressing
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.06),
                Colors.transparent,
                Colors.white.withValues(alpha: 0.04),
              ],
              stops: const [0.0, 0.4, 1.0],
            )
          : base.gradient,
    );
  }

  _BtnColors _colorsFor() {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _BtnColors(
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
          border: Border.all(
            color: AppColors.destructive.withValues(alpha: 0.3),
          ),
        );
      case AppButtonVariant.destructive:
        return _BtnColors(
          background: AppColors.destructive,
          foreground: AppColors.destructiveForeground,
        );
      case AppButtonVariant.ghost:
        return _BtnColors(
          background: Colors.transparent,
          foreground: AppColors.mutedForeground,
        );
      case AppButtonVariant.gold:
        return _BtnColors(
          background: AppColors.primary,
          foreground: AppColors.primaryForeground,
        );
      case AppButtonVariant.light:
        return _BtnColors(
          background: AppColors.foreground,
          foreground: AppColors.background,
        );
    }
  }

  _BtnSizes _sizesFor() {
    switch (widget.size) {
      case AppButtonSize.sm:
        return const _BtnSizes(
          fontSize: AppFontSizes.sm,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          height: 48,
        );
      case AppButtonSize.md:
        return const _BtnSizes(
          fontSize: AppFontSizes.sm,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          height: 48,
        );
      case AppButtonSize.lg:
        return const _BtnSizes(
          fontSize: AppFontSizes.md,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          height: 48,
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
