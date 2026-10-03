import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/glass_styles.dart';
import '../../widgets/icon_tile.dart';

/// The paywall & Premium Features Hub (Build Spec v3.1 G1, D4).
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
  String _selectedPlanId = 'yearly';
  PremiumTier _tier = PremiumTier.free;
  bool _loading = true;

  /// True while the toggle/downgrade is in flight.
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppProvider>();
    await app.loadPremiumTier();
    if (!mounted) return;
    setState(() {
      _tier = app.premiumTier;
      _loading = false;
    });
  }

  /// Decision D4 Free vs Premium feature comparison.
  static const _comparison = <({String free, String? premium})>[
    (free: 'Account, RSVP, event link and QR', premium: null),
    (free: 'Live view and notifications', premium: null),
    (free: 'One table, up to 9 players', premium: 'Multi-table tournaments (2+ tables)'),
    (free: 'Full blind structures and level editing', premium: null),
    (free: 'Check-in, seating and balancing, buy-ins', premium: null),
    (free: 'ICM calculator, deals and payouts', premium: null),
    (free: 'Unlimited tournaments, sync, cash games', premium: null),
    (free: 'One TV display', premium: 'Custom TV layouts & more displays'),
    (free: 'Basic standings', premium: 'Graphs & exportable history'),
    (free: '3 saved templates', premium: 'Unlimited saved templates'),
    (free: 'Fixed bounties', premium: 'Progressive & Mystery bounties'),
    (free: 'Public tools, no account', premium: 'Seasons & points leaderboards'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppPage(
        maxWidth: 760,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isPremium = _tier == PremiumTier.premium;

    return AppPage(
      maxWidth: 760,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          // Top Status Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RoutePaths.home);
                  }
                },
              ),
              AppTag(
                isPremium ? 'PREMIUM ACTIVE' : 'FREE TIER',
                tone: isPremium ? AppTagTone.primary : AppTagTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Center(
            child: IconTile(
              icon: Icons.workspace_premium_rounded,
              size: 56,
              tone: IconTileTone.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isPremium ? 'Poker Night Premium Active' : 'Poker Night Premium',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isPremium
                ? 'All 6 advanced features are unlocked and ready to use.'
                : 'For groups that outgrow one table.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Instant Demo Toggle Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isPremium
                  ? AppColors.primarySoft
                  : AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isPremium
                    ? AppColors.primarySoftBorder
                    : AppColors.borderSubtle,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      isPremium ? Icons.check_circle_outline : Icons.bolt_outlined,
                      size: 20,
                      color: isPremium ? AppColors.successText : AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        isPremium
                            ? 'You are running simulated Premium'
                            : 'Test Premium features with simulated demo payments',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isPremium
                      ? 'All limits on tables, seasons, presets, bounties and TV are lifted. Tap below to test Free tier behavior.'
                      : 'No real card or payment is needed. One tap unlocks all Premium features locally.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, btnConstraints) {
                    final isNarrow = btnConstraints.maxWidth < 360;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppButton(
                            size: AppButtonSize.md,
                            variant: isPremium
                                ? AppButtonVariant.secondary
                                : AppButtonVariant.primary,
                            loading: _toggling,
                            onPressed: () async {
                              if (_toggling) return;
                              setState(() => _toggling = true);
                              final app = context.read<AppProvider>();
                              await app.toggleDemoPremium();
                              await _load();
                              if (!mounted) return;
                              setState(() => _toggling = false);
                            },
                            child: Text(
                              isPremium
                                  ? 'Switch Back to Free Tier'
                                  : 'Activate Demo Premium',
                            ),
                          ),
                          if (!isPremium) ...[
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              size: AppButtonSize.md,
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                context.push('${RoutePaths.checkout}?plan=$_selectedPlanId');
                              },
                              child: const Text('Simulate Checkout'),
                            ),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            size: AppButtonSize.md,
                            variant: isPremium
                                ? AppButtonVariant.secondary
                                : AppButtonVariant.primary,
                            loading: _toggling,
                            onPressed: () async {
                              if (_toggling) return;
                              setState(() => _toggling = true);
                              final app = context.read<AppProvider>();
                              await app.toggleDemoPremium();
                              await _load();
                              if (!mounted) return;
                              setState(() => _toggling = false);
                            },
                            child: Text(
                              isPremium
                                  ? 'Switch Back to Free Tier'
                                  : 'Activate Demo Premium',
                            ),
                          ),
                        ),
                        if (!isPremium) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppButton(
                              size: AppButtonSize.md,
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                context.push('${RoutePaths.checkout}?plan=$_selectedPlanId');
                              },
                              child: const Text('Simulate Checkout'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 6 Interactive Feature Cards Showcase
          _featuresShowcase(isPremium),
          const SizedBox(height: AppSpacing.xl),

          // Plan Picker (if not premium)
          if (!isPremium) ...[
            Text(
              'Choose a Plan',
              style: AppTypography.display(
                size: AppFontSizes.lg,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _planPicker(),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Free vs Premium Comparison Table
          Text(
            'Free vs. Premium Comparison',
            style: AppTypography.display(
              size: AppFontSizes.lg,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Specification Decision D4 monetization boundary:',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _comparisonTable(),
          const SizedBox(height: AppSpacing.xl),

          // Restore Purchase
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

  Widget _featuresShowcase(bool isPremium) {
    final items = [
      (
        icon: Icons.table_restaurant_outlined,
        title: 'Two or more tables',
        desc: 'Multi-table tournaments (10–50+ players) with automated TDA table balancing and redraws.',
        actionLabel: 'Host 2+ Tables',
        onTap: () => context.push(RoutePaths.createTournament),
      ),
      (
        icon: Icons.leaderboard_outlined,
        title: 'Seasons & points',
        desc: 'Club championship leaderboards calculated after every game using field-size weighted, 10-7-5-3-1 ladder, or custom formulas.',
        actionLabel: 'View Seasons',
        onTap: () => context.push(RoutePaths.standings),
      ),
      (
        icon: Icons.tv_outlined,
        title: 'Custom TV layouts & displays',
        desc: 'Custom text scaling for large rooms, multi-screen modes, and cycle pacing on your scoreboard.',
        actionLabel: 'Launch TV Mode',
        onTap: () => context.push(RoutePaths.tvMode),
      ),
      (
        icon: Icons.military_tech_outlined,
        title: 'Progressive & Mystery bounties',
        desc: 'Bounties that increase with each knockout (PKO) or custom mystery bounty prize pools.',
        actionLabel: 'Configure Bounties',
        onTap: () => context.push(RoutePaths.createTournament),
      ),
      (
        icon: Icons.list_alt_outlined,
        title: 'Unlimited saved templates',
        desc: 'Save unlimited custom blind structures, rebuy rules, and chip configs without the 3-preset cap.',
        actionLabel: 'Open Presets',
        onTap: () => context.push(RoutePaths.presets),
      ),
      (
        icon: Icons.analytics_outlined,
        title: 'Graphs & exportable history',
        desc: 'Tournament audit logs, net cash settlement, chip equity trends, and CSV spreadsheet exports.',
        actionLabel: 'View History & Export',
        onTap: () => context.push(RoutePaths.history),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'All 6 Premium Features',
              style: AppTypography.display(
                size: AppFontSizes.lg,
                weight: FontWeight.w700,
              ),
            ),
            AppTag(
              isPremium ? 'ALL UNLOCKED' : 'PREMIUM',
              tone: isPremium ? AppTagTone.success : AppTagTone.primary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          isPremium
              ? 'All 6 advanced capabilities are active. Tap any feature below to test it:'
              : 'Defined in specification §D-G. Tap any feature below to explore:',
          style: AppTypography.bodyXs.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 540;
            if (isWide) {
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: (constraints.maxWidth - AppSpacing.md) / 2,
                      child: _FeatureCard(item: item, isPremium: isPremium),
                    ),
                ],
              );
            }
            return Column(
              children: [
                for (final item in items) ...[
                  _FeatureCard(item: item, isPremium: isPremium),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
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
                                    fontWeight: FontWeight.w600,
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
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item, required this.isPremium});

  final ({
    IconData icon,
    String title,
    String desc,
    String actionLabel,
    VoidCallback onTap,
  }) item;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isPremium ? AppColors.successText : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  item.title,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppTag(
                isPremium ? 'UNLOCKED' : 'PREMIUM',
                tone: isPremium ? AppTagTone.success : AppTagTone.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.desc,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            size: AppButtonSize.sm,
            fullWidth: true,
            variant: isPremium ? AppButtonVariant.primary : AppButtonVariant.secondary,
            onPressed: item.onTap,
            child: Text(item.actionLabel),
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
