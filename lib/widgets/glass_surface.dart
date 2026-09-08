import 'dart:ui';

import 'package:flutter/material.dart';

import 'glass_styles.dart';

/// A wrapper that applies a frosted-glass blur + overlay to its child.
///
/// Use this on surfaces that need real backdrop blur (sidebar, modal,
/// bottom nav). For smaller elements, [Glass] decorations suffice without
/// the expensive blur.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.blur,
    this.decoration,
    this.borderRadius,
    this.enableBlur = true,
  });

  final Widget child;
  final double? blur;
  final Decoration? decoration;
  final BorderRadius? borderRadius;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    if (!enableBlur) {
      return DecoratedBox(decoration: decoration ?? const BoxDecoration(), child: child);
    }

    final effectiveBlur = blur ?? Glass.blurHeavy;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: DecoratedBox(
          decoration: decoration ?? const BoxDecoration(),
          child: child,
        ),
      ),
    );
  }
}

/// Animated glass surface that transitions its opacity on hover.
class GlassHoverSurface extends StatefulWidget {
  const GlassHoverSurface({
    super.key,
    required this.child,
    required this.decoration,
    this.hoverDecoration,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final Decoration decoration;
  final Decoration? hoverDecoration;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  State<GlassHoverSurface> createState() => _GlassHoverSurfaceState();
}

class _GlassHoverSurfaceState extends State<GlassHoverSurface> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: _hovering && widget.hoverDecoration != null
              ? widget.hoverDecoration!
              : widget.decoration,
          child: widget.child,
        ),
      ),
    );
  }
}
