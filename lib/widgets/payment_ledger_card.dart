import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/live_game.dart';
import '../models/payment_record.dart';
import 'app_card.dart';
import 'glass_styles.dart';

/// What the app has collected, and what it has not (QA case PN-DPAY-013).
///
/// **Host only.** Section 23 forbids members and guests from receiving
/// rebuy/add-on totals or the gross collected, and summing this ledger yields
/// exactly those — which is why `projectionFor` strips `payments` for every
/// non-admin role. Rendering this on a player screen would hand it straight
/// back, so don't.
///
/// The reconciliation line is the point of the card. The prize pool counts
/// what is IN PLAY; the ledger counts what went through the app. A host who
/// took cash at the door will see a gap, and that gap is correct — showing it
/// is the difference between "the app disagrees with itself" and "there is 60
/// in my pocket the app has not been told about".
class PaymentLedgerCard extends StatelessWidget {
  const PaymentLedgerCard({
    super.key,
    required this.game,
    required this.inPlay,
    required this.collected,
    required this.outstanding,
  });

  final LiveGame game;
  final int inPlay;
  final int collected;
  final int outstanding;

  @override
  Widget build(BuildContext context) {
    // Newest first — a host checking the ledger is almost always looking for
    // the thing that just happened.
    final records = [...game.payments]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Payments',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Admin only',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ReconciliationRow(
            label: 'In play',
            value: inPlay,
            note: 'What the prize pool is built from',
          ),
          _ReconciliationRow(
            label: 'Through the app',
            value: collected,
            note: 'Recorded here',
          ),
          if (outstanding != 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: outstanding > 0
                    ? AppColors.warning.withValues(alpha: 0.12)
                    : AppColors.destructive.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                outstanding > 0
                    ? 'Taken outside the app: $outstanding. That is normal if '
                          'people paid cash — nothing is wrong.'
                    : 'The ledger shows ${-outstanding} more than is in play. '
                          'Worth checking for a payment recorded twice.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.foreground,
                ),
              ),
            ),
          ],
          if (records.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nothing recorded through the app yet.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.border, height: 1),
            const SizedBox(height: AppSpacing.sm),
            for (final r in records)
              _LedgerRow(record: r, game: game),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Simulated — no money has moved.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconciliationRow extends StatelessWidget {
  const _ReconciliationRow({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final int value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTypography.bodySm),
                Text(
                  note,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$value',
            style: AppTypography.monoSm.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.record, required this.game});

  final PaymentRecord record;
  final LiveGame game;

  @override
  Widget build(BuildContext context) {
    final name = game.players
            .where((p) => p.id == record.playerId)
            .firstOrNull
            ?.name ??
        'Unknown player';

    final (Color colour, IconData icon) = switch (record.status) {
      PaymentStatus.paid => (AppColors.success, Icons.check),
      PaymentStatus.failed => (AppColors.destructive, Icons.close),
      PaymentStatus.cancelled => (AppColors.mutedForeground, Icons.remove),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Glass.solidTint(colour),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: colour),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$name · ${record.purpose.label}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyXs,
            ),
          ),
          // A failed or cancelled attempt reached no money, so its amount is
          // struck through rather than reading as a contribution.
          Text(
            '${record.amount}',
            style: AppTypography.monoXs.copyWith(
              color: record.status.countsTowardPool
                  ? AppColors.foreground
                  : AppColors.mutedForeground,
              decoration: record.status.countsTowardPool
                  ? null
                  : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }
}
