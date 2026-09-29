import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/chip_color.dart';
import 'app_button.dart';
import 'count_stepper.dart';

/// "Fix the count" (Addendum 2, A2-4): a light sheet with one stepper per
/// colour, for the host who opens the box and finds it does not match the set.
///
/// Deliberately not the F5 chip-set editor. It changes tonight's game only
/// (the caller decides what "apply" means) and offers no way to add, rename
/// or re-value a colour.
class FixChipCountSheet extends StatefulWidget {
  const FixChipCountSheet({
    super.key,
    required this.chips,
    required this.onApply,
  });

  final List<ChipColor> chips;

  /// Called with the corrected inventory. Colours keep their value and order.
  final ValueChanged<List<ChipColor>> onApply;

  @override
  State<FixChipCountSheet> createState() => _FixChipCountSheetState();
}

class _FixChipCountSheetState extends State<FixChipCountSheet> {
  late final List<int> _counts = [for (final c in widget.chips) c.quantity];

  bool get _changed {
    for (var i = 0; i < _counts.length; i++) {
      if (_counts[i] != widget.chips[i].quantity) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Set how many of each chip are really in the box. '
          'This changes tonight\'s game only, not your saved chip set.',
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < widget.chips.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: widget.chips[i].colorValue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '${widget.chips[i].color} · ${widget.chips[i].value}',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm,
                  ),
                ),
                CountStepper(
                  value: _counts[i],
                  min: 0,
                  max: 9999,
                  semanticLabel: '${widget.chips[i].color} chips',
                  onChanged: (v) => setState(() => _counts[i] = v),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          onPressed: _changed
              ? () => widget.onApply([
                    for (var i = 0; i < widget.chips.length; i++)
                      widget.chips[i].copyWith(quantity: _counts[i]),
                  ])
              : null,
          child: const Text('Save for tonight'),
        ),
      ],
    );
  }
}
