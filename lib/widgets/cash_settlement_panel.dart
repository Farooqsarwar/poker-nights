import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/cash_game.dart';
import '../services/payment_service.dart';
import '../utils/cash_settlement.dart';
import '../utils/formatters.dart';
import 'app_card.dart';

/// Where the night's money actually ends up.
///
/// Three things a host currently works out on the back of an envelope: who is
/// up and who is down, whether the chips on the table match the money paid in,
/// and — the genuinely tedious one — who hands what to whom.
///
/// D4: "cash games" are named in the free list, not the Premium one, so this
/// is never gated — [tier] is kept only because callers still pass it in.
class CashSettlementPanel extends StatelessWidget {
  const CashSettlementPanel({
    super.key,
    required this.players,
    required this.tier,
  });

  final List<CashPlayer> players;
  final PremiumTier tier;

  @override
  Widget build(BuildContext context) {
    return _Body(players: players);
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.players});

  final List<CashPlayer> players;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Nobody at the table yet.',
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    final standings = CashSettlement.standings(players);
    final transfers = CashSettlement.settle(players);
    final money = CashSettlement.reconcile(players);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Where everyone stands',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final s in standings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(s.name, style: AppTypography.bodyXs),
                      ),
                      Text(
                        // The sign is the information, so it is never dropped.
                        '${s.net >= 0 ? '+' : '−'}${Formatters.money('', s.net.abs())}',
                        style: AppTypography.monoXs.copyWith(
                          fontWeight: FontWeight.w700,
                          color: s.net > 0
                              ? AppColors.success
                              : s.net < 0
                                  ? AppColors.destructive
                                  : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (!money.balances) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              money.difference < 0
                  ? 'There are ${(-money.difference).toStringAsFixed(2)} more '
                      'in chips on the table than has been paid in. Usually a '
                      'buy-in somebody took without it being recorded.'
                  : 'There are ${money.difference.toStringAsFixed(2)} fewer in '
                      'chips than has been paid in. Usually a stack that has '
                      'not been updated since the last hand.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Who pays whom',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                transfers.isEmpty
                    ? 'Nobody owes anybody — the table is square.'
                    : '${transfers.length} payment'
                        '${transfers.length == 1 ? '' : 's'}, and everyone is '
                        'settled.',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              if (transfers.isNotEmpty) const SizedBox(height: AppSpacing.sm),
              for (final t in transfers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.fromName,
                          style: AppTypography.bodyXs,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          t.toName,
                          style: AppTypography.bodyXs,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        Formatters.money('', t.amount),
                        style: AppTypography.monoXs.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (transfers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      // T87: one line per payment, ready for the group chat.
                      final text = transfers
                          .map(
                            (t) =>
                                '${t.fromName} pays ${t.toName} '
                                '${Formatters.money('', t.amount)}',
                          )
                          .join('\n');
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard.')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy as text'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
