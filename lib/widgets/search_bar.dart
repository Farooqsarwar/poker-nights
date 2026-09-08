import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';

/// Search field used on lists (group members, history, notifications).
class SearchBar extends StatelessWidget {
  const SearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search…',
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTypography.bodyStyle,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodySm.copyWith(
          color: AppColors.onSurfaceHint,
        ),
        prefixIcon: Icon(
          Icons.search,
          color: AppColors.mutedForeground,
          size: 20,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(
                  Icons.close,
                  color: AppColors.mutedForeground,
                  size: 18,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                  onClear?.call();
                },
              ),
        isDense: true,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: AppColors.ring),
        ),
      ),
    );
  }
}
