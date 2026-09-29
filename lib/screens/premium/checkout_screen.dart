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
import '../../widgets/glass_styles.dart';

/// Checkout.
///
/// There is no payment provider behind this screen and no card is taken, so it
/// does not ask for one. Collecting card details that go nowhere would only
/// teach people to type them into a form that means nothing. What the button
/// does is switch Premium on for this device through [MockPaymentService], and
/// it is labelled that way.
///
/// The commercial terms (price, billing period, who pays, and whether Apple and
/// Google taking 15–30% on the native apps is acceptable) are not agreed yet.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.planId});

  final String? planId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _payments = Payments.instance;

  bool _processing = false;
  PaymentResult? _result;

  PremiumPlan get _plan => PremiumPlan.placeholders.firstWhere(
        (p) => p.id == widget.planId,
        orElse: () => PremiumPlan.placeholders
            .firstWhere((p) => p.id == 'yearly'),
      );

  Future<void> _activate() async {
    setState(() => _processing = true);
    final result = await _payments.purchase(_plan);
    if (!mounted) return;
    // Re-resolve the tier rather than assuming it changed. The device-local
    // demo entitlement is only one of two sources, and in a build with
    // DEMO_PREMIUM=false it grants nothing at all -- so the only honest way to
    // know what the user now has is to ask.
    if (result.succeeded) {
      await context.read<AppProvider>().loadPremiumTier();
      if (!mounted) return;
    }
    setState(() {
      _processing = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_result?.succeeded == true) return _success();

    return AppPage(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          _testModeBanner(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Activate Premium',
            style: AppTypography.display(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _orderSummary(),
          if (_result?.succeeded == false) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _result!.message ?? 'Premium could not be activated.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.destructiveText,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            loading: _processing,
            onPressed: _processing ? null : _activate,
            child: Text(
              _processing
                  ? 'Activating…'
                  : 'Activate Premium (demo — no payment)',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.ghost,
            onPressed: _processing
                ? null
                : () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RoutePaths.upgrade);
                    }
                  },
            child: const Text('Cancel'),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _testModeBanner() {
    // Tied to which implementation is live, so it cannot be left showing on a
    // real checkout or missing from a simulated one.
    if (!Payments.isSimulated) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Demo — nothing is charged and no card is needed. Billing is '
              'not connected yet, so this only switches Premium on for this '
              'device.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderSummary() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Poker Night Premium',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_plan.name} (${_plan.period})',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _plan.price,
                // Money is white (no-gold rule, B4.9); the Pay button
                // carries crimson.
                style: AppTypography.display(
                  size: AppFontSizes.xl,
                  weight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Due today (demo)',
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '0',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _success() {
    // Whether anything actually unlocked. Saying "You are Premium" over a
    // build that grants nothing is the kind of small lie that costs a
    // demo its credibility the moment somebody taps through to the feature.
    final granted =
        context.select<AppProvider, PremiumTier>((p) => p.premiumTier) ==
        PremiumTier.premium;
    return AppPage(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Glass.solidTint(
                granted ? AppColors.success : AppColors.warning,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              granted ? Icons.check : Icons.science_outlined,
              size: 32,
              color: granted ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            granted ? 'You are Premium' : 'Checkout complete',
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            granted
                ? 'More tables, seasons and points, custom TV layouts, '
                    'bounties, unlimited templates and graphs and export are '
                    'unlocked on this device. Nothing was charged.'
                : 'Nothing was charged and Premium has not been granted -- '
                    'this build does not switch it on from the checkout.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _testModeBanner(),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: () => context.go(RoutePaths.home),
            child: const Text('Back to Poker Night'),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
