import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/live_game.dart';
import '../utils/structure_verification.dart';

/// Shows what this device concluded when it checked the structure itself
/// (addendum §7, acceptance criterion 15).
///
/// Silent when the structure verifies, which is almost always. A banner that
/// says "all correct" on every screen every night is furniture — people stop
/// reading it, including on the night it changes.
///
/// It is also silent when the check could not run. "I cannot tell" is not
/// "something is wrong", and showing a warning for it would burn the warning's
/// credibility on missing chip data.
class StructureAuditBanner extends StatelessWidget {
  const StructureAuditBanner({super.key, required this.game});

  final LiveGame game;

  @override
  Widget build(BuildContext context) {
    final audit = StructureVerification.audit(game);
    if (!audit.isMismatch) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.report_gmailerrorred_outlined,
                size: 18,
                color: AppColors.destructive,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'This structure does not match its settings',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This device rebuilt the structure from the tournament settings '
            'and got something different. Levels edited by hand are allowed '
            'and are not counted here.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final d in audit.differences)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.destructive,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      d,
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
