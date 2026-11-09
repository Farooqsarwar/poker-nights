import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import 'app_card.dart';

/// One label/value line of a [StatRowsCard]. Give either [value] text or a
/// [trailing] widget (an avatar stack, a tag…).
class StatRow {
  const StatRow(this.label, {this.value, this.trailing});

  final String label;
  final String? value;
  final Widget? trailing;
}

/// A card of label-left / value-right rows split by hairlines — the
/// redesign's summary block (A8 invite details, checkout totals, cash-game
/// expected vs. difference, a guest's slot and schedule).
class StatRowsCard extends StatelessWidget {
  const StatRowsCard({super.key, required this.rows});

  final List<StatRow> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md + 2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: rows[i].trailing ??
                        Text(
                          rows[i].value ?? '',
                          textAlign: TextAlign.end,
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
