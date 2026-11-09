import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../models/chip_palette.dart';
import 'min_tap_target.dart';

/// One swatch in the F5 fixed chip palette (Addendum 1 §2 row 2).
///
/// Carries its name under the colour, not only as a tooltip: §B4 rule 16 says
/// colour never carries meaning alone, and the owner is colour blind. A ring
/// rather than a tick marks the selection, so the chip's own colour stays
/// unobscured — the whole point of the swatch is to match it against a real
/// chip on the table.
class ChipPaletteSwatch extends StatelessWidget {
  const ChipPaletteSwatch({
    super.key,
    required this.entry,
    this.size = 38,
    required this.selected,
    required this.onTap,
  });

  final NamedChipColour entry;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: entry.name,
      selected: selected,
      button: true,
      child: MinTapTarget(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Color(entry.hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.foreground
                      : AppColors.borderSubtle,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.name,
              style: AppTypography.bodyXs.copyWith(
                fontSize: 10,
                color: selected
                    ? AppColors.foreground
                    : AppColors.mutedForeground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
