import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Select dropdown mirroring the web `Select` component.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String? label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          dropdownColor: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.mutedForeground,
            size: 20,
          ),
          hint: hint != null
              ? Text(
                  hint!,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceHint,
                  ),
                )
              : null,
          style: AppTypography.bodyStyle,
          decoration: InputDecoration(
            hintStyle: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceHint,
            ),
            isDense: true,
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.ring),
            ),
          ),
        ),
      ],
    );
  }
}
