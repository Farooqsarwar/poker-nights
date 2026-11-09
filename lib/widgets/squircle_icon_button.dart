import 'package:flutter/material.dart';

import '../app/colors.dart';

/// Squircle icon button matching the mobile-first redesign.
///
/// Features a 44x44 rounded container with subtle border, dark background,
/// and smooth ink response.
///
/// Every instance of this is an icon-only control, so its accessible name has
/// to come from somewhere. [tooltip] is the way to give it one; when that is
/// omitted the name is read off the icon itself via [_labelsFor]. The old
/// fallback — the literal string `"Button"` — announced the same thing for
/// every button in the app, which is not a name, and left the four real
/// controls that never pass a tooltip (the header back buttons and the admin
/// overflow menu) effectively unnamed.
class SquircleIconButton extends StatefulWidget {
  const SquircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.tooltip,
    this.size = 44,
    this.iconSize = 22,
    this.borderRadius = 14,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? tooltip;
  final double size;
  final double iconSize;
  final double borderRadius;

  /// Icons whose meaning is fixed enough to name without the caller saying so.
  /// Deliberately short: a mapping that guessed at anything more would be
  /// inventing an accessible name rather than recovering one.
  ///
  /// `final`, not `const` — [IconData] overrides `==`, which a const map key
  /// may not do.
  static final Map<IconData, String> _labelsFor = {
    Icons.chevron_left: 'Back',
    Icons.arrow_back: 'Back',
    Icons.chevron_right: 'Next',
    Icons.arrow_forward: 'Next',
    Icons.more_vert: 'More options',
    Icons.more_horiz: 'More options',
    Icons.menu: 'Menu',
    Icons.close: 'Close',
  };

  @override
  State<SquircleIconButton> createState() => _SquircleIconButtonState();
}

class _SquircleIconButtonState extends State<SquircleIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBg = widget.backgroundColor ?? AppColors.muted;
    final effectiveBorder = widget.borderColor ?? AppColors.borderSubtle;
    final effectiveIconColor = widget.iconColor ?? AppColors.foreground;
    // A null label is the honest answer for an icon with no known meaning: the
    // node stays a button and it is up to the call site to pass a `tooltip`,
    // rather than the app announcing a name that may be wrong.
    final label = widget.tooltip ?? SquircleIconButton._labelsFor[widget.icon];

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        // Only when there is a message to show. `Tooltip` adds its own
        // semantics hint, so an empty one would add noise rather than a name.
        message: widget.tooltip ?? '',
        excludeFromSemantics: true,
        child: _body(effectiveBg, effectiveBorder, effectiveIconColor),
      ),
    );
  }

  Widget _body(Color bg, Color borderColor, Color iconColor) {
    final borderRadius = BorderRadius.circular(widget.borderRadius);
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: widget.onPressed,
        onFocusChange: (focused) => setState(() => _focused = focused),
        borderRadius: borderRadius,
        splashColor: AppColors.primarySoftStrong,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // Keyboard focus ring, painted in front of the 1 px border so it
          // layers over it rather than replacing it, and sized inside the box
          // so focusing never shifts the icon. Same colour and 2 px weight
          // AppButton uses, so focus looks the same app-wide.
          foregroundDecoration: _focused
              ? BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(color: AppColors.ring, width: 2),
                )
              : null,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
