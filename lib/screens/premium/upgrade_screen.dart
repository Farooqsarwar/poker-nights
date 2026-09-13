import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../services/payment_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/glass_styles.dart';

/// The paywall (specification v11 §3).
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
  final _payments = MockPaymentService();
  String _selectedPlanId = 'yearly';
  PremiumTier _tier = PremiumTier.free;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tier = await _payments.currentTier();
    if (!mounted) return;
    setState(() {
      _tier = tier;
      _loading = false;
    });
  }

  /// §3, verbatim. Free on the left, what the money buys on the right.
  static const _comparison = <({String free, String? premium})>[
    (free: 'Account, RSVP, event link and QR', premium: null),
    (free: 'Live view and notifications', premium: null),
    (free: 'One table, up to 9 players', premium: 'Multi-table tournaments'),
    (free: 'Basic blind structures', premium: 'AI-optimised structures'),
    (free: 'Check-in, seating, buy-ins', premium: 'Advanced balancing & seating'),
    (free: 'Basic payouts', premium: 'Advanced payouts, ICM, KO/PKO'),
    (free: 'Basic chip handling', premium: 'Chip optimisation & colour-up plans'),
    (free: 'Basic TV display', premium: 'TV customisation & multiple displays'),
    (free: 'Basic history', premium: 'Advanced stats, analytics, exports'),
    (free: 'Public tools, no account', premium: 'Saved presets & advanced AI'),
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
          Text(
            'Run bigger nights',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xxxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Everything you need for a single table is free, and always will '
            'be. Premium is for more tables, more intelligence and more '
            'control.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _planPicker(),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: () => context.push(
              RoutePaths.checkout,
              extra: _selectedPlanId,
            ),
            child: const Text('Continue'),
          ),
          const SizedBox(height: AppSpacing.xl),
          _comparisonTable(),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await _payments.restore();
                if (!mounted) return;
                await _load();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('No previous purchase found on this device.'),
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

  Widget _planPicker() {
    return Row(
      children: [
        for (final plan in PremiumPlan.placeholders) ...[
          Expanded(
            child: _PlanCard(
              plan: plan,
              selected: plan.id == _selectedPlanId,
              onTap: () => setState(() => _selectedPlanId = plan.id),
            ),
          ),
          if (plan != PremiumPlan.placeholders.last)
            const SizedBox(width: AppSpacing.md),
        ],
      ],
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
                    color: AppColors.primary,
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
            onPressed: () async {
              await _payments.cancel();
              if (!mounted) return;
              await _load();
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
          color: selected
              ? AppColors.primarySoft
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
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      plan.saving!,
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.background,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              plan.price,
              style: AppTypography.display(
                size: AppFontSizes.xxl,
                weight: FontWeight.w700,
              ),
            ),
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
