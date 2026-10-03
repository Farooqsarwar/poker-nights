import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';

/// Standard segmented control component with 44px touch targets
/// and Poker Night redesign styling (active crimson/dark surface).
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.labelBuilder,
    this.labels,
    this.icons,
    this.fullWidth = true,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget Function(T value)? labelBuilder;
  final Map<T, String>? labels;
  final Map<T, IconData>? icons;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final val in values)
            fullWidth
                ? Expanded(child: _buildItem(context, val))
                : _buildItem(context, val),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, T val) {
    final isSelected = val == selected;
    final icon = icons?[val];
    final labelText = labels?[val];

    Widget content;
    if (labelBuilder != null) {
      content = labelBuilder!(val);
    } else {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primaryForeground
                  : AppColors.mutedForeground,
            ),
            if (labelText != null) const SizedBox(width: AppSpacing.xs),
          ],
          if (labelText != null)
            Text(
              labelText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primaryForeground
                    : AppColors.mutedForeground,
              ),
            ),
        ],
      );
    }

    return Semantics(
      button: true,
      selected: isSelected,
      child: SizedBox(
        height: 44, // 44px min touch target
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(val),
            borderRadius: BorderRadius.circular(AppRadius.md - 2),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md - 2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
