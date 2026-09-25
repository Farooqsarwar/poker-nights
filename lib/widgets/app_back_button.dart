import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';

/// Standard back control: the redesign's small square tile with a chevron —
/// a raised dark surface with a hairline — inside a 44px tap target, with a
/// tooltip and screen-reader label. Replaces the duplicated inline back
/// arrows across detail screens.
class AppBackButton extends StatefulWidget {
  const AppBackButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Go back',
  });

  final VoidCallback onTap;
  final String tooltip;

  @override
  State<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends State<AppBackButton> {
  bool _focused = false;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.sm + 2);
    return Semantics(
      label: widget.tooltip,
      button: true,
      child: Tooltip(
        message: widget.tooltip,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onHover: (h) => setState(() => _hovering = h),
                onFocusChange: (f) => setState(() => _focused = f),
                borderRadius: radius,
                focusColor: Colors.transparent,
                // Pad the ink out to the full 44px so the whole target reacts.
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hovering ? AppColors.surfaceHover : AppColors.muted,
                      borderRadius: radius,
                      border: Border.all(
                        color: _focused
                            ? AppColors.ring
                            : AppColors.border.withValues(alpha: 0.75),
                        width: _focused ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.chevron_left,
                      size: 22,
                      color: AppColors.foreground,
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
}
