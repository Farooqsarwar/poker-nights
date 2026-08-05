import 'package:flutter/material.dart';

class InteractiveScale extends StatefulWidget {
  const InteractiveScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scaleDown = 0.95,
  });

  final Widget child;
  final bool enabled;
  final double scaleDown;

  @override
  State<InteractiveScale> createState() => _InteractiveScaleState();
}

class _InteractiveScaleState extends State<InteractiveScale> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final scale = _isPressed ? widget.scaleDown : (_isHovered ? 1.02 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.deferToChild,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: widget.child,
        ),
      ),
    );
  }
}
