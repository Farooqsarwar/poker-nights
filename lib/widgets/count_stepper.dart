import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import 'glass_styles.dart';

/// A minus / value / plus control for a small integer.
///
/// Typing a head-count into a text field is the wrong affordance for a value
/// that is almost always adjusted by one or two from a sensible default: the
/// keyboard covers the form on a phone, and a free-text field admits "2O" and
/// empty strings that then have to be validated. A stepper cannot produce an
/// invalid value at all, and the client asked for exactly this pattern.
///
/// [onChanged] is called with the clamped result; it is never called with a
/// value outside [min]..[max], and the disabled arrow is dimmed rather than
/// hidden so the limit is visible rather than mysterious.
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.suffix,
    this.semanticLabel,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  /// Rendered after the number, e.g. "players".
  final String? suffix;

  final String? semanticLabel;

  void _nudge(int delta) {
    final next = (value + delta).clamp(min, max);
    if (next != value) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      value: '$value',
      child: Container(
        decoration: BoxDecoration(
          color: Glass.solidTint(AppColors.secondary),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperButton(
              icon: Icons.remove,
              enabled: value > min,
              onTap: () => _nudge(-step),
              tooltip: 'Decrease',
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                child: Text(
                  suffix == null ? '$value' : '$value $suffix',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ),
            _StepperButton(
              icon: Icons.add,
              enabled: value < max,
              onTap: () => _nudge(step),
              tooltip: 'Increase',
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: enabled ? onTap : null,
        // 44x44 is the smallest comfortable touch target; the client is using
        // this one-handed at a poker table.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.primary : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
