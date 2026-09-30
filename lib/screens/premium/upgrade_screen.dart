import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_styles.dart';

/// The paywall (Build Spec v3.1 G1, D4).
///
/// The free tier is deliberately complete: a host can run a whole one-table
/// night without paying. §3's monetization principle is explicit that the
/// clock, check-in and basic payouts are never behind the wall — the reason to
/// upgrade is "more tables, more intelligence and more control".
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final _payments = Payments.instance;
  String _selectedPlanId = 'console';
  PremiumTier _tier = PremiumTier.free;
  bool _loading = true;

  /// True while the downgrade is in flight. Changing plan is a billing
  /// action — it must never be possible to fire it twice by tapping twice.
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Re-resolves the tier through the provider.
  ///
  /// Deliberately NOT `_payments.currentTier()`. The device-local mock is only
  /// one of two sources -- a server-held entitlement also grants Premium, and
  /// a build with DEMO_PREMIUM=false ignores the local one entirely. Asking
  /// the mock directly gives an answer the rest of the app disagrees with.
  Future<void> _load() async {
    final app = context.read<AppProvider>();
    await app.loadPremiumTier();
    if (!mounted) return;
    setState(() {
      _tier = app.premiumTier;
      _loading = false;
    });
  }

  static const _features = <String>[
    'Multi-table tournaments',
    'Seasons & points',
    'Custom TV layouts & more displays',
    'Progressive & Mystery bounties',
    'Unlimited saved templates',
    'Graphs & exportable history',
  ];

  /// §3, verbatim. Free on the left, what the money buys on the right.
  static const _comparison = <({String free, String? premium})>[
    (free: 'Account, RSVP, event link and QR', premium: null),
    (free: 'Live view and notifications', premium: null),
    (free: 'One table, up to 9 players', premium: 'Multi-table tournaments'),
    (free: 'Full blind structures and level editing', premium: null),
    (free: 'Check-in, seating and balancing, buy-ins', premium: null),
    (free: 'ICM calculator, deals and payouts', premium: null),
    (free: 'Unlimited tournaments, sync, cash games', premium: null),
    (free: 'One TV display', premium: 'Custom TV layouts & more displays'),
    (free: 'Basic standings', premium: 'Graphs & exportable history'),
    (free: '3 saved templates', premium: 'Unlimited saved templates'),
    (free: 'Fixed bounties', premium: 'Progressive & Mystery bounties'),
    (free: 'Public tools, no account', premium: 'Seasons & points'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppPage(
        maxWidth: 720,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_tier == PremiumTier.premium) return _alreadyPremium();

    return AppPage(
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Center(
            child: IconTile(
              icon: Icons.workspace_premium_rounded,
              size: 64,
              tone: IconTileTone.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Poker Night Premium',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xxxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Multi-table tournaments, seasons, custom TV layouts and more for '
            'the whole group.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final feature in _features)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          // Green ticks, as drawn: crimson marks the plan
                          // price and saving, and stays with the action too
                          // — there is no gold anywhere (no-gold rule).
                          color: AppColors.successText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            feature,
                            style: AppTypography.bodySm,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _planPicker(),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.xl,
            onPressed: () {
              context.push('/checkout?plan=$_selectedPlanId');
            },
            child: const Text('Activate demo Premium'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No payment details are collected in-app.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _comparisonTable(),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final found = await _payments.restore();
                if (!mounted) return;
                await _load();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      found == PremiumTier.premium
                          ? 'Premium restored on this device.'
                          : 'No previous purchase found on this device.',
                    ),
                  ),
                );
              },
              child: Text(
                'Restore purchase',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// Demo pricing remains so the app can exercise the upgrade path without
  /// actually taking a real payment. The purchase is still local-only and does
  /// not reach any real billing provider.
  static const double _minPlanCardWidth = 150;

  Widget _planPicker() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        final plans = PremiumPlan.placeholders;
        final sideBySideWidth =
            (_minPlanCardWidth * plans.length) + (gap * (plans.length - 1));

        if (constraints.maxWidth < sideBySideWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final plan in plans) ...[
                _PlanCard(
                  plan: plan,
                  selected: plan.id == _selectedPlanId,
                  onTap: () => setState(() => _selectedPlanId = plan.id),
                ),
                if (plan != plans.last) const SizedBox(height: gap),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (final plan in plans) ...[
              Expanded(
                child: _PlanCard(
                  plan: plan,
                  selected: plan.id == _selectedPlanId,
                  onTap: () => setState(() => _selectedPlanId = plan.id),
                ),
              ),
              if (plan != plans.last) const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }

  Widget _comparisonTable() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Free',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Premium',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: AppColors.border, height: 1),
          for (final row in _comparison)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            row.free,
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: row.premium == null
                        ? Text(
                            'Included',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  row.premium!,
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
            ),
        ],
      ),
    );
  }

  Widget _alreadyPremium() {
    return AppPage(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Icon(Icons.workspace_premium, size: 48, color: AppColors.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Premium is active',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Multi-table tournaments, AI-optimised structures and the advanced '
            'tooling are all unlocked.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.secondary,
            loading: _cancelling,
            onPressed: () async {
              if (_cancelling) return;
              setState(() => _cancelling = true);
              await _payments.cancel();
              if (!mounted) return;
              await _load();
              if (!mounted) return;
              setState(() => _cancelling = false);
            },
            child: const Text('Switch back to Free'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PremiumPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          // Crimson marks the value: the chosen plan is outlined and tinted
          // crimson — never gold (no-gold rule; §A5 #18: "the selected card
          // has a crimson outline, never gold").
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Glass.solidTint(AppColors.secondary),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (plan.saving != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      // Crimson marks the value (the saving) — there is no
                      // gold anywhere in the design system (no-gold rule).
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      plan.saving!.toUpperCase(),
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.primaryForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              plan.period,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
