import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../constants/app_constants.dart';
import '../app/typography.dart';
import 'glass_styles.dart';

/// Select dropdown mirroring the web `Select` component.
class AppSelect<T> extends StatefulWidget {
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
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        AnimatedContainer(
          duration: AppDurations.fast,
          decoration: Glass.glassInput(focused: _isFocused),
          child: DropdownButtonFormField<T>(
            focusNode: _focusNode,
            initialValue: widget.value,
            items: widget.items,
            onChanged: widget.onChanged,
            isExpanded: true,
            dropdownColor: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.mutedForeground,
              size: 20,
            ),
            hint: widget.hint != null
                ? Text(
                    widget.hint!,
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
              fillColor: Colors.transparent, // Let Glass surface show through
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

