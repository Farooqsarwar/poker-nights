import 'package:flutter/material.dart';

/// The smallest comfortable touch target, in logical pixels.
///
/// 48x48 is the floor both Material and the WCAG 2.2 target-size guidance
/// land on. Flutter enforces it for `IconButton` and friends via
/// `MaterialTapTargetSize.padded`, but NOT for a bare `InkWell` or
/// `GestureDetector` — and hand-rolled taps are the app's dominant pattern,
/// so the floor has to be applied explicitly.
const double kMinTapTarget = 48;

/// Guarantees its child occupies at least [kMinTapTarget] in both axes for
/// the purposes of hit testing, without changing how the child LOOKS.
///
/// The distinction matters: a 22px icon should still render as a 22px icon.
/// What this fixes is the invisible part — the region that actually responds
/// to a finger. Wrapping the child in a larger transparent box costs nothing
/// visually and removes a whole class of "I tapped it and nothing happened".
///
/// Goes INSIDE the tappable, wrapping the icon:
///
/// ```dart
/// InkWell(
///   onTap: ...,
///   child: const MinTapTarget(child: Icon(Icons.menu, size: 22)),
/// )
/// ```
///
/// The placement is load-bearing, and the intuitive order is the wrong one.
/// Wrapped on the OUTSIDE, this reserves 48x48 of layout space but lays the
/// `InkWell` out against loosened constraints, so the ink box — and with it
/// the region that actually hit-tests — stays icon-sized. The dead margin
/// just moves from outside the widget to inside it. On the INSIDE, the
/// `InkWell` sizes to a 48x48 child, so the hit region and the splash both
/// fill the target.
class MinTapTarget extends StatelessWidget {
  const MinTapTarget({
    super.key,
    required this.child,
    this.size = kMinTapTarget,
  });

  final Widget child;

  /// Override only to go LARGER. Going smaller defeats the point.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
