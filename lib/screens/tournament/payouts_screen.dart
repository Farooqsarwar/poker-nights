import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/medal_icon.dart';
import '../../widgets/page_header.dart';

/// C-payouts — Payouts (everyone; host view toggle for the host).
///
/// Route `/t/:id/payouts`. Previously this path reused the player-live view;
/// the spec gives payouts its own layout: pool, entries/rebuys/add-ons,
/// medal rows, the KO pot line, and the host-only gross/organiser/net lines
/// behind a Host view toggle. Non-admin copies carry an empty ladder and a
/// paid-place count only, so members see positions with '—' for money —
/// the same convention as the player-live Payouts tab.
class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  bool _hostView = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;
    if (game == null) {
      return AppPage(
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              onBack: () => context.pop(),
              title: 'Payouts',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No game loaded.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }
    final isAdmin = app.isAdmin;
    final showHost = isAdmin && _hostView;
    final prizes = game.structure.prizes;
    final paidDisplay = game.structure.paidPlacesForDisplay;
    final rows = prizes.isNotEmpty
        ? prizes
        : [
            for (var i = 1; i <= paidDisplay; i++) Prize(place: i, amount: 0),
          ];
    final entries = game.players.length;
    final rebuys =
        game.players.fold<int>(0, (sum, p) => sum + p.rebuys + p.reEntries);
    final addOns = game.players.where((p) => p.hasAddOn).length;
    final knockouts =
        game.players.fold<int>(0, (sum, p) => sum + p.knockouts);
    final showMoney = prizes.isNotEmpty;
    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            onBack: () => context.pop(),
            title: 'Payouts',
            subtitle: game.settings.name,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  game.prizePoolLabel,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  showMoney
                      ? Formatters.prize(game.structure.prizePool)
                      : '—',
                  style: AppTypography.display(size: AppFontSizes.xxl).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$entries ${entries == 1 ? 'entry' : 'entries'}'
                  ' · $rebuys ${rebuys == 1 ? 'rebuy' : 'rebuys'}'
                  ' · $addOns ${addOns == 1 ? 'add-on' : 'add-ons'}',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  paidDisplay > 0
                      ? '$paidDisplay paid of $entries entries'
                      : 'No paid places yet',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (game.settings.koEnabled) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isAdmin
                        ? 'Bounty pot ${Formatters.prize(game.settings.koAmount * knockouts)} — paid at each knockout'
                        : 'Bounty pot — paid at each knockout',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Host view',
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        AppToggle(
                          value: _hostView,
                          onChanged: (v) =>
                              setState(() => _hostView = v),
                        ),
                      ],
                    ),
                  ),
                if (showHost) ...[
                  Text(
                    'Gross ${Formatters.prize(game.structure.prizePool + game.structure.organizerAmount)}'
                    ' · organiser ${game.settings.organizerPct}% '
                    '(${Formatters.prize(game.structure.organizerAmount)})',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Prize pool ${Formatters.prize(game.structure.prizePool)}',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (rows.isEmpty)
                  Text(
                    'No prizes set yet.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  )
                else
                  for (final p in rows)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: p.place <= 3
                                ? MedalIcon(p.place, size: AppFontSizes.lg)
                                : Text(
                                    '${p.place}.',
                                    style: AppTypography.monoSm.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _ordinalPlace(p.place),
                              style: AppTypography.bodySm,
                            ),
                          ),
                          Text(
                            showMoney ? Formatters.prize(p.amount) : '—',
                            style: AppTypography.monoSm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                if (isAdmin) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: () => context.push(RoutePaths.deal),
                    child: const Text('Calculate a chop (ICM)'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ordinalPlace(int place) {
    if (place == 1) return '1st';
    if (place == 2) return '2nd';
    if (place == 3) return '3rd';
    return '${place}th';
  }
}
