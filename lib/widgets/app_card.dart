import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import 'glass_styles.dart';
import 'interactive_scale.dart';

/// Card mirroring the web `Card` component with premium glassmorphism.
///
/// Uses a frosted-glass surface with semi-transparent background, subtle
/// inner highlight, and ambient primary glow. Hover lifts the card with
/// enhanced shadow when [onTap] is provided.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.glow = false,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.radius = AppRadius.md,
  });

  final Widget child;
  final bool glow;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    final borderRadius = BorderRadius.circular(widget.radius);
    final baseColor = widget.color ?? AppColors.card;
    final baseBorder = widget.borderColor ?? AppColors.border;

    final isElevated = _hovering && widget.onTap != null;
    final shadows = isElevated ? Glass.cardElevatedShadow : Glass.cardShadow;

    final decoration = BoxDecoration(
      color: baseColor.withValues(alpha: Glass.surfaceOpacity),
      borderRadius: borderRadius,
      border: Border.all(
        color: isElevated
            ? baseBorder.withValues(alpha: Glass.borderActiveOpacity)
            : baseBorder.withValues(alpha: Glass.borderOpacity),
      ),
      boxShadow: [
        ...shadows,
        if (widget.glow)
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 32,
          ),
      ],
    );

    return InteractiveScale(
      enabled: widget.onTap != null,
      scaleDown: 0.98,
      child: MouseRegion(
        onEnter: widget.onTap != null ? (_) => setState(() => _hovering = true) : null,
        onExit: widget.onTap != null ? (_) => setState(() => _hovering = false) : null,
        cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: borderRadius,
            highlightColor: widget.onTap != null
                ? AppColors.surfaceHover
                : Colors.transparent,
            splashColor: Colors.transparent,
            child: AnimatedContainer(
              duration: AppDurations.fast,
              decoration: decoration,
              child: ClipRRect(
                borderRadius: borderRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: Glass.blurLight,
                    sigmaY: Glass.blurLight,
                  ),
                  child: _InnerHighlight(
                    borderRadius: borderRadius,
                    child: widget.margin != null
                        ? Padding(
                            padding: widget.margin!,
                            child: widget.padding != null
                                ? Padding(padding: widget.padding!, child: widget.child)
                                : widget.child,
                          )
                        : widget.padding != null
                            ? Padding(padding: widget.padding!, child: widget.child)
                            : widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle top-down inner highlight that gives the glass surface depth.
class _InnerHighlight extends StatelessWidget {
  const _InnerHighlight({
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: Glass.innerHighlight,
      ),
      child: child,
    );
  }
}
